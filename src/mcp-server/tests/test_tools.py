"""
MCP ツールのユニットテスト
Azure 接続なしでローカル実行可能
"""
import json
import os
import sys
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# テスト用にルートを参照
sys.path.insert(0, str(Path(__file__).parent.parent))


# ──────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────

@pytest.fixture
def sample_products() -> list[dict]:
    return [
        {
            "product_id": 1,
            "product_code": "ELEC-001",
            "product_name": "ノートパソコン Pro 15",
            "category": "Electronics",
            "unit_price": 125000.00,
            "is_active": True,
        },
        {
            "product_id": 2,
            "product_code": "ELEC-002",
            "product_name": "ワイヤレスマウス",
            "category": "Electronics",
            "unit_price": 3500.00,
            "is_active": True,
        },
    ]


@pytest.fixture
def sample_inventory(sample_products) -> list[dict]:
    return [
        {
            "product_id": 1,
            "product_name": "ノートパソコン Pro 15",
            "category": "Electronics",
            "warehouse_id": 1,
            "warehouse_name": "東京中央倉庫",
            "quantity_on_hand": 50,
            "quantity_reserved": 10,
            "quantity_available": 40,
            "snapshot_date": "2025-01-15",
        },
    ]


@pytest.fixture
def sample_customers() -> list[dict]:
    return [
        {
            "customer_id": 1,
            "company_name": "株式会社テクノソリューション",
            "contact_name": "山田太郎",
            "email": "yamada.taro@techno-solution.co.jp",
            "phone": "03-1234-5678",
            "prefecture": "東京都",
            "customer_tier": "Gold",
        },
    ]


@pytest.fixture
def sample_orders() -> list[dict]:
    return [
        {
            "order_id": 1,
            "order_number": "ORD-2025-001",
            "customer_id": 1,
            "company_name": "株式会社テクノソリューション",
            "order_date": "2025-01-10",
            "status": "completed",
            "total_amount": 250000.00,
        },
    ]


# ──────────────────────────────────────────────
# metadata.py のテスト
# ──────────────────────────────────────────────

class TestMetadataTool:
    @pytest.mark.asyncio
    async def test_get_metadata_local_fallback(self, tmp_path):
        """AI Search が利用できない場合にローカル fallback が機能すること"""
        # モックの data_dictionary.json を作成
        dict_path = tmp_path / "data_dictionary.json"
        dict_content = {
            "schema_version": "1.0",
            "tables": [
                {
                    "table_name": "products",
                    "display_name": "商品マスタ",
                    "description": "全商品の基本情報",
                    "business_context": "SKU管理",
                    "columns": [],
                    "relationships": [],
                    "common_queries": [],
                }
            ],
        }
        dict_path.write_text(json.dumps(dict_content, ensure_ascii=False), encoding="utf-8")

        from tools.metadata import _load_local_metadata

        result = _load_local_metadata(str(dict_path))
        assert result is not None
        assert len(result["tables"]) == 1
        assert result["tables"][0]["table_name"] == "products"

    @pytest.mark.asyncio
    async def test_get_metadata_summary_all_tables(self, tmp_path):
        """テーブル名未指定時に全テーブルの概要が返ること"""
        dict_path = tmp_path / "data_dictionary.json"
        dict_content = {
            "schema_version": "1.0",
            "tables": [
                {"table_name": "products", "display_name": "商品"},
                {"table_name": "inventory", "display_name": "在庫"},
            ],
        }
        dict_path.write_text(json.dumps(dict_content, ensure_ascii=False), encoding="utf-8")

        from tools.metadata import _build_summary

        summary = _build_summary(dict_content, table_name=None)
        assert "products" in summary
        assert "inventory" in summary


# ──────────────────────────────────────────────
# inventory.py のテスト
# ──────────────────────────────────────────────

class TestInventoryTool:
    @pytest.mark.asyncio
    async def test_query_inventory_builds_correct_where_clause(self):
        """フィルタパラメータが正しくSQL WHERE句に変換されること"""
        from tools.inventory import _build_inventory_query

        sql, params = _build_inventory_query(
            category="Electronics",
            warehouse_id=None,
            low_stock_only=False,
            max_rows=100,
        )
        assert "category" in sql.lower() or "p.category" in sql.lower()
        assert "Electronics" in params or params[0] == "Electronics"

    @pytest.mark.asyncio
    async def test_query_inventory_low_stock_filter(self):
        """low_stock_only=True の場合に HAVING 句が含まれること"""
        from tools.inventory import _build_inventory_query

        sql, params = _build_inventory_query(
            category=None,
            warehouse_id=None,
            low_stock_only=True,
            max_rows=100,
        )
        assert "reorder" in sql.lower() or "low" in sql.lower() or "having" in sql.lower()

    def test_category_summary_calculation(self, sample_inventory):
        """カテゴリ別サマリーが正しく計算されること"""
        from tools.inventory import _calculate_category_summary

        summary = _calculate_category_summary(sample_inventory)
        assert "Electronics" in summary
        assert summary["Electronics"]["total_quantity_available"] == 40


# ──────────────────────────────────────────────
# customers.py のテスト
# ──────────────────────────────────────────────

class TestCustomersTool:
    def test_mask_email(self):
        """メールアドレスが正しくマスクされること"""
        from tools.customers import _mask_email

        assert _mask_email("yamada.taro@techno-solution.co.jp") == "y*****@techno-solution.co.jp"
        assert _mask_email(None) is None
        assert _mask_email("") == ""

    def test_mask_phone(self):
        """電話番号が正しくマスクされること"""
        from tools.customers import _mask_phone

        result = _mask_phone("03-1234-5678")
        assert "*" in result
        # 最後の4桁は残す
        assert result.endswith("5678")

    def test_mask_contact_name(self):
        """担当者名が正しくマスクされること"""
        from tools.customers import _mask_contact_name

        result = _mask_contact_name("山田太郎")
        assert "*" in result
        # 姓のみ残す（最初の1文字）
        assert result.startswith("山")

    def test_pii_masking_applied_to_all_rows(self, sample_customers):
        """全行に PII マスキングが適用されること"""
        from tools.customers import _apply_pii_masking

        masked = _apply_pii_masking(sample_customers)
        for row in masked:
            if row.get("email"):
                assert "taro" not in row["email"]
            if row.get("phone"):
                assert row["phone"] != "03-1234-5678"


# ──────────────────────────────────────────────
# orders.py のテスト
# ──────────────────────────────────────────────

class TestOrdersTool:
    def test_status_whitelist_validation(self):
        """無効なステータスが拒否されること"""
        from tools.orders import _validate_status

        assert _validate_status("completed") is True
        assert _validate_status("pending") is True
        assert _validate_status("; DROP TABLE orders--") is False
        assert _validate_status("unknown_status") is False

    def test_group_by_whitelist_validation(self):
        """無効な group_by が拒否されること"""
        from tools.orders import _validate_group_by

        assert _validate_group_by("customer") is True
        assert _validate_group_by("category") is True
        assert _validate_group_by("month") is True
        assert _validate_group_by("1; DROP TABLE--") is False

    @pytest.mark.asyncio
    async def test_query_sales_summary_group_by_month(self):
        """group_by=month で月次集計SQLが生成されること"""
        from tools.orders import _build_sales_summary_query

        sql, params = _build_sales_summary_query(
            group_by="month",
            start_date="2025-01-01",
            end_date="2025-03-31",
        )
        assert "month" in sql.lower() or "year" in sql.lower() or "format" in sql.lower()

    @pytest.mark.asyncio
    async def test_query_sales_summary_group_by_category(self):
        """group_by=category でカテゴリ別集計SQLが生成されること"""
        from tools.orders import _build_sales_summary_query

        sql, params = _build_sales_summary_query(
            group_by="category",
            start_date=None,
            end_date=None,
        )
        assert "category" in sql.lower()


# ──────────────────────────────────────────────
# db/connection.py のテスト
# ──────────────────────────────────────────────

class TestDbConnection:
    def test_execute_query_enforces_max_rows(self):
        """max_rows が SELECT TOP に変換されること"""
        from db.connection import _inject_top_clause

        sql = "SELECT * FROM products"
        result = _inject_top_clause(sql, max_rows=50)
        assert "TOP 50" in result or "top 50" in result.lower()

    def test_execute_query_preserves_existing_top(self):
        """既に TOP 句がある場合は重複しないこと"""
        from db.connection import _inject_top_clause

        sql = "SELECT TOP 10 * FROM products"
        result = _inject_top_clause(sql, max_rows=50)
        count = result.upper().count("TOP")
        assert count == 1
