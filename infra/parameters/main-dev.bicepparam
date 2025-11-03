// デモ環境 (dev) 向けのメイン テンプレート用パラメーター定義。
// シークレット値はパイプラインから上書きする想定でプレースホルダーを配置しています。
using '../main.bicep'

param resourceGroupName = 'rg-bbs-cicd-aks'
param location = 'japaneast'
param environment = 'dev'
// 実運用では CLI や GitHub Actions の入力で安全に差し替える。
param mongoAdminPassword = 'REPLACE-ME-VIA-PIPELINE'
