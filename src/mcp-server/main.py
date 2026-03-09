"""
MCP Server - エントリポイント
Foundry Agent からの MCP ツール呼び出しを処理する Streamable HTTP サーバ
"""

import logging
import os

from fastmcp import FastMCP

from .telemetry import configure_telemetry, get_tracer
from .tools.customers import register_customers_tools
from .tools.inventory import register_inventory_tools
from .tools.metadata import register_metadata_tools
from .tools.orders import register_orders_tools

# ログ設定 (構造化ログ)
logging.basicConfig(
    level=logging.INFO,
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "logger": "%(name)s", "message": "%(message)s"}',
)
logger = logging.getLogger(__name__)

# Application Insights テレメトリ設定
configure_telemetry()
tracer = get_tracer(__name__)

# MCP サーバ初期化
mcp = FastMCP(
    name="business-data-server",
    instructions="""
    このサーバは業務データ照会のためのツールを提供します。
    在庫・顧客・注文データへのアクセスと、データスキーマのメタデータ取得が可能です。
    
    使用可能なツール:
    - get_metadata: テーブル定義・カラム説明・ビジネスコンテキストの取得
    - query_inventory: 在庫データの照会・集計
    - query_customers: 顧客情報の照会
    - query_orders: 注文データの照会・集計
    """,
)

# ツール登録
register_metadata_tools(mcp)
register_inventory_tools(mcp)
register_customers_tools(mcp)
register_orders_tools(mcp)


def create_app():
    """ASGI アプリケーションを生成して返す"""
    return mcp.http_app(transport="streamable-http", path="/mcp")


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8000"))
    logger.info(f"Starting MCP server on port {port}")
    uvicorn.run(
        "main:create_app",
        factory=True,
        host="0.0.0.0",
        port=port,
        log_level="info",
    )
