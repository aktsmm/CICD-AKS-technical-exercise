// ガードレール テンプレート用の dev 環境パラメーター。
// デプロイ名の一意化はテンプレート側 utcNow でカバーするため環境名のみ指定。
using '../policy-guardrails.bicep'

param environment = 'dev'
