-- ============================================================
-- サンプルデータ投入スクリプト
-- PoC: M365 Copilot × Foundry Agent × MCP 統合基盤
-- ============================================================
-- 注意: schema.sql の実行後に実行すること

SET NOCOUNT ON;
GO

-- ============================================================
-- 商品マスタ (50件)
-- ============================================================
INSERT INTO products (product_code, product_name, category, unit_price, unit, supplier_name) VALUES
 (N'ELEC-001', N'ノートPC ProMax 15', N'電子機器', 189800, N'台', N'テック産業株式会社'),
 (N'ELEC-002', N'ノートPC Standard 13', N'電子機器', 98000, N'台', N'テック産業株式会社'),
 (N'ELEC-003', N'デスクトップPC Tower', N'電子機器', 145000, N'台', N'テック産業株式会社'),
 (N'ELEC-004', N'タブレット Pro 12', N'電子機器', 68000, N'台', N'モバイルテック株式会社'),
 (N'ELEC-005', N'スマートフォン X15', N'電子機器', 120000, N'台', N'モバイルテック株式会社'),
 (N'ELEC-006', N'ワイヤレスイヤホン', N'電子機器', 18000, N'個', N'サウンドラボ合同会社'),
 (N'ELEC-007', N'4Kモニター 27インチ', N'電子機器', 54000, N'台', N'ビジョンテック株式会社'),
 (N'ELEC-008', N'メカニカルキーボード', N'電子機器', 12000, N'個', N'インプットデバイス株式会社'),
 (N'ELEC-009', N'ワイヤレスマウス', N'電子機器', 4500, N'個', N'インプットデバイス株式会社'),
 (N'ELEC-010', N'USBハブ 7ポート', N'電子機器', 3200, N'個', N'コネクトデバイス株式会社'),
 (N'FURN-001', N'オフィスチェア エルゴノミクス', N'家具', 48000, N'脚', N'オフィスギア株式会社'),
 (N'FURN-002', N'スタンディングデスク 140cm', N'家具', 68000, N'台', N'オフィスギア株式会社'),
 (N'FURN-003', N'ホワイトボード 120x90', N'家具', 15000, N'枚', N'オフィスギア株式会社'),
 (N'FURN-004', N'3段スチール棚', N'家具', 8500, N'台', N'スチール家具株式会社'),
 (N'FURN-005', N'書類キャビネット 4段', N'家具', 22000, N'台', N'スチール家具株式会社'),
 (N'CONS-001', N'コピー用紙 A4 500枚', N'消耗品', 580, N'冊', N'ペーパーサプライ株式会社'),
 (N'CONS-002', N'コピー用紙 A3 500枚', N'消耗品', 980, N'冊', N'ペーパーサプライ株式会社'),
 (N'CONS-003', N'ボールペン 黒 10本入', N'消耗品', 450, N'箱', N'文具プロ株式会社'),
 (N'CONS-004', N'マジックインキ 各色セット', N'消耗品', 680, N'セット', N'文具プロ株式会社'),
 (N'CONS-005', N'付箋 75x75mm 10冊セット', N'消耗品', 520, N'セット', N'文具プロ株式会社'),
 (N'CONS-006', N'トナーカートリッジ BK', N'消耗品', 7800, N'本', N'プリントサプライ株式会社'),
 (N'CONS-007', N'トナーカートリッジ カラーセット', N'消耗品', 18000, N'セット', N'プリントサプライ株式会社'),
 (N'CONS-008', N'クリアファイル A4 50枚入', N'消耗品', 750, N'袋', N'文具プロ株式会社'),
 (N'CONS-009', N'封筒 長形3号 100枚', N'消耗品', 430, N'袋', N'文具プロ株式会社'),
 (N'CONS-010', N'ラベルシール A4 20面 50枚', N'消耗品', 1200, N'冊', N'ペーパーサプライ株式会社'),
 (N'NETW-001', N'L2スイッチ 24ポート', N'ネットワーク', 45000, N'台', N'ネットワークプロ株式会社'),
 (N'NETW-002', N'Wi-Fi ルーター 6E', N'ネットワーク', 22000, N'台', N'ネットワークプロ株式会社'),
 (N'NETW-003', N'LANケーブル CAT6 10m', N'ネットワーク', 1200, N'本', N'ケーブルサプライ株式会社'),
 (N'NETW-004', N'LANケーブル CAT6 30m', N'ネットワーク', 2800, N'本', N'ケーブルサプライ株式会社'),
 (N'NETW-005', N'NAS 4TB レイド対応', N'ネットワーク', 68000, N'台', N'ストレージテック株式会社'),
 (N'SOFT-001', N'ウイルス対策ソフト 1年ライセンス', N'ソフトウェア', 4800, N'本', N'セキュリティソフト株式会社'),
 (N'SOFT-002', N'Office Suite 1年サブスク', N'ソフトウェア', 12800, N'本', N'ソフトウェアプロ株式会社'),
 (N'SOFT-003', N'図面作成ソフト プロ版', N'ソフトウェア', 89000, N'本', N'デザインソフト株式会社'),
 (N'SOFT-004', N'プロジェクト管理ツール 10ユーザー', N'ソフトウェア', 28000, N'本', N'ビジネスソフト株式会社'),
 (N'MISC-001', N'デスクトップクリーナー', N'その他', 1800, N'セット', N'クリーニング株式会社'),
 (N'MISC-002', N'電源タップ 6口 3m', N'その他', 2800, N'個', N'パワーサプライ株式会社'),
 (N'MISC-003', N'UPS 500VA', N'その他', 18000, N'台', N'パワーサプライ株式会社'),
 (N'MISC-004', N'モバイルバッテリー 20000mAh', N'その他', 4800, N'個', N'モバイルテック株式会社'),
 (N'MISC-005', N'HDMIケーブル 2m 4K対応', N'その他', 1500, N'本', N'ケーブルサプライ株式会社'),
 (N'MISC-006', N'USB-C ケーブル 1m', N'その他', 1200, N'本', N'ケーブルサプライ株式会社'),
 (N'MISC-007', N'プリンター A4 複合機', N'その他', 35000, N'台', N'プリントサプライ株式会社'),
 (N'MISC-008', N'シュレッダー A4 マイクロカット', N'その他', 18500, N'台', N'オフィスギア株式会社'),
 (N'MISC-009', N'コーヒーメーカー 業務用', N'その他', 28000, N'台', N'オフィスアプライアンス株式会社'),
 (N'MISC-010', N'冷蔵庫 100L オフィス用', N'その他', 38000, N'台', N'オフィスアプライアンス株式会社'),
 (N'ELEC-011', N'Webカメラ 4K 広角', N'電子機器', 14800, N'台', N'ビジョンテック株式会社'),
 (N'ELEC-012', N'外付けSSD 1TB', N'電子機器', 12800, N'個', N'ストレージテック株式会社'),
 (N'ELEC-013', N'ドッキングステーション USB-C', N'電子機器', 22000, N'台', N'コネクトデバイス株式会社'),
 (N'ELEC-014', N'プロジェクター FHD 3500lm', N'電子機器', 85000, N'台', N'ビジョンテック株式会社'),
 (N'ELEC-015', N'スキャナー A4 ドキュメント', N'電子機器', 45000, N'台', N'プリントサプライ株式会社'),
 (N'ELEC-016', N'デジタルサイネージ 43インチ', N'電子機器', 125000, N'台', N'ビジョンテック株式会社');
GO

-- ============================================================
-- 倉庫マスタ (5件)
-- ============================================================
INSERT INTO warehouses (warehouse_code, warehouse_name, location) VALUES
 (N'WH-TOKYO', N'東京物流センター', N'東京都江東区'),
 (N'WH-OSAKA', N'大阪物流センター', N'大阪府堺市'),
 (N'WH-NAGOYA', N'名古屋物流センター', N'愛知県名古屋市'),
 (N'WH-FUKUOKA', N'福岡物流センター', N'福岡県福岡市'),
 (N'WH-SAPPORO', N'札幌物流センター', N'北海道札幌市');
GO

-- ============================================================
-- 在庫データ (直近3ヶ月のスナップショット)
-- ============================================================
-- 今月の在庫スナップショット
INSERT INTO inventory (product_id, warehouse_id, snapshot_date, quantity_on_hand, quantity_reserved) VALUES
-- 東京倉庫
(1, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 45, 10),
(2, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 120, 25),
(3, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 30, 5),
(4, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 85, 15),
(5, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 200, 40),
(16, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 2500, 300),
(17, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 1800, 200),
(18, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 3200, 400),
(26, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 50, 8),
(27, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 35, 5),
-- 大阪倉庫
(1, 2, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 30, 8),
(2, 2, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 80, 15),
(16, 2, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 1500, 200),
(18, 2, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 2000, 250),
-- 名古屋倉庫
(3, 3, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 20, 3),
(5, 3, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS DATE), 100, 20);
GO

-- 先月の在庫スナップショット
INSERT INTO inventory (product_id, warehouse_id, snapshot_date, quantity_on_hand, quantity_reserved) VALUES
(1, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 1, 0) AS DATE), 60, 12),
(2, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 1, 0) AS DATE), 140, 30),
(3, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 1, 0) AS DATE), 35, 8),
(16, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 1, 0) AS DATE), 2200, 280),
(17, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 1, 0) AS DATE), 1600, 180),
(18, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 1, 0) AS DATE), 2800, 350),
(1, 2, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 1, 0) AS DATE), 40, 10),
(2, 2, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 1, 0) AS DATE), 90, 18);
GO

-- 2ヶ月前の在庫スナップショット
INSERT INTO inventory (product_id, warehouse_id, snapshot_date, quantity_on_hand, quantity_reserved) VALUES
(1, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 2, 0) AS DATE), 75, 15),
(2, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 2, 0) AS DATE), 160, 35),
(16, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 2, 0) AS DATE), 1900, 250),
(18, 1, CAST(DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 2, 0) AS DATE), 2500, 300);
GO

-- ============================================================
-- 顧客マスタ (20社)
-- ============================================================
INSERT INTO customers (customer_code, company_name, contact_name, contact_email, phone, prefecture, sales_rep_name, credit_limit) VALUES
 (N'C-0001', N'株式会社アルファテクノロジー', N'田中 一郎', N'tanaka@alpha-tech.co.jp', N'03-1234-5678', N'東京都', N'山田 太郎', 5000000),
 (N'C-0002', N'ベータ商事株式会社', N'鈴木 花子', N'suzuki@beta-shoji.co.jp', N'06-2345-6789', N'大阪府', N'佐藤 花子', 3000000),
 (N'C-0003', N'株式会社ガンマソリューションズ', N'高橋 三郎', N'takahashi@gamma-sol.co.jp', N'052-3456-7890', N'愛知県', N'山田 太郎', 8000000),
 (N'C-0004', N'デルタエンジニアリング株式会社', N'渡辺 四郎', N'watanabe@delta-eng.co.jp', N'092-4567-8901', N'福岡県', N'鈴木 一郎', 2000000),
 (N'C-0005', N'株式会社イプシロン', N'伊藤 五郎', N'ito@epsilon.co.jp', N'011-5678-9012', N'北海道', N'佐藤 花子', 1500000),
 (N'C-0006', N'ゼータシステムズ合同会社', N'中村 六子', N'nakamura@zeta-sys.co.jp', N'03-6789-0123', N'東京都', N'山田 太郎', 4000000),
 (N'C-0007', N'株式会社エータ通信', N'小林 七子', N'kobayashi@eta-tsushin.co.jp', N'03-7890-1234', N'神奈川県', N'鈴木 一郎', 6000000),
 (N'C-0008', N'シータ物産株式会社', N'加藤 八郎', N'kato@theta-bussan.co.jp', N'06-8901-2345', N'大阪府', N'佐藤 花子', 2500000),
 (N'C-0009', N'株式会社イオタ建設', N'吉田 九郎', N'yoshida@iota-kensetsu.co.jp', N'082-9012-3456', N'広島県', N'山田 太郎', 10000000),
 (N'C-0010', N'カッパサービス株式会社', N'山田 十子', N'yamada@kappa-svc.co.jp', N'022-0123-4567', N'宮城県', N'鈴木 一郎', 1000000),
 (N'C-0011', N'株式会社ラムダインダストリー', N'松本 一郎', N'matsumoto@lambda-ind.co.jp', N'03-1111-2222', N'東京都', N'山田 太郎', 15000000),
 (N'C-0012', N'ミューコーポレーション株式会社', N'井上 二郎', N'inoue@mu-corp.co.jp', N'045-2222-3333', N'神奈川県', N'佐藤 花子', 3500000),
 (N'C-0013', N'株式会社ニューテクノロジー', N'木村 三子', N'kimura@nu-tech.co.jp', N'06-3333-4444', N'大阪府', N'鈴木 一郎', 7000000),
 (N'C-0014', N'クサイリサーチ株式会社', N'林 四郎', N'hayashi@xi-research.co.jp', N'052-4444-5555', N'愛知県', N'山田 太郎', 4500000),
 (N'C-0015', N'株式会社オミクロン商事', N'清水 五子', N'shimizu@omicron-shoji.co.jp', N'03-5555-6666', N'東京都', N'佐藤 花子', 2000000),
 (N'C-0016', N'パイテクノ株式会社', N'山口 六郎', N'yamaguchi@pi-techno.co.jp', N'092-6666-7777', N'福岡県', N'鈴木 一郎', 5500000),
 (N'C-0017', N'株式会社ローシステム', N'松田 七子', N'matsuda@rho-sys.co.jp', N'03-7777-8888', N'東京都', N'山田 太郎', 9000000),
 (N'C-0018', N'シグマソリューション合同会社', N'池田 八郎', N'ikeda@sigma-sol.co.jp', N'011-8888-9999', N'北海道', N'佐藤 花子', 1200000),
 (N'C-0019', N'株式会社タウコンサルティング', N'橋本 九子', N'hashimoto@tau-consulting.co.jp', N'06-9999-0000', N'大阪府', N'鈴木 一郎', 6500000),
 (N'C-0020', N'ウプシロンホールディングス株式会社', N'石田 十郎', N'ishida@upsilon-hd.co.jp', N'03-0000-1111', N'東京都', N'山田 太郎', 20000000),
 (N'C-0021', N'ファイプレシジョン株式会社', N'西村 裕子', N'nishimura@phi-precision.co.jp', N'03-1212-3434', N'東京都', N'佐藤 花子', 3800000),
 (N'C-0022', N'株式会社カイイノベーション', N'前田 誠', N'maeda@chi-innovation.co.jp', N'06-2323-4545', N'大阪府', N'山田 太郎', 4200000),
 (N'C-0023', N'プサイコンピューティング合同会社', N'後藤 美咲', N'goto@psi-computing.co.jp', N'052-3434-5656', N'愛知県', N'鈴木 一郎', 2800000),
 (N'C-0024', N'株式会社オメガエレクトロニクス', N'藤田 健太', N'fujita@omega-elec.co.jp', N'092-4545-6767', N'福岡県', N'佐藤 花子', 7500000),
 (N'C-0025', N'アルファプライム株式会社', N'中島 さやか', N'nakajima@alpha-prime.co.jp', N'045-5656-7878', N'神奈川県', N'山田 太郎', 5200000),
 (N'C-0026', N'株式会社ベータネクスト', N'斉藤 隆', N'saito@beta-next.co.jp', N'03-6767-8989', N'東京都', N'鈴木 一郎', 3100000),
 (N'C-0027', N'ガンマプロダクツ株式会社', N'阿部 千夏', N'abe@gamma-products.co.jp', N'011-7878-9090', N'北海道', N'佐藤 花子', 1800000),
 (N'C-0028', N'株式会社デルタアドバンス', N'福田 浩二', N'fukuda@delta-advance.co.jp', N'082-8989-0101', N'広島県', N'山田 太郎', 6000000),
 (N'C-0029', N'イプシロンデジタル合同会社', N'岡田 明', N'okada@epsilon-digital.co.jp', N'022-9090-1212', N'宮城県', N'鈴木 一郎', 2200000),
 (N'C-0030', N'株式会社ゼータロジスティクス', N'村上 恵', N'murakami@zeta-logistics.co.jp', N'06-0101-2323', N'大阪府', N'佐藤 花子', 8800000),
 (N'C-0031', N'エータメディア株式会社', N'長谷川 聡', N'hasegawa@eta-media.co.jp', N'03-1313-2424', N'東京都', N'山田 太郎', 4600000),
 (N'C-0032', N'株式会社シータエナジー', N'石川 ゆり', N'ishikawa@theta-energy.co.jp', N'076-2424-3535', N'石川県', N'鈴木 一郎', 9500000),
 (N'C-0033', N'イオタケミカル合同会社', N'小川 大輔', N'ogawa@iota-chemical.co.jp', N'087-3535-4646', N'香川県', N'佐藤 花子', 3300000),
 (N'C-0034', N'株式会社カッパフード', N'宮崎 奈々', N'miyazaki@kappa-food.co.jp', N'099-4646-5757', N'鹿児島県', N'山田 太郎', 1600000),
 (N'C-0035', N'ラムダライフサイエンス株式会社', N'木下 正', N'kinoshita@lambda-lifesci.co.jp', N'03-5757-6868', N'東京都', N'鈴木 一郎', 12000000),
 (N'C-0036', N'株式会社ミューファイナンス', N'藤原 智子', N'fujiwara@mu-finance.co.jp', N'06-6868-7979', N'大阪府', N'佐藤 花子', 5000000),
 (N'C-0037', N'ニュートランスポート合同会社', N'竹内 義雄', N'takeuchi@nu-transport.co.jp', N'052-7979-8080', N'愛知県', N'山田 太郎', 7200000),
 (N'C-0038', N'株式会社クサイリテール', N'上田 麻衣', N'ueda@xi-retail.co.jp', N'03-8080-9191', N'東京都', N'鈴木 一郎', 2600000),
 (N'C-0039', N'オミクロンエンタープライズ株式会社', N'栗原 豊', N'kurihara@omicron-ent.co.jp', N'045-9191-0202', N'神奈川県', N'佐藤 花子', 4000000),
 (N'C-0040', N'株式会社パイコンストラクション', N'矢野 純', N'yano@pi-construction.co.jp', N'092-0202-1313', N'福岡県', N'山田 太郎', 11000000),
 (N'C-0041', N'ローテクノロジーズ株式会社', N'加藤 恵美', N'kato-e@rho-technologies.co.jp', N'03-2121-3232', N'東京都', N'鈴木 一郎', 3700000),
 (N'C-0042', N'株式会社シグマアグリ', N'三浦 浩', N'miura@sigma-agri.co.jp', N'011-3232-4343', N'北海道', N'佐藤 花子', 2400000),
 (N'C-0043', N'タウテキスタイル合同会社', N'坂本 愛', N'sakamoto@tau-textile.co.jp', N'06-4343-5454', N'大阪府', N'山田 太郎', 3200000),
 (N'C-0044', N'株式会社ウプシロンヘルスケア', N'和田 勇', N'wada@upsilon-health.co.jp', N'022-5454-6565', N'宮城県', N'鈴木 一郎', 8000000),
 (N'C-0045', N'ファイエデュケーション株式会社', N'原田 理奈', N'harada@phi-education.co.jp', N'03-6565-7676', N'東京都', N'佐藤 花子', 1900000),
 (N'C-0046', N'株式会社カイフューチャー', N'佐野 哲', N'sano@chi-future.co.jp', N'052-7676-8787', N'愛知県', N'山田 太郎', 5800000),
 (N'C-0047', N'プサイネットワークス合同会社', N'杉山 美由紀', N'sugiyama@psi-networks.co.jp', N'06-8787-9898', N'大阪府', N'鈴木 一郎', 4400000),
 (N'C-0048', N'株式会社オメガマニュファクチャリング', N'大野 博', N'ohno@omega-mfg.co.jp', N'082-9898-0909', N'広島県', N'佐藤 花子', 9200000),
 (N'C-0049', N'アルファグローバル株式会社', N'土屋 瑞希', N'tsuchiya@alpha-global.co.jp', N'03-0909-1010', N'東京都', N'山田 太郎', 6700000),
 (N'C-0050', N'株式会社ベータサポート', N'新井 亘', N'arai@beta-support.co.jp', N'045-1010-2121', N'神奈川県', N'鈴木 一郎', 2100000);
GO

-- ============================================================
-- 注文データ (3ヶ月分 30件)
-- ============================================================
INSERT INTO orders (order_number, customer_id, order_date, required_date, shipped_date, status, total_amount) VALUES
 (N'ORD-2025-0001', 1, DATEADD(day, -85, GETDATE()), DATEADD(day, -80, GETDATE()), DATEADD(day, -79, GETDATE()), N'完了', 567400),
 (N'ORD-2025-0002', 3, DATEADD(day, -82, GETDATE()), DATEADD(day, -77, GETDATE()), DATEADD(day, -76, GETDATE()), N'完了', 420000),
 (N'ORD-2025-0003', 7, DATEADD(day, -80, GETDATE()), DATEADD(day, -75, GETDATE()), DATEADD(day, -73, GETDATE()), N'完了', 189800),
 (N'ORD-2025-0004', 11, DATEADD(day, -75, GETDATE()), DATEADD(day, -70, GETDATE()), DATEADD(day, -69, GETDATE()), N'完了', 1250000),
 (N'ORD-2025-0005', 2, DATEADD(day, -72, GETDATE()), DATEADD(day, -67, GETDATE()), DATEADD(day, -66, GETDATE()), N'完了', 89600),
 (N'ORD-2025-0006', 5, DATEADD(day, -68, GETDATE()), DATEADD(day, -63, GETDATE()), DATEADD(day, -62, GETDATE()), N'完了', 35400),
 (N'ORD-2025-0007', 9, DATEADD(day, -65, GETDATE()), DATEADD(day, -60, GETDATE()), DATEADD(day, -58, GETDATE()), N'完了', 720000),
 (N'ORD-2025-0008', 13, DATEADD(day, -62, GETDATE()), DATEADD(day, -57, GETDATE()), DATEADD(day, -55, GETDATE()), N'完了', 156000),
 (N'ORD-2025-0009', 6, DATEADD(day, -58, GETDATE()), DATEADD(day, -53, GETDATE()), DATEADD(day, -51, GETDATE()), N'完了', 495000),
 (N'ORD-2025-0010', 17, DATEADD(day, -55, GETDATE()), DATEADD(day, -50, GETDATE()), DATEADD(day, -48, GETDATE()), N'完了', 378200),
 (N'ORD-2025-0011', 1, DATEADD(day, -45, GETDATE()), DATEADD(day, -40, GETDATE()), DATEADD(day, -38, GETDATE()), N'完了', 280000),
 (N'ORD-2025-0012', 4, DATEADD(day, -42, GETDATE()), DATEADD(day, -37, GETDATE()), DATEADD(day, -35, GETDATE()), N'完了', 145000),
 (N'ORD-2025-0013', 8, DATEADD(day, -40, GETDATE()), DATEADD(day, -35, GETDATE()), DATEADD(day, -33, GETDATE()), N'完了', 612000),
 (N'ORD-2025-0014', 12, DATEADD(day, -38, GETDATE()), DATEADD(day, -33, GETDATE()), DATEADD(day, -31, GETDATE()), N'完了', 96000),
 (N'ORD-2025-0015', 20, DATEADD(day, -35, GETDATE()), DATEADD(day, -30, GETDATE()), DATEADD(day, -28, GETDATE()), N'完了', 1580000),
 (N'ORD-2025-0016', 3, DATEADD(day, -25, GETDATE()), DATEADD(day, -20, GETDATE()), DATEADD(day, -18, GETDATE()), N'完了', 345000),
 (N'ORD-2025-0017', 11, DATEADD(day, -22, GETDATE()), DATEADD(day, -17, GETDATE()), DATEADD(day, -15, GETDATE()), N'完了', 890000),
 (N'ORD-2025-0018', 6, DATEADD(day, -20, GETDATE()), DATEADD(day, -15, GETDATE()), DATEADD(day, -13, GETDATE()), N'完了', 168000),
 (N'ORD-2025-0019', 15, DATEADD(day, -18, GETDATE()), DATEADD(day, -13, GETDATE()), DATEADD(day, -11, GETDATE()), N'完了', 52000),
 (N'ORD-2025-0020', 9, DATEADD(day, -15, GETDATE()), DATEADD(day, -10, GETDATE()), DATEADD(day, -8, GETDATE()), N'完了', 480000),
 (N'ORD-2025-0021', 17, DATEADD(day, -12, GETDATE()), DATEADD(day, -7, GETDATE()), DATEADD(day, -5, GETDATE()), N'出荷済', 238000),
 (N'ORD-2025-0022', 2, DATEADD(day, -10, GETDATE()), DATEADD(day, -5, GETDATE()), DATEADD(day, -3, GETDATE()), N'出荷済', 145600),
 (N'ORD-2025-0023', 7, DATEADD(day, -8, GETDATE()), DATEADD(day, -3, GETDATE()), NULL, N'処理中', 392000),
 (N'ORD-2025-0024', 14, DATEADD(day, -7, GETDATE()), DATEADD(day, -2, GETDATE()), NULL, N'処理中', 267000),
 (N'ORD-2025-0025', 20, DATEADD(day, -6, GETDATE()), DATEADD(day, -1, GETDATE()), NULL, N'処理中', 1200000),
 (N'ORD-2025-0026', 1, DATEADD(day, -5, GETDATE()), DATEADD(day, 0, GETDATE()), NULL, N'処理中', 380000),
 (N'ORD-2025-0027', 13, DATEADD(day, -4, GETDATE()), DATEADD(day, 1, GETDATE()), NULL, N'受付', 156000),
 (N'ORD-2025-0028', 5, DATEADD(day, -3, GETDATE()), DATEADD(day, 2, GETDATE()), NULL, N'受付', 68000),
 (N'ORD-2025-0029', 19, DATEADD(day, -2, GETDATE()), DATEADD(day, 3, GETDATE()), NULL, N'受付', 285000),
 (N'ORD-2025-0030', 11, DATEADD(day, -1, GETDATE()), DATEADD(day, 4, GETDATE()), NULL, N'受付', 540000),
 -- 追加注文データ (ORD-2025-0031 〜 ORD-2025-0050)
 (N'ORD-2025-0031', 22, DATEADD(day, -90, GETDATE()), DATEADD(day, -85, GETDATE()), DATEADD(day, -83, GETDATE()), N'完了', 312000),
 (N'ORD-2025-0032', 24, DATEADD(day, -88, GETDATE()), DATEADD(day, -83, GETDATE()), DATEADD(day, -81, GETDATE()), N'完了', 765000),
 (N'ORD-2025-0033', 28, DATEADD(day, -84, GETDATE()), DATEADD(day, -79, GETDATE()), DATEADD(day, -77, GETDATE()), N'完了', 58000),
 (N'ORD-2025-0034', 31, DATEADD(day, -78, GETDATE()), DATEADD(day, -73, GETDATE()), DATEADD(day, -71, GETDATE()), N'完了', 462000),
 (N'ORD-2025-0035', 35, DATEADD(day, -74, GETDATE()), DATEADD(day, -69, GETDATE()), DATEADD(day, -67, GETDATE()), N'完了', 1080000),
 (N'ORD-2025-0036', 38, DATEADD(day, -70, GETDATE()), DATEADD(day, -65, GETDATE()), DATEADD(day, -63, GETDATE()), N'完了', 198000),
 (N'ORD-2025-0037', 40, DATEADD(day, -66, GETDATE()), DATEADD(day, -61, GETDATE()), DATEADD(day, -59, GETDATE()), N'完了', 675000),
 (N'ORD-2025-0038', 42, DATEADD(day, -60, GETDATE()), DATEADD(day, -55, GETDATE()), DATEADD(day, -53, GETDATE()), N'完了', 89100),
 (N'ORD-2025-0039', 44, DATEADD(day, -56, GETDATE()), DATEADD(day, -51, GETDATE()), DATEADD(day, -49, GETDATE()), N'完了', 540000),
 (N'ORD-2025-0040', 46, DATEADD(day, -50, GETDATE()), DATEADD(day, -45, GETDATE()), DATEADD(day, -43, GETDATE()), N'完了', 232000),
 (N'ORD-2025-0041', 48, DATEADD(day, -47, GETDATE()), DATEADD(day, -42, GETDATE()), DATEADD(day, -40, GETDATE()), N'完了', 918000),
 (N'ORD-2025-0042', 50, DATEADD(day, -43, GETDATE()), DATEADD(day, -38, GETDATE()), DATEADD(day, -36, GETDATE()), N'完了', 384000),
 (N'ORD-2025-0043', 25, DATEADD(day, -30, GETDATE()), DATEADD(day, -25, GETDATE()), DATEADD(day, -23, GETDATE()), N'完了', 126000),
 (N'ORD-2025-0044', 33, DATEADD(day, -27, GETDATE()), DATEADD(day, -22, GETDATE()), DATEADD(day, -20, GETDATE()), N'完了', 756000),
 (N'ORD-2025-0045', 36, DATEADD(day, -24, GETDATE()), DATEADD(day, -19, GETDATE()), DATEADD(day, -17, GETDATE()), N'完了', 297000),
 (N'ORD-2025-0046', 41, DATEADD(day, -14, GETDATE()), DATEADD(day, -9, GETDATE()), DATEADD(day, -7, GETDATE()), N'出荷済', 450000),
 (N'ORD-2025-0047', 45, DATEADD(day, -11, GETDATE()), DATEADD(day, -6, GETDATE()), DATEADD(day, -4, GETDATE()), N'出荷済', 108000),
 (N'ORD-2025-0048', 47, DATEADD(day, -9, GETDATE()), DATEADD(day, -4, GETDATE()), NULL, N'処理中', 630000),
 (N'ORD-2025-0049', 49, DATEADD(day, -4, GETDATE()), DATEADD(day, 1, GETDATE()), NULL, N'受付', 189000),
 (N'ORD-2025-0050', 30, DATEADD(day, -2, GETDATE()), DATEADD(day, 3, GETDATE()), NULL, N'受付', 342000);
GO

-- ============================================================
-- 注文明細データ
-- ============================================================
INSERT INTO order_items (order_id, line_number, product_id, quantity, unit_price, discount_rate) VALUES
 (1, 1, 1, 2, 189800, 0.05),
 (1, 2, 7, 3, 54000, 0.00),
 (2, 1, 2, 3, 98000, 0.05),
 (2, 2, 9, 10, 4500, 0.00),
 (3, 1, 1, 1, 189800, 0.00),
 (4, 1, 1, 5, 189800, 0.10),
 (4, 2, 7, 5, 54000, 0.10),
 (4, 3, 13, 5, 22000, 0.10),
 (5, 1, 16, 100, 580, 0.00),
 (5, 2, 18, 50, 450, 0.00),
 (6, 1, 16, 50, 580, 0.00),
 (6, 2, 18, 20, 450, 0.00),
 (7, 1, 11, 10, 48000, 0.10),
 (7, 2, 12, 5, 68000, 0.00),
 (8, 1, 31, 10, 4800, 0.00),
 (8, 2, 32, 8, 12800, 0.00),
 (9, 1, 3, 3, 145000, 0.05),
 (10, 1, 2, 3, 98000, 0.05),
 (10, 2, 8, 5, 12000, 0.00),
 (15, 1, 1, 5, 189800, 0.10),
 (15, 2, 14, 5, 45000, 0.10),
 (15, 3, 15, 2, 68000, 0.00),
 (20, 1, 11, 8, 48000, 0.05),
 (20, 2, 12, 2, 68000, 0.00),
 (25, 1, 1, 4, 189800, 0.10),
 (25, 2, 47, 2, 125000, 0.00),
 (26, 1, 7, 5, 54000, 0.00),
 (26, 2, 11, 3, 48000, 0.10),
 (30, 1, 2, 4, 98000, 0.05),
 (30, 2, 4, 3, 68000, 0.00),
 -- 追加注文明細 (order_id 31〜50)
 (31, 1, 2, 2, 98000, 0.05),
 (31, 2, 8, 10, 12000, 0.00),
 (32, 1, 14, 5, 85000, 0.10),
 (32, 2, 7, 3, 54000, 0.05),
 (33, 1, 16, 100, 580, 0.00),
 (34, 1, 11, 5, 48000, 0.05),
 (34, 2, 7, 2, 54000, 0.00),
 (35, 1, 1, 4, 189800, 0.10),
 (35, 2, 7, 4, 54000, 0.10),
 (35, 3, 13, 4, 22000, 0.10),
 (36, 1, 18, 100, 450, 0.00),
 (36, 2, 19, 80, 520, 0.00),
 (37, 1, 3, 3, 145000, 0.05),
 (37, 2, 4, 3, 68000, 0.05),
 (38, 1, 33, 10, 4800, 0.00),
 (38, 2, 6, 5, 18000, 0.00),
 (39, 1, 11, 8, 48000, 0.05),
 (39, 2, 12, 3, 68000, 0.00),
 (40, 1, 26, 3, 45000, 0.05),
 (40, 2, 37, 5, 22000, 0.00),
 (41, 1, 1, 3, 189800, 0.05),
 (41, 2, 47, 2, 125000, 0.00),
 (41, 3, 7, 5, 54000, 0.00),
 (42, 1, 4, 2, 68000, 0.05),
 (42, 2, 5, 2, 120000, 0.05),
 (43, 1, 16, 150, 580, 0.00),
 (43, 2, 18, 50, 450, 0.00),
 (44, 1, 3, 3, 145000, 0.05),
 (44, 2, 8, 5, 12000, 0.00),
 (44, 3, 9, 10, 4500, 0.00),
 (45, 1, 2, 2, 98000, 0.05),
 (45, 2, 8, 5, 12000, 0.00),
 (46, 1, 11, 6, 48000, 0.05),
 (46, 2, 7, 3, 54000, 0.00),
 (47, 1, 18, 50, 450, 0.00),
 (47, 2, 16, 100, 580, 0.00),
 (48, 1, 3, 3, 145000, 0.05),
 (48, 2, 9, 5, 4500, 0.00),
 (49, 1, 1, 1, 189800, 0.00),
 (50, 1, 2, 2, 98000, 0.05),
 (50, 2, 11, 3, 48000, 0.05);
GO

PRINT N'Sample data inserted successfully.';
GO
