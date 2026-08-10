# Supabase 投入手順書

## 1. 事前準備
- Supabase プロジェクトを作成または既存プロジェクトに接続する。
- `public` スキーマを利用する前提で、不要なデフォルトテーブルや拡張機能の影響がないことを確認する。
- `SCHEMA.sql` の内容が最新であることを確認する。

## 2. スキーマ投入
1. Supabase コンソールの SQL Editor を開く。
2. `SCHEMA.sql` の全内容を貼り付けて実行する。
3. インデックス、関数、ビュー、制約が正常に作成されたことを確認する。

## 3. マスターデータ投入
1. `SEED.sql` を SQL Editor に貼り付けて実行する。
2. `public.cost_categories`、`public.target_dimensions`、`public.monthly_target_setting_methods` などのマスターが作成されていることを確認する。

## 4. テストデータ投入
1. `TEST_DATA.sql` を SQL Editor に貼り付けて実行する。
2. 2026年7月の売上・コスト・活動・KPIデータが投入されていることを確認する。

## 5. 検証
1. `VALIDATION_QUERIES.sql` のクエリを SQL Editor で実行する。
2. 以下を確認する。
   - `public.monthly_management_dashboard` に全階層のターゲット／実績／差異／達成率が含まれていること。
   - `activity_kpis` が月次・活動別に登録されていること。
   - `activity_kpis` で異なる KPI 名を扱えることが確認できること。
3. `monthly_management_dashboard` の `operating_profit` が `gross_profit_actual - selling_expense_actual` で計算されていること。

## 6. 本番反映前の追加確認
- Supabase の Row Level Security が必要な場合、対象テーブルのポリシーを設定する。
- `monthly_management_dashboard` ビューを参照するダッシュボード側で必要なアクセス権があることを確認する。
- 既存データがある環境へ適用する場合は、事前にバックアップを取得する。

## 7. フォローアップ
- 検証結果に差異があれば、`SCHEMA.sql` および `TEST_DATA.sql` の定義を再確認し、再度投入する。
- `VALIDATION_QUERIES.sql` を定期的な検証リストに追加する。
