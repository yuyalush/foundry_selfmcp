-- ============================================================
-- Azure SQL Database スキーマ定義
-- PoC: M365 Copilot × Foundry Agent × MCP 統合基盤
-- ============================================================

-- データベース設定
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 160;
GO

-- ============================================================
-- 商品マスタ (products)
-- ============================================================
CREATE TABLE products (
    product_id      INT             NOT NULL IDENTITY(1,1),
    product_code    NVARCHAR(50)    NOT NULL,
    product_name    NVARCHAR(200)   NOT NULL,
    category        NVARCHAR(100)   NOT NULL,
    unit_price      DECIMAL(12, 2)  NOT NULL,
    unit            NVARCHAR(20)    NOT NULL DEFAULT N'個',
    supplier_name   NVARCHAR(200)   NULL,
    is_active       BIT             NOT NULL DEFAULT 1,
    created_at      DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_products PRIMARY KEY (product_id),
    CONSTRAINT UQ_products_code UNIQUE (product_code),
    CONSTRAINT CK_products_price CHECK (unit_price >= 0)
);
GO

-- ============================================================
-- 倉庫マスタ (warehouses)
-- ============================================================
CREATE TABLE warehouses (
    warehouse_id    INT             NOT NULL IDENTITY(1,1),
    warehouse_code  NVARCHAR(20)    NOT NULL,
    warehouse_name  NVARCHAR(200)   NOT NULL,
    location        NVARCHAR(200)   NOT NULL,
    is_active       BIT             NOT NULL DEFAULT 1,
    created_at      DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_warehouses PRIMARY KEY (warehouse_id),
    CONSTRAINT UQ_warehouses_code UNIQUE (warehouse_code)
);
GO

-- ============================================================
-- 在庫テーブル (inventory)
-- 倉庫別・日次スナップショット
-- ============================================================
CREATE TABLE inventory (
    inventory_id        INT             NOT NULL IDENTITY(1,1),
    product_id          INT             NOT NULL,
    warehouse_id        INT             NOT NULL,
    snapshot_date       DATE            NOT NULL,
    quantity_on_hand    INT             NOT NULL DEFAULT 0,
    quantity_reserved   INT             NOT NULL DEFAULT 0,
    quantity_available  AS (quantity_on_hand - quantity_reserved) PERSISTED,
    last_updated_at     DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_inventory PRIMARY KEY (inventory_id),
    CONSTRAINT UQ_inventory UNIQUE (product_id, warehouse_id, snapshot_date),
    CONSTRAINT FK_inventory_products FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT FK_inventory_warehouses FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT CK_inventory_qty CHECK (quantity_on_hand >= 0 AND quantity_reserved >= 0)
);
GO

-- ============================================================
-- 顧客マスタ (customers)
-- ============================================================
CREATE TABLE customers (
    customer_id     INT             NOT NULL IDENTITY(1,1),
    customer_code   NVARCHAR(20)    NOT NULL,
    company_name    NVARCHAR(200)   NOT NULL,
    contact_name    NVARCHAR(100)   NULL,   -- PII: マスキング対象
    contact_email   NVARCHAR(254)   NULL,   -- PII: マスキング対象
    phone           NVARCHAR(20)    NULL,   -- PII: マスキング対象
    prefecture      NVARCHAR(10)    NULL,
    sales_rep_name  NVARCHAR(100)   NULL,
    credit_limit    DECIMAL(14, 2)  NOT NULL DEFAULT 0,
    is_active       BIT             NOT NULL DEFAULT 1,
    created_at      DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_customers PRIMARY KEY (customer_id),
    CONSTRAINT UQ_customers_code UNIQUE (customer_code)
);
GO

-- ============================================================
-- 注文ヘッダー (orders)
-- ============================================================
CREATE TABLE orders (
    order_id            INT             NOT NULL IDENTITY(1,1),
    order_number        NVARCHAR(30)    NOT NULL,
    customer_id         INT             NOT NULL,
    order_date          DATE            NOT NULL,
    required_date       DATE            NULL,
    shipped_date        DATE            NULL,
    status              NVARCHAR(20)    NOT NULL DEFAULT N'受付',
        -- '受付', '処理中', '出荷済', '完了', 'キャンセル'
    total_amount        DECIMAL(14, 2)  NOT NULL DEFAULT 0,
    notes               NVARCHAR(500)   NULL,
    created_at          DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at          DATETIME2(0)    NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_orders PRIMARY KEY (order_id),
    CONSTRAINT UQ_orders_number UNIQUE (order_number),
    CONSTRAINT FK_orders_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT CK_orders_status CHECK (status IN (N'受付', N'処理中', N'出荷済', N'完了', N'キャンセル'))
);
GO

-- ============================================================
-- 注文明細 (order_items)
-- ============================================================
CREATE TABLE order_items (
    item_id         INT             NOT NULL IDENTITY(1,1),
    order_id        INT             NOT NULL,
    line_number     INT             NOT NULL,
    product_id      INT             NOT NULL,
    quantity        INT             NOT NULL,
    unit_price      DECIMAL(12, 2)  NOT NULL,
    discount_rate   DECIMAL(5, 4)   NOT NULL DEFAULT 0,
    line_amount     AS (quantity * unit_price * (1 - discount_rate)) PERSISTED,
    CONSTRAINT PK_order_items PRIMARY KEY (item_id),
    CONSTRAINT UQ_order_items UNIQUE (order_id, line_number),
    CONSTRAINT FK_order_items_orders FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT FK_order_items_products FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT CK_order_items_qty CHECK (quantity > 0)
);
GO

-- ============================================================
-- インデックス
-- ============================================================
CREATE NONCLUSTERED INDEX IX_inventory_product_date
    ON inventory (product_id, snapshot_date DESC) INCLUDE (quantity_on_hand, quantity_reserved);

CREATE NONCLUSTERED INDEX IX_inventory_warehouse_date
    ON inventory (warehouse_id, snapshot_date DESC);

CREATE NONCLUSTERED INDEX IX_orders_customer
    ON orders (customer_id, order_date DESC) INCLUDE (status, total_amount);

CREATE NONCLUSTERED INDEX IX_orders_date
    ON orders (order_date DESC) INCLUDE (customer_id, status, total_amount);

CREATE NONCLUSTERED INDEX IX_order_items_order
    ON order_items (order_id) INCLUDE (product_id, quantity, line_amount);

CREATE NONCLUSTERED INDEX IX_customers_active
    ON customers (is_active) INCLUDE (company_name, prefecture);
GO

-- ============================================================
-- MCP サーバ用 読み取り専用ロール
-- ============================================================
-- Entra ID Managed Identity を使用した読み取り専用アクセス設定
-- デプロイ後に Container Apps の Managed Identity 名を確認し
-- 以下のスクリプトを実行してください。
-- (例: fmcp-dev-mcp-id)

-- ステップ 1: カスタム読み取り専用ロール作成
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'mcp_readonly_role' AND type = 'R')
BEGIN
    CREATE ROLE mcp_readonly_role;
END
GO

-- ステップ 2: 必要なテーブルへの SELECT 権限付与
GRANT SELECT ON dbo.products     TO mcp_readonly_role;
GRANT SELECT ON dbo.warehouses   TO mcp_readonly_role;
GRANT SELECT ON dbo.inventory    TO mcp_readonly_role;
GRANT SELECT ON dbo.customers    TO mcp_readonly_role;
GRANT SELECT ON dbo.orders       TO mcp_readonly_role;
GRANT SELECT ON dbo.order_items  TO mcp_readonly_role;
GRANT VIEW DATABASE STATE        TO mcp_readonly_role;
GO

-- ステップ 3: Managed Identity をロールに追加
-- ※ <managed-identity-name> を実際の Container Apps Managed Identity 名に置換
--    例: CREATE USER [fmcp-dev-mcp-id] FROM EXTERNAL PROVIDER;
--        ALTER ROLE mcp_readonly_role ADD MEMBER [fmcp-dev-mcp-id];
--
-- 本番実行用テンプレート (変数で Identity 名を指定):
-- DECLARE @identity NVARCHAR(200) = N'<managed-identity-name>';
-- EXEC('CREATE USER [' + @identity + '] FROM EXTERNAL PROVIDER');
-- EXEC('ALTER ROLE mcp_readonly_role ADD MEMBER [' + @identity + ']');
-- GO

PRINT N'Schema created successfully.';
GO
