# Security Policy

## ⚠️ Important Notice

**This project intentionally contains security vulnerabilities for educational purposes (Wiz Technical Exercise).**

All vulnerabilities are documented, tracked, and used to demonstrate security detection and remediation capabilities.

---

## 🔒 Reporting a Vulnerability

If you discover an **unintentional** security vulnerability in this project, please report it responsibly:

### Option 1: GitHub Security Advisory (Recommended)

1. Go to https://github.com/aktsmm/CICD-AKS-technical-exercise/security/advisories
2. Click **"New draft security advisory"**
3. Fill in the template with details
4. Submit for review

### Option 2: Private Email

- **Email**: security@example.com (placeholder - update with actual contact)
- **PGP Key**: Available on request
- **Expected Response**: Within 48 hours

### Option 3: GitHub Issue (Low Severity Only)

For low-severity issues that are not security-critical, you may create a public GitHub issue.

---

## 📋 Known Vulnerabilities (Intentional)

The following vulnerabilities are **intentionally implemented** as part of the Wiz Technical Exercise requirements:

### 🔴 Critical Severity

#### GHSA-001: Internet-facing SSH Port on MongoDB VM

- **CVSS**: 9.8 Critical
- **Status**: Known, intentional for demo
- **Location**: [`infra/modules/vm-mongodb.bicep:123`](../infra/modules/vm-mongodb.bicep)
- **Description**: SSH port (22) exposed to internet (0.0.0.0/0) through NSG rules
- **Impact**: Brute-force attacks, unauthorized VM access
- **Mitigation**: Restrict sourceAddressPrefix to specific IPs or use Azure Bastion
- **Wiz Detection**: ✅ "Internet-facing VM with SSH enabled"

#### GHSA-003: Publicly Accessible MongoDB Backup Storage

- **CVSS**: 9.1 Critical
- **Status**: Known, intentional for demo
- **Location**: [`infra/modules/storage.bicep:45`](../infra/modules/storage.bicep)
- **Description**: Blob container with `publicAccess: 'Blob'` allows anonymous downloads
- **Impact**: Data exfiltration, credential exposure
- **Mitigation**: Set `publicAccess: 'None'` and use Private Endpoints
- **Wiz Detection**: ✅ "Public Storage Container with Sensitive Data"
- **Public URL Example**: `https://stwizdevj2axc7dgverlk.blob.core.windows.net/backups/mongodb_backup_*.tar.gz`

#### GHSA-102: Hardcoded MongoDB Credentials in Environment Variables

- **CVSS**: 9.8 Critical
- **Status**: Partially mitigated (Kubernetes Secrets)
- **Location**: [`app/k8s/deployment.yaml:30`](../app/k8s/deployment.yaml)
- **Description**: MongoDB connection string with embedded credentials
- **Impact**: Credential leakage if pod is compromised
- **Mitigation**: Use Azure Key Vault + Secrets Store CSI Driver
- **Wiz Detection**: ✅ "Hardcoded Secrets in Container Environment"

### 🟠 High Severity

#### GHSA-002: Excessive Cloud Permissions on MongoDB VM

- **CVSS**: 8.1 High
- **Status**: Known, intentional for demo
- **Location**: [`infra/modules/vm-mongodb.bicep:89`](../infra/modules/vm-mongodb.bicep)
- **Description**: Managed Identity assigned Contributor role (can create/delete VMs)
- **Impact**: Lateral movement, privilege escalation, resource manipulation
- **Mitigation**: Assign minimal required permissions (Storage Blob Data Contributor only)
- **Wiz Detection**: ✅ "Overprivileged Cloud Identity"

#### GHSA-101: Overprivileged Kubernetes Pod (cluster-admin)

- **CVSS**: 8.8 High
- **Status**: Known, intentional for demo
- **Location**: [`app/k8s/rbac.yaml:10`](../app/k8s/rbac.yaml)
- **Description**: Default ServiceAccount bound to cluster-admin ClusterRole
- **Impact**: Full cluster compromise if pod is exploited
- **Mitigation**: Create dedicated ServiceAccount with least-privilege RBAC
- **Wiz Detection**: ✅ "Overprivileged Kubernetes Workload"

#### GHSA-201: Disabled Security Scanning in CI/CD

- **CVSS**: 7.3 High
- **Status**: Known, intentional for demo
- **Location**: [`.github/workflows/02-1.app-deploy.yml:45`](../.github/workflows/02-1.app-deploy.yml)
- **Description**: Trivy vulnerability scanner commented out in pipeline
- **Impact**: Vulnerable container images deployed to production
- **Mitigation**: Uncomment Trivy action and fail build on HIGH/CRITICAL findings
- **Wiz Detection**: ✅ "Missing Security Gates in Pipeline"

#### GHSA-202: Secrets Stored in GitHub Repository

- **CVSS**: 8.2 High
- **Status**: Mitigated (GitHub Secrets)
- **Location**: [`.github/workflows/01.infra-deploy.yml:20`](../.github/workflows/01.infra-deploy.yml)
- **Description**: MongoDB password stored in GitHub Secrets (encrypted at rest)
- **Impact**: Compromised GitHub account exposes secrets
- **Mitigation**: Use Azure Key Vault with Managed Identity
- **Wiz Detection**: ✅ "Credentials in CI/CD Variables"

### 🟡 Medium Severity

#### GHSA-004: Outdated MongoDB Version (4.4.29)

- **CVSS**: 6.5 Medium
- **Status**: Known, intentional (project requirement)
- **Location**: [`infra/scripts/install-mongodb.sh:15`](../infra/scripts/install-mongodb.sh)
- **Description**: MongoDB 4.4.29 has known CVEs (e.g., CVE-2021-32050)
- **Impact**: Denial of service, potential remote code execution
- **Mitigation**: Upgrade to MongoDB 7.0+ with security patches
- **Wiz Detection**: ✅ "Outdated Database Version with Known CVEs"

#### GHSA-005: Outdated Operating System (Ubuntu 20.04)

- **CVSS**: 5.9 Medium
- **Status**: Known, intentional (project requirement)
- **Location**: [`infra/modules/vm-mongodb.bicep:67`](../infra/modules/vm-mongodb.bicep)
- **Description**: Ubuntu 20.04 LTS (released April 2020) is >1 year old
- **Impact**: Missing security patches for OS vulnerabilities
- **Mitigation**: Upgrade to Ubuntu 22.04 LTS or later
- **Wiz Detection**: ✅ "Outdated OS Version"

#### GHSA-103: Missing Rate Limiting on Web Application

- **CVSS**: 6.1 Medium
- **Status**: Known, not implemented for simplicity
- **Location**: [`app/app.js:25`](../app/app.js)
- **Description**: Express.js application lacks rate limiting middleware
- **Impact**: Denial of service via request flooding
- **Mitigation**: Add `express-rate-limit` middleware
- **Wiz Detection**: ❌ (Application-level control, not infrastructure)

---

## 🛡️ Security Controls Implemented

### Infrastructure Level

- ✅ **Network Segmentation**: MongoDB in separate subnet (10.0.2.0/24)
- ✅ **Authentication Required**: MongoDB enforces username/password auth
- ✅ **Automated Backups**: Daily cron job to Azure Blob Storage
- ✅ **Managed Identity**: VM uses Azure AD identity for resource access
- ✅ **Private AKS Subnet**: Kubernetes nodes in private subnet (10.0.1.0/24)

### Application Level

- ✅ **Kubernetes Secrets**: Credentials injected via Secret resources
- ✅ **Container Registry**: Images stored in Azure Container Registry (ACR)
- ✅ **HTTPS Ready**: Ingress controller supports TLS termination
- ✅ **Input Validation**: Basic sanitization in Express.js routes

### CI/CD Pipeline

- ✅ **Infrastructure as Code**: Bicep templates with version control
- ✅ **Automated Deployment**: GitHub Actions workflows
- ✅ **Pull Request Validation**: Bicep linting on PR
- ⚠️ **Security Scanning**: Trivy available but disabled (demo purpose)

---

## 🔍 Security Scanning Tools

### Enabled

- ✅ **Dependabot Alerts**: Automated dependency vulnerability scanning
- ✅ **Secret Scanning**: Prevents credential leaks in commits
- ✅ **CodeQL Analysis**: Static analysis for code vulnerabilities
- ✅ **Bicep Linting**: Infrastructure code validation

### Available but Disabled (for Demo)

- ⚠️ **Trivy Container Scanning**: Image vulnerability detection
- ⚠️ **OWASP Dependency Check**: Third-party library CVE scanning
- ⚠️ **Checkov**: IaC security policy validation

---

## 📝 Responsible Disclosure Guidelines

### For Unintentional Vulnerabilities

If you discover a vulnerability that is **not listed above**:

1. **Do NOT** create a public GitHub issue
2. **Do** use Security Advisories or private email
3. **Allow** 90 days for remediation before public disclosure
4. **Provide** detailed reproduction steps and proof of concept
5. **Receive** credit in our security acknowledgments page

### Expected Timeline

- **Initial Response**: 48 hours
- **Triage & Validation**: 7 days
- **Fix Development**: 30 days
- **Patch Release**: 60 days
- **Public Disclosure**: 90 days (coordinated with reporter)

---

## 🎯 Wiz Technical Exercise Context

This repository is part of a technical interview exercise for Wiz. The intentional vulnerabilities demonstrate:

1. **Understanding of Security Risks**: Recognition of common cloud misconfigurations
2. **Detection Capabilities**: How security tools like Wiz identify these issues
3. **Remediation Knowledge**: Practical solutions to mitigate each vulnerability
4. **Defense in Depth**: Layered security controls across infrastructure, application, and pipeline

### Presentation Notes

During the Wiz presentation, each vulnerability will be:

- ✅ Explained with technical details
- ✅ Demonstrated with live proof-of-concept
- ✅ Mapped to CVSS scores and CWE categories
- ✅ Compared: "How would Wiz detect this vs GitHub tools?"
- ✅ Remediated with best-practice solutions

---

## 📚 Security Resources

### Documentation

- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Azure Foundations Benchmark](https://www.cisecurity.org/benchmark/azure)

### Tools

- [Wiz Security Platform](https://www.wiz.io/)
- [Azure Defender](https://azure.microsoft.com/en-us/services/azure-defender/)
- [Trivy](https://github.com/aquasecurity/trivy)
- [Checkov](https://www.checkov.io/)

### Training

- [Azure Security Engineer Associate](https://docs.microsoft.com/en-us/certifications/azure-security-engineer/)
- [Certified Kubernetes Security Specialist (CKS)](https://www.cncf.io/certification/cks/)

---

## 🙏 Security Acknowledgments

We thank the following individuals for responsibly disclosing security issues:

- _No unintentional vulnerabilities reported yet_

---

## 📞 Contact

**Project Maintainer**: Tatsumi Yamamoto  
**Repository**: https://github.com/aktsmm/CICD-AKS-technical-exercise  
**Purpose**: Wiz Technical Exercise (Educational)

---

**Last Updated**: 2025-10-31  
**Version**: 1.0.0  
**Status**: Active (Demo Project)
