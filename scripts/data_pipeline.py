"""CartPulse data pipeline: raw Olist CSVs -> cleaned tables in data/processed/.

Raw files are read-only inputs and are never modified.
Every cleaning decision is recorded in data/processed/cleaning_log.json (Problem / Decision / Reason / Impact).

Usage:  python scripts/data_pipeline.py
"""
from pathlib import Path
import json
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW, OUT = ROOT / "data" / "raw", ROOT / "data" / "processed"

# Brazilian macro-regions (public IBGE grouping) used for "regional" analysis
REGION = {**dict.fromkeys(["AC","AM","AP","PA","RO","RR","TO"], "North"),
          **dict.fromkeys(["AL","BA","CE","MA","PB","PE","PI","RN","SE"], "Northeast"),
          **dict.fromkeys(["DF","GO","MS","MT"], "Central-West"),
          **dict.fromkeys(["ES","MG","RJ","SP"], "Southeast"),
          **dict.fromkeys(["PR","RS","SC"], "South")}
# The two categories that are missing from the official translation file (translated by us, documented)
EXTRA_TRANSLATION = {"pc_gamer": "pc_gamer", "portateis_cozinha_e_preparadores_de_alimentos": "portable_kitchen_food_preparers"}
NON_SALE_STATUSES = ["canceled", "unavailable"]
DATE_COLS = ["order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date",
             "order_delivered_customer_date", "order_estimated_delivery_date"]
LOG = []

def log(step, problem, decision, reason, impact):
    LOG.append(dict(step=step, problem=problem, decision=decision, reason=reason, impact=impact))

def load_raw():
    r = lambda f, **k: pd.read_csv(RAW / f, **k)
    return dict(orders=r("olist_orders_dataset.csv", parse_dates=DATE_COLS), customers=r("olist_customers_dataset.csv"),
                items=r("olist_order_items_dataset.csv", parse_dates=["shipping_limit_date"]),
                payments=r("olist_order_payments_dataset.csv"),
                reviews=r("olist_order_reviews_dataset.csv", parse_dates=["review_creation_date", "review_answer_timestamp"]),
                products=r("olist_products_dataset.csv"), sellers=r("olist_sellers_dataset.csv"),
                geo=r("olist_geolocation_dataset.csv"), trans=r("product_category_name_translation.csv"))

def clean(d):
    LOG.clear()
    o, c, i, p, rv, pr, s, g, t = (d[k].copy() for k in ["orders","customers","items","payments","reviews","products","sellers","geo","trans"])

    # 1. Orders: date types + flags -------------------------------------------------
    log("orders/dates", "Date columns are stored as text in the CSV", "Parsed to datetime in pandas", "Needed for delivery-time maths", "0 rows changed; 5 columns typed")
    o["has_items"] = o.order_id.isin(i.order_id)
    o["is_valid_sale"] = ~o.order_status.isin(NON_SALE_STATUSES) & o["has_items"]
    n_inv = int((~o.is_valid_sale).sum())
    log("orders/status", "Orders with status canceled/unavailable, or with no items, are not real sales", "Kept every row but flagged is_valid_sale = False; revenue KPIs use valid sales only",
        "Avoids deleting data while stopping cancelled/unavailable orders from inflating revenue",
        f"{n_inv:,} of {len(o):,} orders flagged non-sale ({n_inv/len(o):.2%})")
    dlv = o.order_status.eq("delivered")
    o["flag_delivered_missing_date"] = dlv & o.order_delivered_customer_date.isna()
    o["flag_carrier_before_purchase"] = o.order_delivered_carrier_date < o.order_purchase_timestamp
    o["flag_customer_before_carrier"] = o.order_delivered_customer_date < o.order_delivered_carrier_date
    o["flag_nondelivered_has_delivery_date"] = ~dlv & o.order_delivered_customer_date.notna()
    o["delivery_metrics_ok"] = dlv & o.order_delivered_customer_date.notna()
    o["delivery_days"] = np.where(o.delivery_metrics_ok, (o.order_delivered_customer_date - o.order_purchase_timestamp).dt.total_seconds() / 86400, np.nan)
    o["estimated_days"] = (o.order_estimated_delivery_date - o.order_purchase_timestamp).dt.total_seconds() / 86400
    o["is_late"] = np.where(o.delivery_metrics_ok, o.order_delivered_customer_date > o.order_estimated_delivery_date, np.nan)
    o["days_late"] = np.where(o.delivery_metrics_ok, ((o.order_delivered_customer_date - o.order_estimated_delivery_date).dt.total_seconds() / 86400).clip(lower=0), np.nan)
    log("orders/delivery", "Delivered orders with no delivery date; canceled orders that have a delivery date", "Flagged; excluded from delivery-time and late-rate metrics (delivery_metrics_ok = False). Rows kept for sales metrics",
        "A delivery time cannot be computed without the date, and we must not guess it",
        f"{int(o.flag_delivered_missing_date.sum())} delivered-without-date and {int(o.flag_nondelivered_has_delivery_date.sum())} non-delivered-with-date orders excluded from delivery metrics")
    log("orders/date order", "Carrier pickup earlier than purchase time; customer delivery earlier than carrier pickup", "Flagged only (not corrected)",
        "Likely timestamp recording noise; delivery_days uses purchase -> customer delivery, which is not affected by the carrier timestamp",
        f"{int(o.flag_carrier_before_purchase.sum())} carrier-before-purchase, {int(o.flag_customer_before_carrier.sum())} customer-before-carrier rows flagged")
    o["purchase_month"] = o.order_purchase_timestamp.dt.to_period("M").dt.to_timestamp()
    o["in_full_month_window"] = o.purchase_month.between("2017-01-01", "2018-08-01")
    log("orders/period", "2016 has only 3 sparse months, and Sept/Oct 2018 have 20 orders in total (partial data)", "Kept all rows; flag in_full_month_window (Jan 2017 - Aug 2018) is used for trend and growth analysis",
        "Including tiny partial months would create fake growth/decline spikes",
        f"{int((~o.in_full_month_window).sum()):,} orders sit outside the trend window ({(~o.in_full_month_window).mean():.2%})")

    # 2. Customers --------------------------------------------------------------------
    c["customer_city"] = c.customer_city.str.strip().str.lower(); c["customer_state"] = c.customer_state.str.strip().str.upper()
    c["customer_region"] = c.customer_state.map(REGION)
    log("customers/text", "City/state text may be inconsistent", "Trimmed, city lower-cased, state upper-cased, macro-region added", "Consistent grouping keys",
        f"{c.customer_region.isna().sum()} customers without region; customer_id unique={c.customer_id.is_unique}; {c.customer_unique_id.nunique():,} real customers behind {len(c):,} customer_ids")

    # 3. Items ------------------------------------------------------------------------
    i["line_total"] = i.price + i.freight_value
    log("items/values", "Checked for price <= 0, negative freight, duplicates", "No change needed", "Zero invalid values found",
        f"price<=0: {(i.price<=0).sum()}, freight<0: {(i.freight_value<0).sum()}, duplicate rows: {i.duplicated().sum()}; {(i.freight_value==0).sum()} items with free freight kept")
    q1, q3 = i.price.quantile([.25, .75]); hi = q3 + 1.5 * (q3 - q1)
    i["flag_price_outlier"] = i.price > hi
    log("items/outliers", "Right-skewed prices with high values (max R$ %s)" % f"{i.price.max():,.0f}", "Flagged with IQR rule (flag_price_outlier); NOT removed", "High prices are real luxury/bulky items, not errors; removing them would understate revenue",
        f"{int(i.flag_price_outlier.sum()):,} items ({i.flag_price_outlier.mean():.1%}) above R$ {hi:,.0f}")

    # 4. Payments ---------------------------------------------------------------------
    p["flag_zero_value"] = p.payment_value == 0
    log("payments/zero", "Zero-value payments (vouchers / not_defined)", "Kept and flagged", "Real voucher rows; harmless in sums", f"{int(p.flag_zero_value.sum())} rows flagged")

    # 5. Reviews ----------------------------------------------------------------------
    n0 = len(rv)
    rv = rv.sort_values(["order_id", "review_answer_timestamp"]).drop_duplicates("order_id", keep="last")
    rv["has_comment"] = rv.review_comment_message.notna()
    log("reviews/duplicates", "review_id repeats and 547 orders have several reviews", "Kept one review per order: the most recent by answer timestamp", "Gives one score per order, so joins do not multiply order/revenue rows",
        f"{n0:,} -> {len(rv):,} rows ({n0-len(rv):,} older duplicates set aside)")

    # 6. Products / categories ---------------------------------------------------------
    tmap = {**dict(zip(t.product_category_name, t.product_category_name_english)), **EXTRA_TRANSLATION}
    miss_cat = int(pr.product_category_name.isna().sum())
    pr["category_en"] = pr.product_category_name.map(tmap).fillna("unknown")
    log("products/category", "610 products have no category; 2 categories are missing from the translation file", "Missing category -> 'unknown'; 2 categories translated manually (documented in EXTRA_TRANSLATION)", "Keeps these products in analysis instead of dropping their revenue",
        f"{miss_cat} products = 'unknown'; {pr.category_en.nunique()} distinct categories after cleaning")
    pr = pr.rename(columns={"product_name_lenght": "product_name_length", "product_description_lenght": "product_description_length"})
    log("products/columns", "Source column names contain the typo 'lenght'", "Renamed to 'length'", "Readability", "2 columns renamed")
    pr.loc[pr.product_weight_g == 0, "product_weight_g"] = np.nan
    log("products/weight", "Products with weight of 0 g (impossible) or missing dimensions", "Zero weight set to NULL; missing dimensions left NULL", "Not filled with guesses; weight/dimensions are not used for headline KPIs",
        f"{int(pr.product_weight_g.isna().sum())} products with unknown weight")

    # 7. Sellers ----------------------------------------------------------------------
    s["seller_city"] = s.seller_city.str.strip().str.lower(); s["seller_state"] = s.seller_state.str.strip().str.upper()
    log("sellers/text", "City/state text formatting", "Trimmed and standardised", "Consistent grouping keys", f"{len(s):,} sellers, seller_id unique={s.seller_id.is_unique}")

    # 8. Geolocation ------------------------------------------------------------------
    n_g = len(g); n_dup = int(g.duplicated().sum())
    inside = g.geolocation_lat.between(-34, 6) & g.geolocation_lng.between(-74, -34)
    n_out = int((~inside).sum()); g = g[inside]
    mode_ = lambda x: x.mode().iat[0]
    g = g.groupby("geolocation_zip_code_prefix").agg(lat=("geolocation_lat", "mean"), lng=("geolocation_lng", "mean"),
            city=("geolocation_city", mode_), state=("geolocation_state", mode_)).reset_index()
    log("geolocation/dedupe", f"{n_g:,} rows, {n_dup:,} exact duplicates, many rows per zip prefix, {n_out} coordinates outside Brazil's bounding box",
        "Dropped out-of-bounds points, then collapsed to one row per zip prefix (mean lat/lng, most common city/state)", "A dimension needs one row per key",
        f"{n_g:,} -> {len(g):,} rows (unique zip prefixes)")

    # 9. Referential integrity --------------------------------------------------------
    ri = {"orders_without_customer": int((~o.customer_id.isin(c.customer_id)).sum()), "items_without_order": int((~i.order_id.isin(o.order_id)).sum()),
          "items_without_product": int((~i.product_id.isin(pr.product_id)).sum()), "items_without_seller": int((~i.seller_id.isin(s.seller_id)).sum()),
          "payments_without_order": int((~p.order_id.isin(o.order_id)).sum()), "reviews_without_order": int((~rv.order_id.isin(o.order_id)).sum()),
          "orders_without_items": int((~o.has_items).sum()), "orders_without_payment": int((~o.order_id.isin(p.order_id)).sum())}
    log("integrity", "Checked all foreign keys", "No orphan rows to fix. Orders without items / payment are legitimate (cancelled/unavailable) and stay flagged", "All fact rows have valid parents", json.dumps(ri))

    # 10. Order-level fact table ----------------------------------------------------------
    agg = i.groupby("order_id").agg(item_count=("order_item_id", "count"), items_value=("price", "sum"), freight_value=("freight_value", "sum"),
                                    seller_count=("seller_id", "nunique"), product_count=("product_id", "nunique")).reset_index()
    pay = p.groupby("order_id").agg(payment_value=("payment_value", "sum"), payment_count=("payment_sequential", "count"), max_installments=("payment_installments", "max")).reset_index()
    ptype = p.sort_values("payment_value", ascending=False).drop_duplicates("order_id")[["order_id", "payment_type"]].rename(columns={"payment_type": "main_payment_type"})
    fo = (o.merge(c[["customer_id", "customer_unique_id", "customer_state", "customer_region"]], on="customer_id", how="left")
            .merge(agg, on="order_id", how="left").merge(pay, on="order_id", how="left").merge(ptype, on="order_id", how="left")
            .merge(rv[["order_id", "review_score", "has_comment"]], on="order_id", how="left"))
    for col in ["item_count", "items_value", "freight_value", "seller_count", "product_count"]:
        fo[col] = fo[col].fillna(0)
    fo["order_value"] = fo.items_value + fo.freight_value
    mm = fo[fo.has_items & fo.payment_value.notna()]
    log("payments/reconcile", "payment_value differs from items + freight for some orders (installment interest, vouchers, rounding)", "Kept both; documented: revenue = items_value (product GMV), order_value = items + freight, payment_value = cash paid", "Choosing one definition per KPI avoids double counting",
        f"{int(((mm.payment_value - mm.order_value).abs() > 1).sum()):,} of {len(mm):,} orders differ by more than R$ 1")
    assert fo.order_id.is_unique and len(fo) == len(o)
    return dict(orders=fo, customers=c, items=i, payments=p, reviews=rv, products=pr, sellers=s, geo=g), ri

def main():
    OUT.mkdir(parents=True, exist_ok=True); (OUT / "samples").mkdir(exist_ok=True)
    tables, ri = clean(load_raw())
    names = {"orders": "orders_clean", "customers": "customers_clean", "items": "order_items_clean", "payments": "order_payments_clean",
             "reviews": "order_reviews_clean", "products": "products_clean", "sellers": "sellers_clean", "geo": "geolocation_clean"}
    for k, n in names.items():
        tables[k].to_csv(OUT / f"{n}.csv", index=False)
        tables[k].head(300).to_csv(OUT / "samples" / f"{n}_sample.csv", index=False)
        print(f"{n:24s} {len(tables[k]):>9,} rows")
    (OUT / "cleaning_log.json").write_text(json.dumps(LOG, indent=2))
    print(f"cleaning_log.json: {len(LOG)} decisions")

if __name__ == "__main__":
    main()
