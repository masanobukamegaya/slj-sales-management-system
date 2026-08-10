-- SLJ 販売・経営管理システム
-- Supabase PostgreSQL 用 DDL
-- 本番運用を想定したスキーマ、コメント、インデックス、RLS、権限設計

-- 1. ENUM 定義
CREATE TYPE public.staff_role_enum AS ENUM ('admin', 'user');
CREATE TYPE public.activity_status_enum AS ENUM ('pending', 'in_progress', 'completed', 'archived');
CREATE TYPE public.attribution_model_enum AS ENUM ('last_touch', 'linear', 'custom', 'first_touch');
CREATE TYPE public.cost_category_group_enum AS ENUM ('cogs', 'sg_a', 'non_operating', 'other');
CREATE TYPE public.report_dimension_type_enum AS ENUM ('corporate', 'brand', 'channel', 'staff', 'activity', 'other');
CREATE TYPE public.target_kpi_type_enum AS ENUM ('sales', 'cost', 'gross_profit', 'selling_expense', 'operating_profit', 'activity_kpi');
CREATE TYPE public.validation_severity_enum AS ENUM ('warning', 'error');

CREATE TABLE public.cost_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  category_group public.cost_category_group_enum NOT NULL DEFAULT 'other',
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.cost_categories IS '費用区分マスタ';
COMMENT ON COLUMN public.cost_categories.category_group IS '費用区分グループ(原価/販管費/営業外費用/その他)';

-- 2. ユーティリティ関数
CREATE OR REPLACE FUNCTION public.current_user_role() RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT current_setting('jwt.claims.role', true);
$$;

CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT current_setting('jwt.claims.role', true) = 'admin';
$$;

CREATE OR REPLACE FUNCTION public.current_user_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.staff_id_for_current_user() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT id FROM public.staff WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_staff_user_or_admin(p_staff_id uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT public.is_admin() OR p_staff_id = public.staff_id_for_current_user();
$$;

-- 3. テーブル定義

CREATE TABLE public.brands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.brands IS 'ブランドマスタ';
COMMENT ON COLUMN public.brands.name IS 'ブランド名';
COMMENT ON COLUMN public.brands.code IS 'ブランドコード';

CREATE TABLE public.channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text UNIQUE,
  description text,
  category text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.channels IS '販売チャネルマスタ';
COMMENT ON COLUMN public.channels.category IS 'チャネルカテゴリ';

CREATE TABLE public.staff (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  role public.staff_role_enum NOT NULL DEFAULT 'user',
  brand_id uuid REFERENCES public.brands(id) ON DELETE SET NULL,
  channel_id uuid REFERENCES public.channels(id) ON DELETE SET NULL,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.staff IS '担当者・ユーザー情報';
COMMENT ON COLUMN public.staff.user_id IS 'Supabase Auth のユーザー ID に対応';
COMMENT ON COLUMN public.staff.role IS 'システム権限(admin/user)';

CREATE TABLE public.sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_date date NOT NULL,
  channel_id uuid REFERENCES public.channels(id) ON DELETE RESTRICT,
  staff_id uuid REFERENCES public.staff(id) ON DELETE SET NULL,
  amount numeric(16,2) NOT NULL,
  quantity integer NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'JPY',
  location text,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.sales IS '売上データ(取引単位)';
COMMENT ON COLUMN public.sales.amount IS '売上金額';

CREATE TABLE public.sales_details (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_id uuid REFERENCES public.sales(id) ON DELETE CASCADE,
  brand_id uuid REFERENCES public.brands(id) ON DELETE RESTRICT,
  amount numeric(16,2) NOT NULL,
  quantity integer NOT NULL DEFAULT 0,
  cost_amount numeric(16,2),
  gross_profit numeric(16,2),
  gross_margin numeric(8,4),
  currency text NOT NULL DEFAULT 'JPY',
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.sales_details IS 'ブランド別売上明細';
COMMENT ON COLUMN public.sales_details.cost_amount IS 'ブランド別原価金額';
COMMENT ON COLUMN public.sales_details.gross_profit IS 'ブランド別粗利益';

CREATE TABLE public.costs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_id uuid REFERENCES public.sales(id) ON DELETE SET NULL,
  brand_id uuid REFERENCES public.brands(id) ON DELETE SET NULL,
  channel_id uuid REFERENCES public.channels(id) ON DELETE SET NULL,
  amount numeric(16,2) NOT NULL,
  cost_type text NOT NULL,
  cost_category_id uuid NOT NULL REFERENCES public.cost_categories(id) ON DELETE RESTRICT,
  vendor text,
  recorded_at date NOT NULL,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON COLUMN public.costs.cost_category_id IS '費用区分(広告費/物流費/人件費/営業外費用など)';
COMMENT ON TABLE public.costs IS '原価・仕入・販管費データ';

CREATE TABLE public.activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid REFERENCES public.staff(id) ON DELETE RESTRICT,
  brand_id uuid REFERENCES public.brands(id) ON DELETE SET NULL,
  channel_id uuid REFERENCES public.channels(id) ON DELETE SET NULL,
  activity_type text NOT NULL,
  title text NOT NULL,
  description text,
  kdi text NOT NULL,
  kdi_value numeric(16,2),
  measurement_unit text,
  target_value numeric(16,2),
  actual_value numeric(16,2),
  report_date date NOT NULL,
  start_date date,
  end_date date,
  status public.activity_status_enum NOT NULL DEFAULT 'pending',
  impact_score numeric(8,4),
  outcome text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.activities IS 'うさかめ活動管理';
COMMENT ON COLUMN public.activities.kdi IS '活動のKDI名称';
COMMENT ON COLUMN public.activities.kdi_value IS '活動KDIの実績値';

CREATE TABLE public.target_setting_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.target_setting_methods IS '目標設定方式マスタ';
COMMENT ON COLUMN public.target_setting_methods.code IS '目標設定方式コード';

CREATE TABLE public.target_dimensions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dimension_type public.report_dimension_type_enum NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.target_dimensions IS '目標管理対象ディメンション';
COMMENT ON COLUMN public.target_dimensions.code IS 'ディメンションコード';
COMMENT ON COLUMN public.target_dimensions.name IS 'ディメンション名称';

CREATE TABLE public.monthly_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  year integer NOT NULL,
  month integer NOT NULL,
  dimension_type public.report_dimension_type_enum NOT NULL,
  dimension_id uuid,
  dimension_name text NOT NULL,
  parent_target_id uuid REFERENCES public.monthly_targets(id) ON DELETE RESTRICT,
  target_setting_method_id uuid NOT NULL REFERENCES public.target_setting_methods(id) ON DELETE RESTRICT,
  fixed_value numeric(18,2),
  year_on_year_rate numeric(8,4),
  month_on_month_rate numeric(8,4),
  growth_rate numeric(8,4),
  allocation_rate numeric(8,4),
  allocated_value numeric(18,2),
  previous_target_id uuid REFERENCES public.monthly_targets(id) ON DELETE SET NULL,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(year, month, dimension_type, dimension_id),
  CHECK (parent_target_id IS NULL OR parent_target_id <> id),
  CHECK (dimension_type IN ('corporate', 'brand', 'channel', 'staff', 'activity'))
);
COMMENT ON TABLE public.monthly_targets IS '月次重点目標ヘッダー';
COMMENT ON COLUMN public.monthly_targets.dimension_name IS '目標対象名称';
COMMENT ON COLUMN public.monthly_targets.target_setting_method_id IS '目標設定方式';
COMMENT ON COLUMN public.monthly_targets.parent_target_id IS '親目標への参照';
COMMENT ON COLUMN public.monthly_targets.allocation_rate IS '親目標から配分する場合の配分率';

CREATE TABLE public.monthly_target_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  monthly_target_id uuid REFERENCES public.monthly_targets(id) ON DELETE CASCADE,
  parent_line_id uuid REFERENCES public.monthly_target_lines(id) ON DELETE SET NULL,
  kpi_type public.target_kpi_type_enum NOT NULL,
  kpi_name text NOT NULL,
  target_value numeric(18,2),
  actual_value numeric(18,2),
  variance numeric(18,2),
  measurement_unit text,
  cause text,
  action_plan text,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(monthly_target_id, kpi_name),
  CHECK (parent_line_id IS NULL OR parent_line_id <> id)
);
COMMENT ON TABLE public.monthly_target_lines IS '月次目標のKPIライン';
COMMENT ON COLUMN public.monthly_target_lines.kpi_type IS '目標KPIの種別';
COMMENT ON COLUMN public.monthly_target_lines.variance IS '目標と実績の差異';
COMMENT ON COLUMN public.monthly_target_lines.cause IS '差異要因分析';
COMMENT ON COLUMN public.monthly_target_lines.action_plan IS '改善活動・次のアクション';

CREATE TABLE public.monthly_target_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  monthly_target_id uuid REFERENCES public.monthly_targets(id) ON DELETE CASCADE,
  monthly_target_line_id uuid REFERENCES public.monthly_target_lines(id) ON DELETE CASCADE,
  changed_at timestamp with time zone NOT NULL DEFAULT now(),
  changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  change_type text NOT NULL,
  previous_value jsonb,
  new_value jsonb,
  reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.monthly_target_history IS '月次目標の変更履歴';
COMMENT ON COLUMN public.monthly_target_history.change_type IS '変更種別';

INSERT INTO public.target_setting_methods(code, name, description)
VALUES
  ('direct', 'Direct Input', 'Absolute target entered directly'),
  ('yoy', 'Year-over-Year', 'Target derived from prior year growth'),
  ('growth_rate', 'Growth Rate', 'Target derived from an overall growth assumption'),
  ('allocation', 'Allocation', 'Target allocated from a parent target'),
  ('copy_previous', 'Previous Copy', 'Target copied from the previous month or year')
ON CONFLICT (code) DO NOTHING;

CREATE OR REPLACE FUNCTION public.current_change_reason() RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT current_setting('app.change_reason', true);
$$;

CREATE OR REPLACE FUNCTION public.monthly_targets_check_parent() RETURNS trigger AS $$
DECLARE
  parent_year integer;
  parent_month integer;
  parent_dimension public.report_dimension_type_enum;
  cycle_found boolean;
BEGIN
  IF NEW.dimension_type = 'corporate' THEN
    IF NEW.parent_target_id IS NOT NULL THEN
      RAISE EXCEPTION 'Corporate target cannot have a parent';
    END IF;
  ELSE
    IF NEW.parent_target_id IS NULL THEN
      RAISE EXCEPTION 'Non-corporate target must have a parent';
    END IF;
    SELECT year, month, dimension_type INTO parent_year, parent_month, parent_dimension
      FROM public.monthly_targets WHERE id = NEW.parent_target_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Parent monthly target % not found', NEW.parent_target_id;
    END IF;
    IF parent_year <> NEW.year OR parent_month <> NEW.month THEN
      RAISE EXCEPTION 'Parent target must share the same year and month';
    END IF;
    IF NEW.parent_target_id = NEW.id THEN
      RAISE EXCEPTION 'Monthly target cannot reference itself as parent';
    END IF;
    WITH RECURSIVE ancestors(id) AS (
      SELECT NEW.parent_target_id
      UNION ALL
      SELECT mt.parent_target_id
      FROM public.monthly_targets mt
      JOIN ancestors a ON mt.id = a.id
      WHERE mt.parent_target_id IS NOT NULL
    )
    SELECT true INTO cycle_found FROM ancestors WHERE id = NEW.id LIMIT 1;
    IF cycle_found THEN
      RAISE EXCEPTION 'Cyclic parent_target_id detected for monthly target %', NEW.id;
    END IF;
    IF NEW.dimension_type = 'brand' AND parent_dimension <> 'corporate' THEN
      RAISE EXCEPTION 'Brand target must have a corporate parent';
    ELSIF NEW.dimension_type = 'channel' AND parent_dimension <> 'brand' THEN
      RAISE EXCEPTION 'Channel target must have a brand parent';
    ELSIF NEW.dimension_type = 'staff' AND parent_dimension <> 'channel' THEN
      RAISE EXCEPTION 'Staff target must have a channel parent';
    ELSIF NEW.dimension_type = 'activity' AND parent_dimension <> 'staff' THEN
      RAISE EXCEPTION 'Activity target must have a staff parent';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.monthly_target_lines_check_parent() RETURNS trigger AS $$
DECLARE
  parent_monthly_target_id uuid;
  cycle_found boolean;
BEGIN
  IF NEW.parent_line_id IS NOT NULL THEN
    SELECT monthly_target_id INTO parent_monthly_target_id
      FROM public.monthly_target_lines WHERE id = NEW.parent_line_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Parent monthly target line % not found', NEW.parent_line_id;
    END IF;
    IF parent_monthly_target_id <> NEW.monthly_target_id THEN
      RAISE EXCEPTION 'Parent line must belong to the same monthly target';
    END IF;
    IF NEW.parent_line_id = NEW.id THEN
      RAISE EXCEPTION 'Monthly target line cannot reference itself as parent';
    END IF;
    WITH RECURSIVE ancestors(id) AS (
      SELECT NEW.parent_line_id
      UNION ALL
      SELECT mtl.parent_line_id
      FROM public.monthly_target_lines mtl
      JOIN ancestors a ON mtl.id = a.id
      WHERE mtl.parent_line_id IS NOT NULL
    )
    SELECT true INTO cycle_found FROM ancestors WHERE id = NEW.id LIMIT 1;
    IF cycle_found THEN
      RAISE EXCEPTION 'Cyclic parent_line_id detected for monthly target line %', NEW.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE public.monthly_target_validation_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  monthly_target_id uuid REFERENCES public.monthly_targets(id) ON DELETE CASCADE,
  monthly_target_line_id uuid REFERENCES public.monthly_target_lines(id) ON DELETE CASCADE,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  severity public.validation_severity_enum NOT NULL DEFAULT 'warning',
  issue_type text NOT NULL,
  message text NOT NULL,
  details jsonb
);
COMMENT ON TABLE public.monthly_target_validation_issues IS '月次目標の整合性チェック警告';

CREATE OR REPLACE FUNCTION public.monthly_target_validation_issue_insert(
  p_monthly_target_id uuid,
  p_monthly_target_line_id uuid,
  p_severity public.validation_severity_enum DEFAULT 'warning',
  p_issue_type text,
  p_message text,
  p_details jsonb DEFAULT '{}'::jsonb
) RETURNS void AS $$
BEGIN
  INSERT INTO public.monthly_target_validation_issues(
    id,
    monthly_target_id,
    monthly_target_line_id,
    severity,
    issue_type,
    message,
    details
  ) VALUES (
    gen_random_uuid(),
    p_monthly_target_id,
    p_monthly_target_line_id,
    p_severity,
    p_issue_type,
    p_message,
    p_details
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.monthly_target_lines_compute_variance() RETURNS trigger AS $$
DECLARE
  parent_target_value numeric(18,2);
  child_sum numeric(18,2);
  effective_parent_line_id uuid;
  parent_target_id uuid;
BEGIN
  IF NEW.target_value IS NOT NULL AND NEW.actual_value IS NOT NULL THEN
    NEW.variance = NEW.actual_value - NEW.target_value;
  ELSE
    NEW.variance = NULL;
  END IF;

  IF NEW.target_value IS NOT NULL THEN
    IF NEW.parent_line_id IS NOT NULL THEN
      effective_parent_line_id := NEW.parent_line_id;
    ELSE
      SELECT mt.parent_target_id INTO parent_target_id
        FROM public.monthly_targets mt
        WHERE mt.id = NEW.monthly_target_id;
      IF parent_target_id IS NOT NULL THEN
        SELECT id, target_value INTO effective_parent_line_id, parent_target_value
          FROM public.monthly_target_lines
          WHERE monthly_target_id = parent_target_id
            AND kpi_name = NEW.kpi_name
          LIMIT 1;
      END IF;
    END IF;

    IF effective_parent_line_id IS NOT NULL THEN
      IF parent_target_value IS NULL THEN
        SELECT target_value INTO parent_target_value
          FROM public.monthly_target_lines WHERE id = effective_parent_line_id;
      END IF;
      IF parent_target_value IS NOT NULL THEN
        IF NEW.parent_line_id IS NOT NULL THEN
          SELECT COALESCE(SUM(target_value), 0) INTO child_sum
            FROM public.monthly_target_lines
            WHERE parent_line_id = NEW.parent_line_id AND id <> NEW.id;
        ELSE
          SELECT COALESCE(SUM(mtl.target_value), 0) INTO child_sum
            FROM public.monthly_target_lines mtl
            JOIN public.monthly_targets mt ON mtl.monthly_target_id = mt.id
            WHERE mt.parent_target_id = parent_target_id
              AND mtl.kpi_name = NEW.kpi_name
              AND mtl.id <> NEW.id;
        END IF;
        child_sum := child_sum + NEW.target_value;
        IF child_sum > parent_target_value + 0.01 THEN
          PERFORM public.monthly_target_validation_issue_insert(
            NEW.monthly_target_id,
            NEW.id,
            'warning',
            'child_sum_exceeds_parent',
            'Child target line sum exceeds parent target line value',
            jsonb_build_object(
              'parent_line_id', effective_parent_line_id,
              'parent_target_value', parent_target_value,
              'child_sum', child_sum
            )
          );
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.monthly_target_history_insert() RETURNS trigger AS $$
BEGIN
  INSERT INTO public.monthly_target_history(
    id,
    monthly_target_id,
    monthly_target_line_id,
    changed_at,
    changed_by,
    change_type,
    previous_value,
    new_value,
    reason,
    created_at
  ) VALUES (
    gen_random_uuid(),
    NEW.id,
    NULL,
    now(),
    auth.uid(),
    TG_OP,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE row_to_json(OLD)::jsonb END,
    row_to_json(NEW)::jsonb,
    public.current_change_reason(),
    now()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.monthly_target_line_history_insert() RETURNS trigger AS $$
BEGIN
  INSERT INTO public.monthly_target_history(
    id,
    monthly_target_id,
    monthly_target_line_id,
    changed_at,
    changed_by,
    change_type,
    previous_value,
    new_value,
    reason,
    created_at
  ) VALUES (
    gen_random_uuid(),
    NEW.monthly_target_id,
    NEW.id,
    now(),
    auth.uid(),
    TG_OP,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE row_to_json(OLD)::jsonb END,
    row_to_json(NEW)::jsonb,
    public.current_change_reason(),
    now()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_monthly_targets_parent_check
  BEFORE INSERT OR UPDATE ON public.monthly_targets
  FOR EACH ROW EXECUTE FUNCTION public.monthly_targets_check_parent();

CREATE TRIGGER trg_monthly_target_lines_parent_check
  BEFORE INSERT OR UPDATE ON public.monthly_target_lines
  FOR EACH ROW EXECUTE FUNCTION public.monthly_target_lines_check_parent();

CREATE TRIGGER trg_monthly_target_lines_variance
  BEFORE INSERT OR UPDATE ON public.monthly_target_lines
  FOR EACH ROW EXECUTE FUNCTION public.monthly_target_lines_compute_variance();

CREATE TRIGGER trg_monthly_target_history_insert
  AFTER INSERT OR UPDATE ON public.monthly_targets
  FOR EACH ROW EXECUTE FUNCTION public.monthly_target_history_insert();

CREATE TRIGGER trg_monthly_target_line_history_insert
  AFTER INSERT OR UPDATE ON public.monthly_target_lines
  FOR EACH ROW EXECUTE FUNCTION public.monthly_target_line_history_insert();

CREATE OR REPLACE FUNCTION public.monthly_report_lines_validate_pl() RETURNS trigger AS $$
DECLARE
  expected_gross_profit numeric(18,2);
  expected_gross_margin numeric(8,4);
  expected_operating_profit numeric(18,2);
BEGIN
  IF NEW.sales_amount IS NOT NULL AND NEW.cost_amount IS NOT NULL THEN
    expected_gross_profit := NEW.sales_amount - NEW.cost_amount;
    IF NEW.gross_profit IS NOT NULL AND abs(NEW.gross_profit - expected_gross_profit) > 0.01 THEN
      RAISE EXCEPTION 'monthly_report_line gross_profit mismatch: expected %', expected_gross_profit;
    END IF;
    IF NEW.gross_margin IS NOT NULL AND NEW.sales_amount <> 0 THEN
      expected_gross_margin := CASE WHEN NEW.sales_amount = 0 THEN NULL ELSE expected_gross_profit / NEW.sales_amount END;
      IF abs(NEW.gross_margin - expected_gross_margin) > 0.0001 THEN
        RAISE EXCEPTION 'monthly_report_line gross_margin mismatch: expected %', expected_gross_margin;
      END IF;
    END IF;
  END IF;
  IF NEW.operating_expense IS NOT NULL AND NEW.gross_profit IS NOT NULL AND NEW.operating_profit IS NOT NULL THEN
    expected_operating_profit := NEW.gross_profit - NEW.operating_expense;
    IF abs(NEW.operating_profit - expected_operating_profit) > 0.01 THEN
      RAISE EXCEPTION 'monthly_report_line operating_profit mismatch: expected %', expected_operating_profit;
    END IF;
  END IF;
  IF NEW.operating_profit IS NOT NULL AND NEW.net_profit IS NOT NULL THEN
    IF abs(NEW.net_profit - NEW.operating_profit) > 0.01 THEN
      RAISE EXCEPTION 'monthly_report_line net_profit mismatch: expected equal to operating_profit';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.monthly_targets_validate_allocation() RETURNS trigger AS $$
BEGIN
  IF NEW.parent_target_id IS NOT NULL AND NEW.target_setting_method_id IS NOT NULL THEN
    IF NEW.target_setting_method_id = (
      SELECT id FROM public.target_setting_methods WHERE code = 'allocation'
    ) AND NEW.allocation_rate IS NULL THEN
      PERFORM public.monthly_target_validation_issue_insert(
        NEW.id,
        NULL,
        'warning',
        'allocation_rate_missing',
        'Allocation target should include allocation_rate when using allocation method',
        jsonb_build_object('parent_target_id', NEW.parent_target_id)
      );
    END IF;
    IF NEW.allocation_rate IS NOT NULL AND NEW.allocated_value IS NULL THEN
      PERFORM public.monthly_target_validation_issue_insert(
        NEW.id,
        NULL,
        'warning',
        'allocated_value_missing',
        'Allocated target uses allocation_rate but allocated_value is not populated',
        jsonb_build_object('allocation_rate', NEW.allocation_rate)
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_monthly_targets_validate_allocation
  BEFORE INSERT OR UPDATE ON public.monthly_targets
  FOR EACH ROW EXECUTE FUNCTION public.monthly_targets_validate_allocation();

CREATE OR REPLACE FUNCTION public.monthly_targets_validate_child_sum() RETURNS trigger AS $$
DECLARE
  parent_fixed_value numeric(18,2);
  sibling_sum numeric(18,2);
BEGIN
  IF NEW.parent_target_id IS NOT NULL AND NEW.fixed_value IS NOT NULL THEN
    SELECT fixed_value INTO parent_fixed_value
      FROM public.monthly_targets WHERE id = NEW.parent_target_id;
    IF parent_fixed_value IS NOT NULL THEN
      SELECT COALESCE(SUM(fixed_value), 0) INTO sibling_sum
        FROM public.monthly_targets
        WHERE parent_target_id = NEW.parent_target_id
          AND id <> NEW.id;
      sibling_sum := sibling_sum + NEW.fixed_value;
      IF sibling_sum > parent_fixed_value + 0.01 THEN
        PERFORM public.monthly_target_validation_issue_insert(
          NEW.id,
          NULL,
          'error',
          'child_header_sum_exceeds_parent',
          'Child monthly target header sum exceeds parent fixed_value',
          jsonb_build_object(
            'parent_target_id', NEW.parent_target_id,
            'parent_fixed_value', parent_fixed_value,
            'child_sum', sibling_sum
          )
        );
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_monthly_targets_validate_child_sum
  BEFORE INSERT OR UPDATE ON public.monthly_targets
  FOR EACH ROW EXECUTE FUNCTION public.monthly_targets_validate_child_sum();

CREATE TABLE public.activity_kpis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id uuid REFERENCES public.activities(id) ON DELETE CASCADE,
  monthly_target_line_id uuid REFERENCES public.monthly_target_lines(id) ON DELETE SET NULL,
  kpi_name text NOT NULL,
  target_value numeric(16,2),
  actual_value numeric(16,2),
  measurement_unit text,
  recorded_at date,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.activity_kpis IS '活動に紐づく行動KPI結果';

CREATE TABLE public.activity_sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id uuid REFERENCES public.activities(id) ON DELETE CASCADE,
  sales_id uuid REFERENCES public.sales(id) ON DELETE CASCADE,
  attributed_amount numeric(16,2),
  attributed_gross_profit numeric(16,2),
  attribution_rate numeric(8,4),
  attribution_model public.attribution_model_enum,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.activity_sales IS '活動と売上の紐付け・帰属分析';
COMMENT ON COLUMN public.activity_sales.attribution_model IS '貢献度モデル';

CREATE OR REPLACE VIEW public.monthly_management_dashboard AS
WITH actuals AS (
  SELECT
    mt.id AS monthly_target_id,
    mt.dimension_type,
    mt.dimension_id,
    mt.year,
    mt.month,
    COALESCE(
      CASE
        WHEN mt.dimension_type = 'corporate' THEN (
          SELECT SUM(amount) FROM public.sales
          WHERE date_part('year', sales_date) = mt.year
            AND date_part('month', sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'brand' THEN (
          SELECT SUM(sd.amount) FROM public.sales_details sd
          JOIN public.sales s ON sd.sales_id = s.id
          WHERE sd.brand_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'channel' THEN (
          SELECT SUM(s.amount) FROM public.sales s
          WHERE s.channel_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'staff' THEN (
          SELECT SUM(s.amount) FROM public.sales s
          WHERE s.staff_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'activity' THEN (
          SELECT SUM(ats.attributed_amount) FROM public.activity_sales ats
          JOIN public.sales s ON ats.sales_id = s.id
          WHERE ats.activity_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        ELSE NULL
      END,
      0
    ) AS sales_actual,
    COALESCE(
      CASE
        WHEN mt.dimension_type = 'corporate' THEN (
          SELECT SUM(sd.amount - COALESCE(sd.cost_amount, 0)) FROM public.sales_details sd
          JOIN public.sales s ON sd.sales_id = s.id
          WHERE date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'brand' THEN (
          SELECT SUM(sd.amount - COALESCE(sd.cost_amount, 0)) FROM public.sales_details sd
          JOIN public.sales s ON sd.sales_id = s.id
          WHERE sd.brand_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'channel' THEN (
          SELECT SUM(sd.amount - COALESCE(sd.cost_amount, 0)) FROM public.sales_details sd
          JOIN public.sales s ON sd.sales_id = s.id
          WHERE s.channel_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'staff' THEN (
          SELECT SUM(sd.amount - COALESCE(sd.cost_amount, 0)) FROM public.sales_details sd
          JOIN public.sales s ON sd.sales_id = s.id
          WHERE s.staff_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'activity' THEN (
          SELECT SUM(ats.attributed_gross_profit) FROM public.activity_sales ats
          JOIN public.sales s ON ats.sales_id = s.id
          WHERE ats.activity_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        ELSE NULL
      END,
      0
    ) AS gross_profit_actual,
    COALESCE(
      CASE
        WHEN mt.dimension_type = 'corporate' THEN (
          SELECT SUM(COALESCE(sd.cost_amount, 0)) FROM public.sales_details sd
          JOIN public.sales s ON sd.sales_id = s.id
          WHERE date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'brand' THEN (
          SELECT SUM(COALESCE(sd.cost_amount, 0)) FROM public.sales_details sd
          JOIN public.sales s ON sd.sales_id = s.id
          WHERE sd.brand_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'channel' THEN (
          SELECT SUM(COALESCE(sd.cost_amount, 0)) FROM public.sales_details sd
          JOIN public.sales s ON sd.sales_id = s.id
          WHERE s.channel_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'staff' THEN (
          SELECT SUM(COALESCE(sd.cost_amount, 0)) FROM public.sales_details sd
          JOIN public.sales s ON sd.sales_id = s.id
          WHERE s.staff_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        WHEN mt.dimension_type = 'activity' THEN (
          SELECT SUM(ats.attributed_amount - COALESCE(ats.attributed_gross_profit, 0)) FROM public.activity_sales ats
          JOIN public.sales s ON ats.sales_id = s.id
          WHERE ats.activity_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        ELSE NULL
      END,
      0
    ) AS cost_actual,
    COALESCE(
      CASE
        WHEN mt.dimension_type = 'corporate' THEN (
          SELECT SUM(c.amount) FROM public.costs c
          JOIN public.cost_categories cc ON c.cost_category_id = cc.id
          WHERE cc.category_group = 'sg_a'
            AND date_part('year', c.recorded_at) = mt.year
            AND date_part('month', c.recorded_at) = mt.month
        )
        WHEN mt.dimension_type = 'brand' THEN (
          SELECT SUM(c.amount) FROM public.costs c
          JOIN public.cost_categories cc ON c.cost_category_id = cc.id
          WHERE cc.category_group = 'sg_a'
            AND c.brand_id = mt.dimension_id
            AND date_part('year', c.recorded_at) = mt.year
            AND date_part('month', c.recorded_at) = mt.month
        )
        WHEN mt.dimension_type = 'channel' THEN (
          SELECT SUM(c.amount) FROM public.costs c
          JOIN public.cost_categories cc ON c.cost_category_id = cc.id
          WHERE cc.category_group = 'sg_a'
            AND c.channel_id = mt.dimension_id
            AND date_part('year', c.recorded_at) = mt.year
            AND date_part('month', c.recorded_at) = mt.month
        )
        WHEN mt.dimension_type = 'staff' THEN (
          SELECT SUM(c.amount) FROM public.costs c
          JOIN public.cost_categories cc ON c.cost_category_id = cc.id
          JOIN public.sales s ON c.sales_id = s.id
          WHERE cc.category_group = 'sg_a'
            AND s.staff_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        ELSE NULL
      END,
      0
    ) AS selling_expense_actual,
    COALESCE(
      CASE
        WHEN mt.dimension_type = 'corporate' THEN (
          SELECT SUM(c.amount) FROM public.costs c
          JOIN public.cost_categories cc ON c.cost_category_id = cc.id
          WHERE cc.category_group = 'non_operating'
            AND date_part('year', c.recorded_at) = mt.year
            AND date_part('month', c.recorded_at) = mt.month
        )
        WHEN mt.dimension_type = 'brand' THEN (
          SELECT SUM(c.amount) FROM public.costs c
          JOIN public.cost_categories cc ON c.cost_category_id = cc.id
          WHERE cc.category_group = 'non_operating'
            AND c.brand_id = mt.dimension_id
            AND date_part('year', c.recorded_at) = mt.year
            AND date_part('month', c.recorded_at) = mt.month
        )
        WHEN mt.dimension_type = 'channel' THEN (
          SELECT SUM(c.amount) FROM public.costs c
          JOIN public.cost_categories cc ON c.cost_category_id = cc.id
          WHERE cc.category_group = 'non_operating'
            AND c.channel_id = mt.dimension_id
            AND date_part('year', c.recorded_at) = mt.year
            AND date_part('month', c.recorded_at) = mt.month
        )
        WHEN mt.dimension_type = 'staff' THEN (
          SELECT SUM(c.amount) FROM public.costs c
          JOIN public.cost_categories cc ON c.cost_category_id = cc.id
          JOIN public.sales s ON c.sales_id = s.id
          WHERE cc.category_group = 'non_operating'
            AND s.staff_id = mt.dimension_id
            AND date_part('year', s.sales_date) = mt.year
            AND date_part('month', s.sales_date) = mt.month
        )
        ELSE NULL
      END,
      0
    ) AS non_operating_expense_actual,
    COALESCE(
      CASE
        WHEN mt.dimension_type = 'staff' THEN (
          SELECT SUM(ak.actual_value) FROM public.activity_kpis ak
          JOIN public.activities a ON ak.activity_id = a.id
          WHERE a.staff_id = mt.dimension_id
            AND date_part('year', ak.recorded_at) = mt.year
            AND date_part('month', ak.recorded_at) = mt.month
        )
        WHEN mt.dimension_type = 'activity' THEN (
          SELECT SUM(ak.actual_value) FROM public.activity_kpis ak
          WHERE ak.activity_id = mt.dimension_id
            AND date_part('year', ak.recorded_at) = mt.year
            AND date_part('month', ak.recorded_at) = mt.month
        )
        ELSE NULL
      END,
      0
    ) AS activity_kpi_actual
  FROM public.monthly_targets mt
)
SELECT
  mt.year,
  mt.month,
  mt.dimension_type,
  mt.dimension_id,
  mt.dimension_name,
  mtl.kpi_type,
  mtl.kpi_name,
  mtl.target_value,
  CASE
    WHEN mtl.kpi_type = 'sales' THEN actuals.sales_actual
    WHEN mtl.kpi_type = 'cost' THEN actuals.cost_actual
    WHEN mtl.kpi_type = 'gross_profit' THEN actuals.gross_profit_actual
    WHEN mtl.kpi_type = 'selling_expense' THEN actuals.selling_expense_actual
    WHEN mtl.kpi_type = 'operating_profit' THEN actuals.gross_profit_actual - actuals.selling_expense_actual
    WHEN mtl.kpi_type = 'activity_kpi' THEN actuals.activity_kpi_actual
    ELSE NULL
  END AS actual_value,
  CASE
    WHEN mtl.kpi_type = 'sales' THEN actuals.sales_actual - mtl.target_value
    WHEN mtl.kpi_type = 'cost' THEN actuals.cost_actual - mtl.target_value
    WHEN mtl.kpi_type = 'gross_profit' THEN actuals.gross_profit_actual - mtl.target_value
    WHEN mtl.kpi_type = 'selling_expense' THEN actuals.selling_expense_actual - mtl.target_value
    WHEN mtl.kpi_type = 'operating_profit' THEN (actuals.gross_profit_actual - actuals.selling_expense_actual) - mtl.target_value
    WHEN mtl.kpi_type = 'activity_kpi' THEN actuals.activity_kpi_actual - mtl.target_value
    ELSE NULL
  END AS variance,
  CASE
    WHEN mtl.target_value IS NOT NULL AND mtl.target_value <> 0 THEN
      CASE
        WHEN mtl.kpi_type = 'sales' THEN actuals.sales_actual / mtl.target_value
        WHEN mtl.kpi_type = 'cost' THEN actuals.cost_actual / mtl.target_value
        WHEN mtl.kpi_type = 'gross_profit' THEN actuals.gross_profit_actual / mtl.target_value
        WHEN mtl.kpi_type = 'selling_expense' THEN actuals.selling_expense_actual / mtl.target_value
        WHEN mtl.kpi_type = 'operating_profit' THEN (actuals.gross_profit_actual - actuals.selling_expense_actual) / mtl.target_value
        WHEN mtl.kpi_type = 'activity_kpi' THEN actuals.activity_kpi_actual / mtl.target_value
        ELSE NULL
      END
    ELSE NULL
  END AS achievement_rate
FROM public.monthly_target_lines mtl
JOIN public.monthly_targets mt ON mtl.monthly_target_id = mt.id
LEFT JOIN actuals ON actuals.monthly_target_id = mt.id
WHERE mt.dimension_type IN ('corporate', 'brand', 'channel', 'staff', 'activity');

CREATE TABLE public.monthly_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  year integer NOT NULL,
  month integer NOT NULL,
  total_sales numeric(18,2) NOT NULL,
  total_cost numeric(18,2) NOT NULL,
  gross_profit numeric(18,2) NOT NULL,
  gross_margin numeric(8,4) NOT NULL,
  operating_expense numeric(18,2),
  operating_profit numeric(18,2),
  net_profit numeric(18,2),
  roi numeric(8,4),
  summary text,
  kpis jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (year, month)
);
COMMENT ON TABLE public.monthly_reports IS '月次経営レポート';

CREATE TABLE public.monthly_report_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  monthly_report_id uuid REFERENCES public.monthly_reports(id) ON DELETE CASCADE,
  dimension_type public.report_dimension_type_enum NOT NULL,
  dimension_id uuid,
  dimension_name text NOT NULL,
  sales_amount numeric(18,2) NOT NULL,
  cost_amount numeric(18,2) NOT NULL,
  gross_profit numeric(18,2) NOT NULL,
  gross_margin numeric(8,4) NOT NULL,
  operating_expense numeric(18,2),
  operating_profit numeric(18,2),
  net_profit numeric(18,2),
  kpis jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.monthly_report_lines IS '月次レポートのP/L明細(ブランド/チャネル/担当者/活動)';

CREATE TRIGGER trg_monthly_report_lines_pl_integrity
  BEFORE INSERT OR UPDATE ON public.monthly_report_lines
  FOR EACH ROW EXECUTE FUNCTION public.monthly_report_lines_validate_pl();

CREATE TABLE public.monthly_report_validation_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  monthly_report_id uuid REFERENCES public.monthly_reports(id) ON DELETE CASCADE,
  monthly_report_line_id uuid REFERENCES public.monthly_report_lines(id) ON DELETE CASCADE,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  severity text NOT NULL DEFAULT 'warning',
  issue_type text NOT NULL,
  message text NOT NULL,
  details jsonb
);
COMMENT ON TABLE public.monthly_report_validation_issues IS '月次レポートの整合性チェック警告';

-- 4. INDEX 設計
CREATE INDEX IF NOT EXISTS idx_staff_user_id ON public.staff(user_id);
CREATE INDEX IF NOT EXISTS idx_staff_brand_id ON public.staff(brand_id);
CREATE INDEX IF NOT EXISTS idx_staff_channel_id ON public.staff(channel_id);

CREATE INDEX IF NOT EXISTS idx_sales_sales_date ON public.sales(sales_date);
CREATE INDEX IF NOT EXISTS idx_sales_channel_id ON public.sales(channel_id);
CREATE INDEX IF NOT EXISTS idx_sales_staff_id ON public.sales(staff_id);

CREATE INDEX IF NOT EXISTS idx_sales_details_sales_id ON public.sales_details(sales_id);
CREATE INDEX IF NOT EXISTS idx_sales_details_brand_id ON public.sales_details(brand_id);

CREATE INDEX IF NOT EXISTS idx_costs_sales_id ON public.costs(sales_id);
CREATE INDEX IF NOT EXISTS idx_costs_brand_id ON public.costs(brand_id);
CREATE INDEX IF NOT EXISTS idx_costs_channel_id ON public.costs(channel_id);
CREATE INDEX IF NOT EXISTS idx_costs_cost_category_id ON public.costs(cost_category_id);

CREATE INDEX IF NOT EXISTS idx_activities_staff_id ON public.activities(staff_id);
CREATE INDEX IF NOT EXISTS idx_activities_brand_id ON public.activities(brand_id);
CREATE INDEX IF NOT EXISTS idx_activities_channel_id ON public.activities(channel_id);
CREATE INDEX IF NOT EXISTS idx_activities_report_date ON public.activities(report_date);

CREATE INDEX IF NOT EXISTS idx_activity_kpis_activity_id ON public.activity_kpis(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_kpis_monthly_target_line_id ON public.activity_kpis(monthly_target_line_id);
CREATE INDEX IF NOT EXISTS idx_activity_sales_activity_id ON public.activity_sales(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_sales_sales_id ON public.activity_sales(sales_id);

CREATE INDEX IF NOT EXISTS idx_target_setting_methods_code ON public.target_setting_methods(code);
CREATE INDEX IF NOT EXISTS idx_target_dimensions_dimension_type ON public.target_dimensions(dimension_type);
CREATE INDEX IF NOT EXISTS idx_monthly_targets_year_month_dimension ON public.monthly_targets(year, month, dimension_type, dimension_id);
CREATE INDEX IF NOT EXISTS idx_monthly_target_lines_monthly_target_id ON public.monthly_target_lines(monthly_target_id);
CREATE INDEX IF NOT EXISTS idx_monthly_reports_year_month ON public.monthly_reports(year, month);
CREATE INDEX IF NOT EXISTS idx_monthly_report_lines_monthly_report_id ON public.monthly_report_lines(monthly_report_id);
CREATE INDEX IF NOT EXISTS idx_monthly_report_lines_dimension ON public.monthly_report_lines(dimension_type, dimension_id);

-- 5. RLS / admin/user 権限設計
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_kpis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_report_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.target_setting_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.target_dimensions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_target_lines ENABLE ROW LEVEL SECURITY;

-- brands
CREATE POLICY brands_select ON public.brands
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY brands_admin ON public.brands
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- channels
CREATE POLICY channels_select ON public.channels
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY channels_admin ON public.channels
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- staff
CREATE POLICY staff_select ON public.staff
  FOR SELECT USING (
    public.is_admin() OR user_id = auth.uid()
  );
CREATE POLICY staff_insert ON public.staff
  FOR INSERT WITH CHECK (
    public.is_admin()
  );
CREATE POLICY staff_update_delete ON public.staff
  FOR UPDATE, DELETE USING (
    public.is_admin() OR user_id = auth.uid()
  ) WITH CHECK (
    public.is_admin() OR user_id = auth.uid()
  );

-- sales
CREATE POLICY sales_select ON public.sales
  FOR SELECT USING (
    public.is_admin() OR staff_id = public.staff_id_for_current_user()
  );
CREATE POLICY sales_insert ON public.sales
  FOR INSERT WITH CHECK (
    public.is_admin() OR staff_id = public.staff_id_for_current_user()
  );
CREATE POLICY sales_update_delete ON public.sales
  FOR UPDATE, DELETE USING (
    public.is_admin() OR staff_id = public.staff_id_for_current_user()
  ) WITH CHECK (
    public.is_admin() OR staff_id = public.staff_id_for_current_user()
  );

-- sales_details
CREATE POLICY sales_details_select ON public.sales_details
  FOR SELECT USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.sales s WHERE s.id = sales_id AND s.staff_id = public.staff_id_for_current_user()
    )
  );
CREATE POLICY sales_details_admin ON public.sales_details
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- costs
CREATE POLICY costs_select ON public.costs
  FOR SELECT USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.staff st
      WHERE st.id = public.staff_id_for_current_user()
        AND (st.brand_id = brand_id OR st.channel_id = channel_id)
    )
  );
CREATE POLICY costs_admin ON public.costs
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- activities
CREATE POLICY activities_select ON public.activities
  FOR SELECT USING (
    public.is_admin() OR staff_id = public.staff_id_for_current_user()
  );
CREATE POLICY activities_insert ON public.activities
  FOR INSERT WITH CHECK (
    public.is_admin() OR staff_id = public.staff_id_for_current_user()
  );
CREATE POLICY activities_update_delete ON public.activities
  FOR UPDATE, DELETE USING (
    public.is_admin() OR staff_id = public.staff_id_for_current_user()
  ) WITH CHECK (
    public.is_admin() OR staff_id = public.staff_id_for_current_user()
  );

-- activity_kpis
CREATE POLICY activity_kpis_select ON public.activity_kpis
  FOR SELECT USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.activities a WHERE a.id = activity_id AND a.staff_id = public.staff_id_for_current_user()
    )
  );
CREATE POLICY activity_kpis_admin ON public.activity_kpis
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- activity_sales
CREATE POLICY activity_sales_select ON public.activity_sales
  FOR SELECT USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.activities a WHERE a.id = activity_id AND a.staff_id = public.staff_id_for_current_user()
    )
  );
CREATE POLICY activity_sales_admin ON public.activity_sales
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- monthly_reports
CREATE POLICY monthly_reports_select ON public.monthly_reports
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY monthly_reports_admin ON public.monthly_reports
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- monthly_report_lines
CREATE POLICY monthly_report_lines_select ON public.monthly_report_lines
  FOR SELECT USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.monthly_reports mr WHERE mr.id = monthly_report_id
    )
  );
CREATE POLICY monthly_report_lines_admin ON public.monthly_report_lines
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- target_setting_methods
CREATE POLICY target_setting_methods_select ON public.target_setting_methods
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY target_setting_methods_admin ON public.target_setting_methods
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- target_dimensions
CREATE POLICY target_dimensions_select ON public.target_dimensions
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY target_dimensions_admin ON public.target_dimensions
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- monthly_targets
CREATE POLICY monthly_targets_select ON public.monthly_targets
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY monthly_targets_admin ON public.monthly_targets
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- monthly_target_lines
CREATE POLICY monthly_target_lines_select ON public.monthly_target_lines
  FOR SELECT USING (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.monthly_targets mt WHERE mt.id = monthly_target_id
    )
  );
CREATE POLICY monthly_target_lines_admin ON public.monthly_target_lines
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- 6. Supabase Auth(users)連携
COMMENT ON TABLE public.staff IS '担当者は Supabase Auth の auth.users と紐付けられています';

-- 7. 更新トリガー (updated_at)
CREATE OR REPLACE FUNCTION public.updated_at_trigger() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_brands_updated_at
  BEFORE UPDATE ON public.brands
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_channels_updated_at
  BEFORE UPDATE ON public.channels
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_staff_updated_at
  BEFORE UPDATE ON public.staff
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_sales_updated_at
  BEFORE UPDATE ON public.sales
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_sales_details_updated_at
  BEFORE UPDATE ON public.sales_details
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_costs_updated_at
  BEFORE UPDATE ON public.costs
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_activities_updated_at
  BEFORE UPDATE ON public.activities
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_activity_kpis_updated_at
  BEFORE UPDATE ON public.activity_kpis
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_activity_sales_updated_at
  BEFORE UPDATE ON public.activity_sales
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_monthly_reports_updated_at
  BEFORE UPDATE ON public.monthly_reports
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_monthly_report_lines_updated_at
  BEFORE UPDATE ON public.monthly_report_lines
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_target_setting_methods_updated_at
  BEFORE UPDATE ON public.target_setting_methods
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_target_dimensions_updated_at
  BEFORE UPDATE ON public.target_dimensions
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_monthly_targets_updated_at
  BEFORE UPDATE ON public.monthly_targets
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();
CREATE TRIGGER trg_monthly_target_lines_updated_at
  BEFORE UPDATE ON public.monthly_target_lines
  FOR EACH ROW EXECUTE FUNCTION public.updated_at_trigger();

-- 8. 権限補足
-- Supabase では auth.role() は匿名/認証済みによる判定です。
-- 追加の role クレームを付与している場合は public.is_admin() で判定します。

-- 注意:
-- Supabase SQL Editor では auth.users テーブルへの参照は利用できますが、
-- auth スキーマに対する権限設定が必要です。


-- END OF SCHEMA
