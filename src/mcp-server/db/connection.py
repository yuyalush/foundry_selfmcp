"""
Azure SQL Database 接続モジュール
Managed Identity (DefaultAzureCredential) を使用したパスワードレス接続
"""

import logging
import os
import struct
import time

import pyodbc
from azure.identity import DefaultAzureCredential

logger = logging.getLogger(__name__)

_credential: DefaultAzureCredential | None = None
_token_cache: dict = {"token": None, "expires_on": 0}

SQL_COPT_SS_ACCESS_TOKEN = 1256  # pyodbc SQL Server 固有の属性


def _get_credential() -> DefaultAzureCredential:
    """DefaultAzureCredential のシングルトンを返す"""
    global _credential
    if _credential is None:
        _credential = DefaultAzureCredential()
    return _credential


def _get_access_token() -> bytes:
    """
    Azure SQL 用のアクセストークンを取得し、pyodbc が要求するバイト形式に変換する。
    トークンはキャッシュし、期限切れの5分前に再取得する。
    """
    now = time.time()
    if _token_cache["token"] and _token_cache["expires_on"] - now > 300:
        return _token_cache["token"]

    credential = _get_credential()
    token = credential.get_token("https://database.windows.net/.default")

    # pyodbc が要求する形式: token 文字列を UTF-16-LE エンコードし長さをプレフィックス
    token_bytes = token.token.encode("utf-16-le")
    token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

    _token_cache["token"] = token_struct
    _token_cache["expires_on"] = token.expires_on

    return token_struct


def get_connection() -> pyodbc.Connection:
    """
    Azure SQL Database への接続を確立して返す。
    Managed Identity による認証を使用（SQL 認証は使用しない）。
    """
    server = os.environ["SQL_SERVER"]          # 例: myserver.database.windows.net
    database = os.environ["SQL_DATABASE"]      # 例: mydb

    connection_string = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={server};"
        f"DATABASE={database};"
        "Encrypt=yes;"
        "TrustServerCertificate=no;"
        "Connection Timeout=30;"
    )

    token = _get_access_token()
    conn = pyodbc.connect(connection_string, attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token})
    conn.autocommit = True  # 読み取り専用のため自動コミット

    return conn


def execute_query(
    sql: str,
    params: tuple = (),
    max_rows: int = 1000,
) -> list[dict]:
    """
    パラメータ化クエリを実行し、結果を辞書リストで返す。

    Args:
        sql: 実行する SQL クエリ（プレースホルダ ? を使用）
        params: バインドパラメータのタプル
        max_rows: 最大返却行数 (デフォルト 1000)

    Returns:
        辞書のリスト。各辞書がカラム名をキーとする1行分のデータ。
    """
    start = time.monotonic()
    conn = None

    try:
        conn = get_connection()
        cursor = conn.cursor()

        # TOP 句で最大行数を制限 (SQL インジェクション防止のためパラメータは使わない)
        # max_rows は整数であることを検証済み
        if max_rows and "SELECT" in sql.upper() and "TOP" not in sql.upper():
            sql = sql.replace("SELECT ", f"SELECT TOP {int(max_rows)} ", 1)

        cursor.execute(sql, params)
        columns = [desc[0] for desc in cursor.description]
        rows = cursor.fetchall()

        result = [dict(zip(columns, row)) for row in rows]

        duration_ms = (time.monotonic() - start) * 1000
        logger.info(
            f"Query executed",
            extra={"duration_ms": round(duration_ms, 2), "row_count": len(result)},
        )
        return result

    except pyodbc.Error as e:
        duration_ms = (time.monotonic() - start) * 1000
        logger.error(f"SQL error after {duration_ms:.0f}ms: {e.args[1] if len(e.args) > 1 else str(e)}")
        raise RuntimeError(f"Database query failed: {e.args[1] if len(e.args) > 1 else str(e)}") from e
    finally:
        if conn:
            conn.close()
