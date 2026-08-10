-- SEED.sql
-- Supabase 起動前の初期マスタ投入用

-- 1. 費用区分マスタ
INSERT INTO public.cost_categories (id, code, name, category_group, description)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'cogs', '売上原価', 'cogs', '製品原価・仕入原価'),
  ('00000000-0000-0000-0000-000000000002', 'marketing', '広告費', 'sg_a', '広告・販促費'),
  ('00000000-0000-0000-0000-000000000003', 'logistics', '物流費', 'sg_a', '物流・配送費用'),
  ('00000000-0000-0000-0000-000000000004', 'hr', '人件費', 'sg_a', '人件費・社内労務費'),
  ('00000000-0000-0000-0000-000000000005', 'non_operating', '営業外費用', 'non_operating', '営業外費用(支払利息等)'),
  ('00000000-0000-0000-0000-000000000006', 'other', 'その他費用', 'other', 'その他の費用')
ON CONFLICT (code) DO NOTHING;

-- 2. 目標設定方式マスタ
INSERT INTO public.target_setting_methods (id, code, name, description)
VALUES
  ('00000000-0000-0000-0000-000000000011', 'direct', '直接入力', '実数値を直接登録する方式'),
  ('00000000-0000-0000-0000-000000000012', 'yoy', '前年比', '前年実績から成長率を乗じる方式'),
  ('00000000-0000-0000-0000-000000000013', 'growth_rate', '成長率', '成長率を使って目標を設定する方式'),
  ('00000000-0000-0000-0000-000000000014', 'allocation', '配分', '親目標から配分する方式'),
  ('00000000-0000-0000-0000-000000000015', 'copy_previous', '前月コピー', '前月実績をコピーする方式')
ON CONFLICT (code) DO NOTHING;

-- 3. 目標ディメンションマスタ
INSERT INTO public.target_dimensions (id, dimension_type, code, name, description)
VALUES
  ('00000000-0000-0000-0000-000000000021', 'corporate', 'corporate', '全社', '全社目標'),
  ('00000000-0000-0000-0000-000000000022', 'brand', 'brand', 'ブランド', 'ブランド別目標'),
  ('00000000-0000-0000-0000-000000000023', 'channel', 'channel', 'チャネル', 'チャネル別目標'),
  ('00000000-0000-0000-0000-000000000024', 'staff', 'staff', '担当者', '担当者別目標'),
  ('00000000-0000-0000-0000-000000000025', 'activity', 'activity', '活動', '活動別目標')
ON CONFLICT (code) DO NOTHING;

-- 5. 権限ロール
-- staff_role_enum は enum 定義です: admin, user
-- Supabase Auth で権限を設定する場合、auth.users のユーザーを作成し、
-- public.staff レコードの role に admin または user を設定してください。
