
# Rossmann Store Health — Early Warning Rules

## 1. Purpose

This document defines the initial rule-based Store Health classification system for the Rossmann Store Health & Sales Forecasting Platform.

The system aims to:

- Identify stores showing signs of underperformance.
- Prioritise stores requiring further investigation.
- Provide transparent and explainable warning signals.
- Support store performance monitoring.

The initial classification is designed for monitoring and investigation prioritisation, not for predicting future sales deterioration.

## 2. Early Warning Indicators

Three indicators were selected from the Business Analysis and Early Warning Analysis.

### Signal 1 — Low Peer Performance

**KPI:** Peer Performance Gap (%)

**Condition:** Peer Performance Gap <= -25.70%

**Description:**

The store generates substantially lower average daily sales than comparable stores.

Peer groups are defined by Store Type and Assortment.

The evaluated store is excluded from its own peer benchmark.

**Minimum requirement:** A peer group containing at least five stores, including the evaluated store.

**Source:** Business Analysis Q5 / Early Warning Analysis Q1

### Signal 2 — Recent Sales Deterioration

**KPI:** Recent Sales Change (%)

**Condition:** Recent Sales Change <= -9.08%

**Description:**

The store experienced a substantial decline in average sales per operating day.

The latest eight weeks are compared with the previous eight weeks.

**Minimum requirement:** At least 20 operating days in each comparison period.

**Source:** Business Analysis Q6 / Early Warning Analysis Q2

### Signal 3 — Persistent Monthly Decline

**KPI:** Consecutive Monthly Declines

**Condition:** Three consecutive monthly declines.

**Description:**

Average daily sales decreased for three consecutive monthly intervals across four complete calendar months.

**Minimum requirement:** At least 15 operating days in each of the four months.

**Source:** Business Analysis Q4 / Early Warning Analysis Q3

## 3. Store Health Classification

Each activated warning signal contributes one point.

| Total Signals | Store Health Status | Monitoring Priority |
|---|---|---|
| 0 | Healthy | Routine monitoring |
| 1 | Watch | Increased monitoring |
| 2 | At Risk | Detailed investigation |
| 3 | Critical | Highest investigation priority |

These classifications are preliminary operational categories.

They do not represent validated probabilities of future deterioration.

## 4. Insufficient Data

A store should receive the status "Insufficient Data" when the minimum data requirements for any of the three indicators are not satisfied.

Missing indicators must not automatically be treated as healthy performance.

Stores with insufficient data should be reviewed separately.

## 5. Supporting Diagnostic Indicators

The following indicators help explain potential performance issues:

- Average Daily Sales
- Average Daily Customers
- Sales per Customer
- Customer Traffic Change (%)
- Sales per Customer Change (%)
- Sales Volatility (CV %)
- Promotional Sales Uplift (%)
- Promotional Sales Concentration
- Competition Distance
- Seasonal Performance Patterns

These indicators do not contribute directly to the initial warning signal count.

## 6. Historical Analysis Results

The combined warning analysis included 1,109 stores.

| Warning Signals | Stores | Percentage |
|---|---:|---:|
| 0 | 636 | 57.35% |
| 1 | 354 | 31.92% |
| 2 | 108 | 9.74% |
| 3 | 11 | 0.99% |

Six stores were excluded from the combined analysis because they did not satisfy all data requirements.

These results describe the initial historical classification using the preliminary thresholds.

## 7. Historical Validation

Historical validation tested whether warning signals were associated with subsequent sales deterioration.

The initial indicators did not demonstrate a consistent ability to predict future absolute or peer-relative sales declines.

Therefore:

- Store Health classifications will be used for current performance monitoring.
- Warning levels will represent investigation priorities.
- Predictive sales forecasting will be developed separately using Machine Learning.
- The operational usefulness of the monitoring rules will require further assessment.

## 8. Methodological Limitations

- Warning thresholds were selected from historical distributions.
- Recent sales changes may be influenced by seasonality.
- Warning indicators are not statistically independent.
- Peer groups may differ in local market conditions.
- Low relative sales performance does not necessarily indicate deterioration.
- The initial Peer Performance Gap uses historical performance, while recent sales changes use shorter comparison periods.
- Historical backtesting must use only information available at each evaluation date.

## 9. Implementation Plan

The initial Store Health system will be implemented in Python.

The implementation should:

1. Load validated store performance data.
2. Calculate the three warning indicators.
3. Check minimum data requirements.
4. Generate individual warning flags.
5. Calculate total warning signals.
6. Assign preliminary Store Health classifications.
7. Provide explanations for activated alerts.
8. Export the results for dashboard integration.

## 10. Future Improvements

Potential future improvements include:

- Peer-adjusted recent sales changes.
- Seasonally adjusted performance monitoring.
- More detailed evaluation of warning severity.
- Historical calibration of thresholds.
- Monitoring classification stability over time.
- Integration of Machine Learning sales forecasts.

## 11. Conclusion

The initial Early Warning System provides an explainable framework for identifying and prioritising stores showing signs of underperformance.

Its primary purpose is to support store monitoring and investigation.

It should not be presented as a validated predictive risk model.
S