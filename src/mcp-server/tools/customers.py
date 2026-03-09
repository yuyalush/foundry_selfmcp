"""
顧客照会ツール
customers テーブルのクエリ処理 (PII マスキング適用)
"""

import logging
import re
import time
from typing import Optional

from fastmcp import FastMCP

from ..db.connection import execute_query

logger = logging.getLogger(__name__)


def _mask_email(email: str | None) -> str | None:
    """メールアドレスをマスキングする"""
    if not email:
        return None
    return re.sub(r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}", "***@***.***", email)


def _mask_phone(phone: str | None) -> str | None:
    """電話番号の下4桁をマスキングする"""
    if not phone:
        return None
    return re.sub(r"\d{4}$", "****", phone)


def _mask_contact_name(name: str | None) -> str | None:
    """担当者名は姓のみ残してマスキングする"""
    if not name:
        return None
    parts = name.split()
    if len(parts) >= 2:
        return f"{parts[0]} ***"
    return "***"


def _apply_pii_masking(row: dict) -> dict:
    """行データの PII フィールドをマスキングする"""
    masked = dict(row)
    if "contact_email" in masked:
        masked["contact_email"] = _mask_email(masked["contact_email"])
    if "phone" in masked:
        masked["phone"] = _mask_phone(masked["phone"])
    if "contact_name" in masked:
        masked["contact_name"] = _mask_contact_name(masked["contact_name"])
    return masked


def register_customers_tools(mcp: FastMCP) -> None:
    """顧客関連ツールを MCP サーバに登録する"""

    @mcp.tool()
    def query_customers(
        company_name_keyword: Optional[str] = None,
        prefecture: Optional[str] = None,
        customer_code: Optional[str] = None,
        sales_rep_name: Optional[str] = None,
        active_only: bool = True,
        limit: int = 50,
    ) -> dict:
        """
        顧客情報を照会します。PII フィールド（メール・電話・担当者名）は自動的にマスキングされます。

        Args:
            company_name_keyword: 企業名のキーワード検索 (部分一致)
            prefecture: 都道府県で絞り込み (例: "東京都", "大阪府")
            customer_code: 顧客コードで完全一致検索 (例: "C-0001")
            sales_rep_name: 担当営業名で絞り込み (例: "山田 太郎")
            active_only: 有効顧客のみ返す (デフォルト: True)
            limit: 最大返却件数 (デフォルト: 50, 最大: 200)

        Returns:
            顧客情報のリスト (PII はマスキング済み)
        """
        start = time.monotonic()
        limit = min(max(1, limit), 200)

        where_clauses = []
        params_list: list = []

        if active_only:
            where_clauses.append("c.is_active = 1")

        if company_name_keyword:
            where_clauses.append("c.company_name LIKE ?")
            params_list.append(f"%{company_name_keyword}%")

        if prefecture:
            where_clauses.append("c.prefecture = ?")
            params_list.append(prefecture)

        if customer_code:
            where_clauses.append("c.customer_code = ?")
            params_list.append(customer_code)

        if sales_rep_name:
            where_clauses.append("c.sales_rep_name = ?")
            params_list.append(sales_rep_name)

        where_sql = " AND ".join(where_clauses) if where_clauses else "1=1"

        sql = f"""
        SELECT
            c.customer_code,
            c.company_name,
            c.contact_name,
            c.contact_email,
            c.phone,
            c.prefecture,
            c.sales_rep_name,
            c.credit_limit,
            c.is_active,
            c.created_at
        FROM customers c
        WHERE {where_sql}
        ORDER BY c.company_name
        """

        rows = execute_query(sql, tuple(params_list), max_rows=limit)

        # PII マスキング適用
        masked_rows = [_apply_pii_masking(row) for row in rows]

        return {
            "rows": masked_rows,
            "row_count": len(masked_rows),
            "pii_note": "contact_name・contact_email・phone はプライバシー保護のためマスキングされています",
            "duration_ms": round((time.monotonic() - start) * 1000, 2),
        }

    @mcp.tool()
    def query_customer_orders_summary(
        customer_code: str,
        months: int = 12,
    ) -> dict:
        """
        特定顧客の注文サマリーを照会します（最新N月分）。

        Args:
            customer_code: 顧客コード (例: "C-0001")
            months: 遡る月数 (デフォルト: 12, 最大: 24)

        Returns:
            顧客の基本情報と注文サマリー（件数・合計金額・最新注文状況）
        """
        start = time.monotonic()
        months = min(max(1, months), 24)

        sql = """
        SELECT
            c.customer_code,
            c.company_name,
            c.prefecture,
            c.sales_rep_name,
            COUNT(o.order_id) AS order_count,
            COALESCE(SUM(o.total_amount), 0) AS total_amount,
            MAX(o.order_date) AS latest_order_date,
            SUM(CASE WHEN o.status IN (N'受付', N'処理中') THEN 1 ELSE 0 END) AS pending_orders,
            SUM(CASE WHEN o.status IN (N'受付', N'処理中') THEN o.total_amount ELSE 0 END) AS pending_amount
        FROM customers c
        LEFT JOIN orders o ON c.customer_id = o.customer_id
            AND o.order_date >= DATEADD(month, -?, CAST(GETDATE() AS DATE))
            AND o.status != N'キャンセル'
        WHERE c.customer_code = ?
        GROUP BY c.customer_code, c.company_name, c.prefecture, c.sales_rep_name
        """

        rows = execute_query(sql, (months, customer_code), max_rows=1)

        if not rows:
            return {"error": f"Customer not found: {customer_code}"}

        return {
            "customer_summary": rows[0],
            "months_period": months,
            "duration_ms": round((time.monotonic() - start) * 1000, 2),
        }
