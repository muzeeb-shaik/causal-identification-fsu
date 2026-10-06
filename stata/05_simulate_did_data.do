*==============================================================================
* 05_simulate_did_data.do
*
* Creates a simulated quarterly panel for the difference-in-differences (DiD)
* appendix. The setting extends the B2B app example of Gill, Sridhar, and
* Grewal (2017, JM): instead of launching the app everywhere at once, the
* manufacturer rolls it out to its sales regions at different times
* (a staggered rollout).
*
*   1,148 buyers in 8 sales regions, observed for 12 quarters
*   Regions 1-2 get the app in quarter 5
*   Regions 3-4 get the app in quarter 7
*   Regions 5-6 get the app in quarter 9
*   Regions 7-8 do not get it during the 12 quarters (never treated)
*
* The rollout schedule is unrelated to buyers' sales, so parallel trends
* holds by construction. The effect of the app grows with time since rollout
* and is larger in early regions. This kind of heterogeneity is what makes
* the standard two-way fixed effects (TWFE) estimate misleading.
*
* The treatment is the app being AVAILABLE in the buyer's region, so the
* effect is an intent-to-treat effect of the rollout.
*
* Output: did_rollout.dta and did_rollout.csv, saved in this folder.
*==============================================================================


*------------------------------------------------------------------------------
* STEP 0. SET UP
*------------------------------------------------------------------------------

* Use Stata 19 rules so the random numbers are reproducible
version 19

* Start with an empty data set
clear all

* Fix the random-number seed so everyone gets the same data
set seed 2013


*------------------------------------------------------------------------------
* STEP 1. CREATE 1,148 BUYERS AND ASSIGN THEM TO 8 SALES REGIONS
*------------------------------------------------------------------------------

* One row per buyer
set obs 1148

* Buyer identifier: 1, 2, ..., 1148
generate int buyer_id = _n

* Sales region: 1 to 8, assigned at random
generate byte region = ceil(8*runiform())

* Quarter in which the app reaches the buyer's region (missing = never)
generate byte rollout_q = .
replace rollout_q = 5 if region == 1 | region == 2
replace rollout_q = 7 if region == 3 | region == 4
replace rollout_q = 9 if region == 5 | region == 6

* Buyer's typical quarterly sales ($10,000), a permanent buyer effect
generate double buyer_effect = rnormal(16, 5)


*------------------------------------------------------------------------------
* STEP 2. EXPAND TO A BUYER-QUARTER PANEL (12 quarters)
*------------------------------------------------------------------------------

* Copy each buyer 12 times, one row per quarter
expand 12

* Quarter: 1, 2, ..., 12
bysort buyer_id: generate byte quarter = _n


*------------------------------------------------------------------------------
* STEP 3. TREATMENT INDICATOR AND TIME SINCE ROLLOUT
*------------------------------------------------------------------------------

* app_live = 1 once the app is available in the buyer's region
generate byte app_live = 0
replace app_live = 1 if rollout_q < . & quarter >= rollout_q

* Quarters since rollout (0 = rollout quarter, negative = before);
* missing for never-treated regions
generate byte event_time = quarter - rollout_q if rollout_q < .


*------------------------------------------------------------------------------
* STEP 4. TRUE EFFECT OF THE APP
*------------------------------------------------------------------------------

* The effect grows by 0.5 each quarter after rollout (0.5 in the rollout
* quarter, 1.0 one quarter later, and so on), and is scaled up in early
* regions (whose buyers engage more) and down in later ones.
generate double tau_it = 0
replace tau_it = 1.5*0.5*(event_time + 1) if app_live == 1 & rollout_q == 5
replace tau_it = 1.0*0.5*(event_time + 1) if app_live == 1 & rollout_q == 7
replace tau_it = 0.7*0.5*(event_time + 1) if app_live == 1 & rollout_q == 9


*------------------------------------------------------------------------------
* STEP 5. QUARTERLY SALES
*------------------------------------------------------------------------------

* Sales = buyer effect + common upward trend + seasonality (fourth quarters
* are stronger) + effect of the app + noise
generate double sales = buyer_effect ///
    + 0.30*quarter ///
    + 1.0*(mod(quarter, 4) == 0) ///
    + tau_it ///
    + rnormal(0, 3)


*------------------------------------------------------------------------------
* STEP 6. KEEP, LABEL, AND SAVE
*------------------------------------------------------------------------------

* Keep the variables a researcher would see, plus the true effect
keep buyer_id region rollout_q quarter app_live event_time sales tau_it
order buyer_id region rollout_q quarter app_live event_time sales tau_it

* Describe each variable
label variable buyer_id   "Buyer firm identifier"
label variable region     "Sales region (1 to 8)"
label variable rollout_q  "Quarter the app reached the region (. = never)"
label variable quarter    "Quarter (1 to 12)"
label variable app_live   "App available in buyer's region (1 = yes)"
label variable event_time "Quarters since rollout"
label variable sales      "Quarterly sales ($10,000)"
label variable tau_it     "TRUE effect of the app (simulation only)"

* Show two decimals
format sales tau_it %9.2f

* Declare the panel structure (buyer and quarter)
xtset buyer_id quarter

* Store each variable in the smallest type that holds it
compress

* Save as a Stata file and as a CSV
save "did_rollout.dta", replace
export delimited using "did_rollout.csv", replace


*------------------------------------------------------------------------------
* STEP 7. CHECKS
*------------------------------------------------------------------------------

* Number of buyers by rollout quarter (one row per buyer)
tabulate rollout_q if quarter == 1, missing

* True ATT: average effect over treated buyer-quarters
summarize tau_it if app_live == 1
