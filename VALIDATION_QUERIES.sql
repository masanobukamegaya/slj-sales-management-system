-- VALIDATION_QUERIES.sql
-- 月次経営会議ビューと activity_kpis の検証用クエリ

-- 1. 月次経営会議ビューで全階層の売上/粗利益/販管費/営業利益を確認
SELECT
  year,
  month,
  dimension_type,
  dimension_name,
  kpi_type,
  kpi_name,
  target_value,
  actual_value,
  variance,
  achievement_rate
FROM public.monthly_management_dashboard
WHERE year = 2026 AND month = 7
ORDER BY
  CASE dimension_type
    WHEN 'corporate' THEN 1
    WHEN 'brand' THEN 2
    WHEN 'channel' THEN 3
    WHEN 'staff' THEN 4
    WHEN 'activity' THEN 5
    ELSE 6
  END,
  dimension_name,
  kpi_type;

-- 2. activity_kpis の項目を月次・活動別に確認
SELECT
  a.id AS activity_id,
  a.title AS activity_title,
  a.activity_type,
  ak.kpi_name,
  ak.recorded_at,
  ak.target_value,
  ak.actual_value,
  ak.measurement_unit
FROM public.activity_kpis ak
JOIN public.activities a ON ak.activity_id = a.id
ORDER BY ak.recorded_at, a.id, ak.kpi_name;

-- 3. activity_kpis に月ごとに異なる KPI 名を登録できることを確認する例
SELECT
  DATE_TRUNC('month', ak.recorded_at) AS month,
  ak.kpi_name,
  COUNT(*) AS records
FROM public.activity_kpis ak
GROUP BY DATE_TRUNC('month', ak.recorded_at), ak.kpi_name
ORDER BY month, ak.kpi_name;

-- 4. 目標と実績の差異および達成率を直接確認するクエリ
SELECT
  mt.dimension_type,
  mt.dimension_name,
  mtl.kpi_type,
  mtl.kpi_name,
  mtl.target_value,
  CASE
    WHEN mtl.kpi_type = 'sales' THEN a.sales_actual
    WHEN mtl.kpi_type = 'cost' THEN a.cost_actual
    WHEN mtl.kpi_type = 'gross_profit' THEN a.gross_profit_actual
    WHEN mtl.kpi_type = 'selling_expense' THEN a.selling_expense_actual
    WHEN mtl.kpi_type = 'operating_profit' THEN a.gross_profit_actual - a.selling_expense_actual
    WHEN mtl.kpi_type = 'activity_kpi' THEN a.activity_kpi_actual
    ELSE NULL
  END AS actual_value,
  CASE
    WHEN mtl.kpi_type = 'sales' THEN a.sales_actual - mtl.target_value
    WHEN mtl.kpi_type = 'cost' THEN a.cost_actual - mtl.target_value
    WHEN mtl.kpi_type = 'gross_profit' THEN a.gross_profit_actual - mtl.target_value
    WHEN mtl.kpi_type = 'selling_expense' THEN a.selling_expense_actual - mtl.target_value
    WHEN mtl.kpi_type = 'operating_profit' THEN (a.gross_profit_actual - a.selling_expense_actual) - mtl.target_value
    WHEN mtl.kpi_type = 'activity_kpi' THEN a.activity_kpi_actual - mtl.target_value
    ELSE NULL
  END AS variance,
  CASE
    WHEN mtl.target_value IS NOT NULL AND mtl.target_value <> 0 THEN
      CASE
        WHEN mtl.kpi_type = 'sales' THEN a.sales_actual / mtl.target_value
        WHEN mtl.kpi_type = 'cost' THEN a.cost_actual / mtl.target_value
        WHEN mtl.kpi_type = 'gross_profit' THEN a.gross_profit_actual / mtl.target_value
        WHEN mtl.kpi_type = 'selling_expense' THEN a.selling_expense_actual / mtl.target_value
        WHEN mtl.kpi_type = 'operating_profit' THEN (a.gross_profit_actual - a.selling_expense_actual) / mtl.target_value
        WHEN mtl.kpi_type = 'activity_kpi' THEN a.activity_kpi_actual / mtl.target_value
        ELSE NULL
      END
    ELSE NULL
  END AS achievement_rate
FROM public.monthly_target_lines mtl
JOIN public.monthly_targets mt ON mtl.monthly_target_id = mt.id
LEFT JOIN (
  SELECT * FROM public.monthly_management_dashboard WHERE year = 2026 AND month = 7
) a ON a.monthly_target_id = mt.id
WHERE mt.year = 2026 AND mt.month = 7
ORDER BY mt.dimension_type, mt.dimension_name, mtl.kpi_type;

-- 5. 目標変更履歴が保存されていることを確認
SELECT
  mth.monthly_target_id,
  mth.monthly_target_line_id,
  mt.dimension_type,
  mt.dimension_name,
  mth.change_type,
  mth.previous_value,
  mth.new_value,
  mth.changed_at,
  mth.reason
FROM public.monthly_target_history mth
JOIN public.monthly_targets mt ON mth.monthly_target_id = mt.id
WHERE mt.year = 2026 AND mt.month = 7
ORDER BY mth.changed_at, mt.dimension_type, mt.dimension_name;
