# CartPulse - Business Recommendations

Each recommendation follows **Observation -> Evidence -> Implication -> Recommendation**. All figures are calculated from the cleaned Olist data (valid sales unless stated) - see `sql/` and `notebooks/` for the underlying queries.

---

### 1. Diversify beyond the Southeast, but price shipping realistically first
**Observation:** revenue is heavily concentrated in one region.
**Evidence:** the Southeast produces 65.4% of revenue from 68.6% of orders; freight is 15.2% of item price there versus 22.7% in the North and 21.7% in the Northeast (`sql/02_sales_analysis.sql`).
**Implication:** expansion outside the Southeast is limited less by demand and more by delivery cost eating into affordability.
**Recommendation:** pilot regional fulfillment or freight subsidies for the North/Northeast on the top revenue categories, and track whether freight-burden reduction moves order volume in those states before committing broader capital.

---

### 2. Treat this as a new-customer-acquisition business, not a loyalty business
**Observation:** repeat purchasing is rare and does not improve with time.
**Evidence:** 3.04% repeat rate; repeat customers are only 5.56% of revenue; cohort retention averages under 1% at month 1 for every cohort observed (`sql/03_customer_analysis.sql`, `notebooks/06_advanced_analysis.ipynb`).
**Implication:** loyalty-program investment will have a small ceiling on this data; acquisition efficiency and average order value are the levers with real headroom.
**Recommendation:** shift marketing measurement from "retention rate" to cost-per-new-customer and average order value; reserve loyalty spend for the "At-Risk" high-value segment (36% of revenue from 15% of customers, `reports/sql_results/08_advanced_analysis__rfm_segment_summary.csv`) where a win-back campaign has a clear, measurable target.

---

### 3. Protect the top sellers and top categories - they carry the business
**Observation:** both revenue and the seller base follow a Pareto pattern.
**Evidence:** 18 of 74 categories = 80% of revenue; the top 10% of sellers (about 305 of 3,053) = 67.5% of revenue (`sql/05_seller_analysis.sql`, `sql/08_advanced_analysis.sql`).
**Implication:** concentration is a risk as much as an opportunity - losing a top seller or a disruption to a top category has outsized impact.
**Recommendation:** build a seller-health dashboard (using `sql/05_seller_analysis.sql`'s scorecard) for the top 10% of sellers by revenue, tracking late-delivery rate and review score monthly, with proactive account-management outreach when either degrades.

---

### 4. Fix delivery reliability - it is the strongest satisfaction driver found in this data
**Observation:** late delivery is associated with a large review-score gap.
**Evidence:** late orders average 2.57 stars vs 4.29 for on-time (a 1.72-star gap); 54% of late orders get 1-2 stars vs 9% on-time; 8.11% of delivered orders are late, by an average of 9.6 days (`sql/06_operations_analysis.sql`).
**Implication:** delivery reliability outweighs most other levers examined (price band, category) for customer satisfaction.
**Recommendation:** identify and support the sellers/states with the worst late-delivery rates (`sql/05_seller_analysis.sql`, `sellers_poor_delivery`; `sql/06_operations_analysis.sql`, `delivery_by_customer_state`) first, since fixing the worst outliers will move the average rate the most.

---

### 5. Use freight burden, not intuition, to prioritise shipping-cost projects
**Observation:** some high-revenue categories carry disproportionate freight cost.
**Evidence:** `furniture_decor`, `housewares` and `office_furniture` sit in the "high revenue / high freight burden" quadrant of the estimated contribution-proxy analysis (`reports/profitability_analysis.md`).
**Implication:** these categories are prime candidates for packaging redesign, carrier renegotiation, or freight-inclusive pricing tests.
**Recommendation:** run a controlled pilot (e.g. revised packaging or a different carrier) on one of these three categories and measure the change in `freight_pct_of_price` and order conversion before rolling out further - because true product cost is unavailable, success should be measured on freight ratio and volume, not claimed profit.

---

## What this analysis cannot tell us (be upfront about limitations)
- **No true profit** - only revenue, freight, and a labelled estimated proxy (no cost/commission data exists).
- **No marketing-channel or acquisition-cost data** - "new customer acquisition" is recommended directionally, but CAC cannot be calculated from this dataset.
- **Short/partial history** - the data ends Oct 2018; cohort and seasonality conclusions are bounded by roughly 20 full months of data (Jan 2017-Aug 2018).
- **Multi-seller orders** - a small share of orders involve more than one seller; seller-level delivery/review metrics attribute the whole order's outcome to each seller involved, which slightly blends responsibility in those cases.
