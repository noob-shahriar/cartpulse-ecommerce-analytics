# CartPulse - Executive Summary

**Data:** Olist Brazilian e-commerce orders, Sep 2016 - Oct 2018 (99,441 orders). All figures below use *valid sales* only (order not canceled/unavailable, has items - 98,199 of 99,441 orders). Full source queries: `sql/`, `reports/sql_results/`.

## Headline numbers
| Metric | Value |
|---|---:|
| Total revenue (product value) | R$ 13,494,400.74 |
| Total orders | 98,199 |
| Unique customers | 94,983 |
| Average order value | R$ 137.42 |
| Repeat customer rate | 3.04% |
| Average review score | 4.09 (of 98,673 reviewed orders) |
| Late delivery rate | 8.11% of delivered orders |

## Key findings

**1. Revenue is concentrated in the Southeast.**
The Southeast region generates 65.4% of revenue from 68.6% of orders; São Paulo state alone leads every other state by a wide margin (`sql/02_sales_analysis.sql`, `revenue_by_region`/`revenue_by_state`). Freight burden rises the further from the Southeast a customer is - from 15.2% of item price in the Southeast to 22.7% in the North.
*Implication:* the business is dependent on one region; growth in the North/Northeast is constrained by shipping cost, not just demand.

**2. Repeat purchasing is structurally low.**
Only 3.04% of customers place a second order, and repeat customers contribute just 5.56% of revenue despite spending nearly double per order (R$259.95 vs R$138.38 for one-time buyers) (`sql/03_customer_analysis.sql`, `customer_kpis`). Cohort analysis confirms this holds for every acquisition month, not just older cohorts (`notebooks/06_advanced_analysis.ipynb`).
*Implication:* growth must come mainly from new-customer acquisition and higher average order value, not retention programs - though the small repeat segment is disproportionately valuable and worth protecting.

**3. Revenue and seller base are both concentrated (Pareto pattern).**
18 of 74 product categories (24%) generate 80% of revenue. Among sellers, the top 1% (about 31 of 3,053 active sellers) generate 26.2% of revenue, and the top 10% generate 67.5% (`sql/05_seller_analysis.sql`, `seller_concentration`; `sql/08_advanced_analysis.sql`, `pareto_summary`).
*Implication:* losing a handful of top sellers or top categories would be a material revenue risk; seller-retention and category-management effort should be prioritised for this small group.

**4. Late delivery has a large, measurable effect on satisfaction.**
Orders delivered late average a 2.57-star review versus 4.29 stars for on-time orders - a gap of 1.7 stars - and 54% of late orders receive a 1- or 2-star review, versus 9% of on-time orders (`sql/06_operations_analysis.sql`, `review_vs_delivery`). 8.11% of delivered orders arrive late, averaging 9.6 days late when they do.
*Implication:* delivery reliability is one of the highest-leverage levers on customer satisfaction available in this data - more so than price or category.

**5. True profit cannot be measured - only estimated contribution proxies.**
The dataset has no cost, commission or profit field. Using an estimated proxy (revenue - freight), `furniture_decor`, `housewares` and `office_furniture` combine high revenue with high freight burden and are the categories most worth investigating for shipping-cost optimisation (`reports/profitability_analysis.md`).

## Recommendations
See `reports/business_recommendations.md` for the full Observation -> Evidence -> Implication -> Recommendation structure behind each finding above.
