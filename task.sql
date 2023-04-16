-- Mencari mobil keluaran tahun 2015
SELECT * FROM cars WHERE year >= 2015;

-- Insert bid
INSERT INTO bids (buyer_id, ads_id, bid_price) VALUES (1, 1, 100000);

-- Melihat semua mobil yg dijual 1 akun dari yg paling baru
SELECT c.car_id, b.name as merk, c.name as model, c.year, c.price as harga, TO_CHAR(a.created_at, 'YYYY-MM-DD') as date_post
FROM users u
JOIN ads a ON u.user_id = a.owner_id
JOIN cars c ON a.car_id = c.car_id
JOIN brand b ON c.brand_id = b.brand_id
WHERE u.user_id = (
    SELECT user_id
    FROM users
    ORDER BY created_at DESC
    LIMIT 1
)
ORDER BY a.created_at DESC;

-- Mencari mobil bekas yang termurah berdasarkan keyword
SELECT *
FROM cars
WHERE name ilike '%bmw%';

-- Mencari mobil bekas yang terdekat berdasarkan sebuah id kota, jarak terdekat dihitung 
-- berdasarkan latitude longitude. Perhitungan jarak dapat dihitung menggunakan rumus jarak euclidean 
-- berdasarkan latitude dan longitude.
SELECT a.ad_id, u.user_id, c.car_id, b.brand_id, b.name AS brand_name, ci.city_id, ci.nama_kota AS city_name, ci.longitude AS city_longitude, ci.latitude AS city_latitude,
       SQRT(POWER(ci.latitude - target_city.latitude, 2) + POWER(ci.longitude - target_city.longitude, 2)) AS euclidean_distance
FROM ads a
JOIN users u ON a.owner_id = u.user_id
JOIN cars c ON a.car_id = c.car_id
JOIN brand b ON c.brand_id = b.brand_id
JOIN city ci ON u.city_id = ci.city_id
CROSS JOIN (SELECT latitude, longitude FROM city WHERE nama_kota = 'Bekasi') AS target_city
ORDER BY euclidean_distance ASC;

-- Ranking popularitas model mobil berdasarkan jumlah bid
WITH car_bid_count AS (
  SELECT c.car_id, c.name AS car_name, b.brand_id, b.name AS brand_name, COUNT(bid_id) AS bid_count
  FROM cars c
  JOIN brand b ON c.brand_id = b.brand_id
  JOIN ads a ON c.car_id = a.car_id
  LEFT JOIN bids bi ON a.ad_id = bi.ads_id
  GROUP BY c.car_id, c.name, b.brand_id, b.name
)
SELECT car_id, car_name, brand_id, brand_name, bid_count,
	RANK() OVER (ORDER BY bid_count DESC) AS popularity_rank
FROM car_bid_count
ORDER BY popularity_rank;

-- Membandingkan harga mobil berdasarkan harga rata-rata per kota.
WITH city_car_avg AS (
  SELECT ci.city_id, AVG(bi.bid_price) AS avg_car_city
  FROM city ci
  JOIN users u ON ci.city_id = u.city_id
  JOIN ads a ON u.user_id = a.owner_id
  JOIN bids bi ON a.ad_id = bi.ads_id
  GROUP BY ci.city_id
)
SELECT ci.nama_kota, b.name AS merk, c.name AS model, c.year, bi.bid_price AS price, cca.avg_car_city
FROM city ci
JOIN users u ON ci.city_id = u.city_id
JOIN ads a ON u.user_id = a.owner_id
JOIN cars c ON a.car_id = c.car_id
JOIN brand b ON c.brand_id = b.brand_id
JOIN bids bi ON a.ad_id = bi.ads_id
JOIN city_car_avg cca ON ci.city_id = cca.city_id
ORDER BY ci.nama_kota, b.name, c.name, c.year;

-- Dari penawaran suatu model mobil, cari perbandingan 
-- tanggal user melakukan bid dengan bid selanjutnya beserta harga tawar yang diberikan
WITH bid_data AS (
  SELECT c.name AS model, bi.buyer_id AS user_id, bi.created_at AS bid_date, bi.bid_price AS bid_price,
         ROW_NUMBER() OVER (PARTITION BY c.name, bi.buyer_id ORDER BY bi.created_at) AS bid_sequence
  FROM bids bi
  JOIN ads a ON bi.ads_id = a.ad_id
  JOIN cars c ON a.car_id = c.car_id
)
SELECT model, user_id, first_bid_date, next_bid_date, first_bid_price, next_bid_price
FROM (
  SELECT model, user_id,
         bid_date AS first_bid_date,
         LEAD(bid_date) OVER (PARTITION BY model, user_id ORDER BY bid_sequence) AS next_bid_date,
         bid_price AS first_bid_price,
         LEAD(bid_price) OVER (PARTITION BY model, user_id ORDER BY bid_sequence) AS next_bid_price,
         bid_sequence
  FROM bid_data
) AS bid_comparison
WHERE model ilike '%BMW%'
ORDER BY model, user_id;


-- Membandingkan persentase perbedaan rata-rata harga mobil berdasarkan modelnya dan 
-- rata-rata harga bid yang ditawarkan oleh customer pada 6 bulan terakhir
WITH car_avg_price AS (
  SELECT c.car_id, c.name AS model, AVG(c.price) AS avg_price
  FROM cars c
  JOIN ads a ON c.car_id = a.car_id
  GROUP BY c.car_id, c.name
),
bid_avg_6month AS (
  SELECT c.car_id, c.name AS model, AVG(bi.bid_price) AS avg_bid_6month
  FROM cars c
  JOIN ads a ON c.car_id = a.car_id
  JOIN bids bi ON a.ad_id = bi.ads_id
  WHERE bi.created_at >= NOW() - INTERVAL '6 months'
  GROUP BY c.car_id, c.name
)
SELECT cap.model, cap.avg_price, bam.avg_bid_6month, 
       (cap.avg_price - bam.avg_bid_6month) AS difference,
       ((cap.avg_price - bam.avg_bid_6month) / cap.avg_price) * 100 AS difference_percent
FROM car_avg_price cap
JOIN bid_avg_6month bam ON cap.car_id = bam.car_id
ORDER BY model;


-- Membuat window function rata-rata harga bid sebuah merk 
-- dan model mobil selama 6 bulan terakhir
WITH monthly_avg_bid AS (
  SELECT b.name AS merk, c.name AS model,
         EXTRACT(MONTH FROM bi.created_at) AS bid_month,
         AVG(bi.bid_price) AS avg_bid_price
  FROM bids bi
  JOIN ads a ON bi.ads_id = a.ad_id
  JOIN cars c ON a.car_id = c.car_id
  JOIN brand b ON c.brand_id = b.brand_id
  WHERE bi.created_at >= NOW() - INTERVAL '6 months'
  GROUP BY b.name, c.name, EXTRACT(MONTH FROM bi.created_at)
)
SELECT merk, model,
       MAX(CASE WHEN bid_month = EXTRACT(MONTH FROM NOW()) - 5 THEN avg_bid_price END) AS m_min_6,
       MAX(CASE WHEN bid_month = EXTRACT(MONTH FROM NOW()) - 4 THEN avg_bid_price END) AS m_min_5,
       MAX(CASE WHEN bid_month = EXTRACT(MONTH FROM NOW()) - 3 THEN avg_bid_price END) AS m_min_4,
       MAX(CASE WHEN bid_month = EXTRACT(MONTH FROM NOW()) - 2 THEN avg_bid_price END) AS m_min_3,
       MAX(CASE WHEN bid_month = EXTRACT(MONTH FROM NOW()) - 1 THEN avg_bid_price END) AS m_min_2,
       MAX(CASE WHEN bid_month = EXTRACT(MONTH FROM NOW())     THEN avg_bid_price END) AS m_min_1
FROM monthly_avg_bid
GROUP BY merk, model
ORDER BY merk, model;
