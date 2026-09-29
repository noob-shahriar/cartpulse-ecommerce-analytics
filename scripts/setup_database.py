"""Create the CartPulse schema in PostgreSQL and load the cleaned tables.

Connection settings come from environment variables (see .env.example); no credentials are stored in the repo.
Usage:  python scripts/setup_database.py
"""
import io, os
from pathlib import Path
import pandas as pd, psycopg2

ROOT = Path(__file__).resolve().parents[1]
PROC = ROOT / "data" / "processed"
CONN = dict(host=os.getenv("PGHOST", "localhost"), port=os.getenv("PGPORT", "5432"), dbname=os.getenv("PGDATABASE", "cartpulse"),
            user=os.getenv("PGUSER", "cartpulse"), password=os.getenv("PGPASSWORD", ""))

def copy(cur, table, df):
    buf = io.StringIO(); df.to_csv(buf, index=False, header=False, na_rep="\\N"); buf.seek(0)
    cur.copy_expert(f"COPY cartpulse.{table} ({','.join(df.columns)}) FROM STDIN WITH (FORMAT csv, NULL '\\N')", buf)
    print(f"  loaded {table:18s} {len(df):>9,}")

def b(s):  # pandas bool -> True/False/None
    return s.astype("object").where(s.notna(), None)

def main():
    rd = lambda n, **k: pd.read_csv(PROC / f"{n}.csv", **k)
    orders = rd("orders_clean", parse_dates=["order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date", "order_delivered_customer_date", "order_estimated_delivery_date"])
    cust, prod, sell, geo = rd("customers_clean"), rd("products_clean"), rd("sellers_clean"), rd("geolocation_clean")
    items, pay, rev = rd("order_items_clean"), rd("order_payments_clean"), rd("order_reviews_clean", parse_dates=["review_creation_date", "review_answer_timestamp"])
    raw_prod = pd.read_csv(ROOT / "data" / "raw" / "olist_products_dataset.csv", usecols=["product_id", "product_category_name"])

    dates = pd.DataFrame({"date_key": pd.date_range("2016-09-01", "2018-12-31")})
    d = dates.date_key
    dates = dates.assign(year=d.dt.year, quarter=d.dt.quarter, month=d.dt.month, month_start=d.dt.to_period("M").dt.to_timestamp().dt.date,
                         month_name=d.dt.strftime("%b"), day_of_week=d.dt.dayofweek + 1, is_weekend=d.dt.dayofweek >= 5)
    dates["date_key"] = dates.date_key.dt.date

    dim_loc = geo.rename(columns={"geolocation_zip_code_prefix": "zip_code_prefix"})[["zip_code_prefix", "lat", "lng", "city", "state"]]
    dim_cust = cust.rename(columns={"customer_zip_code_prefix": "zip_code_prefix", "customer_city": "city", "customer_state": "state", "customer_region": "region"})[
        ["customer_id", "customer_unique_id", "zip_code_prefix", "city", "state", "region"]]
    dim_prod = prod.merge(raw_prod, on="product_id", suffixes=("", "_pt")).rename(columns={"product_category_name": "category_pt", "category_en": "category_en",
        "product_name_length": "name_length", "product_description_length": "description_length", "product_photos_qty": "photos_qty",
        "product_weight_g": "weight_g", "product_length_cm": "length_cm", "product_height_cm": "height_cm", "product_width_cm": "width_cm"})
    dim_prod = dim_prod[["product_id", "category_pt", "category_en", "name_length", "description_length", "photos_qty", "weight_g", "length_cm", "height_cm", "width_cm"]]
    for col in ["name_length", "description_length", "photos_qty"]:
        dim_prod[col] = dim_prod[col].astype("Int64")
    dim_sell = sell.rename(columns={"seller_zip_code_prefix": "zip_code_prefix", "seller_city": "city", "seller_state": "state"})

    fo = pd.DataFrame({"order_id": orders.order_id, "customer_id": orders.customer_id, "order_status": orders.order_status,
        "purchase_ts": orders.order_purchase_timestamp, "purchase_date": orders.order_purchase_timestamp.dt.date,
        "approved_ts": orders.order_approved_at, "carrier_ts": orders.order_delivered_carrier_date, "delivered_ts": orders.order_delivered_customer_date,
        "estimated_delivery_date": orders.order_estimated_delivery_date, "item_count": orders.item_count.astype(int),
        "items_value": orders.items_value.round(2), "freight_value": orders.freight_value.round(2), "order_value": orders.order_value.round(2),
        "payment_value": orders.payment_value.round(2), "main_payment_type": orders.main_payment_type,
        "max_installments": orders.max_installments.astype("Int64"), "is_valid_sale": orders.is_valid_sale,
        "delivery_metrics_ok": orders.delivery_metrics_ok, "delivery_days": orders.delivery_days.round(3),
        "is_late": orders.is_late.map({1.0: True, 0.0: False}), "days_late": orders.days_late.round(3), "in_full_month_window": orders.in_full_month_window})
    foi = items.rename(columns={"shipping_limit_date": "shipping_limit_ts"})[["order_id", "order_item_id", "product_id", "seller_id", "shipping_limit_ts", "price", "freight_value"]]
    fp = pay.rename(columns={"payment_installments": "installments"})[["order_id", "payment_sequential", "payment_type", "installments", "payment_value"]]
    fr = rev.rename(columns={"review_creation_date": "created_date", "review_answer_timestamp": "answered_ts"})[["order_id", "review_id", "review_score", "has_comment", "created_date", "answered_ts"]]

    with psycopg2.connect(**CONN) as con, con.cursor() as cur:
        cur.execute((ROOT / "database" / "schema.sql").read_text()); cur.execute("SET search_path TO cartpulse")
        for name, df in [("dim_date", dates), ("dim_location", dim_loc), ("dim_customer", dim_cust), ("dim_product", dim_prod), ("dim_seller", dim_sell),
                         ("fact_orders", fo), ("fact_order_items", foi), ("fact_payments", fp), ("fact_reviews", fr)]:
            copy(cur, name, df)
        for f in sorted((ROOT / "database" / "transformations").glob("*.sql")):   # analytical views
            cur.execute(f.read_text()); print(f"  applied {f.name}")
        cur.execute("ANALYZE")
    print("Database load complete.")

if __name__ == "__main__":
    main()
