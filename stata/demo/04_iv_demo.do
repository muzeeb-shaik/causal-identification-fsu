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
* Data:     stata/data/disclosure_panel.dta, created by
*           stata/simulation/03_simulate_iv_data.do
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
* Run this file from the stata/demo/ folder. Official Stata commands only.
*==============================================================================


*------------------------------------------------------------------------------
* STEP 0. LOAD THE DATA
*------------------------------------------------------------------------------

* Start with a clean slate
clear all

* Load the simulated firm-year panel
use "../data/disclosure_panel.dta", clear

* Look at the variables and their labels
describe

* Tell Stata the data are a panel of firms over years
xtset firm_id year

* Summary statistics (compare with the paper's Table 2)
summarize disclose peer_disc size sga roa rd big6

* CONCLUSION
*   The simulated data look like the paper's: about a quarter of firm-years
*   disclose, and peer disclosure has the same average.
* BASED ON
*   Mean of disclose = 0.264 (paper 0.274); mean of peer_disc = 0.273
*   (paper 0.273); 15,000 firm-years.


*------------------------------------------------------------------------------
* STEP 1. THE TRUTH (only possible with simulated data)
*------------------------------------------------------------------------------

* True average herding effect. Write it down: about 0.46.
* Every estimate below can be compared with this number.
summarize tau_i

* CONCLUSION
*   The benchmark is 0.46: a 10-point rise in the share of peers disclosing
*   raises the probability that a firm discloses by about 4.6 points.
* BASED ON
*   Mean of tau_i = 0.459 (0.48 for most firm-years; 0 for the few whose
*   disclosure probability sits at zero).


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

* CONCLUSION
*   OLS finds a large, very precise "herding" effect, but it overstates the
*   truth by about 75%, because it mixes herding with the common shock.
* BASED ON
*   Coefficient on peer_disc = 0.813 (SE 0.020) versus the truth of 0.459.
*   The 95% interval (0.773 to 0.853) excludes the truth: precision does not
*   mean the estimate is right.


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

* CONCLUSION
*   The instruments are relevant: second-degree peers' traits move the share
*   of peers disclosing, and they are not weak by the usual rule of thumb.
* BASED ON
*   Joint F(4, 1499) = 32.26 (p < 0.001), above 10 (paper: F = 29.23).
*   Size (t = 5.45), SG&A (t = 6.04), and Big Six auditor (t = 8.32) are
*   significant; ROA is not (t = 0.13), the same pattern as the paper.
*   The instruments explain little of peer disclosure (R-squared = 0.019),
*   which is typical and is why IV estimates are imprecise.


*------------------------------------------------------------------------------
* STEP 4. REDUCED FORM: DO THE INSTRUMENTS MOVE THE OUTCOME?
*------------------------------------------------------------------------------

* Regress the outcome directly on the instruments plus controls.
* If the instruments affect disclosure only through peers, these effects
* are the first-stage effects scaled by the herding effect.
regress disclose size_2nd sga_2nd roa_2nd big6_2nd ///
    size sga roa rd big6 size_peer sga_peer roa_peer big6_peer ///
    i.industry i.year, vce(cluster firm_id)

* Joint test that the instruments have no effect on the outcome
test size_2nd sga_2nd roa_2nd big6_2nd

* CONCLUSION
*   The instruments' effect on disclosure is positive but noisy. Because
*   each effect equals the first-stage effect times the herding effect,
*   their ratios preview the 2SLS estimate. This joint test is also the
*   Anderson-Rubin test of "no herding," which remains valid even with weak
*   instruments, and it does not reject: the evidence for herding in this
*   sample is weaker than the 2SLS p-value in Step 6 suggests.
* BASED ON
*   Big Six: 0.112 / 0.222 = 0.50; SG&A: 0.028 / 0.095 = 0.29;
*   size: 0.0077 / 0.0119 = 0.65 (2SLS combines these into 0.478).
*   No reduced-form coefficient is significant on its own (p from 0.13 to
*   0.52), and jointly F(4, 1499) = 1.25 (p = 0.29).


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

* CONCLUSION
*   Running the two stages by hand gives the 2SLS point estimate, close to
*   the truth, but its standard error is not the correct one.
* BASED ON
*   Coefficient on peer_hat = 0.478 (by-hand SE 0.238, versus the correct
*   0.229 from ivregress in Step 6).


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

* CONCLUSION
*   2SLS removes the bias: the estimate is close to the truth and close to
*   the paper's 2SLS estimate, but it is about 11 times less precise than
*   OLS. The endogeneity test cannot distinguish OLS from 2SLS here.
* BASED ON
*   2SLS = 0.478 (SE 0.229, p = 0.037, 95% CI 0.030 to 0.927) versus the
*   truth of 0.459 and the paper's 0.483 (SE 0.186).
*   First-stage partial R-squared = 0.0085, F = 32.26.
*   Endogeneity test F(1, 1499) = 2.19, p = 0.139.


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

* CONCLUSION
*   GMM gives nearly the same estimate as 2SLS, and the four instruments
*   agree with one another.
* BASED ON
*   GMM = 0.482 (SE 0.228). Hansen's J = 1.03 with 3 degrees of freedom,
*   p = 0.79 (paper: J = 4.54, p > .10).


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

* CONCLUSION
*   With a weak instrument, 2SLS is useless: the estimate is far from the
*   truth and so imprecise that it is consistent with almost anything.
* BASED ON
*   Estimate = -41.81 (SE 814.25; 95% CI -1,638 to 1,554).
*   First-stage F(1, 1499) = 0.003 (p = 0.96), partial R-squared = 0.0000.


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

* CONCLUSION
*   An invalid instrument can be strong and still give an estimate as biased
*   as OLS, and the overidentification test may not catch it. Validity has
*   to be argued from the setting, not read off the diagnostics.
* BASED ON
*   Invalid IV alone = 0.885 (SE 0.051) versus the truth of 0.459 and OLS
*   of 0.813. Its first-stage F(1, 1499) = 3,054.86 (partial R-squared
*   0.163).
*   With all five instruments, GMM = 0.868 (SE 0.050), pulled toward the
*   invalid one, yet Hansen's J = 4.03 with 4 degrees of freedom, p = 0.40.


*------------------------------------------------------------------------------
* STEP 10. COMPARE ALL ESTIMATES
*------------------------------------------------------------------------------

* Side-by-side estimates of the herding effect (estimate above, SE below)
estimates table ols tsls gmm weak invalid, ///
    keep(peer_disc) b(%9.3f) se(%9.3f)

* Reminder of the truth
summarize tau_i

* OVERALL CONCLUSION
*   With valid, reasonably strong instruments, 2SLS and GMM recover the true
*   herding effect (about 0.48 versus 0.46), while OLS overstates it
*   (0.81). The price is precision (SE 0.23 versus 0.02), and weak-IV-robust
*   inference (Step 4) is less conclusive than the 2SLS t-test. Weak
*   instruments produce nonsense (-41.8), and an invalid instrument produces
*   a confident but wrong answer (0.885) that the diagnostics do not flag.
* BASED ON
*   The comparison table above: OLS 0.813, 2SLS 0.478, GMM 0.482,
*   weak -41.814, invalid 0.885; true effect 0.459.
