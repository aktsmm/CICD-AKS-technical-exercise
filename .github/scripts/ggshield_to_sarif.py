#!/usr/bin/env python3
"""
Convert GitGuardian ggshield JSON findings into SARIF output.
(Enhanced version: adds uriBaseId and relative path normalization for GitHub Code Scanning)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Dict, Iterable, List

# SARIF Schema URL
SARIF_SCHEMA = "https://json.schemastore.org/sarif-2.1.0.json"

# Severity mapping from GitGuardian → SARIF
SEVERITY_MAP = {
    "critical": "error",
    "high": "error",
    "medium": "warning",
    "low": "warning",
    "info": "note",
    "warning": "warning",
    "error": "error",
}


def load_json(path: Path) -> Dict:
    """Load JSON data from disk."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise SystemExit(f"入力ファイルが見つかりません: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"JSON の読み込みに失敗しました: {exc}") from exc


def normalize_rule_id(raw_rule: Dict) -> str:
    """Pick the most informative rule identifier available."""
    candidates = (
        raw_rule.get("id"),
        raw_rule.get("rule_id"),
        raw_rule.get("identifier"),
        raw_rule.get("name"),
    ) if isinstance(raw_rule, dict) else (None,)
    for candidate in candidates:
        if candidate:
            return str(candidate)
    return "UNSPECIFIED_RULE"


def normalize_severity(raw_rule: Dict) -> str:
    """Translate GitGuardian severity into SARIF level."""
    severity = None
    if isinstance(raw_rule, dict):
        severity = raw_rule.get("severity") or raw_rule.get("level")
    if isinstance(severity, str):
        return SEVERITY_MAP.get(severity.lower(), "warning")
    return "warning"


def extract_description(raw_rule: Dict) -> str:
    """Extract or fallback rule description."""
    if not isinstance(raw_rule, dict):
        return "Secret detected by ggshield."
    return raw_rule.get("message") or raw_rule.get("description") or "Secret detected by ggshield."


def iter_policy_breaks(data: Dict) -> Iterable[Dict]:
    """Yield policy breaks regardless of ggshield CLI schema version."""
    if "policy_breaks" in data and isinstance(data["policy_breaks"], list):
        yield from data["policy_breaks"]
        return

    # Legacy schema storing findings under "secrets"
    if "secrets" in data and isinstance(data["secrets"], list):
        for secret in data["secrets"]:
            occurrences = secret.get("occurrences", [])
            rule = secret.get("policy") or secret.get("rule") or {}
            matches = []
            for occurrence in occurrences:
                matches.append(
                    {
                        "filename": occurrence.get("filename")
                        or occurrence.get("file")
                        or occurrence.get("path"),
                        "line_start": occurrence.get("line_start")
                        or occurrence.get("line")
                        or occurrence.get("line_begin"),
                        "index_start": occurrence.get("index_start"),
                        "index_end": occurrence.get("index_end"),
                        "match": occurrence.get("match"),
                    }
                )
            yield {
                "matches": matches,
                "rule": rule,
                "occurrence": secret,
            }


def build_sarif(data: Dict) -> Dict:
    """Build SARIF structure from ggshield findings."""
    results: List[Dict] = []
    rules: Dict[str, Dict] = {}
    repo_root = Path.cwd()

    for policy_break in iter_policy_breaks(data):
        matches = policy_break.get("matches") or []

        # ggshield v1.40+ uses "occurrences" instead of "matches"
        if not matches and isinstance(policy_break.get("occurrences"), list):
            for occurrence in policy_break["occurrences"]:
                matches.append(
                    {
                        "filename": occurrence.get("filename")
                        or occurrence.get("file")
                        or occurrence.get("path"),
                        "line_start": occurrence.get("line_start")
                        or occurrence.get("line")
                        or occurrence.get("line_begin"),
                        "index_start": occurrence.get("index_start"),
                        "index_end": occurrence.get("index_end"),
                        "match": occurrence.get("match") or occurrence.get("secret_hash"),
                    }
                )

        raw_rule = policy_break.get("rule") or policy_break.get("policy")
        if not isinstance(raw_rule, dict):
            raw_rule = {"name": str(policy_break.get("break_type") or "policy_break")}
        rule_id = normalize_rule_id(raw_rule)
        sarif_level = normalize_severity(raw_rule)
        description = extract_description(raw_rule)

        # Register rule metadata once per rule id
        if rule_id not in rules:
            rules[rule_id] = {
                "id": rule_id,
                "name": rule_id,
                "shortDescription": {"text": description[:120]},
                "fullDescription": {"text": description},
                "defaultConfiguration": {"level": sarif_level},
                "help": {"text": description},
            }

        if not matches:
            # No location information; still emit a finding
            results.append(
                {
                    "ruleId": rule_id,
                    "level": sarif_level,
                    "message": {"text": description},
                    "locations": [],
                }
            )
            continue

        for match in matches:
            file_path = match.get("filename") or "(unknown file)"
            line = match.get("line_start") or 1
            start_col = match.get("index_start") or 1
            end_col = match.get("index_end") or start_col
            message_text = match.get("match") or description

            # Normalize file path (absolute → relative)
            try:
                relative_path = str(Path(file_path).resolve().relative_to(repo_root))
            except Exception:
                relative_path = str(file_path)

            results.append(
                {
                    "ruleId": rule_id,
                    "level": sarif_level,
                    "message": {"text": message_text},
                    "locations": [
                        {
                            "physicalLocation": {
                                "artifactLocation": {
                                    "uri": relative_path,
                                    "uriBaseId": "SRCROOT"  # ★ 必須: GitHub がファイルを認識する
                                },
                                "region": {
                                    "startLine": int(line),
                                    "startColumn": int(start_col),
                                    "endColumn": int(end_col),
                                },
                            }
                        }
                    ],
                }
            )

    sarif = {
        "$schema": SARIF_SCHEMA,
        "version": "2.1.0",
        "runs": [
            {
                "tool": {
                    "driver": {
                        "name": "GitGuardian ggshield",
                        "informationUri": "https://docs.gitguardian.com/ggshield/reference/commands/secret_scan",
                        "rules": list(rules.values()),
                    }
                },
                "results": results,
            }
        ],
    }

    return sarif


def write_sarif(path: Path, sarif: Dict) -> None:
    """Persist SARIF output to disk."""
    with path.open("w", encoding="utf-8") as handle:
        json.dump(sarif, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def main() -> None:
    input_path = Path("ggshield-results.json")
    output_path = Path("ggshield-results.sarif")

    data = load_json(input_path)
    sarif = build_sarif(data)
    write_sarif(output_path, sarif)

    print(f"SARIF を {output_path} に出力しました。")


if __name__ == "__main__":
    try:
        main()
    except SystemExit as exc:
        print(exc, file=sys.stderr)
        raise
