
# Rossmann Store Health — Early Warning Analysis

## Q1. Peer Performance Gap Distribution

### Objective

Analyse the distribution of store performance relative to comparable stores to identify potential thresholds for the Early Warning System.

Stores are compared with peers sharing the same Store Type and Assortment. Each store is excluded from its own peer benchmark.

Only peer groups containing at least five stores are included.

### Findings

The analysis included **1,114 stores**, divided into 10 performance deciles based on their Peer Performance Gap (%).

- **Bottom 10% (112 stores):** Performance gaps ranged from -59.47% to -35.17%, with an average gap of -43.27%.
- **Bottom 20% (224 stores):** Performance gaps were -25.70% or lower.
- **Middle deciles:** Stores showed considerably smaller deviations from their peer benchmarks.
- **Top 10%:** Stores recorded an average positive performance gap of 70.40%.

The results reveal substantial differences in average daily sales between stores with similar characteristics.

### Interpretation

Stores in the lowest performance deciles generate significantly less revenue per operating day than comparable stores.

However, low relative performance does not necessarily indicate recent deterioration.

Some stores may consistently perform below their peer averages while maintaining stable sales.

Therefore, Peer Performance Gap should be combined with recent sales trends and sustained decline indicators before determining store health.

### Potential Early Warning Thresholds

Based on the observed distribution, two preliminary thresholds were identified:

| Indicator | Candidate Threshold | Interpretation |
|---|---|---|
| Low Relative Performance | ≤ -25.70% | Bottom 20% of stores |
| Very Low Relative Performance | ≤ -35.17% | Bottom 10% of stores |

**Important:** These thresholds are preliminary and must be validated before implementation.

### Further Investigation

1. Analyse the distribution of recent sales changes.
2. Identify stores showing both low relative performance and recent sales deterioration.
3. Investigate sustained monthly declines.
4. Validate potential thresholds using historical data.
5. Investigate why one store was excluded from the analysis.

### Conclusion

Peer Performance Gap is a useful indicator for identifying stores with low relative sales performance.

However, it should not independently determine whether a store is classified as *At Risk* or *Critical*.

The Early Warning System should combine relative performance with recent sales deterioration and persistent declining trends to provide more reliable alerts.


## Q2. Recent Sales Change Distribution

### Objective

Analyse changes in average daily sales between the latest eight weeks and the previous eight weeks to identify unusually large declines and assess potential early warning thresholds.

Only operating days are included. Stores must have at least 20 operating days in each comparison period.

### Findings

The analysis included **1,115 stores**, divided into 10 deciles according to their recent sales change (%).

- **Bottom 10% (112 stores):** Sales declines ranged from -34.80% to -10.59%, with an average decline of 12.85%.
- **Bottom 20% (224 stores):** Sales declined by at least 9.08%.
- **Deciles 1–9:** All 1,004 stores recorded negative sales changes.
- **Top 10% (111 stores):** Changes ranged from -2.59% to +38.33%, with an average increase of 2.61%.

The results indicate that declining sales are widespread across the store network.

### Interpretation

The widespread decline suggests that recent sales deterioration may be associated with factors affecting multiple stores simultaneously.

Potential explanations include seasonal patterns, promotional activity, and other common temporal factors.

Therefore, negative sales growth alone is insufficient to identify stores experiencing unusual deterioration.

Stores with large declines should be compared with similar stores over the same period to distinguish individual underperformance from network-wide trends.

### Potential Early Warning Thresholds

Two preliminary thresholds were identified from the observed distribution:

| Indicator | Candidate Threshold | Interpretation |
|---|---|---|
| Large Sales Decline | <= -9.08% | Bottom 20% of stores |
| Severe Sales Decline | <= -10.59% | Bottom 10% of stores |

These thresholds describe relative rankings within the current dataset.

They are not yet validated early warning thresholds and should not independently determine store health classifications.

### Further Investigation

1. Compare recent sales changes against stores with the same Store Type and Assortment over the same periods.
2. Investigate whether the widespread decline reflects seasonal or promotional patterns.
3. Analyse consecutive monthly sales declines.
4. Identify stores showing both low Peer Performance Gap and unusually large recent sales declines.
5. Validate candidate thresholds using historical periods.

### Conclusion

Recent Sales Change (%) is a relevant indicator for detecting sales deterioration.

However, the widespread negative trend suggests that absolute sales declines should not independently trigger high-severity alerts.

The Early Warning System should account for changes in peer group performance and combine recent deterioration with other indicators.


## Q3. Consecutive Monthly Declines

### Objective

Identify stores experiencing persistent monthly declines in average sales per operating day.

The analysis compares the latest four complete calendar months, requiring at least 15 operating days per month.

Stores are classified according to the number of consecutive monthly declines, from 0 to 3.

### Findings

The analysis included **1,110 stores**.

| Consecutive Declines | Stores | Percentage | Avg. 3-Month Change |
|---|---:|---:|---:|
| 0 | 304 | 27.39% | +0.57% |
| 1 | 464 | 41.80% | -5.88% |
| 2 | 184 | 16.58% | -5.00% |
| 3 | 158 | 14.23% | -7.85% |

Key findings:

- **806 stores (72.61%)** experienced at least one consecutive monthly decline.
- **342 stores (30.81%)** experienced at least two consecutive monthly declines.
- **158 stores (14.23%)** experienced three consecutive monthly declines.
- Stores with three consecutive declines recorded an average cumulative sales decrease of 7.85% over the three monthly intervals.
- Five stores were excluded because they did not meet the minimum data requirements.

### Interpretation

The results indicate that declining monthly sales are widespread across the Rossmann store network.

However, most stores experienced only one consecutive monthly decline.

The 158 stores with three consecutive declines demonstrate more persistent deterioration and may require closer monitoring.

Importantly, the number of consecutive declines does not necessarily reflect the magnitude of sales deterioration.

For example, stores with one consecutive decline recorded a larger average three-month sales decrease (-5.88%) than those with two consecutive declines (-5.00%).

This suggests that decline persistence and decline magnitude should be evaluated separately.

### Potential Early Warning Signal

**Three Consecutive Monthly Declines**

A store experiencing three consecutive decreases in average daily sales may be flagged for further investigation.

However, this signal should not independently determine a store's health classification.

The warning system should also consider:

- Peer Performance Gap (%)
- Recent Sales Change (%)
- Performance trends among comparable stores

The signal requires historical validation before implementation.

### Further Investigation

1. Identify stores with three consecutive monthly declines that also perform below their peer benchmarks.
2. Compare declining stores with similar stores over the same periods.
3. Investigate whether persistent declines are associated with seasonal patterns.
4. Evaluate the magnitude of sales deterioration alongside decline persistence.
5. Investigate the five stores excluded from the analysis.
6. Validate whether persistent declines are associated with subsequent sales deterioration.

### Conclusion

Consecutive Monthly Declines is a useful indicator of persistent sales deterioration.

The analysis identified 158 stores with three consecutive monthly declines, representing 14.23% of the analysed network.

However, widespread sales declines suggest that persistence alone is insufficient to identify stores experiencing unusual underperformance.

The Early Warning System should combine this indicator with peer-relative performance and recent sales changes.


## Q4. Combined Early Warning Signals

### Objective

Identify stores exhibiting multiple performance warning signals simultaneously.

The analysis combines three indicators:

1. Peer Performance Gap <= -25.70%
2. Recent Sales Change <= -9.08%
3. Three Consecutive Monthly Declines

These thresholds are preliminary and require historical validation.

### Findings

The analysis included **1,109 stores** with sufficient data to calculate all three indicators.

| Warning Signals | Store Count | Percentage |
|---|---:|---:|
| 0 | 636 | 57.35% |
| 1 | 354 | 31.92% |
| 2 | 108 | 9.74% |
| 3 | 11 | 0.99% |
| **Total** | **1,109** | **100%** |

Key findings:

- **636 stores (57.35%)** did not trigger any of the three warning signals.
- **354 stores (31.92%)** triggered one warning signal.
- **108 stores (9.74%)** triggered two warning signals.
- **11 stores (0.99%)** triggered all three warning signals.
- **119 stores (10.73%)** triggered at least two warning signals.

Among stores with exactly two warning signals:

- 42 showed recent sales deterioration and persistent monthly declines.
- 42 showed low peer-relative performance and recent sales deterioration.
- 24 showed low peer-relative performance and persistent monthly declines.

### Interpretation

The results demonstrate that combining performance indicators provides a more selective approach to identifying stores requiring investigation.

While individual indicators identified relatively large groups of stores, only 11 stores exhibited all three warning signals simultaneously.

These stores show:

- Substantially lower sales than comparable stores.
- Large recent sales declines.
- Persistent monthly deterioration.

This combination may indicate a more concerning performance pattern than any individual signal alone.

However, the presence of multiple signals does not establish that a store will continue to deteriorate.

Furthermore, the indicators overlap and should not be treated as independent evidence.

### Potential Early Warning Framework

The number of simultaneous warning signals may provide an initial framework for prioritising store investigations.

| Warning Signals | Preliminary Interpretation |
|---|---|
| 0 | No current warning signals |
| 1 | Monitoring recommended |
| 2 | Further investigation recommended |
| 3 | High-priority investigation candidate |

These categories are exploratory and do not represent validated Store Health classifications.

### Limitations

- Thresholds were selected from the current historical distribution.
- Peer Performance Gap was calculated using the full available history, while recent sales changes use two eight-week periods.
- Widespread sales declines may reflect common seasonal or network-wide effects.
- Six stores were excluded because they did not meet all data requirements.
- The analysis does not establish whether warning signals predict future deterioration.

### Further Investigation

1. Identify the 11 stores exhibiting all three warning signals.
2. Compare their sales trends against similar stores.
3. Investigate the factors associated with their deterioration.
4. Evaluate whether peer-adjusted recent sales changes improve warning detection.
5. Test the warning signals using historical evaluation periods.
6. Assess whether multiple signals are associated with subsequent sales deterioration.

### Conclusion

Combining Peer Performance Gap, Recent Sales Change, and Consecutive Monthly Declines provides a structured approach to identifying stores requiring closer monitoring.

The analysis identified **119 stores with at least two warning signals**, including **11 stores exhibiting all three**.

These results support the development of a preliminary Early Warning System.

However, historical validation is necessary before assigning definitive Store Health classifications or implementing operational alerts.


## Q5. Historical Validation of Early Warning Signals

### Objective

Evaluate whether historical warning signals are associated with subsequent sales deterioration.

The analysis uses three historical evaluation dates:

- September 30, 2014
- December 31, 2014
- March 31, 2015

Warning signals are calculated using information available up to each evaluation date.

Future sales performance is measured over the following eight weeks and compared with the preceding eight weeks.

A future sales decline of at least 10% is used as the preliminary evaluation outcome.

### Findings

The analysis produced **2,790 store-date evaluations**.

| Warning Signals | Evaluations | Avg. Future Sales Change | Future Decline Rate |
|---|---:|---:|---:|
| 0 | 1,585 | -3.54% | 40.57% |
| 1 | 1,024 | +4.22% | 14.94% |
| 2 | 172 | +8.51% | 0.58% |
| 3 | 9 | +7.98% | 0.00% |

Key findings:

- Stores with no warning signals recorded the highest subsequent deterioration rate (40.57%).
- Stores with one warning signal had a substantially lower future deterioration rate (14.94%).
- Stores with two warning signals recorded an average future sales increase of 8.51%.
- Only one evaluation with two warning signals was followed by a sales decline of at least 10%.
- Stores with three warning signals recorded positive average future sales growth, although this group contained only nine evaluations.

### Interpretation

The results do not support the initial hypothesis that a higher number of warning signals is associated with a higher probability of subsequent sales deterioration.

Instead, evaluations with more warning signals generally experienced stronger subsequent sales recovery.

Possible explanations include:

- Seasonal sales patterns.
- Mean reversion following unusually weak performance.
- Differences in promotional activity across evaluation periods.
- Misalignment between current underperformance indicators and the selected future deterioration outcome.

These explanations require further investigation.

Importantly, the warning signals may still be useful for identifying stores experiencing current performance problems.

However, identifying current underperformance is different from predicting future deterioration.

### Limitations

- Only three historical evaluation dates were tested.
- The three-signal category contains just nine evaluations.
- The same store may appear in multiple evaluations.
- The 10% future decline threshold is preliminary.
- Future sales changes are not adjusted for peer-group trends or seasonal effects.
- The warning thresholds were selected using the overall historical distribution, rather than an independent training period.
- The analysis does not establish the operational usefulness of the current warning classification.

### Further Investigation

1. Analyse validation results separately for each evaluation date.
2. Investigate seasonal patterns and potential mean reversion.
3. Compare future store performance with future peer-group performance.
4. Evaluate the three warning indicators individually.
5. Test additional historical evaluation periods.
6. Reconsider the definition of the future deterioration outcome.
7. Evaluate whether alternative warning rules improve performance.

### Conclusion

The initial Early Warning System successfully identifies stores experiencing multiple historical performance warning signals.

However, historical validation did not demonstrate that a higher number of signals predicts a greater probability of subsequent sales deterioration.

The results suggest that the current indicators are more appropriate for monitoring existing underperformance than for independently predicting future sales declines.

Further analysis is required before establishing final Store Health classifications or predictive warning rules.


## Q5A. Historical Validation by Evaluation Date

### Objective

Investigate whether the relationship between warning signals and subsequent sales deterioration differs across historical evaluation periods.

The analysis evaluates three dates:

- September 30, 2014
- December 31, 2014
- March 31, 2015

### Findings

The analysis produced **2,790 store-date evaluations** across three historical periods.

| Evaluation Date | Warning Signals | Evaluations | Avg. Future Change | Future Decline Rate |
|---|---:|---:|---:|---:|
| 2014-09-30 | 0 | 573 | +5.56% | 2.27% |
| 2014-09-30 | 1 | 285 | +6.62% | 1.75% |
| 2014-09-30 | 2 | 64 | +8.45% | 0.00% |
| 2014-09-30 | 3 | 5 | +10.18% | 0.00% |
| 2014-12-31 | 0 | 744 | -14.74% | 84.41% |
| 2014-12-31 | 1 | 186 | -14.22% | 79.03% |
| 2014-12-31 | 2 | 1 | -25.71% | 100.00% |
| 2015-03-31 | 0 | 268 | +8.09% | 0.75% |
| 2015-03-31 | 1 | 553 | +9.19% | 0.18% |
| 2015-03-31 | 2 | 107 | +8.86% | 0.00% |
| 2015-03-31 | 3 | 4 | +5.23% | 0.00% |

### Interpretation

The results reveal substantial differences in future sales performance across evaluation periods.

September 2014 and March 2015 were followed by generally positive sales growth and very low deterioration rates.

In contrast, December 2014 was followed by widespread sales declines across nearly all warning-signal categories.

This suggests that temporal factors, particularly seasonality, may have a stronger influence on the selected future deterioration outcome than the initial warning signals.

The December results are consistent with a potential post-holiday sales slowdown, although further analysis is needed to confirm this explanation.

Within individual evaluation periods, a higher number of warning signals was not consistently associated with higher future deterioration rates.

### Implications for the Early Warning System

The current warning indicators are useful for identifying historical underperformance and recent sales deterioration.

However, they have not demonstrated reliable predictive value for future absolute sales declines.

The Early Warning System should distinguish between:

1. Current store underperformance.
2. Deterioration relative to comparable stores.
3. Future sales deterioration.

These objectives require different evaluation criteria.

### Limitations

- Only three historical evaluation dates were tested.
- Some warning-signal categories contain very few observations.
- Future sales changes were not adjusted for seasonality.
- Future performance was not compared with peer-group trends.
- Preliminary thresholds were selected using the full historical distribution.
- Multiple evaluations may correspond to the same store.

### Conclusion

Historical validation revealed that future sales deterioration rates varied considerably across evaluation periods.

The results suggest that seasonality and other common temporal factors may substantially influence the evaluation outcome.

The initial warning signals did not demonstrate a consistent positive relationship with subsequent sales deterioration.

Therefore, the initial rules should not yet be used as validated predictive risk indicators.


## Q6. Peer-Adjusted Future Sales Performance

### Objective

Evaluate whether historical warning signals can identify stores that subsequently underperform comparable stores.

Future sales changes are compared with peer-group sales changes over the same eight-week period.

Peer groups are defined by Store Type and Assortment, excluding the evaluated store.

A future performance gap of -10 percentage points or lower is used as the preliminary deterioration outcome.

### Findings

The analysis included 2,790 store-date evaluations across three historical evaluation dates.

Only 70 evaluations (2.51%) were followed by relative sales deterioration of at least 10 percentage points.

| Evaluation Date | 0 Signals | 1 Signal | 2 Signals | 3 Signals |
|---|---:|---:|---:|---:|
| 2014-09-30 | 4.19% | 3.16% | 1.56% | 0.00% |
| 2014-12-31 | 2.82% | 1.61% | 0.00% | N/A |
| 2015-03-31 | 2.24% | 0.72% | 0.93% | 25.00% |

The percentages represent future relative deterioration rates.

Key findings:

- Peer adjustment substantially changes the interpretation of future sales declines.
- In December 2014, stores with zero warning signals recorded an average sales decrease of 14.74%, while their peers declined by approximately 14.79%.
- Despite substantial absolute sales declines, most stores did not experience severe deterioration relative to their peers.
- Stores with more warning signals did not consistently exhibit higher future relative deterioration rates.
- The 25% deterioration rate among stores with three signals in March 2015 represents only one out of four evaluations.

### Interpretation

The results demonstrate the importance of distinguishing absolute sales declines from deterioration relative to comparable stores.

A store experiencing declining sales may still be performing in line with, or better than, its peers.

Peer-adjusted evaluation helps reduce the influence of common temporal factors, although it does not eliminate all seasonal or operational differences.

However, the current warning signals did not demonstrate a consistent positive relationship with subsequent peer-relative sales deterioration.

### Implications for Store Health

The three indicators remain relevant for monitoring current store performance:

1. Peer Performance Gap identifies low relative sales performance.
2. Recent Sales Change identifies recent deterioration.
3. Consecutive Monthly Declines identifies persistent negative trends.

However, these indicators should not be presented as validated predictors of future deterioration.

The platform should distinguish between current performance monitoring and predictive sales forecasting.

### Limitations

- Only three historical evaluation dates were analysed.
- Some warning-signal categories contain very small samples.
- The -10 percentage point deterioration threshold is exploratory.
- Peer groups are based only on Store Type and Assortment.
- Historical alert thresholds were not calibrated using independent training periods.
- Peer adjustment does not fully control for differences in local conditions or promotional activity.
- Predictive performance has not been established.

### Conclusion

Peer-adjusted evaluation provides a more meaningful assessment of store-specific deterioration than absolute sales changes alone.

However, the initial warning signals did not demonstrate reliable predictive value for future relative deterioration.

The findings support using the indicators primarily for Store Health Monitoring, while developing and evaluating Sales Forecasting separately through Machine Learning.

### Next Step

Define the initial operational Store Health classifications and implement a transparent, rule-based monitoring system.

Validate the classifications as prioritisation tools rather than as established predictions of future sales deterioration.


