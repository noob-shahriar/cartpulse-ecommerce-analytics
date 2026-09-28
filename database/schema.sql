-- CartPulse analytical schema (PostgreSQL 16)
-- Star-style model: 4 fact tables around shared dimensions.
-- Grain:  fact_orders = 1 row per order | fact_order_items = 1 row per order item
--         fact_payments = 1 row per payment | fact_reviews = 1 row per order (latest review)
DROP SCHEMA IF EXISTS cartpulse CASCADE;
CREATE SCHEMA cartpulse;
SET search_path TO cartpulse;

-- ---------- Dimensions ----------
CREATE TABLE dim_date (
    date_key      DATE PRIMARY KEY,
    year          SMALLINT NOT NULL,
    quarter       SMALLINT NOT NULL,
    month         SMALLINT NOT NULL,
    month_start   DATE NOT NULL,
    month_name    TEXT NOT NULL,
    day_of_week   SMALLINT NOT NULL,          -- 1 = Monday
    is_weekend    BOOLEAN NOT NULL
);

CREATE TABLE dim_location (               -- one row per zip prefix (from cleaned geolocation)
    zip_code_prefix INTEGER PRIMARY KEY,
    lat  DOUBLE PRECISION,
    lng  DOUBLE PRECISION,
    city TEXT,
    state CHAR(2)
);

CREATE TABLE dim_customer (               -- one row per customer_id (per-order key)
    customer_id        TEXT PRIMARY KEY,
    customer_unique_id TEXT NOT NULL,     -- real customer identity
    zip_code_prefix    INTEGER,
    city   TEXT,
    state  CHAR(2) NOT NULL,
    region TEXT NOT NULL
);
CREATE INDEX ix_dim_customer_unique ON dim_customer (customer_unique_id);

CREATE TABLE dim_product (
    product_id      TEXT PRIMARY KEY,
    category_pt     TEXT,
    category_en     TEXT NOT NULL,
    name_length     INTEGER,
    description_length INTEGER,
    photos_qty      INTEGER,
    weight_g        NUMERIC,
    length_cm       NUMERIC,
    height_cm       NUMERIC,
    width_cm        NUMERIC
);

CREATE TABLE dim_seller (
    seller_id       TEXT PRIMARY KEY,
    zip_code_prefix INTEGER,
    city  TEXT,
    state CHAR(2) NOT NULL
);

-- ---------- Facts ----------
CREATE TABLE fact_orders (
    order_id     TEXT PRIMARY KEY,
    customer_id  TEXT NOT NULL REFERENCES dim_customer (customer_id),
    order_status TEXT NOT NULL,
    purchase_ts  TIMESTAMP NOT NULL,
    purchase_date DATE NOT NULL REFERENCES dim_date (date_key),
    approved_ts  TIMESTAMP,
    carrier_ts   TIMESTAMP,
    delivered_ts TIMESTAMP,
    estimated_delivery_date TIMESTAMP NOT NULL,
    item_count   INTEGER NOT NULL,
    items_value  NUMERIC(12,2) NOT NULL,   -- sum(price): product value / GMV
    freight_value NUMERIC(12,2) NOT NULL,  -- sum(freight_value)
    order_value  NUMERIC(12,2) NOT NULL,   -- items_value + freight_value
    payment_value NUMERIC(12,2),           -- cash paid; may differ slightly from order_value
    main_payment_type TEXT,
    max_installments INTEGER,
    is_valid_sale BOOLEAN NOT NULL,        -- not canceled/unavailable and has items
    delivery_metrics_ok BOOLEAN NOT NULL,  -- delivered AND has delivery date
    delivery_days NUMERIC(8,3),
    is_late BOOLEAN,
    days_late NUMERIC(8,3),
    in_full_month_window BOOLEAN NOT NULL  -- Jan 2017 - Aug 2018
);
CREATE INDEX ix_fo_customer ON fact_orders (customer_id);
CREATE INDEX ix_fo_date ON fact_orders (purchase_date);

CREATE TABLE fact_order_items (
    order_id      TEXT NOT NULL REFERENCES fact_orders (order_id),
    order_item_id INTEGER NOT NULL,
    product_id    TEXT NOT NULL REFERENCES dim_product (product_id),
    seller_id     TEXT NOT NULL REFERENCES dim_seller (seller_id),
    shipping_limit_ts TIMESTAMP,
    price         NUMERIC(10,2) NOT NULL CHECK (price > 0),
    freight_value NUMERIC(10,2) NOT NULL CHECK (freight_value >= 0),
    PRIMARY KEY (order_id, order_item_id)
);
CREATE INDEX ix_foi_product ON fact_order_items (product_id);
CREATE INDEX ix_foi_seller ON fact_order_items (seller_id);

CREATE TABLE fact_payments (
    order_id           TEXT NOT NULL REFERENCES fact_orders (order_id),
    payment_sequential INTEGER NOT NULL,
    payment_type       TEXT NOT NULL,
    installments       INTEGER NOT NULL,
    payment_value      NUMERIC(12,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE fact_reviews (
    order_id     TEXT PRIMARY KEY REFERENCES fact_orders (order_id),
    review_id    TEXT NOT NULL,
    review_score SMALLINT NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    has_comment  BOOLEAN NOT NULL,
    created_date DATE,
    answered_ts  TIMESTAMP
);
