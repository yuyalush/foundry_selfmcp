"""
メタデータ取得ツール
Azure AI Search からテーブル定義・ビジネスコンテキストを取得する
"""

import json
import logging
import os
import time
from pathlib import Path

from fastmcp import FastMCP

logger = logging.getLogger(__name__)

# ローカルフォールバック用のデータディクショナリパス
_DICT_PATH = Path(__file__).parents[3] / "database" / "metadata" / "data_dictionary.json"
_LOCAL_DICT: dict | None = None


def _load_local_dict() -> dict:
    global _LOCAL_DICT
    if _LOCAL_DICT is None:
        try:
            with open(_DICT_PATH, encoding="utf-8") as f:
                _LOCAL_DICT = json.load(f)
        except FileNotFoundError:
            _LOCAL_DICT = {}
    return _LOCAL_DICT


def _load_local_metadata(path: str) -> dict:
    """指定パスからデータディクショナリを読み込む"""
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _build_summary(data_dict: dict, table_name: str | None = None) -> dict:
    """
    データディクショナリからテーブルサマリーを構築する。

    Args:
        data_dict: データディクショナリ全体
        table_name: 絞り込むテーブル名。None の場合は全テーブルを返す

    Returns:
        テーブル名をキーとするサマリー辞書
    """
    tables = data_dict.get("tables", [])
    result = {}
    for t in tables:
        # "table_name" キーと "name" キーの両方に対応
        name = t.get("table_name") or t.get("name", "")
        if not name:
            continue
        if table_name is None or name == table_name:
            result[name] = {
                "display_name": t.get("display_name", ""),
                "description": t.get("description", ""),
                "business_context": t.get("business_context", ""),
                "relationships": t.get("relationships", []),
                "common_queries": t.get("common_queries", []),
            }
    return result


def _search_ai_search(query: str, table_name: str | None) -> list[dict]:
    """Azure AI Search からメタデータを取得する"""
    try:
        from azure.identity import DefaultAzureCredential
        from azure.search.documents import SearchClient

        endpoint = os.environ["AI_SEARCH_ENDPOINT"]
        index_name = os.environ.get("AI_SEARCH_INDEX", "metadata-index")

        credential = DefaultAzureCredential()
        client = SearchClient(
            endpoint=endpoint,
            index_name=index_name,
            credential=credential,
        )

        search_filter = f"table_name eq '{table_name}'" if table_name else None
        results = client.search(
            search_text=query,
            filter=search_filter,
            top=5,
            include_total_count=False,
        )

        return [dict(r) for r in results]

    except Exception as e:
        logger.warning(f"AI Search unavailable, using local dict: {e}")
        return []


def register_metadata_tools(mcp: FastMCP) -> None:
    """メタデータ関連ツールを MCP サーバに登録する"""

    @mcp.tool()
    def get_metadata(
        table_name: str | None = None,
        query: str | None = None,
    ) -> dict:
        """
        テーブル定義・カラム説明・ビジネスコンテキスト・テーブル間リレーションを取得します。

        クエリツールを呼び出す前に、このツールでスキーマを確認することを推奨します。

        Args:
            table_name: 特定のテーブル名で絞り込む場合に指定 (例: "inventory", "customers")
                       省略した場合はすべてのテーブルの概要を返す
            query: メタデータを意味検索するためのキーワード (例: "在庫数量", "顧客の担当営業")

        Returns:
            テーブル定義・カラム情報・ビジネスコンテキスト・リレーション情報
        """
        start = time.monotonic()

        # AI Search を試みる
        if query:
            ai_results = _search_ai_search(query, table_name)
            if ai_results:
                return {
                    "source": "ai_search",
                    "results": ai_results,
                    "duration_ms": round((time.monotonic() - start) * 1000, 2),
                }

        # ローカルのデータディクショナリにフォールバック
        data_dict = _load_local_dict()

        if not data_dict:
            return {"error": "Metadata not available", "tables": []}

        if table_name:
            tables = [t for t in data_dict.get("tables", []) if t["name"] == table_name]
        else:
            # 全テーブルの概要のみ返す（重量な完全定義は除く）
            tables = [
                {
                    "name": t["name"],
                    "display_name": t["display_name"],
                    "description": t["description"],
                    "business_context": t["business_context"],
                    "relationships": t.get("relationships", []),
                    "common_queries": t.get("common_queries", []),
                }
                for t in data_dict.get("tables", [])
            ]

        return {
            "source": "local_dictionary",
            "entity_relationships": data_dict.get("entity_relationships", {}),
            "tables": tables,
            "duration_ms": round((time.monotonic() - start) * 1000, 2),
        }
