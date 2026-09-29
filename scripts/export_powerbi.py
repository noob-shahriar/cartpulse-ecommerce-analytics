"""Export the star-schema tables and the customer segmentation to CSV for Power BI import.
Usage: python scripts/export_powerbi.py
"""
import csv, os
from pathlib import Path
import psycopg2

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "processed" / "powerbi"; OUT.mkdir(parents=True, exist_ok=True)
CONN = dict(host=os.getenv("PGHOST", "localhost"), port=os.getenv("PGPORT", "5432"), dbname=os.getenv("PGDATABASE", "cartpulse"),
            user=os.getenv("PGUSER", "cartpulse"), password=os.getenv("PGPASSWORD", ""))
TABLES = ["dim_date", "dim_location", "dim_customer", "dim_product", "dim_seller", "fact_orders", "fact_order_items", "fact_payments", "fact_reviews"]

def main():
    con = psycopg2.connect(**CONN); cur = con.cursor(); cur.execute("SET search_path TO cartpulse")
    for t in TABLES:
        cur.execute(f"SELECT * FROM {t}")
        cols = [d[0] for d in cur.description]
        with open(OUT / f"{t}.csv", "w", newline="") as f:
            w = csv.writer(f); w.writerow(cols); w.writerows(cur.fetchall())
        print(f"  {t} exported")
    print(f"Done. Files in {OUT}")

if __name__ == "__main__":
    main()
