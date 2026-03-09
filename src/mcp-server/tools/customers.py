"""
顧客照会ツール
customers テーブルのクエリ処理 (PII マスキング適用)
"""

import logging
import re
import time
from typing import Optional

from fastmcp import FastMCP

try:
    from ..db.connection import execute_query
except ImportError:
    from db.connection import execute_query  # type: ignore[no-redef]

logger = logging.getLogger(__name__)


def _mask_email(email: str | None) -> str | None:
    """
    メールアドレスをマスキングする。
    ローカルパートの先頭1文字を残し、残りを ***** に置換する。
    例: yamada.taro@example.co.jp → y*****@example.co.jp
    """
    if email is None:
        return None
    if not email:
        return ""
    match = re.match(r"([^@]+)(@.+)", email)
    if match:
        local = match.group(1)
        domain_part = match.group(2)
        if len(local) == 0:
            return f"*****{domain_part}"
        return f"{local[0]}*****{domain_part}"
    return email


def _mask_phone(phone: str | None) -> str | None:
    """
    電話番号の先頭部分をマスキングし、末尾4桁を残す。
    例: 03-1234-5678 → **-****-5678
    """
    if not phone:
        return None
    if len(phone) <= 4:
        return phone
    suffix = phone[-4:]
    prefix_masked = re.sub(r"\d", "*", phone[:-4])
    return prefix_masked + suffix


def _mask_contact_name(name: str | None) -> str | None:
    """
    担当者名の先頭1文字を残してマスキングする。
    例: 山田太郎 → 山***
    """
    if not name:
        return None
    if len(name) >= 1:
        return f"{name[0]}***"
    return "***"


def _apply_pii_masking(rows: list[dict]) -> list[dict]:
    """行データのリストに PII マスキングを適用する"""
    return [_mask_row(row) for row in rows]


def _mask_row(row: dict) -> dict:
    """単一行の PII フィールドをマスキングする"""
    masked = dict(row)
    if "contact_email" in masked:
        masked["contact_email"] = _mask_email(masked["contact_email"])
    if "email" in masked:
        masked["email"] = _mask_email(masked["email"])
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
        masked_rows = _apply_pii_masking(rows)

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
