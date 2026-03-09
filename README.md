# M365 Copilot × Azure AI Foundry × MCP 統合基盤 PoC

[![Azure](https://img.shields.io/badge/Azure-Foundry%20Agent-0078d4)](https://learn.microsoft.com/azure/ai-services/agents/)
[![MCP](https://img.shields.io/badge/Protocol-MCP-green)](https://modelcontextprotocol.io/)
[![IaC](https://img.shields.io/badge/IaC-Bicep-orange)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

## 概要

Microsoft 365 Copilot をフロントエンドとして、Azure AI Foundry で構築したエージェントが MCP サーバ経由でバックエンドデータベースにアクセスするエンドツーエンド AI エージェント基盤の PoC です。

```
M365 Copilot → AI Foundry Agent → API Management → MCP Server → Azure SQL DB
```

## リポジトリ構造

```
foundry_selfmcp/
├── docs/                          # ドキュメント
│   ├── 01_poc_concept.md         # PoC コンセプト
│   ├── 02_architecture.md        # アーキテクチャ設計
│   └── 03_deployment_guide.md    # デプロイガイド
├── infra/                         # Bicep IaC
│   ├── main.bicep                # エントリポイント
│   ├── main.bicepparam           # パラメータファイル
│   └── modules/                   # モジュール
│       ├── networking.bicep
│       ├── ai-foundry.bicep
│       ├── apim.bicep
│       ├── container-apps.bicep
│       ├── sql.bicep
│       ├── ai-search.bicep
│       ├── keyvault.bicep
│       └── monitoring.bicep
├── src/
│   └── mcp-server/               # MCP サーバ実装 (Python)
│       ├── Dockerfile
│       ├── pyproject.toml
│       ├── main.py
│       └── tools/
│           ├── inventory.py
│           ├── customers.py
│           ├── orders.py
│           └── metadata.py
├── database/
│   ├── schema.sql                # テーブル定義
│   ├── sample_data.sql           # サンプルデータ
│   └── metadata/
│       └── data_dictionary.json  # データディクショナリ
├── agents/
│   └── data-agent.yaml          # Foundry エージェント設定
├── azure.yaml                    # azd 設定
└── .github/
    └── ISSUE_TEMPLATE/           # Issue テンプレート
```

## クイックスタート

### 前提条件

- Azure サブスクリプション
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- Docker Desktop
- Python 3.12+

### デプロイ手順

```bash
# 1. リポジトリのクローン
git clone <repo-url>
cd foundry_selfmcp

# 2. Azure ログイン
azd auth login

# 3. 環境作成とデプロイ
azd up
```

## ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [PoC コンセプト](docs/01_poc_concept.md) | 目的・ユースケース・コンポーネント概要 |
| [アーキテクチャ設計](docs/02_architecture.md) | 詳細設計・技術スタック・デプロイ順序 |
| [デプロイガイド](docs/03_deployment_guide.md) | 手順・設定・検証方法 |

## 作業 Issues

各作業タスクは GitHub Issues で管理しています。[Issues 一覧](../../issues)を参照してください。

## ライセンス

MIT
