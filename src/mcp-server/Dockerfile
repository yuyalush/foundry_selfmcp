# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────
# Stage 1: ビルドステージ
# ──────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

# ODBC ドライバのインストール
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    unixodbc-dev \
    && curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" \
       > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Python 依存関係のインストール
COPY pyproject.toml .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir .

# ──────────────────────────────────────────────
# Stage 2: ランタイムステージ
# ──────────────────────────────────────────────
FROM python:3.12-slim AS runtime

WORKDIR /app

# ODBC ライブラリのコピー
COPY --from=builder /usr/share/keyrings/microsoft.gpg /usr/share/keyrings/microsoft.gpg
COPY --from=builder /etc/apt/sources.list.d/mssql-release.list /etc/apt/sources.list.d/mssql-release.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    unixodbc \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# インストール済みパッケージのコピー
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# アプリケーションコードのコピー
COPY . .

# データディクショナリのコピー (メタデータフォールバック用)
COPY ../../database/metadata/data_dictionary.json /app/database/metadata/data_dictionary.json

# 非 root ユーザーで実行
RUN useradd --system --no-create-home --shell /bin/false appuser \
    && chown -R appuser:appuser /app
USER appuser

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${PORT:-8000}/health')" || exit 1

EXPOSE 8000

ENV PORT=8000
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

CMD ["python", "-m", "uvicorn", "main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info"]
