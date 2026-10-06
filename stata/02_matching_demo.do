*==============================================================================
* 02_matching_demo.do
*
* Live demonstration of propensity score matching (PSM) and inverse
* probability weighting (IPW) for the PhD seminar "Causal Identification with
* Observational Data," Florida State University.
*
* Question: Does adopting a seller's free B2B mobile app increase the buyer's
*           purchases? (Setting from Gill, Sridhar, and Grewal 2017, JM)
*
* Data:     app_adoption.dta, created by 01_simulate_app_data.do
*
* Key variables
*   app        = 1 if the buyer adopted the app (the treatment)
*   dsales     = change in 15-month sales, post minus pre, in $10,000 (outcome)
*   firm_size, buyer_power, competitiveness, t0_sales, t0_freq,
*   developing, division = pre-launch buyer characteristics (covariates)
*   tau_i      = the TRUE effect for each buyer (exists only because the data
*                are simulated; never available in real data)
*
* Run this file from the stata/ folder. It uses only official Stata commands
* (teffects, tebalance, teoverlap), available in Stata 14 and later.
*==============================================================================


*------------------------------------------------------------------------------
* STEP 0. LOAD THE DATA
*------------------------------------------------------------------------------

* Start with a clean slate
clear all

* Load the simulated buyer data (1,148 buyers)
use "app_adoption.dta", clear

* Look at the variables and their labels
describe

* How many buyers adopted the app? (522 adopters, 626 nonadopters)
tabulate app


*------------------------------------------------------------------------------
* STEP 1. THE TRUTH (only possible with simulated data)
*------------------------------------------------------------------------------

* True ATE: the average effect of the app across ALL buyers
summarize tau_i

* True ATT: the average effect of the app among buyers who ADOPTED
summarize tau_i if app == 1

* Write these down: ATE = 14.63, ATT = 15.85
* Every estimate below can be compared with these two numbers.


*------------------------------------------------------------------------------
* STEP 2. THE NAIVE COMPARISON
*------------------------------------------------------------------------------

* Average sales before, after, and the change, by adoption status
tabstat sales_pre sales_post dsales, by(app) statistics(mean) format(%9.2f)

* Naive estimate: difference in the average change in sales between
* adopters and nonadopters (equivalent to a simple DiD with no covariates)
regress dsales i.app, vce(robust)

* Save the result so we can compare it with other estimators at the end
estimates store naive

* Why is this biased? Adopters looked different BEFORE the launch.
* Compare pre-launch characteristics of adopters and nonadopters.
tabstat firm_size buyer_power competitiveness t0_sales t0_freq developing, ///
    by(app) statistics(mean) format(%9.2f)


*------------------------------------------------------------------------------
* STEP 3. PREPARE COVARIATES
*------------------------------------------------------------------------------

* Firm size, buyer power, T0 sales, and T0 frequency are right-skewed.
* Taking logs keeps a few very large buyers from dominating the logit.
generate ln_size  = ln(firm_size)
generate ln_power = ln(buyer_power)
generate ln_sales = ln(t0_sales)
generate ln_freq  = ln(t0_freq)

* Label the new variables so graphs and tables are readable
label variable ln_size  "Log buyer firm size"
label variable ln_power "Log buyer power"
label variable ln_sales "Log buyer T0 sales"
label variable ln_freq  "Log buyer T0 purchase frequency"


*------------------------------------------------------------------------------
* STEP 4. ESTIMATE THE PROPENSITY SCORE
*------------------------------------------------------------------------------

* Logit model of app adoption on pre-launch covariates.
* i. tells Stata to treat developing and division as categorical.
logit app ln_size ln_power competitiveness ln_sales ln_freq ///
    i.developing i.division

* Predicted probability of adoption = the propensity score
predict pscore, pr

* Compare the range of propensity scores for adopters and nonadopters
summarize pscore if app == 1
summarize pscore if app == 0

* Overlap plot: densities of the propensity score by group.
* We need nonadopters across the whole range where adopters lie.
twoway (kdensity pscore if app == 0, lcolor(gs8)) ///
       (kdensity pscore if app == 1, lcolor(cranberry)), ///
       legend(order(1 "Nonadopters" 2 "Adopters")) ///
       xtitle("Estimated propensity score") ytitle("Density") ///
       title("Overlap in the propensity score")

* Save the graph for the slides
graph export "../images/app_overlap.png", replace width(1600)


*------------------------------------------------------------------------------
* STEP 5. PROPENSITY SCORE MATCHING (PSM)
*------------------------------------------------------------------------------

* 5a. One nearest neighbor, ATT (option atet).
*     Each adopter is matched to the nonadopter with the closest propensity
*     score. teffects estimates the logit itself from the second parentheses.
*     Standard errors (Abadie and Imbens 2016) account for the estimated score.
teffects psmatch (dsales) ///
    (app ln_size ln_power competitiveness ln_sales ln_freq i.developing i.division), ///
    atet

* Save the result
estimates store psm1

* 5b. Check balance in the matched sample.
*     Standardized differences should be near 0 (rule of thumb: below 0.1).
*     Variance ratios should be near 1.
tebalance summarize

* Compare the full distribution of one covariate before and after matching
tebalance density ln_freq

* Save the graph for the slides
graph export "../images/app_balance_freq.png", replace width(1600)

* 5c. Three nearest neighbors: averages over more controls per adopter
*     (lower variance, possibly more bias)
teffects psmatch (dsales) ///
    (app ln_size ln_power competitiveness ln_sales ln_freq i.developing i.division), ///
    atet nneighbor(3)

* Save the result
estimates store psm3

* 5d. Caliper: only accept matches within 0.1 on the propensity score.
*     If an adopter has no match that close, teffects stops with an error;
*     adding osample(newvar) would flag those buyers.
teffects psmatch (dsales) ///
    (app ln_size ln_power competitiveness ln_sales ln_freq i.developing i.division), ///
    atet caliper(0.1)

* 5e. What if we had entered the covariates in levels instead of logs?
*     The estimate is similar, but check the variance ratios: firm size and
*     T0 frequency are far from 1. Balance on means is not enough.
teffects psmatch (dsales) ///
    (app firm_size buyer_power competitiveness t0_sales t0_freq i.developing i.division), ///
    atet
tebalance summarize


*------------------------------------------------------------------------------
* STEP 6. INVERSE PROBABILITY WEIGHTING (IPW)
*------------------------------------------------------------------------------

* 6a. Build the weights by hand to see what they are.

* ATE weights: 1/pscore for adopters, 1/(1 - pscore) for nonadopters
generate w_ate = 1/pscore if app == 1
replace  w_ate = 1/(1 - pscore) if app == 0

* ATT weights: 1 for adopters, pscore/(1 - pscore) for nonadopters
generate w_att = 1 if app == 1
replace  w_att = pscore/(1 - pscore) if app == 0

* Look for extreme weights (check the largest values)
summarize w_ate w_att, detail

* A weighted regression gives the IPW point estimate for the ATT.
* Its standard errors ignore that the propensity score was estimated,
* so use teffects (below) for inference.
regress dsales i.app [pweight = w_att], vce(robust)

* 6b. IPW with teffects, ATT
teffects ipw (dsales) ///
    (app ln_size ln_power competitiveness ln_sales ln_freq i.developing i.division), ///
    atet

* Save the result
estimates store ipw_att

* Balance in the weighted sample
tebalance summarize

* 6c. IPW with teffects, ATE (no atet option)
teffects ipw (dsales) ///
    (app ln_size ln_power competitiveness ln_sales ln_freq i.developing i.division)

* Save the result
estimates store ipw_ate

* Built-in overlap plot
teoverlap

* 6d. Trimming: drop buyers with propensity scores below 0.1 or above 0.9
*     (Crump et al. 2009). This changes the population the estimate describes.
teffects ipw (dsales) ///
    (app ln_size ln_power competitiveness ln_sales ln_freq i.developing i.division) ///
    if pscore >= 0.1 & pscore <= 0.9, atet


*------------------------------------------------------------------------------
* STEP 7. DOUBLY ROBUST ESTIMATORS
*         First parentheses: outcome model. Second parentheses: treatment model.
*         Consistent if EITHER model is correctly specified.
*------------------------------------------------------------------------------

* Regression adjustment alone (outcome model only), ATT, for comparison
teffects ra ///
    (dsales firm_size buyer_power competitiveness t0_sales t0_freq i.developing i.division) ///
    (app), atet

* Save the result
estimates store ra

* IPW plus regression adjustment (IPWRA), ATT
teffects ipwra ///
    (dsales firm_size buyer_power competitiveness t0_sales t0_freq i.developing i.division) ///
    (app ln_size ln_power competitiveness ln_sales ln_freq i.developing i.division), ///
    atet

* Save the result
estimates store ipwra

* Augmented IPW (AIPW), ATE
teffects aipw ///
    (dsales firm_size buyer_power competitiveness t0_sales t0_freq i.developing i.division) ///
    (app ln_size ln_power competitiveness ln_sales ln_freq i.developing i.division)

* Save the result
estimates store aipw


*------------------------------------------------------------------------------
* STEP 8. COMPARE ALL ESTIMATES
*------------------------------------------------------------------------------

* Side-by-side table of every stored estimate (estimate above, SE below).
* keep() shows only the treatment effect from each model.
* Naive: first block (regression coefficient on app).
* ATT estimators: ATET block. ATE estimators: ATE block.
estimates table naive ra psm1 psm3 ipw_att ipwra ipw_ate aipw, ///
    b(%9.2f) se(%9.2f) keep(1.app ATET: ATE:)

* Reminder of the truth: ATT = 15.85, ATE = 14.63
summarize tau_i if app == 1
summarize tau_i
