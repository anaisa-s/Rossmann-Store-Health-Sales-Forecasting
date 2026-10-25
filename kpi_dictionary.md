
# Rossmann Store Health — KPI Dictionary

## 1. Purpose

This document defines the Key Performance Indicators (KPIs) used in the Rossmann Store Health & Sales Forecasting Platform.

The KPIs support three objectives:
- Monitor store performance.
- Detect early signs of performance deterioration.
- Diagnose potential factors associated with underperformance.

## 2. Store Performance KPIs

### KPI 1 — Average Daily Sales
**Purpose:** Measure average revenue generated per operating day.

**Formula:** Total Sales / Number of Open Days

**Source:** Q1

**Usage:** Performance Monitoring

### KPI 2 — Average Daily Customers
**Purpose:** Measure average customer traffic per operating day.

**Formula:** Total Customers / Number of Open Days

**Source:** Q2

**Usage:** Performance Monitoring & Diagnosis

### KPI 3 — Sales per Customer
**Purpose:** Measure average revenue generated per customer visit.

**Formula:** Total Sales / Total Customers

**Source:** Q3

**Usage:** Performance Diagnosis

## 3. Store Health & Early Warning KPIs

### KPI 4 — Peer Performance Gap (%)
**Purpose:** Identify stores performing below comparable stores.

**Formula:**
(Store Average Daily Sales / Peer Average Daily Sales - 1) × 100

**Peer Groups:** Store Type + Assortment

**Source:** Q5

**Usage:** Early Warning Indicator

### KPI 5 — Recent Sales Change (%)
**Purpose:** Detect recent deterioration in store sales.

**Formula:**
(Recent 8-Week Average Daily Sales / Previous 8-Week Average Daily Sales - 1) × 100

**Source:** Q6

**Usage:** Early Warning Indicator

### KPI 6 — Consecutive Monthly Declines
**Purpose:** Detect sustained deterioration in sales performance.

**Method:** Identify three consecutive monthly decreases in average daily sales.

Only months with at least 15 operating days are considered.

**Source:** Q4

**Usage:** Early Warning Indicator

### KPI 7 — Sales Volatility (CV %)
**Purpose:** Measure instability in store performance.

**Formula:**
(Standard Deviation of Monthly Average Daily Sales / Mean Monthly Average Daily Sales) × 100

**Source:** Q7

**Usage:** Supporting Risk Indicator

## 4. Diagnostic KPIs

### KPI 8 — Customer Traffic Change (%)
**Purpose:** Identify whether declining sales are associated with changes in customer traffic.

**Formula:**
(Recent Average Daily Customers / Previous Average Daily Customers - 1) × 100

**Source:** Q6, Q8

**Usage:** Performance Diagnosis

### KPI 9 — Sales per Customer Change (%)
**Purpose:** Identify whether declining sales are associated with lower revenue per customer.

**Formula:**
(Recent Sales per Customer / Previous Sales per Customer - 1) × 100

**Source:** Q6, Q8

**Usage:** Performance Diagnosis

## 5. Calculation Guidelines

- Average daily metrics include only operating days.
- Recent performance comparisons use two consecutive eight-week periods.
- Peer groups are defined using Store Type and Assortment.
- Missing values and zero denominators must be handled.
- KPI definitions must remain consistent between Python and Power BI.
- The initial SQL benchmark includes the evaluated store in its peer average. Excluding it will be evaluated before implementing the alert system.
- Alert thresholds and minimum data requirements will be established and validated in the next stage.

## 6. Additional Contextual Indicators

The following indicators support investigations but are not primary health classification signals:

- Promotional Sales Uplift (Q9)
- Promotional Sales Concentration (Q10)
- Competition Distance and Competitor Opening (Q11)
- Store Type and Assortment (Q12)
- Seasonal Peer Performance Gap (Q13)

## 7. Next Steps

- Define early warning rules.
- Establish minimum data requirements.
- Validate thresholds using historical data.
- Implement Store Health detection in Python.
- Calculate dynamic dashboard KPIs using DAX.
