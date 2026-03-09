# デプロイガイド

## 前提条件

### ツール
| ツール | バージョン | インストール |
|--------|-----------|-------------|
| Azure CLI | 2.65+ | `winget install -e --id Microsoft.AzureCLI` |
| Azure Developer CLI (azd) | 1.12+ | `winget install microsoft.azd` |
| Docker Desktop | 27+ | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Python | 3.12+ | `winget install -e --id Python.Python.3.12` |

### Azure 権限
- サブスクリプション: **Owner** または **Contributor + User Access Administrator**
- Entra ID: **Application Administrator**（APIM JWT 検証用アプリ登録のため）

---

## Step 1: リポジトリのクローンと初期設定

```bash
git clone https://github.com/yuyalush/foundry_selfmcp.git
cd foundry_selfmcp

# Azure ログイン
az login
azd auth login

# サブスクリプション選択
az account set --subscription "<SUBSCRIPTION_ID>"
```

---

## Step 2: パラメータファイルの編集

[infra/main.bicepparam](../infra/main.bicepparam) を編集します。

```bicep
// SQL 管理者の Entra オブジェクト ID を取得
az ad signed-in-user show --query id -o tsv

// パラメータファイルに設定
param sqlAdminObjectId = '<取得した ID>'
param sqlAdminLoginName = '<YOUR_UPN@example.com>'
param apimPublisherEmail = '<your-email@example.com>'
```

---

## Step 3: インフラのプロビジョニング

```bash
# azd 環境の初期化
azd env new dev

# インフラのみプロビジョニング（コンテナデプロイは後）
azd provision
```

> **所要時間**: APIM Premium v2 の作成に約 30〜45 分かかります。

プロビジョニング完了後、以下のリソースが作成されます:
- VNET (`fmcp-dev-vnet`)
- Log Analytics + Application Insights
- Key Vault
- Azure SQL Database (Serverless)
- Azure AI Search (Standard)
- Azure Container Registry (Premium)
- Azure Container Apps Environment + MCP Server App (ダミーイメージ)
- Azure API Management (Premium v2)
- Azure AI Foundry Hub + Project + GPT-4o デプロイ

---

## Step 4: データベースの初期化

Container Apps は Private Link 内にあるため、直接接続できません。  
以下のいずれかの方法でスキーマとサンプルデータを適用します。

### 方法 A: Azure Bastion + Jump Box (推奨)

```bash
# Bastion Host のデプロイ (別途)
az vm create \
  --resource-group <RG_NAME> \
  --name jumpbox \
  --image Ubuntu2204 \
  --vnet-name fmcp-dev-vnet \
  --subnet snet-shared \
  --admin-username azureuser \
  --generate-ssh-keys \
  --size Standard_B1s

# Bastion 経由で Jump Box に接続し、sqlcmd を実行
# スキーマ適用
sqlcmd -S fmcp-dev-sql.database.windows.net \
  -d fmcp-dev-db \
  --authentication-method=ActiveDirectoryIntegrated \
  -i database/schema.sql

# サンプルデータ適用
sqlcmd -S fmcp-dev-sql.database.windows.net \
  -d fmcp-dev-db \
  --authentication-method=ActiveDirectoryIntegrated \
  -i database/sample_data.sql
```

### 方法 B: GitHub Actions ワークフロー (CI/CD)

`.github/workflows/db-migrate.yml` を作成して自動化することも可能です。  
Self-hosted Runner を VNET 内にデプロイする必要があります。

---

## Step 5: コンテナイメージのビルドとデプロイ

```bash
# ACR ログイン
ACR_NAME=$(az deployment group show \
  --resource-group <RG_NAME> \
  --name main \
  --query properties.outputs.acrLoginServer.value -o tsv)

az acr login --name $ACR_NAME

# イメージビルドと Push
cd src/mcp-server
docker build -t $ACR_NAME/mcp-server:latest .
docker push $ACR_NAME/mcp-server:latest

cd ../..

# Container Apps のイメージ更新
az containerapp update \
  --name fmcp-dev-mcp \
  --resource-group <RG_NAME> \
  --image $ACR_NAME/mcp-server:latest
```

または `azd deploy` でまとめて実行できます:

```bash
azd deploy
```

---

## Step 6: メタデータのアップロード

AI Search インデックスにデータディクショナリをアップロードします。

```bash
# 依存関係インストール
pip install azure-search-documents azure-identity

# アップロード実行
SEARCH_ENDPOINT=$(az deployment group show \
  --resource-group <RG_NAME> \
  --name main \
  --query properties.outputs.aiSearchEndpoint.value -o tsv)

python database/metadata/upload_metadata.py \
  --endpoint $SEARCH_ENDPOINT \
  --index-name metadata-index \
  --dict-path database/metadata/data_dictionary.json
```

> Jump Box または Private Link 経由でアクセス可能な環境から実行してください。

---

## Step 7: Foundry エージェントのデプロイ

```bash
# Foundry Project エンドポイントの取得
PROJECT_ENDPOINT=$(az ml workspace show \
  --name fmcp-dev-project \
  --resource-group <RG_NAME> \
  --query properties.discoveryUrl -o tsv)

# APIM Gateway URL の取得
MCP_URL=$(az deployment group show \
  --resource-group <RG_NAME> \
  --name main \
  --query properties.outputs.mcpApiUrl.value -o tsv)

# 依存関係インストール
pip install azure-ai-projects pyyaml

# エージェントデプロイ
python agents/deploy_agent.py \
  --project-endpoint $PROJECT_ENDPOINT \
  --mcp-server-url $MCP_URL
```

成功すると `.azure/agent_config.json` にエージェント ID が保存されます。

---

## Step 8: M365 Copilot Declarative Agent のパッケージング

```bash
# Teams Toolkit (CLI) のインストール
npm install -g @microsoft/teamsfx-cli

# appPackage パッケージング
cd agents/appPackage

# manifest.json の APP_ID を更新
APP_ID=$(uuidgen)  # または az ad app create --display-name mcp-poc ... --query appId
sed -i "s/{{APP_ID}}/$APP_ID/" manifest.json

# パッケージ作成
teamsapp package

# 管理センターでサイドロード or Teams Admin Center からデプロイ
```

> **M365 Copilot ライセンス**が必要です。

---

## 動作確認

### MCP Server の直接テスト (Jump Box から)

```bash
# ヘルスチェック
curl https://<MCP_INTERNAL_FQDN>/health

# メタデータ取得
curl -X POST https://<APIM_URL>/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(az account get-access-token --resource api://mcp-server --query accessToken -o tsv)" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "get_metadata",
      "arguments": {}
    }
  }'
```

### Application Insights でのログ確認

Azure Portal → Application Insights → ライブ メトリック からリアルタイム確認できます。

KQL クエリ例:
```kql
traces
| where message contains "tool_call"
| project timestamp, message, customDimensions
| order by timestamp desc
| take 20
```

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| APIM が 401 を返す | JWT 検証失敗 | Foundry の Managed Identity に `api://mcp-server` オーディエンスが設定されているか確認 |
| MCP サーバが 500 を返す | SQL 接続失敗 | MCP Identity に SQL の `db_datareader` ロールが付与されているか確認 |
| AI Search から結果が返らない | インデックス未作成 | Step 6 のメタデータアップロードが完了しているか確認 |
| Container Apps が起動しない | イメージ Pull 失敗 | MCP Identity に ACR の `AcrPull` ロールが付与されているか確認 |

---

## リソースの削除

```bash
# azd で全リソースを削除
azd down --purge

# Key Vault のソフト削除をパージ
az keyvault purge --name fmcp-dev-kv
```
