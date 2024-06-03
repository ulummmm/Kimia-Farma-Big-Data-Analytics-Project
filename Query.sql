--- Membuat Base Table Dari Dataset Yang Telah Diimport ---

CREATE TABLE `rakamin-kf-analytics-425007.kimia_farma.base_table` AS (
  SELECT
    tr.transaction_id,
    tr.date,
    tr.customer_name,
    tr.discount_percentage,
    tr.rating AS tr_rating,
    kc.branch_id,
    kc.branch_name,
    kc.kota,
    kc.provinsi,
    kc.rating AS branch_rating,
    pr.product_id,
    pr.product_name,
    pr.price,
    CASE
      WHEN pr.price > 500000 THEN 'laba 30%'
      WHEN pr.price >= 300000 THEN 'laba 25%'
      WHEN pr.price >= 100000 THEN 'laba 20%'
      WHEN pr.price >= 50000 THEN 'laba 15%'
      ELSE 'laba 10%'
    END AS gross_profit,
    (pr.price - (pr.price * discount_percentage)) AS nett_sales,
    CASE
      WHEN pr.price > 500000 THEN (pr.price*(30/100))
      WHEN pr.price >= 300000 THEN (pr.price*(25/100))
      WHEN pr.price >= 100000 THEN (pr.price*(20/100))
      WHEN pr.price >= 50000 THEN  (pr.price*(15/100))
      ELSE (pr.price*(10/100))
    END AS nett_profit,
  FROM `rakamin-kf-analytics-425007.kimia_farma.kf_final_transaction` AS tr
  JOIN `rakamin-kf-analytics-425007.kimia_farma.kf_kantor_cabang`AS kc
    ON tr.branch_id = kc.branch_id
  JOIN `rakamin-kf-analytics-425007.kimia_farma.kf_product` AS pr
    ON tr.product_id = pr.product_id
);

--- Table Agregasi ---

--- Pertumbuhan Revenue ---

CREATE TABLE `rakamin-kf-analytics-425007.kimia_farma.revenue_growth` AS (
WITH quarterly_revenue AS (
  SELECT
    EXTRACT(YEAR FROM date) AS year,
    EXTRACT(QUARTER FROM date) AS quarter,
    SUM(nett_sales) AS total_revenue
  FROM
    `rakamin-kf-analytics-425007.kimia_farma.base_table`
  GROUP BY year, quarter
  ORDER BY year, quarter
)
SELECT
  year,
  quarter,
  total_revenue,
  LAG(total_revenue) OVER (ORDER BY year, quarter) AS previous_q_revenue,
  (total_revenue - LAG(total_revenue) OVER (ORDER BY year, quarter)) AS revenue_growth,
  CONCAT(CAST(ROUND(((total_revenue - LAG(total_revenue) OVER (ORDER BY year, quarter)) / LAG(total_revenue) OVER (ORDER BY year, quarter)) * 100, 2) AS STRING), '%')AS percentage_growth
FROM
  quarterly_revenue
ORDER BY year, quarter
);

--- TOP 10 Transaksi Tingkat Provinsi ---

CREATE TABLE `rakamin-kf-analytics-425007.kimia_farma.top_branch_transactions` AS(
SELECT
  provinsi AS provinsi,
  COUNT(transaction_id) AS total_transactions
FROM
  `rakamin-kf-analytics-425007.kimia_farma.base_table`
GROUP BY
  provinsi
ORDER BY
  total_transactions DESC
Limit 10
)
;

--- TOP 10 Nett Sales Tingkat Provinsi ---

CREATE TABLE `rakamin-kf-analytics-425007.kimia_farma.top_branch_sales` AS (
SELECT
  provinsi AS provinsi,
  SUM(nett_sales) AS total_sales,
FROM
  `rakamin-kf-analytics-425007.kimia_farma.base_table`
GROUP BY
  provinsi
ORDER BY
  total_sales DESC
LIMIT 10
)
;

---Top 5 Branch Rating dengan Rating Transaksi Terendah ---

CREATE TABLE `rakamin-kf-analytics-425007.kimia_farma.top5_rate_branch_low_transactions` AS(
WITH branch_ratings AS (
  SELECT
    branch_id,
    branch_name,
    provinsi,
    AVG(tr_rating) AS avg_tr_rating,
    branch_rating
  FROM
    `rakamin-kf-analytics-425007.kimia_farma.base_table`
  GROUP BY
    branch_id, branch_name, provinsi, branch_rating
),
ranked_branches AS (
  SELECT
    branch_id,
    branch_name,
    provinsi,
    avg_tr_rating,
    branch_rating,
    ROW_NUMBER() OVER (ORDER BY branch_rating DESC, avg_tr_rating) AS rank
  FROM
    branch_ratings
)
SELECT
  branch_id,
  branch_name,
  provinsi,
  avg_tr_rating,
  branch_rating
FROM
  ranked_branches
WHERE
  rank <= 5
ORDER BY
  branch_rating DESC, avg_tr_rating
)
;

--- Pengaruh Diskon Terhadap Penjualan ---

CREATE TABLE `rakamin-kf-analytics-425007.kimia_farma.discount_prc_to_sales` AS (
SELECT
  discount_percentage,
  SUM(nett_sales) AS total_sales,
  SUM(nett_profit) AS total_profit,
  COUNT(transaction_id) AS total_transactions
FROM
  `rakamin-kf-analytics-425007.kimia_farma.base_table`
GROUP BY
  discount_percentage
ORDER BY
  discount_percentage
)
;

--- TOP 10 Produk Terlaris ---

CREATE TABLE `rakamin-kf-analytics-425007.kimia_farma.top10_product_sales` AS (
SELECT
  product_id,
  product_name,
  SUM(nett_sales) AS total_sales,
  COUNT(transaction_id) AS total_transactions
FROM
  `rakamin-kf-analytics-425007.kimia_farma.base_table`
GROUP BY
  product_id, product_name
ORDER BY
  total_sales DESC
LIMIT 10
)
;

--- Geomap Profit ---

CREATE TABLE `rakamin-kf-analytics-425007.kimia_farma.profit_geomap` AS (
SELECT
  provinsi AS provinsi,
  ROUND(SUM(nett_profit),2) AS profit
FROM `rakamin-kf-analytics-425007.kimia_farma.base_table`
GROUP BY provinsi
ORDER BY profit DESC
);