// ================================================================
// main.bicepparam - 開発環境パラメータ
// ================================================================
using './main.bicep'

param environmentName = 'dev'
param location = 'japaneast'

// APIM
param apimPublisherEmail = 'admin@example.com'
param apimPublisherName = 'MCP PoC Admin'

// SQL Entra ID 管理者
// az ad signed-in-user show --query id -o tsv で取得
param sqlAdminObjectId = '<YOUR_ENTRA_OBJECT_ID>'
param sqlAdminLoginName = '<YOUR_UPN_OR_GROUP_NAME>'

// コンテナイメージ (azd deploy 後に更新)
param containerImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
