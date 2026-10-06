*==============================================================================
* 04_iv_demo.do
*
* Live demonstration of instrumental variables (IV) for the PhD seminar
* "Causal Identification with Observational Data," Florida State University.
*
* Question: Do firms herd on their peers when deciding whether to disclose
*           advertising spending? (Setting from Shi, Grewal, and Sridhar
*           2021, JMR)
*
* Data:     disclosure_panel.dta, created by 03_simulate_iv_data.do
*           1,500 firms x 10 years = 15,000 firm-years
*
* Key variables
*   disclose   = 1 if the firm discloses advertising spending (outcome)
*   peer_disc  = share of the firm's peers that disclose (endogenous)
*   size_2nd, sga_2nd, roa_2nd, big6_2nd
*              = average traits of second-degree peers (instruments)
*   size, sga, roa, rd, big6
*              = the firm's own traits (controls)
*   size_peer, sga_peer, roa_peer, big6_peer
*              = average traits of the firm's peers (controls)
*   ind_adtrend = industry advertising trend (an INVALID instrument)
*   tau_i      = the TRUE effect (exists only because the data are simulated)
*
* Model: linear probability model with industry and year fixed effects,
* standard errors clustered by firm. (The paper uses industry x year fixed
* effects; industry and year effects keep the demo fast.)
*
* Run this file from the stata/ folder. Official Stata commands only.
*==============================================================================


*------------------------------------------------------------------------------
* STEP 0. LOAD THE DATA
*------------------------------------------------------------------------------

* Start with a clean slate
clear all

* Load the simulated firm-year panel
use "disclosure_panel.dta", clear

* Look at the variables and their labels
describe

* Tell Stata the data are a panel of firms over years
xtset firm_id year

* Summary statistics (compare with the paper's Table 2)
summarize disclose peer_disc size sga roa rd big6


*------------------------------------------------------------------------------
* STEP 1. THE TRUTH (only possible with simulated data)
*------------------------------------------------------------------------------

* True average herding effect. Write it down: about 0.46.
* Every estimate below can be compared with this number.
summarize tau_i


*------------------------------------------------------------------------------
* STEP 2. OLS: THE NAIVE ESTIMATE
*------------------------------------------------------------------------------

* Regress the firm's disclosure on the share of peers disclosing, with the
* firm's own traits, its peers' average traits, and industry and year
* fixed effects. Cluster standard errors by firm.
regress disclose peer_disc ///
    size sga roa rd big6 size_peer sga_peer roa_peer big6_peer ///
    i.industry i.year, vce(cluster firm_id)

* Save the result for the comparison at the end
estimates store ols

* Why is OLS biased? The firm and its peers share unobserved shocks. A shock
* that makes peers disclose also makes the firm disclose, so OLS credits the
* shock to herding. The estimate is too large.


*------------------------------------------------------------------------------
* STEP 3. FIRST STAGE: DO THE INSTRUMENTS MOVE PEER DISCLOSURE? (relevance)
*------------------------------------------------------------------------------

* Regress the endogenous variable on the instruments plus all controls
regress peer_disc size_2nd sga_2nd roa_2nd big6_2nd ///
    size sga roa rd big6 size_peer sga_peer roa_peer big6_peer ///
    i.industry i.year, vce(cluster firm_id)

* Joint test that the four instruments are all zero.
* This F statistic is the first-stage F. Rule of thumb: above 10.
* (Paper: F = 29.23, with three of four instruments significant; ROA of
* second-degree peers is not, here or in the paper.)
test size_2nd sga_2nd roa_2nd big6_2nd

* Save the predicted share of peers disclosing (the first-stage fitted value)
predict peer_hat, xb


*------------------------------------------------------------------------------
* STEP 4. REDUCED FORM: DO THE INSTRUMENTS MOVE THE OUTCOME?
*------------------------------------------------------------------------------

* Regress the outcome directly on the instruments plus controls.
* If the instruments affect disclosure only through peers, these effects
* are the first-stage effects scaled by the herding effect.
regress disclose size_2nd sga_2nd roa_2nd big6_2nd ///
    size sga roa rd big6 size_peer sga_peer roa_peer big6_peer ///
    i.industry i.year, vce(cluster firm_id)


*------------------------------------------------------------------------------
* STEP 5. TWO-STAGE LEAST SQUARES BY HAND (to see the idea)
*------------------------------------------------------------------------------

* Second stage: replace peer_disc with its fitted value from the first stage.
* The coefficient on peer_hat is the 2SLS estimate.
* WARNING: the standard errors here are wrong, because they ignore that
* peer_hat was estimated. Use ivregress (next step) for inference.
regress disclose peer_hat ///
    size sga roa rd big6 size_peer sga_peer roa_peer big6_peer ///
    i.industry i.year, vce(cluster firm_id)


*------------------------------------------------------------------------------
* STEP 6. TWO-STAGE LEAST SQUARES WITH ivregress
*------------------------------------------------------------------------------

* Syntax: ivregress 2sls outcome (endogenous = instruments) controls
ivregress 2sls disclose ///
    (peer_disc = size_2nd sga_2nd roa_2nd big6_2nd) ///
    size sga roa rd big6 size_peer sga_peer roa_peer big6_peer ///
    i.industry i.year, vce(cluster firm_id)

* Save the result
estimates store tsls

* First-stage diagnostics: partial R-squared and the first-stage F
estat firststage

* Test whether peer_disc is endogenous (does IV differ from OLS?).
* Here p is about 0.14: OLS (0.81) and 2SLS (0.48) differ a lot, but the
* 2SLS standard error (0.23) is too large for the test to tell them apart.
* Failing to reject is not evidence that OLS is fine.
estat endogenous


*------------------------------------------------------------------------------
* STEP 7. OVERIDENTIFICATION TEST (four instruments, one endogenous variable)
*------------------------------------------------------------------------------

* Re-estimate by GMM to obtain Hansen's J statistic, as in the paper
ivregress gmm disclose ///
    (peer_disc = size_2nd sga_2nd roa_2nd big6_2nd) ///
    size sga roa rd big6 size_peer sga_peer roa_peer big6_peer ///
    i.industry i.year, vce(cluster firm_id)

* Save the result
estimates store gmm

* Hansen's J. A large p-value means the instruments agree with each other.
* It cannot prove they are valid: if all are invalid in the same way, or if
* the instruments are imprecise, the test will not notice (see Step 9).
* (Paper: J = 4.54, p > .10.)
estat overid


*------------------------------------------------------------------------------
* STEP 8. WHAT A WEAK INSTRUMENT DOES
*------------------------------------------------------------------------------

* Use only the ROA of second-degree peers, which barely moves peer
* disclosure (it was insignificant in the paper's first stage, too)
ivregress 2sls disclose ///
    (peer_disc = roa_2nd) ///
    size sga roa rd big6 size_peer sga_peer roa_peer big6_peer ///
    i.industry i.year, vce(cluster firm_id)

* Save the result
estimates store weak

* The first-stage F is close to 0: the estimate (about -42, with a standard
* error over 800) is meaningless
estat firststage


*------------------------------------------------------------------------------
* STEP 9. WHAT AN INVALID INSTRUMENT DOES
*------------------------------------------------------------------------------

* The industry advertising trend moves peer disclosure (it is relevant), but
* it is driven by the same unobserved shock (it violates exclusion)
ivregress 2sls disclose ///
    (peer_disc = ind_adtrend) ///
    size sga roa rd big6 size_peer sga_peer roa_peer big6_peer ///
    i.industry i.year, vce(cluster firm_id)

* Save the result
estimates store invalid

* Its first stage is very strong (F above 3,000), so the F statistic gives
* no warning. Relevance says nothing about exclusion.
estat firststage

* Add it to the four valid instruments and run the overidentification test.
* Hansen's J does NOT reject (p is about 0.40), even though one instrument is
* invalid: the valid instruments are too imprecise for the test to detect
* the disagreement. A passed J test is weak evidence of validity.
ivregress gmm disclose ///
    (peer_disc = size_2nd sga_2nd roa_2nd big6_2nd ind_adtrend) ///
    size sga roa rd big6 size_peer sga_peer roa_peer big6_peer ///
    i.industry i.year, vce(cluster firm_id)
estat overid


*------------------------------------------------------------------------------
* STEP 10. COMPARE ALL ESTIMATES
*------------------------------------------------------------------------------

* Side-by-side estimates of the herding effect (estimate above, SE below)
estimates table ols tsls gmm weak invalid, ///
    keep(peer_disc) b(%9.3f) se(%9.3f)

* Reminder of the truth
summarize tau_i
