-- ============================================================
-- CloudFlow year-end review: six business questions in SQL
-- Run sql/cloudflow.sql first, then run each query on its own.
-- ============================================================

-- Task 1: Count the daily active users of the last quarter
-- Translation: count the distinct user_id per day in activity_logs,
-- between October 1 and December 31, 2025. One row per day.
SELECT
  DATE(event_timestamp) AS activity_date,
  COUNT(DISTINCT user_id) AS dau
FROM cloudflow.activity_logs
WHERE DATE(event_timestamp) BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
GROUP BY activity_date
ORDER BY activity_date;


-- Task 2: Smooth the daily active users with a 7-day rolling average
-- Translation: reuse Task 1 as a CTE, then average the current day
-- and the 6 days before it with AVG() OVER and a ROWS frame.
WITH daily_active_users AS (
  SELECT
    DATE(event_timestamp) AS activity_date,
    COUNT(DISTINCT user_id) AS dau
  FROM cloudflow.activity_logs
  WHERE DATE(event_timestamp) BETWEEN DATE '2025-10-01' AND DATE '2025-12-31'
  GROUP BY activity_date
)
SELECT
  activity_date,
  dau,
  ROUND(AVG(dau) OVER (
    ORDER BY activity_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ), 1) AS dau_7d_avg
FROM daily_active_users
ORDER BY activity_date;


-- Task 3: Find the top 3 uploaders of each country
-- Translation: count upload_file events per account, rank the accounts
-- inside each country with RANK() OVER (PARTITION BY country), keep ranks 1 to 3.
WITH uploads_per_account AS (
  SELECT
    u.country,
    u.company_name,
    COUNT(*) AS uploads
  FROM cloudflow.activity_logs AS a
  INNER JOIN cloudflow.users AS u
    ON a.user_id = u.user_id
  WHERE a.event_name = 'upload_file'
  GROUP BY u.country, u.company_name
),
ranked_accounts AS (
  SELECT
    country,
    company_name,
    uploads,
    RANK() OVER (PARTITION BY country ORDER BY uploads DESC) AS country_rank
  FROM uploads_per_account
)
SELECT
  country,
  company_name,
  uploads,
  country_rank
FROM ranked_accounts
WHERE country_rank <= 3
ORDER BY country, country_rank;


-- Task 4: Flag the Enterprise accounts at risk of churn
-- Translation: count events per Enterprise account and per month, put the
-- previous month on the same row with LAG(), keep December 2025 rows where
-- the activity dropped by 50% or more.
WITH monthly_activity AS (
  SELECT
    u.user_id,
    u.company_name,
    DATE_TRUNC(DATE(a.event_timestamp), MONTH) AS activity_month,
    COUNT(*) AS events
  FROM cloudflow.activity_logs AS a
  INNER JOIN cloudflow.users AS u
    ON a.user_id = u.user_id
  WHERE u.plan_tier = 'Enterprise'
  GROUP BY u.user_id, u.company_name, activity_month
),
with_previous_month AS (
  SELECT
    company_name,
    activity_month,
    events,
    LAG(events) OVER (PARTITION BY user_id ORDER BY activity_month) AS previous_month_events
  FROM monthly_activity
)
SELECT
  company_name,
  activity_month,
  previous_month_events,
  events,
  ROUND(100 * (events - previous_month_events) / previous_month_events, 1) AS change_pct
FROM with_previous_month
WHERE activity_month = DATE '2025-12-01'
  AND events <= 0.5 * previous_month_events
ORDER BY change_pct;


-- Task 5: Show the revenue collected day by day in 2025, with a running total
-- Translation: sum the paid invoices per paid_date in 2025, then add a
-- running total with SUM() OVER (ORDER BY paid_date).
WITH revenue_per_day AS (
  SELECT
    paid_date,
    SUM(amount) AS daily_revenue
  FROM cloudflow.invoices
  WHERE status = 'paid'
    AND paid_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
  GROUP BY paid_date
)
SELECT
  paid_date,
  daily_revenue,
  SUM(daily_revenue) OVER (ORDER BY paid_date) AS cumulative_revenue
FROM revenue_per_day
ORDER BY paid_date;


-- Task 6: Find the day the cumulative revenue crossed one million dollars
-- Translation: reuse Task 5, keep the days at or above 1,000,000,
-- and take the first one.
WITH revenue_per_day AS (
  SELECT
    paid_date,
    SUM(amount) AS daily_revenue
  FROM cloudflow.invoices
  WHERE status = 'paid'
    AND paid_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
  GROUP BY paid_date
),
running_total AS (
  SELECT
    paid_date,
    SUM(daily_revenue) OVER (ORDER BY paid_date) AS cumulative_revenue
  FROM revenue_per_day
)
SELECT
  paid_date,
  cumulative_revenue
FROM running_total
WHERE cumulative_revenue >= 1000000
ORDER BY paid_date
LIMIT 1;
