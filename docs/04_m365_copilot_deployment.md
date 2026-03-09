# M365 Copilot Declarative Agent 登録・デプロイガイド

> **ドキュメントバージョン**: 1.0  
> **作成日**: 2026-03-09  
> **前提ドキュメント**: [03_deployment_guide.md](./03_deployment_guide.md)

---

## 概要

本ドキュメントでは、Azure AI Foundry で構築したデータ照会エージェントを M365 Copilot の **Declarative Agent** として登録し、Teams Admin Center からテナント全体にデプロイするまでの手順を説明します。

### 前提条件

| 要件 | 詳細 |
|------|------|
| M365 Copilot ライセンス | M365 Copilot が付与されたユーザーが対象テナントに存在すること |
| Azure AI Foundry エージェント | [03_deployment_guide.md](./03_deployment_guide.md) の Step 7 が完了していること |
| APIM ゲートウェイ URL | Foundry Agent を呼び出す APIM エンドポイントが稼働していること |
| Microsoft Entra ID アプリ登録 | OAuth 2.0 認証用のアプリが登録されていること |
| Teams 管理者権限 | Teams Admin Center へのアクセス権限を持つアカウント |
| Node.js 18+ | Teams Toolkit CLI のインストールに必要 |

---

## Step 1: Entra ID アプリ登録

M365 Copilot から Foundry Agent API を呼び出す際の OAuth 2.0 認証に使用するアプリを登録します。

```bash
# アプリ登録
az ad app create \
  --display-name "foundry-data-agent-m365" \
  --sign-in-audience "AzureADMyOrg" \
  --query "{appId:appId, objectId:id}" \
  -o json

# 出力例:
# {
#   "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",  ← APP_ID
#   "objectId": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
# }
```

### API スコープの追加

```bash
APP_ID="<上記で取得した appId>"

# API スコープの追加 (Agent.Invoke)
az ad app update \
  --id $APP_ID \
  --identifier-uris "api://foundry-agent" \
  --set api.oauth2PermissionScopes='[{
    "id": "'$(uuidgen)'",
    "adminConsentDescription": "Foundry データ照会エージェントを呼び出す",
    "adminConsentDisplayName": "Agent.Invoke",
    "isEnabled": true,
    "type": "User",
    "userConsentDescription": "データ照会エージェントを呼び出すことを許可します",
    "userConsentDisplayName": "Agent.Invoke",
    "value": "Agent.Invoke"
  }]'
```

### クライアントシークレットの作成

```bash
# クライアントシークレット作成
az ad app credential reset \
  --id $APP_ID \
  --display-name "m365-copilot" \
  --years 1 \
  --query password \
  -o tsv
# 出力値を安全な場所（Key Vault）に保管してください
```

---

## Step 2: appPackage の設定ファイル更新

### 2.1 manifest.json の APP_ID を設定

```bash
cd agents/appPackage

# APP_ID の置換
APP_ID="<Step 1 で取得した appId>"
sed -i "s/{{APP_ID}}/$APP_ID/g" manifest.json
```

### 2.2 ai-plugin.json の OAUTH_REGISTRATION_ID を設定

Teams Toolkit を使用すると OAuth 登録 ID が自動生成されますが、手動設定の場合は以下の手順で取得します。

```bash
# OAuth 登録 ID は Teams Toolkit のパッケージング時に自動設定されます
# 手動設定が必要な場合は teamsapp package 実行後に .publish/appPackage.zip 内を確認してください
```

### 2.3 openapi.json の APIM URL と テナント ID を設定

```bash
# APIM ゲートウェイ URL の取得
APIM_URL=$(az deployment group show \
  --resource-group <RG_NAME> \
  --name main \
  --query properties.outputs.apimGatewayUrl.value -o tsv)

# テナント ID の取得
TENANT_ID=$(az account show --query tenantId -o tsv)

# openapi.json の更新
sed -i "s/{{APIM_GATEWAY_URL}}/$APIM_URL/g" openapi.json
sed -i "s/{{TENANT_ID}}/$TENANT_ID/g" openapi.json
```

---

## Step 3: アプリアイコンの準備

`agents/appPackage/` ディレクトリに以下のアイコンファイルを配置します。

| ファイル名 | サイズ | 説明 |
|-----------|--------|------|
| `color.png` | 192×192 px | カラーアイコン（アプリ詳細画面に表示） |
| `outline.png` | 32×32 px | アウトラインアイコン（透過PNG、Teams サイドバーに表示） |

> **注意**: アイコンファイルは `manifest.json` の `icons` セクションで参照されています。  
> テスト用にプレースホルダ画像を使用する場合は、上記サイズの PNG ファイルを作成してください。

```bash
# テスト用プレースホルダ生成（ImageMagick が使用可能な場合）
convert -size 192x192 xc:#0078D4 color.png
convert -size 32x32 xc:#FFFFFF -fill '#0078D4' -draw 'circle 16,16 16,4' outline.png
```

---

## Step 4: appPackage のビルド（zip 作成）

### Teams Toolkit CLI を使用する方法（推奨）

```bash
# Teams Toolkit CLI のインストール
npm install -g @microsoft/teamsapp-cli

# バージョン確認
teamsapp --version

# appPackage のパッケージング
cd agents/appPackage
teamsapp package

# 生成物: ./build/appPackage.zip
```

### 手動で zip を作成する方法

```bash
cd agents/appPackage

# 必要ファイルの確認
ls -la
# manifest.json
# declarativeAgent.json
# ai-plugin.json
# openapi.json
# color.png
# outline.png

# zip パッケージ作成
zip -r ../../appPackage.zip \
  manifest.json \
  declarativeAgent.json \
  ai-plugin.json \
  openapi.json \
  color.png \
  outline.png

cd ../..
echo "パッケージ作成完了: appPackage.zip"
```

---

## Step 5: Teams Admin Center からのデプロイ

### 5.1 Teams Admin Center へアクセス

1. [Microsoft Teams 管理センター](https://admin.teams.microsoft.com/) にアクセス
2. **Teams アプリ** → **アプリを管理** を選択

### 5.2 カスタムアプリのアップロード

1. **[カスタムアプリをアップロード]** ボタンをクリック
2. 作成した `appPackage.zip`（または Teams Toolkit で生成した `build/appPackage.zip`）をアップロード
3. アプリが一覧に表示されることを確認

   > アップロード後、**「データ照会エージェント」** という名前で表示されます。

### 5.3 アプリの許可設定

1. アップロードしたアプリ名をクリック
2. **[許可]** タブで以下を確認・設定:
   - **状態**: 許可済み
   - **組織全体のアクセス許可**: 必要に応じて **[組織全体のデフォルト]** を設定

### 5.4 アプリのデプロイポリシー設定

1. **Teams アプリ** → **セットアップ ポリシー** に移動
2. 対象のポリシー（例: **グローバル（組織全体のデフォルト）**）をクリック
3. **[インストール済みアプリ]** セクションで **[アプリを追加]** をクリック
4. 「データ照会エージェント」を検索して追加

   > これにより、ポリシーが適用されたユーザーのテナントに自動インストールされます。

---

## Step 6: Microsoft 365 管理センターでの Copilot 拡張設定

M365 Copilot で Declarative Agent を使用可能にするための追加設定です。

### 6.1 Microsoft 365 管理センターへアクセス

1. [Microsoft 365 管理センター](https://admin.microsoft.com/) にアクセス
2. **設定** → **統合アプリ** を選択

### 6.2 アプリの展開

1. **[アプリを展開]** をクリック
2. **[カスタムアプリ]** を選択し、`appPackage.zip` をアップロード
3. デプロイ対象ユーザーを選択:
   - **全組織**: 全ユーザーに展開
   - **特定のグループ**: テスト用グループに限定展開（推奨）
4. **[次へ]** → **[展開]** をクリック

---

## Step 7: 動作確認

### 7.1 M365 Copilot での確認

1. [Microsoft 365 Copilot](https://m365.cloud.microsoft/chat) にアクセス
2. 左サイドバーまたは Copilot チャット右側の **エージェント一覧** に **「データ照会エージェント」** が表示されることを確認
3. エージェントを選択し、以下のテストプロンプトを入力:

   ```
   Electronicsカテゴリの在庫状況を教えてください
   ```

4. エージェントが Azure AI Foundry を経由してデータを取得し、回答することを確認

### 7.2 会話スターターの確認

Declarative Agent 選択後、以下の会話スターターが表示されることを確認してください:

- 「在庫状況を確認する」
- 「今月の売上サマリー」
- 「在庫切れ商品の確認」

### 7.3 Application Insights でのトレース確認

```kql
// Azure Portal > Application Insights > ログ
traces
| where message contains "tool_call" or message contains "foundry"
| project timestamp, message, customDimensions
| order by timestamp desc
| take 20
```

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| エージェントが Copilot に表示されない | デプロイポリシー未適用 | Teams Admin Center のセットアップポリシーに「データ照会エージェント」が追加されているか確認 |
| M365 Copilot ライセンスエラー | ライセンス未割り当て | 対象ユーザーに M365 Copilot ライセンスが割り当てられているか確認 |
| `manifest.json` のバリデーションエラー | スキーマ不一致 | `manifestVersion` が Teams の要件（1.19 以上）を満たしているか確認 |
| 401 認証エラー | OAuth 設定ミス | Entra ID アプリの `APP_ID`・スコープ・リダイレクト URI が正しく設定されているか確認 |
| 「アクセス許可が必要です」ダイアログ | 管理者同意が未実施 | Entra ID でアプリに対して管理者同意を付与する |
| API 呼び出しが失敗する | APIM URL の設定ミス | `openapi.json` の `servers.url` が正しい APIM ゲートウェイ URL を指しているか確認 |
| zip のアップロードが拒否される | ファイル欠損 | `color.png` と `outline.png` が zip に含まれているか確認 |

---

## 管理者同意の付与

アプリが組織のユーザーにより利用されるためには、テナント管理者が OAuth スコープの同意を付与する必要があります。

```bash
# Azure Portal > Microsoft Entra ID > アプリの登録 > <アプリ名> >
# API のアクセス許可 > [<組織名> に管理者の同意を与えます] ボタンをクリック
```

または Azure CLI で:

```bash
APP_ID="<appId>"
TENANT_ID=$(az account show --query tenantId -o tsv)

az ad app permission admin-consent --id $APP_ID
```

---

## 関連リソース

| リソース | URL |
|---------|-----|
| Microsoft 365 Copilot 拡張機能概要 | https://learn.microsoft.com/microsoft-365-copilot/extensibility/overview-declarative-agent |
| Declarative agents for Microsoft 365 Copilot | https://learn.microsoft.com/microsoft-365-copilot/extensibility/overview-declarative-agent |
| Teams アプリマニフェストスキーマ | https://learn.microsoft.com/microsoftteams/platform/resources/schema/manifest-schema |
| Teams Toolkit CLI | https://learn.microsoft.com/microsoftteams/platform/toolkit/teams-toolkit-cli |
| Microsoft 365 管理センター | https://admin.microsoft.com/ |
| Teams 管理センター | https://admin.teams.microsoft.com/ |

---

*本ドキュメントは作業の進行に合わせて継続的に更新されます。*
