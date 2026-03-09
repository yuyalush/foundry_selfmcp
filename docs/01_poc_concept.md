# PoC コンセプト: M365 Copilot × Azure AI Foundry × MCP サーバ統合基盤

> **ドキュメントバージョン**: 1.0  
> **作成日**: 2026-03-09  
> **ステータス**: Draft

---

## 1. 概要

本 PoC は、Microsoft 365 Copilot をエンドユーザー向けのフロントエンドとして活用し、Azure AI Foundry で構築したエージェントが Model Context Protocol (MCP) を介してバックエンドデータを取得・操作するエンドツーエンドの AI エージェント基盤を実証するものです。

### 1.1 達成したいこと

| # | 目標 | 実現方法 |
|---|------|----------|
| 1 | M365 Copilot からエージェントを呼び出す | Copilot 拡張 (Declarative Agent / Graph Connector) |
| 2 | エージェントが MCP 経由でデータにアクセスする | Azure AI Foundry Agent + MCP Tool Extension |
| 3 | MCP サーバがデータベースを操作する | Azure Container Apps 上の MCP Server |
| 4 | データの意味・関係性をエージェントが理解する | メタデータ層 (AI Search + Data Dictionary) |
| 5 | セキュアなネットワーク分離 | Private Link / Private Endpoint |
| 6 | API ガバナンスと認証 | Azure API Management |
| 7 | デバッグとトレーサビリティ | Application Insights + Distributed Tracing |

---

## 2. 背景と課題

### 2.1 現状の課題

企業の業務データは複数のシステムに分散しており、業務担当者が自然言語で即座に問い合わせ・集計・推論を行うことが困難な状況にある。

- **データアクセスの壁**: SQL や API の知識がないと業務データを活用できない  
- **コンテキストの欠如**: データの意味・業務上の関連性が技術者以外には不明  
- **セキュリティリスク**: 直接アクセスを許可するとデータ漏洩・改ざんリスクが生じる  
- **ガバナンスの欠如**: 誰が何のデータにアクセスしたかを把握しにくい  

### 2.2 PoC が解決するアプローチ

```
業務担当者 ─→ M365 Copilot ─→ AI Agent ─→ MCP Server ─→ DB
                (自然言語)    (推論・判断)  (安全なAPI)  (データ取得)
```

自然言語による対話を入口とし、エージェントが業務ロジックとメタデータを理解した上でデータにアクセス。全通信は認証・暗号化・ネットワーク分離により保護する。

---

## 3. ユースケース (PoC スコープ)

### UC-01: 在庫照会

> 「先月の商品カテゴリ別の在庫数と、前月比の変化を教えて」

1. ユーザーが M365 Copilot に自然言語で質問
2. Foundry エージェントが意図を解析し、必要な MCP ツールを選択
3. MCP サーバが在庫テーブルに対してパラメータ付きクエリを実行
4. 結果をエージェントが集計・整形してユーザーに返答

### UC-02: 顧客情報照会

> 「A社の最新の注文状況と担当営業を確認したい」

1. エージェントが顧客データのメタデータ (テーブル定義・リレーション) を参照
2. 複数テーブルにまたがるデータを MCP ツール経由で取得
3. 個人情報マスキングポリシーを APIM で適用して返却

### UC-03: データ分析質問

> 「今四半期の売上上位10社とその傾向を分析して」

1. エージェントがデータスキーマを理解した上でクエリを生成
2. MCP サーバ経由で集計データを取得
3. エージェントが自然言語で分析結果を生成

---

## 4. コンポーネント概要

### 4.1 フロントエンド層: M365 Copilot

- **役割**: エンドユーザーとのインターフェース
- **実現方法**: Microsoft 365 Copilot の Declarative Agent として Foundry エージェントを登録
- **認証**: Azure AD / Microsoft Entra ID による SSO
- **参考**: [Microsoft 365 Copilot extensibility](https://learn.microsoft.com/microsoft-365-copilot/extensibility/)

### 4.2 エージェント層: Azure AI Foundry Agent

- **役割**: ユーザーの意図を解析し、適切な MCP ツールを選択・実行して回答を生成
- **実現方法**: Azure AI Foundry Agent Service
- **ツール**: MCP Tool Extension により MCP サーバを外部ツールとして登録
- **モデル**: Azure OpenAI GPT-4o / GPT-4o-mini
- **参考**: [Azure AI Foundry Agent Service](https://learn.microsoft.com/azure/ai-services/agents/overview)

### 4.3 API ゲートウェイ層: Azure API Management

- **役割**: MCP サーバへのアクセスを一元管理する API ゲートウェイ
- **機能**:
  - 認証・認可 (OAuth 2.0 / JWT 検証)
  - レート制限・クォータ管理
  - リクエスト/レスポンスの変換・マスキング
  - ロギングと監査証跡の収集
- **参考**: [Azure API Management](https://learn.microsoft.com/azure/api-management/api-management-key-concepts)

### 4.4 MCP サーバ層: Azure Container Apps

- **役割**: Model Context Protocol に準拠したツールサーバ
- **実装**: Python (FastMCP) または TypeScript (MCP SDK)
- **ツール例**:
  - `query_inventory`: 在庫データ照会
  - `query_customers`: 顧客データ照会
  - `query_orders`: 注文データ照会
  - `get_schema`: テーブルスキーマ・メタデータ取得
- **ホスティング**: Azure Container Apps (サーバーレス・自動スケール)
- **参考**: [Model Context Protocol](https://modelcontextprotocol.io/)

### 4.5 メタデータ層: Azure AI Search + Data Dictionary

- **役割**: データの意味・業務ロジック・テーブル間のリレーション情報を管理
- **構成**:
  - **Azure AI Search**: メタデータの意味検索 (vector search)
  - **Data Dictionary JSON**: テーブル定義・カラム説明・ビジネスルール
  - **Knowledge Store**: エンティティ関係図とドメイン知識
- **用途**: エージェントがクエリ生成前にスキーマ・ビジネスコンテキストを取得
- **参考**: [Azure AI Search](https://learn.microsoft.com/azure/search/search-what-is-azure-search)

### 4.6 データ層: Azure SQL Database

- **役割**: 業務データの永続化
- **構成**:
  - **General Purpose** または **Business Critical** ティア
  - Private Endpoint 経由のみアクセス可
  - Transparent Data Encryption (TDE) 有効
  - Azure Defender for SQL 有効
- **参考**: [Azure SQL Database](https://learn.microsoft.com/azure/azure-sql/database/)

### 4.7 セキュリティ・ネットワーク層

- **Azure Virtual Network**: 全コンポーネントを VNET 内に配置
- **Azure Private Link / Private Endpoint**: APIM → Container Apps → SQL DB 間の通信をプライベートに
- **Azure Key Vault**: シークレット・接続文字列の一元管理
- **Managed Identity**: サービス間認証にパスワードレス接続を使用
- **参考**: [Azure Private Link](https://learn.microsoft.com/azure/private-link/private-link-overview)

### 4.8 可観測性層: Azure Monitor + Application Insights

- **役割**: 分散トレーシング・ログ収集・アラート
- **収集対象**:
  - AI Foundry Agent の実行ログ・レイテンシ
  - APIM のリクエスト/レスポンスログ (最小限)
  - MCP サーバの呼び出しログ・エラーログ
  - SQL クエリの実行ログ (低頻度サンプリング)
- **参考**: [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)

---

## 5. データフロー

```
[ユーザー]
    │ 自然言語クエリ
    ▼
[M365 Copilot]
    │ Declarative Agent 呼び出し
    ▼
[Azure AI Foundry Agent]
    │ 1. メタデータ取得 (AI Search)
    │ 2. MCP ツール選択
    │ 3. MCP ツール実行リクエスト
    ▼
[Azure API Management]  ← JWT 検証 / レート制限 / ログ
    │ Private Endpoint 経由
    ▼
[MCP Server (Container Apps)]
    │ 1. 入力バリデーション
    │ 2. SQL クエリ生成・実行
    │ Private Link 経由
    ▼
[Azure SQL Database]
    │ クエリ結果
    ▼
[MCP Server] → [APIM] → [Foundry Agent] → [M365 Copilot] → [ユーザー]
```

---

## 6. セキュリティ設計方針

### 6.1 ネットワーク分離

| コンポーネント | アクセス経路 |
|--------------|------------|
| M365 Copilot → Foundry Agent | インターネット (TLS 1.3 + Entra ID 認証) |
| Foundry Agent → APIM | Private Endpoint |
| APIM → Container Apps | VNET Integration |
| Container Apps → SQL DB | Private Endpoint |
| 管理アクセス | Azure Bastion (JIT) |

### 6.2 認証・認可

- **M365 → Agent**: Microsoft Entra ID OAuth 2.0
- **Agent → APIM**: Managed Identity + OAuth 2.0
- **APIM → MCP Server**: Mutual TLS + API Key
- **MCP Server → SQL**: Managed Identity (パスワードレス)

### 6.3 最小権限の原則

- MCP サーバの DB アクセスは **読み取り専用ロール** を基本とする
- 書き込み操作が必要なツールは明示的な許可リストで管理
- APIM ポリシーで PII データをレスポンス時にマスク

---

## 7. ロギング方針

### 7.1 収集する情報 (最小限の原則)

| レイヤー | 収集内容 | 保持期間 |
|---------|--------|--------|
| Foundry Agent | セッションID・ツール呼び出し名・レイテンシ・エラー | 30日 |
| APIM | リクエストURI・ステータスコード・レイテンシ・クライアントID | 90日 |
| MCP Server | ツール名・入力パラメータ概要・実行時間・エラー詳細 | 30日 |
| SQL | スロークエリ (>1秒)・エラークエリのみ | 14日 |

### 7.2 収集しない情報

- ユーザーの自然言語クエリ全文 (プライバシー保護)
- SQL クエリの返却データ本体
- 個人情報・機密情報

### 7.3 分散トレーシング

Application Insights の相関 ID によりリクエストを Foundry Agent → APIM → MCP Server → DB まで追跡可能とする。

---

## 8. PoC の成功条件

| # | 評価項目 | 成功基準 |
|---|---------|---------|
| 1 | 機能動作 | UC-01〜03 の全ユースケースが M365 Copilot から実行可能 |
| 2 | レスポンスタイム | エンドツーエンドで P95 < 10秒 |
| 3 | セキュリティ | パブリックネットワークから SQL DB に直接アクセス不可を確認 |
| 4 | トレーサビリティ | Application Insights でリクエストのエンドツーエンド追跡が可能 |
| 5 | デプロイ自動化 | `azd up` 一発で全環境がデプロイ可能 |

---

## 9. スコープ外 (PoC 対象外)

- 本番での高可用性設計 (DR・マルチリージョン)
- Copilot ライセンス取得・M365 テナント設定
- データ移行・既存システムとの連携
- CI/CD パイプラインの設計

---

## 10. 次のステップ

1. **アーキテクチャ設計** → [02_architecture.md](./02_architecture.md)
2. **インフラ構成 (Bicep)** → [infra/](../infra/)
3. **MCP サーバ実装** → [src/mcp-server/](../src/mcp-server/)
4. **データベース設計** → [database/](../database/)
5. **デプロイガイド** → [03_deployment_guide.md](./03_deployment_guide.md)

---

*本ドキュメントは作業の進行に合わせて継続的に更新されます。*
