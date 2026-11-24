-- ============================================================
-- CloudFlow: sample data for BigQuery
-- M05 / D03 - SQL Case Study
--
-- How to use: paste this whole script into a BigQuery query tab
-- and click Run. It creates the dataset `cloudflow` and three
-- tables: users, activity_logs, invoices.
-- You can run it again at any time. It rebuilds the tables.
--
-- The activity covers July 1 to December 31, 2025. The invoices
-- cover the year 2025. All dates are fixed, and the script uses no
-- random function, so every learner gets exactly the same data.
-- The script uses CREATE TABLE AS SELECT only (no INSERT), so it
-- also works in the BigQuery sandbox.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS cloudflow;

-- Turns a text into a fixed number between 0 and 1.
-- The same text always gives the same number.
CREATE TEMP FUNCTION score(key STRING) AS (
  ABS(MOD(FARM_FINGERPRINT(key), 1000)) / 1000
);

-- 40 business accounts in 3 countries
CREATE OR REPLACE TABLE cloudflow.users AS
SELECT *
FROM UNNEST(ARRAY<STRUCT<
  user_id INT64,
  company_name STRING,
  signup_date DATE,
  country STRING,
  plan_tier STRING
>>[
  (1, 'Acme Logistics', DATE '2023-02-14', 'US', 'Enterprise'),
  (2, 'Brightline Media', DATE '2023-05-03', 'US', 'Pro'),
  (3, 'Cobalt Health', DATE '2023-09-21', 'US', 'Free'),
  (4, 'Delta Freight', DATE '2024-01-10', 'US', 'Enterprise'),
  (5, 'Evergreen Labs', DATE '2024-03-18', 'US', 'Pro'),
  (6, 'Foxglove Studio', DATE '2024-06-02', 'US', 'Free'),
  (7, 'Granite Legal', DATE '2024-08-27', 'US', 'Pro'),
  (8, 'Harbor Analytics', DATE '2024-11-05', 'US', 'Enterprise'),
  (9, 'Ironwood Capital', DATE '2025-01-15', 'US', 'Free'),
  (10, 'Juniper Retail', DATE '2025-02-20', 'US', 'Pro'),
  (11, 'Keystone Builders', DATE '2025-04-08', 'US', 'Free'),
  (12, 'Lumen Architects', DATE '2025-05-30', 'US', 'Pro'),
  (13, 'Maple Events', DATE '2025-07-14', 'US', 'Free'),
  (14, 'Northwind Travel', DATE '2025-08-19', 'US', 'Free'),
  (15, 'Orbit Games', DATE '2025-09-23', 'US', 'Pro'),
  (16, 'Pioneer Schools', DATE '2025-10-06', 'US', 'Free'),
  (17, 'Atelier Lumiere', DATE '2023-03-09', 'FR', 'Enterprise'),
  (18, 'Banque Rivage', DATE '2023-07-17', 'FR', 'Pro'),
  (19, 'Cafe Numerique', DATE '2024-02-05', 'FR', 'Free'),
  (20, 'Domaine Vallon', DATE '2024-04-22', 'FR', 'Pro'),
  (21, 'Editions Mistral', DATE '2024-09-12', 'FR', 'Enterprise'),
  (22, 'Ferme Digitale', DATE '2024-12-01', 'FR', 'Free'),
  (23, 'Groupe Hexa', DATE '2025-02-11', 'FR', 'Enterprise'),
  (24, 'Hopital Saint-Roch', DATE '2025-03-27', 'FR', 'Pro'),
  (25, 'Institut Lagrange', DATE '2025-06-16', 'FR', 'Free'),
  (26, 'Jardins de Provence', DATE '2025-08-04', 'FR', 'Free'),
  (27, 'Kiosque Media', DATE '2025-10-20', 'FR', 'Pro'),
  (28, 'Lycee Voltaire', DATE '2025-11-10', 'FR', 'Free'),
  (29, 'Aozora Design', DATE '2023-04-11', 'JP', 'Enterprise'),
  (30, 'Bento Systems', DATE '2023-10-30', 'JP', 'Pro'),
  (31, 'Chiyoda Trading', DATE '2024-03-04', 'JP', 'Free'),
  (32, 'Daichi Robotics', DATE '2024-07-15', 'JP', 'Enterprise'),
  (33, 'Ebisu Records', DATE '2024-10-09', 'JP', 'Pro'),
  (34, 'Fuji Clinics', DATE '2025-01-27', 'JP', 'Free'),
  (35, 'Ginza Fashion', DATE '2025-03-12', 'JP', 'Pro'),
  (36, 'Hikari Energy', DATE '2025-05-21', 'JP', 'Free'),
  (37, 'Inari Foods', DATE '2025-07-02', 'JP', 'Pro'),
  (38, 'Kumo Software', DATE '2025-09-08', 'JP', 'Free'),
  (39, 'Minato Logistics', DATE '2025-11-17', 'JP', 'Enterprise'),
  (40, 'Nagoya Motors', DATE '2025-12-01', 'JP', 'Free')
]);

-- One row per action of a user, from July 1 to December 31, 2025
CREATE OR REPLACE TABLE cloudflow.activity_logs AS
WITH profiles AS (
  -- Usage profile of each account
  SELECT
    user_id,
    signup_date,
    CASE plan_tier WHEN 'Enterprise' THEN 0.80 WHEN 'Pro' THEN 0.60 ELSE 0.30 END AS p_active,
    CASE plan_tier WHEN 'Enterprise' THEN 5 WHEN 'Pro' THEN 4 ELSE 2 END AS max_events,
    CASE user_id
      WHEN 4 THEN 0.60 WHEN 17 THEN 0.60 WHEN 32 THEN 0.60
      WHEN 12 THEN 0.55 WHEN 24 THEN 0.55 WHEN 35 THEN 0.55
      WHEN 20 THEN 0.50 WHEN 30 THEN 0.50
      WHEN 1 THEN 0.45 WHEN 21 THEN 0.45
      ELSE 0.20
    END AS upload_share,
    CASE user_id WHEN 8 THEN 0.30 WHEN 23 THEN 0.35 WHEN 29 THEN 0.70 ELSE 1.0 END AS december_factor
  FROM cloudflow.users
),
user_days AS (
  SELECT
    p.*,
    d AS activity_date,
    CONCAT(CAST(p.user_id AS STRING), '|', CAST(d AS STRING)) AS k
  FROM profiles AS p
  CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(DATE '2025-07-01', DATE '2025-12-31')) AS d
  WHERE d >= p.signup_date
),
active_days AS (
  -- Fewer users on weekends and during the Christmas week
  SELECT *
  FROM user_days
  WHERE score(CONCAT('a|', k)) <
    p_active
    * IF(EXTRACT(DAYOFWEEK FROM activity_date) IN (1, 7), 0.3, 1.0)
    * IF(activity_date >= DATE '2025-12-24', 0.5, 1.0)
    * IF(EXTRACT(MONTH FROM activity_date) = 12, december_factor, 1.0)
),
events AS (
  SELECT
    a.user_id,
    a.activity_date,
    a.upload_share,
    n,
    CONCAT(a.k, '|', CAST(n AS STRING)) AS ke
  FROM active_days AS a
  CROSS JOIN UNNEST(GENERATE_ARRAY(1, 1 + CAST(FLOOR(score(CONCAT('n|', a.k)) * a.max_events) AS INT64))) AS n
),
labeled AS (
  SELECT
    user_id,
    n,
    CASE
      WHEN score(CONCAT('e|', ke)) < upload_share THEN 'upload_file'
      WHEN score(CONCAT('e|', ke)) < upload_share + 0.25 THEN 'download_file'
      WHEN score(CONCAT('e|', ke)) < upload_share + 0.35 THEN 'share_link'
      ELSE 'login'
    END AS event_name,
    TIMESTAMP_ADD(
      TIMESTAMP(activity_date),
      INTERVAL (8 + CAST(FLOOR(score(CONCAT('h|', ke)) * 11) AS INT64)) * 60
        + CAST(FLOOR(score(CONCAT('m|', ke)) * 60) AS INT64) MINUTE
    ) AS event_timestamp
  FROM events
)
SELECT
  ROW_NUMBER() OVER (ORDER BY event_timestamp, user_id, n) AS log_id,
  user_id,
  event_name,
  event_timestamp
FROM labeled;

-- One invoice per month for each paying account (Pro and Enterprise), year 2025
CREATE OR REPLACE TABLE cloudflow.invoices AS
WITH contracts AS (
  SELECT
    user_id,
    signup_date,
    CASE user_id
      WHEN 1 THEN 15000 WHEN 4 THEN 12500 WHEN 8 THEN 10000
      WHEN 17 THEN 11500 WHEN 21 THEN 9000 WHEN 23 THEN 11000
      WHEN 29 THEN 13500 WHEN 32 THEN 9500 WHEN 39 THEN 13000
      ELSE 490
    END AS monthly_fee
  FROM cloudflow.users
  WHERE plan_tier IN ('Pro', 'Enterprise')
),
monthly AS (
  SELECT
    c.user_id,
    c.monthly_fee,
    due_date,
    CONCAT(CAST(c.user_id AS STRING), '|', CAST(due_date AS STRING)) AS k
  FROM contracts AS c
  CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(DATE '2025-01-01', DATE '2025-12-01', INTERVAL 1 MONTH)) AS due_date
  WHERE due_date > c.signup_date
),
payments AS (
  SELECT
    *,
    DATE_ADD(due_date, INTERVAL CAST(FLOOR(score(CONCAT('p|', k)) * 21) AS INT64) - 3 DAY) AS payment_date,
    score(CONCAT('s|', k)) AS s
  FROM monthly
),
statuses AS (
  SELECT
    *,
    CASE
      WHEN s < 0.04 THEN 'refunded'
      WHEN s < 0.07 OR payment_date > DATE '2025-12-31' THEN 'unpaid'
      ELSE 'paid'
    END AS status
  FROM payments
)
SELECT
  1000 + ROW_NUMBER() OVER (ORDER BY due_date, user_id) AS invoice_id,
  user_id,
  CAST(monthly_fee AS NUMERIC) AS amount,
  status,
  due_date,
  IF(status = 'unpaid', NULL, payment_date) AS paid_date
FROM statuses;

-- Check: the three counts below must match the exercise
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM cloudflow.users
UNION ALL
SELECT 'activity_logs', COUNT(*) FROM cloudflow.activity_logs
UNION ALL
SELECT 'invoices', COUNT(*) FROM cloudflow.invoices
ORDER BY table_name;
