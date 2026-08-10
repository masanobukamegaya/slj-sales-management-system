# SLJ販売・経営管理システム設計資料

## 1. システム全体アーキテクチャ

### 1.1 構成要素

- Frontend: Next.js
  - Vercel にデプロイ
  - 管理者用ダッシュボード、月次レポート閲覧、グラフ表示、フィルタ機能
- Backend / Database: Supabase
  - PostgreSQL データベース
  - 認証・アクセス制御（Supabase Auth）
  - API エンドポイントは Next.js と Supabase SQL で実装
- Hosting: Vercel
  - フロントエンドホスティング
  - API ルートの実行
  - GitHub 連携による CI/CD
- メール通知 / スケジュール: GitHub Actions または Vercel Cron
  - 月次レポートの自動生成・配信

### 1.2 データフロー

1. ユーザーが Next.js UI にログイン
2. ダッシュボードから日次・月次の集計リクエストを実行
3. Next.js から Supabase Postgres にクエリを発行
4. Supabase から集計結果を取得し、グラフやレポートに表示
5. 月次レポートはバックグラウンドジョブで生成し、メール配信または CSV ダウンロード

### 1.3 利用シナリオ

- 管理者は全ブランド/チャネルの売上・利益を把握
- 通常ユーザーは担当ブランド・担当チャネルに紐付くデータ閲覧
- 月次経営会議では`monthly_reports`を基にP&LとKPIを確認
- うさかめ活動の進捗を`activities`で管理し、経営施策の進行を可視化
- うさかめ活動は「個人別 KDI 時系列」「単月全員結果」「特定 KDI 別比較」画面で分析可能とする

## 2. Supabase データベース設計

### 2.1 設計方針

- ブランド別・チャネル別の収益性を分析しやすくする
- 売上と原価を分離し、粗利・粗利率を算出できるようにする
- ローデータと集計データを区別し、レポート生成に耐える構造
- 活動管理と月次レポートを経営判断に直結させる

### 2.2 主要テーブル

- `brands`: ブランドマスタ
- `channels`: 販売チャネルマスタ
- `sales`: 売上データ（取引単位）
- `sales_details`: ブランド別売上明細
- `costs`: 原価・仕入・販管費データ
- `staff`: 担当者・ユーザー情報
- `activities`: うさかめ活動管理
- `activity_kpis`: 活動に紐づく行動KPI結果
- `activity_sales`: 活動と売上の紐付け・帰属分析
- `target_setting_methods`: 目標設定方式マスタ
- `monthly_targets`: 月次重点目標ヘッダー
- `target_dimensions`: 目標管理対象ディメンション
- `monthly_target_lines`: 月次目標の KPI ライン
- `monthly_reports`: 月次経営レポート
- `monthly_report_lines`: 月次レポートのブランド/チャネル/担当者別 P/L 明細

### 2.3 集計・分析の考慮点

- ブランド別収益性: `sales_details` と `costs` をブランド単位で結合
- チャネル別収益性: `sales` の `channel_id` による集計
- 売上高: `sales` の `amount` 合計
- 粗利益: `sales.amount - costs.amount` または `sales_details.gross_profit`
- 粗利率: `gross_profit / sales_amount`
- 販管費: `costs` に `cost_category`/`is_operating_expense` を持たせ、販管費と原価を区分
- 営業利益: `monthly_reports` で総売上・原価・販管費・営業利益を算出
- 月次目標: `monthly_targets` / `monthly_target_lines` で全社・ブランド別・チャネル別・担当者別・活動別の目標を管理
- 目標方式: 直接入力・前年同月比・前月比・成長率・年間計画配賦・前回コピーを `target_setting_methods` で制御
- 目標対比分析: `monthly_target_lines` の目標・実績・差異と `activity_kpis`/`activity_sales` を紐付け
- 月次レポート明細: `monthly_report_lines` を使いブランド別・チャネル別・担当者別・活動別のP/LとKPIを保存
- 経営会議用ダッシュボード: KPI カード、ブランド別/チャネル別トレンド、担当者別成果、活動別貢献、目標差異、月次レビュー

## 3. ER図

```mermaid
erDiagram
    brands ||--o{ sales_details : has
    channels ||--o{ sales : via
    sales ||--o{ sales_details : contains
    sales ||--o{ costs : relates
    staff ||--o{ activities : owns
    staff ||--o{ sales : manages
    activities ||--o{ activity_kpis : tracks
    activities ||--o{ activity_sales : produces
    sales ||--o{ activity_sales : attributed
    monthly_reports ||--o{ sales : summarizes
    monthly_reports ||--o{ costs : summarizes
    monthly_reports ||--o{ monthly_report_lines : contains
    monthly_targets ||--o{ monthly_target_lines : contains
    target_setting_methods ||--o{ monthly_targets : uses
    target_dimensions ||--o{ monthly_targets : defines
    monthly_target_lines ||--o{ activity_kpis : relates

    brands {
        uuid id PK
        varchar name
        varchar code
        text description
        timestamp created_at
        timestamp updated_at
    }
    channels {
        uuid id PK
        varchar name
        varchar code
        text description
        timestamp created_at
        timestamp updated_at
    }
    sales {
        uuid id PK
        date sales_date
        uuid channel_id FK
        numeric amount
        numeric quantity
        varchar currency
        uuid staff_id FK
        varchar location
        text notes
        timestamp created_at
        timestamp updated_at
    }
    sales_details {
        uuid id PK
        uuid sales_id FK
        uuid brand_id FK
        numeric amount
        numeric quantity
        numeric cost_amount
        numeric gross_profit
        numeric gross_margin
        varchar currency
        timestamp created_at
        timestamp updated_at
    }
    costs {
        uuid id PK
        uuid sales_id FK NULL
        uuid brand_id FK NULL
        uuid channel_id FK NULL
        numeric amount
        varchar cost_type
        varchar cost_category
        boolean is_operating_expense
        varchar vendor
        date recorded_at
        text notes
        timestamp created_at
        timestamp updated_at
    }
    staff {
        uuid id PK
        varchar name
        varchar email
        varchar role
        uuid brand_id FK NULL
        uuid channel_id FK NULL
        text notes
        timestamp created_at
        timestamp updated_at
    }
    activities {
        uuid id PK
        uuid staff_id FK
        uuid brand_id FK NULL
        uuid channel_id FK NULL
        varchar activity_type
        varchar title
        text description
        varchar kdi
        numeric kdi_value
        varchar measurement_unit
        numeric target_value NULL
        numeric actual_value NULL
        date report_date
        date start_date
        date end_date
        varchar status
        numeric impact_score
        text outcome
        timestamp created_at
        timestamp updated_at
    }
    activity_kpis {
        uuid id PK
        uuid activity_id FK
        uuid monthly_target_line_id FK NULL
        varchar kpi_name
        numeric target_value NULL
        numeric actual_value NULL
        varchar measurement_unit
        date recorded_at
        text notes
        timestamp created_at
        timestamp updated_at
    }
    monthly_targets {
        uuid id PK
        int year
        int month
        public.report_dimension_type_enum dimension_type
        uuid dimension_id NULL
        varchar dimension_name
        uuid target_setting_method_id FK
        numeric fixed_value NULL
        numeric year_on_year_rate NULL
        numeric month_on_month_rate NULL
        numeric growth_rate NULL
        numeric allocated_value NULL
        uuid previous_target_id NULL
        text notes
        timestamp created_at
        timestamp updated_at
    }
    target_setting_methods {
        uuid id PK
        varchar code
        varchar name
        text description
        timestamp created_at
        timestamp updated_at
    }
    target_dimensions {
        uuid id PK
        public.report_dimension_type_enum dimension_type
        varchar code
        varchar name
        text description
        timestamp created_at
        timestamp updated_at
    }
    monthly_target_lines {
        uuid id PK
        uuid monthly_target_id FK
        varchar kpi_name
        numeric target_value NULL
        numeric actual_value NULL
        numeric variance NULL
        varchar measurement_unit
        text notes
        timestamp created_at
        timestamp updated_at
    }
    activity_sales {
        uuid id PK
        uuid activity_id FK
        uuid sales_id FK
        numeric attributed_amount NULL
        numeric attributed_gross_profit NULL
        numeric attribution_rate NULL
        varchar attribution_model NULL
        text notes
        timestamp created_at
        timestamp updated_at
    }
    monthly_report_lines {
        uuid id PK
        uuid monthly_report_id FK
        varchar dimension_type
        uuid dimension_id NULL
        varchar dimension_name
        numeric sales_amount
        numeric cost_amount
        numeric gross_profit
        numeric gross_margin
        numeric operating_expense NULL
        numeric operating_profit NULL
        numeric net_profit NULL
        jsonb kpis NULL
        timestamp created_at
        timestamp updated_at
    }
    monthly_reports {
        uuid id PK
        int year
        int month
        numeric total_sales
        numeric total_cost
        numeric gross_profit
        numeric gross_margin
        numeric operating_expense
        numeric operating_profit
        numeric net_profit
        numeric roi
        text summary
        jsonb kpis
        timestamp created_at
        timestamp updated_at
    }
```

## 4. テーブル定義

### 4.1 `brands`

- `id` UUID PK
- `name` varchar(255) NOT NULL
- `code` varchar(50) UNIQUE
- `description` text
- `is_active` boolean DEFAULT true
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

### 4.2 `channels`

- `id` UUID PK
- `name` varchar(255) NOT NULL
- `code` varchar(50) UNIQUE
- `description` text
- `category` varchar(100) NULL
- `is_active` boolean DEFAULT true
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

### 4.3 `sales`

- `id` UUID PK
- `sales_date` date NOT NULL
- `channel_id` UUID REFERENCES channels(id)
- `staff_id` UUID REFERENCES staff(id)
- `amount` numeric(14,2) NOT NULL
- `quantity` integer DEFAULT 0
- `currency` varchar(10) DEFAULT 'JPY'
- `location` varchar(255)
- `notes` text
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

### 4.4 `sales_details`

- `id` UUID PK
- `sales_id` UUID REFERENCES sales(id) ON DELETE CASCADE
- `brand_id` UUID REFERENCES brands(id)
- `amount` numeric(14,2) NOT NULL
- `quantity` integer DEFAULT 0
- `cost_amount` numeric(14,2) NULL
- `gross_profit` numeric(14,2) NULL
- `gross_margin` numeric(14,4) NULL
- `currency` varchar(10) DEFAULT 'JPY'
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

### 4.5 `costs`

- `id` UUID PK
- `sales_id` UUID REFERENCES sales(id) NULL
- `brand_id` UUID REFERENCES brands(id) NULL
- `channel_id` UUID REFERENCES channels(id) NULL
- `amount` numeric(14,2) NOT NULL
- `cost_type` varchar(100) NOT NULL
- `cost_category` varchar(100) NOT NULL  -- e.g. COGS, SG&A, Marketing, Logistics
- `is_operating_expense` boolean DEFAULT false
- `vendor` varchar(255) NULL
- `recorded_at` date NOT NULL
- `notes` text
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

### 4.6 `staff`

- `id` UUID PK
- `name` varchar(255) NOT NULL
- `email` varchar(255) UNIQUE NOT NULL
- `role` varchar(50) NOT NULL
- `brand_id` UUID REFERENCES brands(id) NULL
- `channel_id` UUID REFERENCES channels(id) NULL
- `notes` text
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

### 4.7 `activities`

- `id` UUID PK
- `staff_id` UUID REFERENCES staff(id)
- `brand_id` UUID REFERENCES brands(id) NULL
- `channel_id` UUID REFERENCES channels(id) NULL
- `activity_type` varchar(100) NOT NULL
- `title` varchar(255) NOT NULL
- `description` text
- `kdi` varchar(100) NOT NULL
- `kdi_value` numeric(14,2) NULL
- `measurement_unit` varchar(50) NULL
- `target_value` numeric(14,2) NULL
- `actual_value` numeric(14,2) NULL
- `report_date` date NOT NULL
- `start_date` date
- `end_date` date
- `status` varchar(50) DEFAULT 'pending'
- `impact_score` numeric(5,2) NULL
- `outcome` text NULL
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

### 4.8 `activity_kpis`

- `id` UUID PK
- `activity_id` UUID REFERENCES activities(id)
- `kpi_name` varchar(100) NOT NULL
- `target_value` numeric(14,2) NULL
- `actual_value` numeric(14,2) NULL
- `measurement_unit` varchar(50) NULL
- `recorded_at` date
- `notes` text
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

### 4.9 `activity_sales`

- `id` UUID PK
- `activity_id` UUID REFERENCES activities(id)
- `sales_id` UUID REFERENCES sales(id)
- `attributed_amount` numeric(14,2) NULL
- `attributed_gross_profit` numeric(14,2) NULL
- `attribution_rate` numeric(8,4) NULL
- `attribution_model` varchar(50) NULL -- e.g. last_touch, linear, custom
- `notes` text
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

### 4.10 `monthly_reports`

- `id` UUID PK
- `year` integer NOT NULL
- `month` integer NOT NULL
- `total_sales` numeric(16,2) NOT NULL
- `total_cost` numeric(16,2) NOT NULL
- `gross_profit` numeric(16,2) NOT NULL
- `gross_margin` numeric(8,4) NOT NULL
- `operating_expense` numeric(16,2) NULL
- `operating_profit` numeric(16,2) NULL
- `net_profit` numeric(16,2) NULL
- `roi` numeric(8,4) NULL
- `summary` text
- `kpis` jsonb NULL
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

### 4.11 `monthly_report_lines`

- `id` UUID PK
- `monthly_report_id` UUID REFERENCES monthly_reports(id)
- `dimension_type` varchar(50) NOT NULL  -- brand/channel/staff/activity
- `dimension_id` UUID NULL
- `dimension_name` varchar(255) NOT NULL
- `sales_amount` numeric(16,2) NOT NULL
- `cost_amount` numeric(16,2) NOT NULL
- `gross_profit` numeric(16,2) NOT NULL
- `gross_margin` numeric(8,4) NOT NULL
- `operating_expense` numeric(16,2) NULL
- `operating_profit` numeric(16,2) NULL
- `net_profit` numeric(16,2) NULL
- `kpis` jsonb NULL
- `created_at` timestamp with time zone DEFAULT now()
- `updated_at` timestamp with time zone DEFAULT now()

## 5. 設計メモ

- `sales_details` を使ってブランド別売上を集計し、`brand_id` ごとの収益性を出せる
- `sales.channel_id` によってチャネル別売上・粗利を集計
- `costs` は売上に紐づく原価・仕入に加え、チャネル別固定費や販管費も蓄積可能
- `costs.cost_category` / `costs.is_operating_expense` で COGS と SG&A を区分し、営業利益を算出可能
- `activity_sales` によって活動別売上貢献度を分析し、KDI→売上→粗利益への帰属を可視化
- `monthly_reports.kpis` は JSONB で月次ダッシュボード指標を保存
- `activities` は経営施策や案件管理を可視化し、会議用の進捗ダッシュボードに反映
- `activities` は以下の分析画面を想定
  - 個人別 KDI 時系列: 担当者ごとのKDI推移をグラフ化
  - 単月全員結果: 指定月の全メンバーのKDI実績をランキング/比較
  - KDI別比較: 特定のKDIに対する担当者別／ブランド別／チャネル別の達成状況

この設計書をレビューしてください。もし必要であれば、ER図の詳細化や `monthly_reports` に紐づく `report_items` テーブル追加もできます。
