"""
在庫照会ツール
products + inventory テーブルのクエリ処理
"""

import logging
import time
from typing import Optional

from fastmcp import FastMCP

try:
    from ..db.connection import execute_query
except ImportError:
    from db.connection import execute_query  # type: ignore[no-redef]

logger = logging.getLogger(__name__)

# 在庫不足と判断するしきい値（利用可能在庫数）
_LOW_STOCK_THRESHOLD = 10


def _build_inventory_query(
    category: Optional[str],
    warehouse_id: Optional[int],
    low_stock_only: bool,
    max_rows: int,
    snapshot_date: Optional[str] = None,
    product_name_keyword: Optional[str] = None,
    include_zero_stock: bool = False,
    warehouse_code: Optional[str] = None,
) -> tuple[str, list]:
    """
    在庫照会 SQL クエリとパラメータを構築する。

    Args:
        category: 商品カテゴリ絞り込み
        warehouse_id: 倉庫 ID 絞り込み
        low_stock_only: 在庫不足商品のみ
        max_rows: 最大返却行数
        snapshot_date: 在庫スナップショット日付
        product_name_keyword: 商品名キーワード (部分一致)
        include_zero_stock: 在庫ゼロ商品を含めるか
        warehouse_code: 倉庫コード絞り込み

    Returns:
        (sql, params) のタプル
    """
    if snapshot_date:
        date_condition = "i.snapshot_date = ?"
        params_list: list = [snapshot_date]
    else:
        date_condition = "i.snapshot_date = (SELECT MAX(snapshot_date) FROM inventory)"
        params_list = []

    where_clauses = [date_condition]

    if category:
        where_clauses.append("p.category = ?")
        params_list.append(category)

    if warehouse_id is not None:
        where_clauses.append("i.warehouse_id = ?")
        params_list.append(warehouse_id)

    if warehouse_code:
        where_clauses.append("w.warehouse_code = ?")
        params_list.append(warehouse_code)

    if product_name_keyword:
        where_clauses.append("p.product_name LIKE ?")
        params_list.append(f"%{product_name_keyword}%")

    if not include_zero_stock:
        where_clauses.append("i.quantity_available > 0")

    if low_stock_only:
        where_clauses.append(
            f"i.quantity_available <= {{_LOW_STOCK_THRESHOLD}} /* low stock threshold */"
        )

    where_clauses.append("p.is_active = 1")
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
    WHERE {{where_sql}}
    ORDER BY p.category, p.product_name, w.warehouse_name
    """
    return sql, params_list


def _calculate_category_summary(rows: list[dict]) -> dict[str, dict]:
    """
    在庫行データからカテゴリ別サマリーを計算する。

    Returns:
        カテゴリ名をキーとするサマリー辞書。
        各値は total_quantity_available・total_quantity_on_hand・item_count を含む。
    """
    summary: dict[str, dict] = {}
    for row in rows:
        cat = row.get("category", "")
        if cat not in summary:
            summary[cat] = {
                "total_quantity_available": 0,
                "total_quantity_on_hand": 0,
                "item_count": 0,
            }
        summary[cat]["total_quantity_available"] += row.get("quantity_available", 0) or 0
        summary[cat]["total_quantity_on_hand"] += row.get("quantity_on_hand", 0) or 0
        summary[cat]["item_count"] += 1
    return summary


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
        """在庫データを照会します。"""
        start = time.monotonic()
        limit = min(max(1, limit), 500)

        sql, params_list = _build_inventory_query(
            category=category,
            warehouse_id=None,
            low_stock_only=False,
            max_rows=limit,
            snapshot_date=snapshot_date,
            product_name_keyword=product_name_keyword,
            include_zero_stock=include_zero_stock,
            warehouse_code=warehouse_code,
        )

        rows = execute_query(sql, tuple(params_list), max_rows=limit)
        category_summary = _calculate_category_summary(rows)

        return {
            "rows": rows,
            "row_count": len(rows),
            "category_summary": {
                cat: {
                    "total_on_hand": v["total_quantity_on_hand"],
                    "total_available": v["total_quantity_available"],
                    "item_count": v["item_count"],
                }
                for cat, v in category_summary.items()
            },
            "duration_ms": round((time.monotonic() - start) * 1000, 2),
        }

    @mcp.tool()
    def query_inventory_trend(
        category: Optional[str] = None,
        product_code: Optional[str] = None,
        months: int = 3,
    ) -> dict:
        """在庫の時系列推移を照会します（月次比較）。"""
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
            AND {{where_sql}}
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