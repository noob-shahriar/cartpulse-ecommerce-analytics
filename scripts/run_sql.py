"""Run every query in sql/*.sql and save each result to reports/sql_results/<file>__<query>.csv.

Queries are separated by comment markers of the form:   -- @query_name : one line business purpose
Usage:  python scripts/run_sql.py [file_prefix]        e.g.  python scripts/run_sql.py 02
"""
import os, re, sys
from pathlib import Path
import pandas as pd, psycopg2

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "reports" / "sql_results"; OUT.mkdir(parents=True, exist_ok=True)
CONN = dict(host=os.getenv("PGHOST", "localhost"), port=os.getenv("PGPORT", "5432"), dbname=os.getenv("PGDATABASE", "cartpulse"),
            user=os.getenv("PGUSER", "cartpulse"), password=os.getenv("PGPASSWORD", ""))

def main(prefix=""):
    with psycopg2.connect(**CONN) as con, con.cursor() as cur:
        cur.execute("SET search_path TO cartpulse")
        for f in sorted((ROOT / "sql").glob(f"{prefix}*.sql")):
            parts = re.split(r"^-- @(\w+)\s*:.*$", f.read_text(), flags=re.M)
            for name, body in zip(parts[1::2], parts[2::2]):
                cur.execute(body)
                df = pd.DataFrame(cur.fetchall(), columns=[d[0] for d in cur.description])
                df.to_csv(OUT / f"{f.stem}__{name}.csv", index=False)
                print(f"{f.name:28s} {name:32s} {len(df):>6,} rows")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "")
