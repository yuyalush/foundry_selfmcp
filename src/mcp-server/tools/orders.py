"""
注文照会ツール
orders + order_items + customers + products のクエリ処理
"""

import logging
import time
from typing import Optional

from fastmcp import FastMCP

from ..db.connection import execute_query

logger = logging.getLogger(__name__)


def register_orders_tools(mcp: FastMCP) -> None:
    """注文関連ツールを MCP サーバに登録する"""

    @mcp.tool()
    def query_orders(
        customer_code: Optional[str] = None,
        status: Optional[str] = None,
        date_from: Optional[str] = None,
        date_to: Optional[str] = None,
        order_number: Optional[str] = None,
        limit: int = 100,
    ) -> dict:
        """
        注文データを照会します。

        Args:
            customer_code: 顧客コードで絞り込み (例: "C-0001")
            status: 注文ステータスで絞り込み (受付/処理中/出荷済/完了/キャンセル)
            date_from: 注文日の開始日 (YYYY-MM-DD)
            date_to: 注文日の終了日 (YYYY-MM-DD)
            order_number: 注文番号で完全一致検索
            limit: 最大返却件数 (デフォルト: 100, 最大: 500)

        Returns:
            注文ヘッダー情報のリスト
        """
        start = time.monotonic()
        limit = min(max(1, limit), 500)

        # ステータスのホワイトリスト検証
        valid_statuses = {"受付", "処理中", "出荷済", "完了", "キャンセル"}
        if status and status not in valid_statuses:
            return {"error": f"Invalid status. Must be one of: {', '.join(valid_statuses)}"}

        where_clauses = []
        params_list: list = []

        if customer_code:
            where_clauses.append("c.customer_code = ?")
            params_list.append(customer_code)

        if status:
            where_clauses.append("o.status = ?")
            params_list.append(status)

        if date_from:
            where_clauses.append("o.order_date >= ?")
            params_list.append(date_from)

        if date_to:
            where_clauses.append("o.order_date <= ?")
            params_list.append(date_to)

        if order_number:
            where_clauses.append("o.order_number = ?")
            params_list.append(order_number)

        where_sql = " AND ".join(where_clauses) if where_clauses else "1=1"

        sql = f"""
        SELECT
            o.order_number,
            c.customer_code,
            c.company_name,
            c.prefecture,
            c.sales_rep_name,
            o.order_date,
            o.required_date,
            o.shipped_date,
            o.status,
            o.total_amount
        FROM orders o
        INNER JOIN customers c ON o.customer_id = c.customer_id
        WHERE {where_sql}
        ORDER BY o.order_date DESC
        """

        rows = execute_query(sql, tuple(params_list), max_rows=limit)

        return {
            "rows": rows,
            "row_count": len(rows),
            "duration_ms": round((time.monotonic() - start) * 1000, 2),
        }

    @mcp.tool()
    def query_sales_summary(
        date_from: Optional[str] = None,
        date_to: Optional[str] = None,
        group_by: str = "customer",
        top_n: int = 10,
    ) -> dict:
        """
        売上サマリーを集計します。

        Args:
            date_from: 集計開始日 (YYYY-MM-DD)。省略時は当四半期初め
            date_to: 集計終了日 (YYYY-MM-DD)。省略時は本日
            group_by: 集計軸 ("customer"=顧客別, "category"=商品カテゴリ別, "month"=月別)
            top_n: 上位N件を返す (デフォルト: 10, 最大: 50)

        Returns:
            集計結果のリスト（合計金額降順）
        """
        start = time.monotonic()
        top_n = min(max(1, top_n), 50)

        # group_by のホワイトリスト検証
        valid_group_by = {"customer", "category", "month"}
        if group_by not in valid_group_by:
            return {"error": f"Invalid group_by. Must be one of: {', '.join(valid_group_by)}"}

        # 日付範囲の設定（省略時のデフォルト）
        params_list: list = []
        date_filter = "o.status != N'キャンセル'"

        if date_from:
            date_filter += " AND o.order_date >= ?"
            params_list.append(date_from)
        else:
            # デフォルト: 当四半期初め
            date_filter += " AND o.order_date >= DATEADD(quarter, DATEDIFF(quarter, 0, GETDATE()), 0)"

        if date_to:
            date_filter += " AND o.order_date <= ?"
            params_list.append(date_to)

        # group_by に応じたクエリ生成
        if group_by == "customer":
            sql = f"""
            SELECT TOP {top_n}
                c.company_name,
                c.customer_code,
                c.prefecture,
                c.sales_rep_name,
                COUNT(DISTINCT o.order_id) AS order_count,
                SUM(o.total_amount) AS total_amount,
                MAX(o.order_date) AS latest_order_date
            FROM orders o
            INNER JOIN customers c ON o.customer_id = c.customer_id
            WHERE {date_filter}
            GROUP BY c.company_name, c.customer_code, c.prefecture, c.sales_rep_name
            ORDER BY total_amount DESC
            """

        elif group_by == "category":
            sql = f"""
            SELECT TOP {top_n}
                p.category,
                COUNT(DISTINCT o.order_id) AS order_count,
                SUM(oi.quantity) AS total_quantity,
                SUM(oi.line_amount) AS total_amount
            FROM orders o
            INNER JOIN order_items oi ON o.order_id = oi.order_id
            INNER JOIN products p ON oi.product_id = p.product_id
            WHERE {date_filter}
            GROUP BY p.category
            ORDER BY total_amount DESC
            """

        else:  # month
            sql = f"""
            SELECT TOP {top_n}
                FORMAT(o.order_date, 'yyyy-MM') AS year_month,
                COUNT(DISTINCT o.order_id) AS order_count,
                SUM(o.total_amount) AS total_amount
            FROM orders o
            WHERE {date_filter}
            GROUP BY FORMAT(o.order_date, 'yyyy-MM')
            ORDER BY year_month DESC
            """

        rows = execute_query(sql, tuple(params_list), max_rows=top_n)

        return {
            "rows": rows,
            "row_count": len(rows),
            "group_by": group_by,
            "top_n": top_n,
            "duration_ms": round((time.monotonic() - start) * 1000, 2),
        }
