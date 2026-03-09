# アーキテクチャ設計: M365 Copilot × Azure AI Foundry × MCP 統合基盤

> **ドキュメントバージョン**: 1.0  
> **作成日**: 2026-03-09  
> **前提ドキュメント**: [01_poc_concept.md](./01_poc_concept.md)

---

## 1. アーキテクチャ全体図

```
┌─────────────────────────────────────────────────────────────────────┐
│  Microsoft 365 テナント                                               │
│  ┌─────────────────────┐                                            │
│  │  M365 Copilot       │                                            │
│  │  (Declarative Agent)│                                            │
│  └──────────┬──────────┘                                            │
└─────────────┼───────────────────────────────────────────────────────┘
              │ HTTPS (Entra ID OAuth 2.0)
              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Azure サブスクリプション                                              │
│                                                                     │
│  ┌─────────────────────────── VNET (10.0.0.0/16) ──────────────────┐│
│  │                                                                  ││
│  │  ┌──────────────────────────────────────────────────────────┐   ││
│  │  │  AI Foundry Subnet (10.0.1.0/24)                         │   ││
│  │  │  ┌─────────────────────────────────────────────────┐     │   ││
│  │  │  │  Azure AI Foundry Project                       │     │   ││
│  │  │  │  ┌───────────────┐  ┌──────────────────────┐   │     │   ││
│  │  │  │  │  Agent Service│  │  Azure OpenAI         │   │     │   ││
│  │  │  │  │  (GPT-4o)     │  │  (GPT-4o-mini embed) │   │     │   ││
│  │  │  │  └───────┬───────┘  └──────────────────────┘   │     │   ││
│  │  │  │          │ MCP Tool 呼び出し                     │     │   ││
│  │  │  └──────────┼──────────────────────────────────────┘     │   ││
│  │  └─────────────┼────────────────────────────────────────────┘   ││
│  │                │                                                  ││
│  │                ▼ Private Endpoint                                 ││
│  │  ┌─────────────────────────────────────────────────────────┐     ││
│  │  │  APIM Subnet (10.0.2.0/24)                              │     ││
│  │  │  ┌──────────────────────────────────────────────────┐   │     ││
│  │  │  │  Azure API Management (Premium)                  │   │     ││
│  │  │  │  - JWT 検証 (Entra ID)                           │   │     ││
│  │  │  │  - レート制限 (100 req/min per client)           │   │     ││
│  │  │  │  - Application Insights ログ連携                 │   │     ││
│  │  │  │  - PII マスキングポリシー                        │   │     ││
│  │  │  └──────────────────────────┬───────────────────────┘   │     ││
│  │  └─────────────────────────────┼───────────────────────────┘     ││
│  │                                │                                  ││
│  │                                ▼ VNET Integration                 ││
│  │  ┌─────────────────────────────────────────────────────────┐     ││
│  │  │  Container Apps Subnet (10.0.3.0/24)                    │     ││
│  │  │  ┌──────────────────────────────────────────────────┐   │     ││
│  │  │  │  Azure Container Apps Environment                │   │     ││
│  │  │  │  ┌────────────────────────────────────────────┐  │   │     ││
│  │  │  │  │  MCP Server (Streamable HTTP)              │  │   │     ││
│  │  │  │  │  - query_inventory tool                    │  │   │     ││
│  │  │  │  │  - query_customers tool                    │  │   │     ││
│  │  │  │  │  - query_orders tool                       │  │   │     ││
│  │  │  │  │  - get_metadata tool                       │  │   │     ││
│  │  │  │  └────────────────────────────────────────────┘  │   │     ││
│  │  │  └──────────────────────────┬───────────────────────┘   │     ││
│  │  └─────────────────────────────┼───────────────────────────┘     ││
│  │                                │                                  ││
│  │         ┌──────────────────────┼──────────────────┐              ││
│  │         │                      │ Private Endpoint  │              ││
│  │         ▼                      ▼                   ▼              ││
│  │  ┌──────────────┐  ┌──────────────────┐  ┌───────────────┐       ││
│  │  │ Data Subnet  │  │  DB Subnet        │  │ Shared Subnet │       ││
│  │  │ (10.0.4.0/24)│  │  (10.0.5.0/24)   │  │ (10.0.6.0/24) │       ││
│  │  │              │  │                  │  │               │       ││
│  │  │ Azure AI     │  │ Azure SQL DB     │  │ Azure Key     │       ││
│  │  │ Search       │  │ (Business        │  │ Vault         │       ││
│  │  │ (Data Dict + │  │  Critical)       │  │               │       ││
│  │  │  Vector)     │  │                  │  │ Azure Monitor │       ││
│  │  └──────────────┘  └──────────────────┘  │ + App Insights│       ││
│  │                                           └───────────────┘       ││
│  └──────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. コンポーネント詳細設計

### 2.1 M365 Copilot 統合

#### Declarative Agent の登録

Azure AI Foundry で作成したエージェントを M365 Copilot に Declarative Agent として公開するには、Teams App Manifest (appPackage) を作成して管理者が Teams Admin Center でデプロイする。

```json
// appPackage/manifest.json (抜粋)
{
  "copilotAgents": {
    "declarativeAgents": [
      {
        "id": "foundry-data-agent",
        "file": "declarativeAgent.json"
      }
    ]
  }
}
```

**参考**: [Copilot extensibility - Declarative agents](https://learn.microsoft.com/microsoft-365-copilot/extensibility/overview-declarative-agent)

---

### 2.2 Azure AI Foundry Agent

#### リソース構成

| リソース | SKU/設定 | 用途 |
|---------|---------|------|
| Azure AI Foundry Hub | Standard | プロジェクト管理・接続管理 |
| Azure AI Foundry Project | - | エージェント定義・デプロイ |
| Azure OpenAI | GPT-4o (2024-11-20) | 推論モデル |
| Azure OpenAI | text-embedding-3-small | ベクトル埋め込み |

#### エージェント設定

```yaml
# agents/data-agent.yaml
name: data-query-agent
description: |
  業務データへの自然言語クエリを処理するエージェント。
  在庫・顧客・注文データを照会し、業務上の質問に答える。
model: gpt-4o
instructions: |
  あなたは業務データ照会の専門エージェントです。
  ユーザーからのデータ照会要求を受け取り、以下の手順で回答してください：
  
  1. まず get_metadata ツールでデータスキーマとビジネスコンテキストを確認すること
  2. 適切なクエリツールを選択して実行すること
  3. 結果を分かりやすい日本語で整形して回答すること
  4. 個人情報・機密情報は適切にマスクすること

tools:
  - type: mcp
    server_label: business-data-mcp
    server_url: https://apim-{env}.azure-api.net/mcp/v1
    allowed_tools:
      - query_inventory
      - query_customers
      - query_orders
      - get_metadata
```

**参考**: [Azure AI Foundry Agent MCP tool extension](https://learn.microsoft.com/azure/ai-services/agents/how-to/tools/model-context-protocol)

---

### 2.3 Azure API Management

#### 構成方針

- **ティア**: Premium (VNET 統合のため)
- **プロトコル**: HTTPS のみ (HTTP 無効化)
- **バックエンド**: Container Apps Internal Load Balancer

#### MCP エンドポイントのポリシー設計

```xml
<!-- APIM Policy: MCP Server向けポリシー -->
<policies>
  <inbound>
    <!-- Entra ID JWT 検証 -->
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
      <openid-config url="https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration"/>
      <audiences>
        <audience>api://{apim-client-id}</audience>
      </audiences>
    </validate-jwt>
    
    <!-- レート制限: クライアントIDごとに100req/min -->
    <rate-limit-by-key calls="100" renewal-period="60"
      counter-key="@(context.Request.Headers.GetValueOrDefault("x-client-id"))" />
    
    <!-- リクエストサイズ制限 (1MB) -->
    <set-body>@{
      if (context.Request.Body != null && context.Request.Body.As<string>().Length > 1048576)
        throw new Exception("Request body too large");
      return context.Request.Body.As<string>(true);
    }</set-body>
    
    <!-- バックエンドへの認証ヘッダー注入 (Managed Identity) -->
    <authentication-managed-identity resource="https://management.azure.com/" />
  </inbound>
  
  <outbound>
    <!-- PII マスキング (メールアドレス) -->
    <find-and-replace from="[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" to="***@***.***"/>
    
    <!-- セキュリティヘッダー -->
    <set-header name="X-Content-Type-Options" exists-action="override">
      <value>nosniff</value>
    </set-header>
    <set-header name="X-Frame-Options" exists-action="override">
      <value>DENY</value>
    </set-header>
    
    <!-- Application Insights にレスポンスログ送信 (ステータスコード・レイテンシのみ) -->
  </outbound>
  
  <on-error>
    <set-variable name="errorMessage" value="@(context.LastError.Message)" />
    <return-response>
      <set-status code="@(context.Response.StatusCode)" />
      <set-body>@{ return new JObject(new JProperty("error", "Internal error")).ToString(); }</set-body>
    </return-response>
  </on-error>
</policies>
```

**参考**: [API Management policies](https://learn.microsoft.com/azure/api-management/api-management-policies)

---

### 2.4 MCP サーバ (Azure Container Apps)

#### 構成方針

- **ランタイム**: Python 3.12 + FastMCP
- **プロトコル**: MCP Streamable HTTP (SSE)
- **スケーリング**: 最小0レプリカ (コールドスタート許容) / 最大10レプリカ
- **認証**: APIM からの Mutual TLS のみ受け付け

#### ツール定義

```python
# src/mcp-server/tools/inventory.py (概念設計)

from fastmcp import FastMCP
from typing import Optional

mcp = FastMCP("business-data-server")

@mcp.tool()
async def query_inventory(
    category: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    limit: int = 100
) -> dict:
    """
    在庫データを照会します。
    
    Args:
        category: 商品カテゴリ (例: "電子機器", "食品")
        date_from: 照会開始日 (YYYY-MM-DD)
        date_to: 照会終了日 (YYYY-MM-DD)
        limit: 最大返却件数 (デフォルト100、最大1000)
    
    Returns:
        在庫データのリスト
    """
    # 入力バリデーション
    if limit > 1000:
        limit = 1000
    
    # SQL クエリ実行 (Managed Identity 認証)
    # ...
```

#### ツール一覧

| ツール名 | 説明 | DB テーブル |
|---------|------|-----------|
| `get_metadata` | テーブル定義・カラム説明・関連性取得 | AI Search (メタデータ) |
| `query_inventory` | 在庫照会 (集計含む) | `inventory`, `products` |
| `query_customers` | 顧客情報照会 | `customers` |
| `query_orders` | 注文照会 | `orders`, `order_items` |

**参考**: [FastMCP](https://github.com/jlowin/fastmcp), [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)

---

### 2.5 メタデータ層 (AI Search + Data Dictionary)

#### Data Dictionary 構造

```json
// database/metadata/data_dictionary.json
{
  "version": "1.0",
  "tables": [
    {
      "name": "products",
      "description": "商品マスタ。在庫管理・注文処理で使用するすべての商品情報を管理する",
      "business_context": "新商品登録は商品部門が管理。価格は月次で見直し",
      "columns": [
        {
          "name": "product_id",
          "type": "INT",
          "description": "商品の一意識別子",
          "is_primary_key": true,
          "is_pii": false
        },
        {
          "name": "product_name",
          "type": "NVARCHAR(200)",
          "description": "商品名。日本語・英語の両方を含む場合がある",
          "is_pii": false
        }
      ],
      "relationships": [
        {
          "to_table": "inventory",
          "type": "one_to_many",
          "description": "1商品に対して複数の在庫レコードが存在する（倉庫別）"
        }
      ]
    }
  ]
}
```

#### AI Search インデックス設計

```json
// AI Search インデックス: metadata-index
{
  "name": "metadata-index",
  "fields": [
    { "name": "id", "type": "Edm.String", "key": true },
    { "name": "table_name", "type": "Edm.String", "filterable": true },
    { "name": "content", "type": "Edm.String", "searchable": true },
    { "name": "business_context", "type": "Edm.String", "searchable": true },
    { "name": "content_vector", "type": "Collection(Edm.Single)", 
      "dimensions": 1536, "vectorSearchProfile": "vector-profile" }
  ]
}
```

---

### 2.6 Azure SQL Database

#### ティア選択根拠

| 項目 | PoC 設定 | 理由 |
|------|---------|------|
| ティア | General Purpose (Serverless) | PoC での コスト最適化 |
| vCores | 2 (min: 0.5) | 自動一時停止でコスト削減 |
| ストレージ | 32 GB | サンプルデータで十分 |
| バックアップ | 7日間 | PoC では最小限 |

#### セキュリティ設定

- **パブリックアクセス**: 無効化
- **Private Endpoint**: Container Apps サブネットからのみ
- **認証**: Entra ID 認証のみ (SQL 認証無効)
- **TDE**: 有効 (Customer-Managed Key は本番で検討)
- **Defender for SQL**: 有効

---

### 2.7 ネットワーク設計

#### VNET アドレス空間

| サブネット | アドレス | 用途 |
|----------|---------|------|
| `snet-foundry` | 10.0.1.0/24 | AI Foundry Private Endpoint |
| `snet-apim` | 10.0.2.0/24 | APIM |
| `snet-container-apps` | 10.0.3.0/24 | Container Apps |
| `snet-search` | 10.0.4.0/24 | AI Search Private Endpoint |
| `snet-sql` | 10.0.5.0/24 | SQL DB Private Endpoint |
| `snet-shared` | 10.0.6.0/24 | Key Vault, Monitor |
| `snet-bastion` | 10.0.7.0/27 | Azure Bastion |

#### Private Endpoint 一覧

| サービス | PE 名 | サブネット |
|---------|------|----------|
| Azure AI Foundry | pe-foundry | snet-foundry |
| Azure AI Search | pe-search | snet-search |
| Azure SQL | pe-sql | snet-sql |
| Azure Key Vault | pe-keyvault | snet-shared |
| Azure Container Registry | pe-acr | snet-shared |

---

### 2.8 可観測性設計

#### Application Insights 構成

```
Foundry Agent ──traceId──▶ APIM ──traceId──▶ MCP Server ──traceId──▶ SQL
      └─────────────────────────────────────────────────────────────────┘
                        Application Insights (Log Analytics Workspace)
```

#### ログ収集方針 (最小限)

```python
# MCP サーバのログ例 (src/mcp-server/telemetry.py)
import logging
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace

# Application Insights への接続
configure_azure_monitor(connection_string=os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"))
tracer = trace.get_tracer(__name__)

def log_tool_call(tool_name: str, success: bool, duration_ms: float):
    """ツール呼び出しの最小限ログ"""
    # ツール名・成否・実行時間のみ記録（入力データは記録しない）
    logger.info(
        "tool_call",
        extra={
            "tool_name": tool_name,
            "success": success,
            "duration_ms": duration_ms
        }
    )
```

---

## 3. 技術スタック

| レイヤー | 技術 | バージョン/SKU |
|---------|-----|-------------|
| ユーザー IF | Microsoft 365 Copilot | - |
| エージェント | Azure AI Foundry Agent | - |
| LLM | Azure OpenAI GPT-4o | 2024-11-20 |
| API GW | Azure API Management | Premium v2 |
| MCP Server | Python FastMCP | 2.x |
| コンテナ基盤 | Azure Container Apps | - |
| コンテナレジストリ | Azure Container Registry | Standard |
| メタデータ検索 | Azure AI Search | Standard |
| データベース | Azure SQL Database | Serverless GP |
| シークレット管理 | Azure Key Vault | Standard |
| ID・認証 | Microsoft Entra ID | - |
| ネットワーク | Azure Virtual Network + Private Link | - |
| 可観測性 | Azure Monitor + Application Insights | - |
| IaC | Azure Bicep | - |
| デプロイ | Azure Developer CLI (azd) | - |

---

## 4. デプロイ順序

```
1. リソースグループ作成
2. VNET + サブネット + NSG
3. Azure Bastion
4. Azure Key Vault (PE 含む)
5. Azure Container Registry (PE 含む)
6. Azure SQL Database (PE 含む)
7. Azure AI Search (PE 含む)
8. Azure Monitor + Log Analytics + Application Insights
9. Azure Container Apps Environment (VNET 統合)
10. MCP Server コンテナビルド & ACR プッシュ
11. Azure Container Apps (MCP Server デプロイ)
12. Azure AI Foundry Hub + Project (PE 含む)
13. Azure API Management (VNET 統合)
14. Foundry エージェント設定・デプロイ
15. M365 Copilot Declarative Agent パッケージ生成
```

---

## 5. 参考リンク (Microsoft Learn)

- [Azure AI Foundry Agent Service 概要](https://learn.microsoft.com/azure/ai-services/agents/overview)
- [Foundry Agent + MCP ツール設定](https://learn.microsoft.com/azure/ai-services/agents/how-to/tools/model-context-protocol)
- [Azure API Management + VNET 統合](https://learn.microsoft.com/azure/api-management/virtual-network-concepts)
- [Azure Container Apps VNET 統合](https://learn.microsoft.com/azure/container-apps/networking)
- [Azure SQL Private Endpoint](https://learn.microsoft.com/azure/azure-sql/database/private-endpoint-overview)
- [Azure Private Link 概要](https://learn.microsoft.com/azure/private-link/private-link-overview)
- [Azure AI Search Private Endpoint](https://learn.microsoft.com/azure/search/service-create-private-endpoint)
- [Application Insights 分散トレーシング](https://learn.microsoft.com/azure/azure-monitor/app/distributed-trace-data)
- [Microsoft 365 Copilot Declarative Agent](https://learn.microsoft.com/microsoft-365-copilot/extensibility/overview-declarative-agent)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview)
