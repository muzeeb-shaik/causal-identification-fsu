*==============================================================================
* 06_did_demo.do
*
* Self-study demonstration of difference-in-differences (DiD) for the
* appendix of "Causal Identification with Observational Data," PhD Seminar,
* Florida State University.
*
* Part A: two-period DiD on the app adoption data (app_adoption.dta, from
*         01_simulate_app_data.do), as in Equation 1 of Gill, Sridhar, and
*         Grewal (2017, JM)
* Part B: staggered rollout of the app across sales regions
*         (did_rollout.dta, from 05_simulate_did_data.do)
*
* Run this file from the stata/ folder. Official Stata commands only;
* xtdidregress needs Stata 17 or later; estat bdecomp and xthdidregress
* need Stata 18 or later.
*==============================================================================


*==============================================================================
* PART A. TWO-PERIOD DiD: DID THE APP RAISE SALES?
*==============================================================================

*------------------------------------------------------------------------------
* STEP A1. LOAD THE APP DATA AND RESHAPE TO TWO ROWS PER BUYER
*------------------------------------------------------------------------------

* Start with a clean slate
clear all

* Load the buyer data: one row per buyer, with pre and post sales
use "app_adoption.dta", clear

* Rename the sales variables so reshape can stack them:
* sales0 = 15 months before launch, sales1 = 15 months after
rename sales_pre  sales0
rename sales_post sales1

* Reshape to two rows per buyer (post = 0 before launch, post = 1 after)
reshape long sales, i(buyer_id) j(post)

* Label the new time indicator
label variable post "After the app launch (1 = yes)"


*------------------------------------------------------------------------------
* STEP A2. THE FOUR MEANS BEHIND DiD
*------------------------------------------------------------------------------

* Average sales by group (adopter or not) and period (before or after)
table app post, statistic(mean sales) nformat(%9.2f)

* DiD = (adopters after - adopters before) - (nonadopters after - nonadopters before)


*------------------------------------------------------------------------------
* STEP A3. DiD AS A REGRESSION (Gill et al. 2017, Equation 1)
*------------------------------------------------------------------------------

* sales = b0 + b1 app + b2 post + b3 app x post + error
* b3 (the app#post coefficient) is the DiD estimate.
* Standard errors are clustered by buyer (two rows per buyer).
regress sales i.app##i.post, vce(cluster buyer_id)

* The same estimate with Stata's built-in DiD command.
* First declare the panel, then build the treated-and-after indicator.
xtset buyer_id post
generate treat_post = app*post
xtdidregress (sales) (treat_post), group(buyer_id) time(post) vce(cluster buyer_id)

* The estimate (25.08) equals the naive comparison from the matching demo.
* The true effect is 15.85. DiD assumes adopters and nonadopters would have
* followed parallel trends without the app, but frequent buyers grow faster
* anyway, so parallel trends fails here.


*------------------------------------------------------------------------------
* STEP A4. ADDING COVARIATES: LEVELS DO NOT HELP, INTERACTIONS DO
*------------------------------------------------------------------------------

* Adding time-invariant covariates in levels leaves b3 unchanged, because
* they are the same before and after for each buyer.
* (Gill et al. report the same 16.01 with and without covariates.)
regress sales i.app##i.post ///
    firm_size buyer_power competitiveness t0_sales t0_freq ///
    i.developing i.division, vce(cluster buyer_id)

* Conditional parallel trends: let the trend (post) differ with each
* covariate by interacting the covariates with post.
* The estimate drops to about 15, close to the truth.
regress sales i.app##i.post ///
    i.post##c.firm_size i.post##c.buyer_power i.post##c.competitiveness ///
    i.post##c.t0_sales i.post##c.t0_freq ///
    i.post##i.developing i.post##i.division, vce(cluster buyer_id)

* This is the same idea as matching or weighting on the change in sales,
* which is what the matching section of the seminar did.


*==============================================================================
* PART B. STAGGERED ROLLOUT: EVENT STUDIES AND THE TWFE PROBLEM
*==============================================================================

*------------------------------------------------------------------------------
* STEP B1. LOAD THE ROLLOUT PANEL
*------------------------------------------------------------------------------

* Start with a clean slate
clear all

* Load the buyer-quarter panel (1,148 buyers x 12 quarters)
use "did_rollout.dta", clear

* Declare the panel: buyers observed over quarters
xtset buyer_id quarter

* How many buyers got the app in each quarter (one row per buyer)
tabulate rollout_q if quarter == 1, missing

* True ATT (simulation only): average effect over treated buyer-quarters.
* Write it down: 2.31.
summarize tau_it if app_live == 1


*------------------------------------------------------------------------------
* STEP B2. PLOT AVERAGE SALES BY ROLLOUT GROUP
*------------------------------------------------------------------------------

* Average sales in each quarter for each rollout group
* (rollout_q missing = never treated)
preserve
collapse (mean) sales, by(rollout_q quarter)

* One line per rollout group, with dashed lines at each rollout quarter
twoway (connected sales quarter if rollout_q == 5, lcolor(cranberry) mcolor(cranberry)) ///
       (connected sales quarter if rollout_q == 7, lcolor(orange) mcolor(orange)) ///
       (connected sales quarter if rollout_q == 9, lcolor(navy) mcolor(navy)) ///
       (connected sales quarter if rollout_q == ., lcolor(gs8) mcolor(gs8)), ///
       xline(5 7 9, lpattern(dash) lcolor(gs10)) ///
       legend(order(1 "App in Q5" 2 "App in Q7" 3 "App in Q9" 4 "Never") rows(1) position(6)) ///
       xtitle("Quarter") ytitle("Average quarterly sales ($10,000)") ylabel(, format(%9.0f)) ///
       xlabel(1(1)12) title("Staggered rollout of the app")

* Save the graph for the slides
graph export "../images/did_rollout_means.png", replace width(1600)
restore


*------------------------------------------------------------------------------
* STEP B3. STANDARD TWO-WAY FIXED EFFECTS (TWFE)
*------------------------------------------------------------------------------

* TWFE regression: buyer fixed effects, quarter fixed effects, and the
* treatment indicator. xtdidregress does this and reports the ATET.
xtdidregress (sales) (app_live), group(buyer_id) time(quarter) vce(cluster buyer_id)

* Save the result
estimates store twfe

* The TWFE estimate (about 1.1) is less than half the true ATT (2.31).


*------------------------------------------------------------------------------
* STEP B4. WHY TWFE FAILS: GOODMAN-BACON DECOMPOSITION
*------------------------------------------------------------------------------

* Break the TWFE estimate into all its 2x2 comparisons and their weights.
* "Treated later vs earlier" uses already-treated regions as controls; their
* growing effects are subtracted off, producing negative components.
estat bdecomp

* Same decomposition as a graph
estat bdecomp, graph

* Save the graph for the slides
graph export "../images/did_bdecomp.png", replace width(1600)


*------------------------------------------------------------------------------
* STEP B5. HETEROGENEITY-ROBUST DiD (Callaway and Sant'Anna 2021)
*------------------------------------------------------------------------------

* Estimate a separate ATET for each rollout cohort and quarter, comparing
* each cohort only with never-treated buyers. aipw = doubly robust version.
xthdidregress aipw (sales) (app_live), group(buyer_id)

* Overall ATET: average of the cohort-quarter effects (compare with 2.31)
estat aggregation

* Event study: effects by quarters since rollout. Leads (negative values)
* near zero support parallel trends; lags show the effect growing.
estat aggregation, dynamic graph

* Save the graph for the slides
graph export "../images/did_event_study.png", replace width(1600)

* Effects by rollout cohort (early regions gain more)
estat aggregation, cohort


*------------------------------------------------------------------------------
* STEP B6. OTHER ESTIMATORS IN THE SAME COMMAND
*------------------------------------------------------------------------------

* Regression adjustment version of Callaway and Sant'Anna
xthdidregress ra (sales) (app_live), group(buyer_id)
estat aggregation

* Extended TWFE (Wooldridge): TWFE with cohort-by-time interactions,
* which allows effects to differ by cohort and time
xthdidregress twfe (sales) (app_live), group(buyer_id)
estat aggregation

* Reminder of the truth
summarize tau_it if app_live == 1
