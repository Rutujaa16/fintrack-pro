-- =============================================================================
-- FinTrack Pro — Seed Data
-- Engine : Microsoft SQL Server 2022
-- =============================================================================
-- Run AFTER tables.sql.
-- Provides:
--   1. System categories (income + expense)
--   2. One demo user with accounts, transactions, budgets, and goals
--      (realistic data so the UI never looks empty in demos / screenshots)
-- =============================================================================

USE FinTrackPro;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- Deterministic GUIDs so re-runs are idempotent
-- ─────────────────────────────────────────────────────────────────────────────
DECLARE @demo_user_id   UNIQUEIDENTIFIER = '11111111-0000-0000-0000-000000000001';
DECLARE @acc_savings    UNIQUEIDENTIFIER = '22222222-0000-0000-0000-000000000001';
DECLARE @acc_salary     UNIQUEIDENTIFIER = '22222222-0000-0000-0000-000000000002';
DECLARE @acc_credit     UNIQUEIDENTIFIER = '22222222-0000-0000-0000-000000000003';

-- category IDs — income
DECLARE @cat_salary     UNIQUEIDENTIFIER = '33333333-0000-0000-0001-000000000001';
DECLARE @cat_freelance  UNIQUEIDENTIFIER = '33333333-0000-0000-0001-000000000002';
DECLARE @cat_interest   UNIQUEIDENTIFIER = '33333333-0000-0000-0001-000000000003';

-- category IDs — expense
DECLARE @cat_food       UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000001';
DECLARE @cat_transport  UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000002';
DECLARE @cat_shopping   UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000003';
DECLARE @cat_subs       UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000004';
DECLARE @cat_utilities  UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000005';
DECLARE @cat_health     UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000006';
DECLARE @cat_education  UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000007';
DECLARE @cat_travel     UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000008';
DECLARE @cat_dining     UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000009';
DECLARE @cat_electronics UNIQUEIDENTIFIER= '33333333-0000-0000-0002-000000000010';
DECLARE @cat_rent       UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000011';
DECLARE @cat_other_exp  UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000099';

-- budget / goal IDs
DECLARE @budget_jun     UNIQUEIDENTIFIER = '44444444-0000-0000-0000-000000000001';
DECLARE @goal_japan     UNIQUEIDENTIFIER = '55555555-0000-0000-0000-000000000001';
DECLARE @goal_emerg     UNIQUEIDENTIFIER = '55555555-0000-0000-0000-000000000002';
DECLARE @goal_laptop    UNIQUEIDENTIFIER = '55555555-0000-0000-0000-000000000003';

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. SYSTEM CATEGORIES  (user_id = NULL, is_system = 1)
-- ─────────────────────────────────────────────────────────────────────────────
DELETE FROM dbo.category WHERE is_system = 1;

INSERT INTO dbo.category (category_id, user_id, name, icon, color, category_type, is_system) VALUES
-- Income
(@cat_salary,    NULL, 'Salary',             'briefcase',   '#34D399', 'income',  1),
(@cat_freelance, NULL, 'Freelance',          'code',        '#5EC8F2', 'income',  1),
(@cat_interest,  NULL, 'Interest & Returns', 'trending-up', '#7C8AFF', 'income',  1),
-- Expense
(@cat_food,      NULL, 'Food & Dining',      'coffee',      '#F4B740', 'expense', 1),
(@cat_transport, NULL, 'Transport',          'car',         '#5EC8F2', 'expense', 1),
(@cat_shopping,  NULL, 'Shopping',           'shopping-bag','#FF6B6B', 'expense', 1),
(@cat_subs,      NULL, 'Subscriptions',      'credit-card', '#7C8AFF', 'expense', 1),
(@cat_utilities, NULL, 'Utilities',          'zap',         '#34D399', 'expense', 1),
(@cat_health,    NULL, 'Health',             'heart',       '#FF8FAB', 'expense', 1),
(@cat_education, NULL, 'Education',          'book-open',   '#C9A661', 'expense', 1),
(@cat_travel,    NULL, 'Travel',             'plane',       '#5EC8F2', 'expense', 1),
(@cat_dining,    NULL, 'Dining Out',         'utensils',    '#F4B740', 'expense', 1),
(@cat_electronics,NULL,'Electronics',        'monitor',     '#9AA3B8', 'expense', 1),
(@cat_rent,      NULL, 'Rent & Housing',     'home',        '#C9A661', 'expense', 1),
(@cat_other_exp, NULL, 'Other',              'more-horizontal','#5C657C','expense',1);
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. DEMO USER
-- ─────────────────────────────────────────────────────────────────────────────
DECLARE @demo_user_id UNIQUEIDENTIFIER = '11111111-0000-0000-0000-000000000001';

DELETE FROM dbo.notification      WHERE user_id = @demo_user_id;
DELETE FROM dbo.goal_contribution WHERE user_id = @demo_user_id;
DELETE FROM dbo.goal              WHERE user_id = @demo_user_id;
DELETE FROM dbo.budget_category
    WHERE budget_id IN (SELECT budget_id FROM dbo.budget WHERE user_id = @demo_user_id);
DELETE FROM dbo.budget            WHERE user_id = @demo_user_id;
DELETE FROM dbo.[transaction]     WHERE user_id = @demo_user_id;
DELETE FROM dbo.import_session    WHERE user_id = @demo_user_id;
DELETE FROM dbo.account           WHERE user_id = @demo_user_id;
DELETE FROM dbo.user_preference   WHERE user_id = @demo_user_id;
DELETE FROM dbo.app_user          WHERE user_id = @demo_user_id;

INSERT INTO dbo.app_user (user_id, email, full_name, password_hash, plan, email_verified_at)
VALUES (
    @demo_user_id,
    'maya.rao@demo.vantage.app',
    'Maya Rao',
    -- bcrypt hash of "Demo@1234" — replace with real hash in production
    '$2b$12$demohashdemohashdemohashdemohashdemohashdemohashdemo',
    'premium',
    SYSUTCDATETIME()
);

INSERT INTO dbo.user_preference (user_id, currency_code, theme, accent_color, notif_push, notif_email)
VALUES (@demo_user_id, 'INR', 'dark', '#C9A661', 1, 1);


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. DEMO ACCOUNTS
-- ─────────────────────────────────────────────────────────────────────────────
DECLARE @acc_savings  UNIQUEIDENTIFIER = '22222222-0000-0000-0000-000000000001';
DECLARE @acc_salary   UNIQUEIDENTIFIER = '22222222-0000-0000-0000-000000000002';
DECLARE @acc_credit   UNIQUEIDENTIFIER = '22222222-0000-0000-0000-000000000003';

INSERT INTO dbo.account (account_id, user_id, name, institution, account_type, masked_number, color, icon, is_default)
VALUES
(@acc_savings, @demo_user_id, 'HDFC Savings',   'HDFC Bank',  'savings', '4821', '#34D399', 'landmark',    1),
(@acc_salary,  @demo_user_id, 'HDFC Salary',    'HDFC Bank',  'savings', '9012', '#7C8AFF', 'briefcase',   0),
(@acc_credit,  @demo_user_id, 'ICICI Platinum', 'ICICI Bank', 'credit',  '3344', '#C9A661', 'credit-card', 0);
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. DEMO TRANSACTIONS  (Jan–Jun 2026)
-- ─────────────────────────────────────────────────────────────────────────────
DECLARE @demo_user_id  UNIQUEIDENTIFIER = '11111111-0000-0000-0000-000000000001';
DECLARE @acc_savings   UNIQUEIDENTIFIER = '22222222-0000-0000-0000-000000000001';
DECLARE @acc_salary    UNIQUEIDENTIFIER = '22222222-0000-0000-0000-000000000002';
DECLARE @acc_credit    UNIQUEIDENTIFIER = '22222222-0000-0000-0000-000000000003';

DECLARE @cat_salary     UNIQUEIDENTIFIER = '33333333-0000-0000-0001-000000000001';
DECLARE @cat_food       UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000001';
DECLARE @cat_transport  UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000002';
DECLARE @cat_shopping   UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000003';
DECLARE @cat_subs       UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000004';
DECLARE @cat_utilities  UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000005';
DECLARE @cat_electronics UNIQUEIDENTIFIER= '33333333-0000-0000-0002-000000000010';
DECLARE @cat_rent       UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000011';

INSERT INTO dbo.[transaction]
    (transaction_id, user_id, account_id, category_id, txn_date, description, merchant_name, amount, txn_type, is_recurring)
VALUES
-- ── JUNE 2026 ──────────────────────────────────────────────────────────────
(NEWID(), @demo_user_id, @acc_salary,  @cat_salary,      '2026-06-15', 'Acme Corp Payroll',          'Acme Corp',        92400.00, 'credit', 1),
(NEWID(), @demo_user_id, @acc_savings, @cat_rent,        '2026-06-01', 'Apartment Rent June',        NULL,               25000.00, 'debit',  1),
(NEWID(), @demo_user_id, @acc_savings, @cat_food,        '2026-06-14', 'Swiggy Order',               'Swiggy',             680.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_savings, @cat_food,        '2026-06-13', 'Zomato Dinner',              'Zomato',             920.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_credit,  @cat_shopping,    '2026-06-16', 'Amazon Electronics',         'Amazon',            2340.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_credit,  @cat_subs,        '2026-06-13', 'Netflix Monthly',            'Netflix',            649.00, 'debit',  1),
(NEWID(), @demo_user_id, @acc_credit,  @cat_subs,        '2026-06-02', 'Spotify Premium',            'Spotify',            119.00, 'debit',  1),
(NEWID(), @demo_user_id, @acc_savings, @cat_transport,   '2026-06-12', 'Uber Ride',                  'Uber',               310.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_savings, @cat_transport,   '2026-06-10', 'Ola Cab Airport',            'Ola',                580.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_credit,  @cat_electronics, '2026-06-10', 'Reliance Digital - Earbuds', 'Reliance Digital', 14999.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_savings, @cat_utilities,   '2026-06-05', 'BESCOM Electricity Bill',    'BESCOM',            2240.00, 'debit',  1),
(NEWID(), @demo_user_id, @acc_savings, @cat_food,        '2026-06-08', 'Big Basket Groceries',       'Big Basket',        3200.00, 'debit',  0),

-- ── MAY 2026 ───────────────────────────────────────────────────────────────
(NEWID(), @demo_user_id, @acc_salary,  @cat_salary,      '2026-05-15', 'Acme Corp Payroll',          'Acme Corp',        90500.00, 'credit', 1),
(NEWID(), @demo_user_id, @acc_savings, @cat_rent,        '2026-05-01', 'Apartment Rent May',         NULL,               25000.00, 'debit',  1),
(NEWID(), @demo_user_id, @acc_credit,  @cat_shopping,    '2026-05-20', 'Myntra Fashion Sale',        'Myntra',            3800.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_savings, @cat_food,        '2026-05-18', 'Swiggy Instamart',           'Swiggy',            1400.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_credit,  @cat_subs,        '2026-05-13', 'Netflix Monthly',            'Netflix',            649.00, 'debit',  1),
(NEWID(), @demo_user_id, @acc_savings, @cat_transport,   '2026-05-12', 'Metro Card Recharge',        'BMRCL',             500.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_savings, @cat_utilities,   '2026-05-05', 'BESCOM Electricity Bill',    'BESCOM',            1980.00, 'debit',  1),

-- ── APRIL 2026 ─────────────────────────────────────────────────────────────
(NEWID(), @demo_user_id, @acc_salary,  @cat_salary,      '2026-04-15', 'Acme Corp Payroll',          'Acme Corp',        90500.00, 'credit', 1),
(NEWID(), @demo_user_id, @acc_savings, @cat_rent,        '2026-04-01', 'Apartment Rent April',       NULL,               25000.00, 'debit',  1),
(NEWID(), @demo_user_id, @acc_credit,  @cat_shopping,    '2026-04-14', 'Amazon Order',               'Amazon',            5600.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_savings, @cat_food,        '2026-04-10', 'Licious Order',              'Licious',            890.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_savings, @cat_utilities,   '2026-04-05', 'BESCOM Electricity Bill',    'BESCOM',            2100.00, 'debit',  1),

-- ── MARCH 2026 ─────────────────────────────────────────────────────────────
(NEWID(), @demo_user_id, @acc_salary,  @cat_salary,      '2026-03-15', 'Acme Corp Payroll',          'Acme Corp',        90500.00, 'credit', 1),
(NEWID(), @demo_user_id, @acc_savings, @cat_rent,        '2026-03-01', 'Apartment Rent March',       NULL,               25000.00, 'debit',  1),
(NEWID(), @demo_user_id, @acc_savings, @cat_food,        '2026-03-12', 'Swiggy x3',                  'Swiggy',            2100.00, 'debit',  0),
(NEWID(), @demo_user_id, @acc_savings, @cat_transport,   '2026-03-08', 'Petrol Fill-up',             NULL,               3200.00, 'debit',  0),

-- ── FEB 2026 ───────────────────────────────────────────────────────────────
(NEWID(), @demo_user_id, @acc_salary,  @cat_salary,      '2026-02-15', 'Acme Corp Payroll',          'Acme Corp',        90500.00, 'credit', 1),
(NEWID(), @demo_user_id, @acc_savings, @cat_rent,        '2026-02-01', 'Apartment Rent Feb',         NULL,               25000.00, 'debit',  1),
(NEWID(), @demo_user_id, @acc_savings, @cat_food,        '2026-02-14', 'Valentine Dinner',           'Taj Bistro',        4800.00, 'debit',  0),

-- ── JAN 2026 ───────────────────────────────────────────────────────────────
(NEWID(), @demo_user_id, @acc_salary,  @cat_salary,      '2026-01-15', 'Acme Corp Payroll',          'Acme Corp',        88000.00, 'credit', 1),
(NEWID(), @demo_user_id, @acc_savings, @cat_rent,        '2026-01-01', 'Apartment Rent Jan',         NULL,               25000.00, 'debit',  1),
(NEWID(), @demo_user_id, @acc_savings, @cat_food,        '2026-01-10', 'Big Basket Groceries',       'Big Basket',        2800.00, 'debit',  0);
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. JUNE 2026 BUDGET
-- ─────────────────────────────────────────────────────────────────────────────
DECLARE @demo_user_id UNIQUEIDENTIFIER = '11111111-0000-0000-0000-000000000001';
DECLARE @budget_jun   UNIQUEIDENTIFIER = '44444444-0000-0000-0000-000000000001';

DECLARE @cat_food      UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000001';
DECLARE @cat_transport UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000002';
DECLARE @cat_shopping  UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000003';
DECLARE @cat_subs      UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000004';
DECLARE @cat_utilities UNIQUEIDENTIFIER = '33333333-0000-0000-0002-000000000005';

INSERT INTO dbo.budget (budget_id, user_id, name, period_start, period_end, total_limit)
VALUES (@budget_jun, @demo_user_id, 'June 2026 Budget', '2026-06-01', '2026-06-30', 35000.00);

INSERT INTO dbo.budget_category (budget_id, category_id, amount_limit, alert_at_percent)
VALUES
(@budget_jun, @cat_food,      9000.00, 80),
(@budget_jun, @cat_shopping,  5000.00, 80),
(@budget_jun, @cat_transport, 4000.00, 80),
(@budget_jun, @cat_subs,      2000.00, 80),
(@budget_jun, @cat_utilities, 4000.00, 80);
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. SAVINGS GOALS
-- ─────────────────────────────────────────────────────────────────────────────
DECLARE @demo_user_id UNIQUEIDENTIFIER = '11111111-0000-0000-0000-000000000001';
DECLARE @goal_japan   UNIQUEIDENTIFIER = '55555555-0000-0000-0000-000000000001';
DECLARE @goal_emerg   UNIQUEIDENTIFIER = '55555555-0000-0000-0000-000000000002';
DECLARE @goal_laptop  UNIQUEIDENTIFIER = '55555555-0000-0000-0000-000000000003';

INSERT INTO dbo.goal (goal_id, user_id, name, icon, color, target_amount, current_amount, monthly_contribution, target_date, status)
VALUES
(@goal_japan,  @demo_user_id, 'Japan Trip',     'plane',    '#7C8AFF', 150000.00,  62000.00, 8800.00, '2026-12-31', 'active'),
(@goal_emerg,  @demo_user_id, 'Emergency Fund', 'shield',   '#34D399', 300000.00, 240000.00,15000.00, NULL,         'active'),
(@goal_laptop, @demo_user_id, 'New Laptop',     'monitor',  '#C9A661',  90000.00,  90000.00, NULL,    '2026-05-01', 'achieved');

-- Contribution history
INSERT INTO dbo.goal_contribution (contribution_id, goal_id, user_id, amount, contribution_type, contribution_date)
VALUES
(NEWID(), @goal_japan, @demo_user_id,  8800.00, 'auto',   '2026-06-15'),
(NEWID(), @goal_japan, @demo_user_id,  5000.00, 'manual', '2026-05-28'),
(NEWID(), @goal_japan, @demo_user_id,  8800.00, 'auto',   '2026-05-15'),
(NEWID(), @goal_emerg, @demo_user_id, 15000.00, 'auto',   '2026-06-01'),
(NEWID(), @goal_emerg, @demo_user_id, 15000.00, 'auto',   '2026-05-01'),
(NEWID(), @goal_laptop,@demo_user_id, 15000.00, 'auto',   '2026-05-01');
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. SAMPLE NOTIFICATIONS
-- ─────────────────────────────────────────────────────────────────────────────
DECLARE @demo_user_id UNIQUEIDENTIFIER = '11111111-0000-0000-0000-000000000001';
DECLARE @budget_jun   UNIQUEIDENTIFIER = '44444444-0000-0000-0000-000000000001';

INSERT INTO dbo.notification (notification_id, user_id, title, body, notif_type, related_entity_type, related_entity_id, is_read)
VALUES
(NEWID(), @demo_user_id, 'Shopping budget exceeded',        'You have spent ₹5,200 of your ₹5,000 Shopping limit.',            'budget_exceeded', 'budget', @budget_jun, 0),
(NEWID(), @demo_user_id, 'Food & Dining at 89%',           '₹8,010 spent of ₹9,000 budget. ₹990 remaining.',                  'budget_alert',    'budget', @budget_jun, 0),
(NEWID(), @demo_user_id, 'Import complete',                 '244 transactions imported from hdfc-statement-june-2026.csv.',    'import_complete',  NULL,     NULL,        1),
(NEWID(), @demo_user_id, 'Japan Trip: 41% reached 🎉',     'You have saved ₹62,000 of your ₹1,50,000 goal.',                  'goal_milestone',   NULL,     NULL,        1);
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. RECALCULATE ALL ACCOUNT BALANCES from transactions
-- ─────────────────────────────────────────────────────────────────────────────
EXEC dbo.usp_account_recalc_balance '22222222-0000-0000-0000-000000000001';
EXEC dbo.usp_account_recalc_balance '22222222-0000-0000-0000-000000000002';
EXEC dbo.usp_account_recalc_balance '22222222-0000-0000-0000-000000000003';
GO

PRINT 'seed-data.sql — demo data loaded successfully.';
PRINT 'Demo login: maya.rao@demo.vantage.app / Demo@1234';
GO