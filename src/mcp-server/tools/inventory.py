"""
在庫照会ツール
products + inventory テーブルのクエリ処理
"""

import logging
import time
from typing import Optional

from fastmcp import FastMCP

from ..db.connection import execute_query

logger = logging.getLogger(__name__)


def register_inventory_tools(mcp: FastMCP) -> None:
    """在庫関連ツールを MCP サーバに登録する"""

    @mcp.tool()
    def query_inventory(
        category: Optional[str] = None,
        warehouse_code: Optional[str] = None,
        snapshot_date: Optional[str] = None,
        product_name_keyword: Optional[str] = None,
        include_zero_stock: bool = False,
        limit: int = 100,
    ) -> dict:
        """
        在庫データを照会します。倉庫別・カテゴリ別の在庫数量を返します。

        Args:
            category: 商品カテゴリで絞り込み (例: "電子機器", "消耗品", "家具")
            warehouse_code: 倉庫コードで絞り込み (例: "WH-TOKYO", "WH-OSAKA")
            snapshot_date: 照会対象の在庫日付 (YYYY-MM-DD形式)。省略時は最新日付
            product_name_keyword: 商品名のキーワード検索 (部分一致)
            include_zero_stock: 在庫ゼロ商品を含めるか (デフォルト: False)
            limit: 最大返却件数 (デフォルト: 100, 最大: 500)

        Returns:
            在庫データのリスト。各要素に商品名・カテゴリ・倉庫・在庫数量を含む。
        """
        start = time.monotonic()
        limit = min(max(1, limit), 500)

        # snapshot_date の決定 (指定がなければ最新日付を使用)
        if snapshot_date:
            date_condition = "i.snapshot_date = ?"
            params_list = [snapshot_date]
        else:
            date_condition = "i.snapshot_date = (SELECT MAX(snapshot_date) FROM inventory)"
            params_list = []

        # WHERE 句の動的構築
        where_clauses = [date_condition]

        if category:
            where_clauses.append("p.category = ?")
            params_list.append(category)

        if warehouse_code:
            where_clauses.append("w.warehouse_code = ?")
            params_list.append(warehouse_code)

        if product_name_keyword:
            where_clauses.append("p.product_name LIKE ?")
            params_list.append(f"%{product_name_keyword}%")

        if not include_zero_stock:
            where_clauses.append("i.quantity_available > 0")

        where_sql = " AND ".join(where_clauses)

        sql = f"""
        SELECT
            p.product_code,
            p.product_name,
            p.category,
            p.unit,
            p.unit_price,
            w.warehouse_name,
            w.location AS warehouse_location,
            i.snapshot_date,
            i.quantity_on_hand,
            i.quantity_reserved,
            i.quantity_available
        FROM inventory i
        INNER JOIN products p ON i.product_id = p.product_id
        INNER JOIN warehouses w ON i.warehouse_id = w.warehouse_id
        WHERE {where_sql}
            AND p.is_active = 1
        ORDER BY p.category, p.product_name, w.warehouse_name
        """

        rows = execute_query(sql, tuple(params_list), max_rows=limit)

        # カテゴリ別サマリー計算
        category_summary: dict[str, dict] = {}
        for row in rows:
            cat = row["category"]
            if cat not in category_summary:
                category_summary[cat] = {"total_on_hand": 0, "total_available": 0, "item_count": 0}
            category_summary[cat]["total_on_hand"] += row["quantity_on_hand"] or 0
            category_summary[cat]["total_available"] += row["quantity_available"] or 0
            category_summary[cat]["item_count"] += 1

        return {
            "rows": rows,
            "row_count": len(rows),
            "category_summary": category_summary,
            "duration_ms": round((time.monotonic() - start) * 1000, 2),
        }

    @mcp.tool()
    def query_inventory_trend(
        category: Optional[str] = None,
        product_code: Optional[str] = None,
        months: int = 3,
    ) -> dict:
        """
        在庫の時系列推移を照会します（月次比較）。

        Args:
            category: 商品カテゴリで絞り込み
            product_code: 商品コードで絞り込み (例: "ELEC-001")
            months: 遡る月数 (デフォルト: 3, 最大: 12)

        Returns:
            月次の在庫推移データ
        """
        start = time.monotonic()
        months = min(max(1, months), 12)

        where_clauses = ["p.is_active = 1"]
        params_list: list = [months]

        if category:
            where_clauses.append("p.category = ?")
            params_list.append(category)
        if product_code:
            where_clauses.append("p.product_code = ?")
            params_list.append(product_code)

        where_sql = " AND ".join(where_clauses)

        sql = f"""
        SELECT
            i.snapshot_date,
            p.category,
            p.product_name,
            SUM(i.quantity_on_hand) AS total_on_hand,
            SUM(i.quantity_available) AS total_available
        FROM inventory i
        INNER JOIN products p ON i.product_id = p.product_id
        WHERE i.snapshot_date >= DATEADD(month, -?, (SELECT MAX(snapshot_date) FROM inventory))
            AND {where_sql}
        GROUP BY i.snapshot_date, p.category, p.product_name
        ORDER BY i.snapshot_date DESC, p.category, p.product_name
        """

        rows = execute_query(sql, tuple(params_list), max_rows=500)

        return {
            "rows": rows,
            "row_count": len(rows),
            "months_requested": months,
            "duration_ms": round((time.monotonic() - start) * 1000, 2),
        }
