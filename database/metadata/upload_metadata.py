"""
upload_metadata.py - data_dictionary.json を Azure AI Search にアップロードするスクリプト

使用方法:
    python database/metadata/upload_metadata.py \
        --endpoint https://<search>.search.windows.net \
        --index-name metadata-index \
        --dict-path database/metadata/data_dictionary.json

認証:
    DefaultAzureCredential (Managed Identity / az login)
"""
import argparse
import json
import sys
from pathlib import Path

from azure.core.credentials import AzureKeyCredential
from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex,
    SearchField,
    SearchFieldDataType,
    SimpleField,
    SearchableField,
    VectorSearch,
    HnswAlgorithmConfiguration,
    VectorSearchProfile,
)


# ──────────────────────────────────────────────
# インデックス定義
# ──────────────────────────────────────────────
INDEX_FIELDS = [
    SimpleField(name="id", type=SearchFieldDataType.String, key=True),
    SimpleField(name="table_name", type=SearchFieldDataType.String, filterable=True),
    SearchableField(name="display_name", type=SearchFieldDataType.String, analyzer_name="ja.lucene"),
    SearchableField(name="description", type=SearchFieldDataType.String, analyzer_name="ja.lucene"),
    SearchableField(name="business_context", type=SearchFieldDataType.String, analyzer_name="ja.lucene"),
    SimpleField(name="has_pii", type=SearchFieldDataType.Boolean, filterable=True),
    SearchableField(
        name="column_names_text",
        type=SearchFieldDataType.String,
        analyzer_name="ja.lucene",
    ),
    SearchableField(
        name="common_queries_text",
        type=SearchFieldDataType.String,
        analyzer_name="ja.lucene",
    ),
    SearchableField(
        name="relationships_text",
        type=SearchFieldDataType.String,
        analyzer_name="ja.lucene",
    ),
    # フルコンテンツ (JSON 文字列) - LLM への返却用
    SimpleField(name="full_content", type=SearchFieldDataType.String),
]


def create_index(client: SearchIndexClient, index_name: str) -> None:
    index = SearchIndex(
        name=index_name,
        fields=INDEX_FIELDS,
    )
    client.create_or_update_index(index)
    print(f"Index '{index_name}' created/updated.")


def build_documents(data_dict: dict) -> list[dict]:
    """data_dictionary.json から検索ドキュメントを構築する"""
    docs = []
    for table in data_dict.get("tables", []):
        table_name = table.get("table_name", "")

        # カラム名テキスト
        column_names = [
            f"{c.get('column_name', '')} ({c.get('display_name', '')}): {c.get('description', '')}"
            for c in table.get("columns", [])
        ]

        # よくあるクエリテキスト
        common_queries = [
            f"{q.get('description', '')}: {q.get('example_natural_language', '')}"
            for q in table.get("common_queries", [])
        ]

        # リレーションテキスト
        relationships = [
            f"{r.get('related_table', '')} - {r.get('description', '')}"
            for r in table.get("relationships", [])
        ]

        # PII 列の有無
        has_pii = any(c.get("is_pii", False) for c in table.get("columns", []))

        doc = {
            "id": table_name,
            "table_name": table_name,
            "display_name": table.get("display_name", ""),
            "description": table.get("description", ""),
            "business_context": table.get("business_context", ""),
            "has_pii": has_pii,
            "column_names_text": "\n".join(column_names),
            "common_queries_text": "\n".join(common_queries),
            "relationships_text": "\n".join(relationships),
            "full_content": json.dumps(table, ensure_ascii=False),
        }
        docs.append(doc)
        print(f"  Built document for table: {table_name}")

    return docs


def upload(endpoint: str, index_name: str, dict_path: str, api_key: str | None = None) -> None:
    # 認証
    if api_key:
        credential = AzureKeyCredential(api_key)
    else:
        credential = DefaultAzureCredential()

    # インデックス作成
    index_client = SearchIndexClient(endpoint=endpoint, credential=credential)
    create_index(index_client, index_name)

    # ドキュメント読み込み
    data_dict = json.loads(Path(dict_path).read_text(encoding="utf-8"))
    docs = build_documents(data_dict)

    if not docs:
        print("No documents to upload.")
        return

    # アップロード
    search_client = SearchClient(endpoint=endpoint, index_name=index_name, credential=credential)
    result = search_client.upload_documents(documents=docs)

    succeeded = sum(1 for r in result if r.succeeded)
    failed = sum(1 for r in result if not r.succeeded)
    print(f"Upload complete: {succeeded} succeeded, {failed} failed.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload metadata to Azure AI Search")
    parser.add_argument("--endpoint", required=True, help="AI Search endpoint URL")
    parser.add_argument("--index-name", default="metadata-index", help="Index name")
    parser.add_argument(
        "--dict-path",
        default="database/metadata/data_dictionary.json",
        help="Path to data_dictionary.json",
    )
    parser.add_argument("--api-key", default=None, help="API Key (dev only; use Managed Identity in production)")
    args = parser.parse_args()

    upload(
        endpoint=args.endpoint,
        index_name=args.index_name,
        dict_path=args.dict_path,
        api_key=args.api_key,
    )


if __name__ == "__main__":
    main()
