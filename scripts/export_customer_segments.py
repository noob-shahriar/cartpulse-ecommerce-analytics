"""Export the RFM customer segmentation (view vw_customer_rfm) to data/processed/customer_segments.csv
so it can be loaded straight into Power BI without a live database connection.
"""
import os
from pathlib import Path
import pandas as pd, psycopg2

ROOT = Path(__file__).resolve().parents[1]
CONN = dict(host=os.getenv("PGHOST", "localhost"), port=os.getenv("PGPORT", "5432"), dbname=os.getenv("PGDATABASE", "cartpulse"),
            user=os.getenv("PGUSER", "cartpulse"), password=os.getenv("PGPASSWORD", ""))

def main():
    with psycopg2.connect(**CONN) as con, con.cursor() as cur:
        cur.execute("SET search_path TO cartpulse")
        cur.execute("SELECT * FROM vw_customer_rfm ORDER BY monetary DESC")
        df = pd.DataFrame(cur.fetchall(), columns=[d[0] for d in cur.description])
    out = ROOT / "data" / "processed" / "customer_segments.csv"
    df.to_csv(out, index=False)
    print(f"wrote {out} ({len(df):,} rows)")
    print(df.segment.value_counts(normalize=True).mul(100).round(2))

if __name__ == "__main__":
    main()
