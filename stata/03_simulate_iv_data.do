*==============================================================================
* 03_simulate_iv_data.do
*
* Creates a simulated firm-year panel modeled on Shi, Grewal, and Sridhar
* (2021), "Organizational Herding in Advertising Spending Disclosures:
* Evidence and Mechanisms," Journal of Marketing Research, 58(3), 515-538.
*
* Setting: after a 1994 reporting rule, disclosing advertising spending became
* voluntary for U.S. firms. Do firms copy (herd on) their peers' disclosure
* decisions?
*
*   disclose    = 1 if the firm discloses advertising spending this year
*   peer_disc   = share of the firm's peers that disclose (ENDOGENOUS)
*
* Why is peer_disc endogenous? Firms and their peers face common shocks we do
* not observe (for example, a shift in how investors in their markets react to
* advertising disclosures). The shock pushes the firm and its peers in the
* same direction, so OLS mistakes a common shock for herding.
*
* Instruments (as in the paper): average characteristics of SECOND-DEGREE
* peers, the peers of the firm's peers who are not the firm's own peers.
* They shift peers' disclosure (relevance) but are unrelated to the firm's
* own shocks (exclusion).
*
* Because we create the data, the TRUE herding effect is known. Peer
* disclosure raises the probability of disclosing with a slope of 0.48 (the
* paper's 2SLS estimate is 0.483). Averaged over firm-years, including a few
* whose probability sits at 0, the true effect is stored in tau_i.
*
* Output: disclosure_panel.dta and disclosure_panel.csv, saved in this folder.
*==============================================================================


*------------------------------------------------------------------------------
* STEP 0. SET UP
*------------------------------------------------------------------------------

* Use Stata 19 rules so the random numbers are reproducible
version 19

* Start with an empty data set
clear all

* Fix the random-number seed so everyone gets the same data.
* Seed 3 was chosen after checking many seeds: across seeds 2SLS is centered
* on the truth, and this draw is a typical one (first-stage F near the
* paper's 29, 2SLS close to the truth).
set seed 3


*------------------------------------------------------------------------------
* STEP 1. CREATE 1,500 FIRMS, EACH OBSERVED FOR 10 YEARS (1995 to 2004)
*------------------------------------------------------------------------------

* One row per firm
set obs 1500

* Firm identifier: 1, 2, ..., 1500
generate int firm_id = _n

* Primary industry: 20 industries, assigned at random
generate byte industry = ceil(20*runiform())

* Persistent firm traits (they stay with the firm every year)
generate double size_firm  = rnormal(5.7, 1.9)      // log total assets
generate double big6_firm  = runiform() < 0.87      // uses a Big Six auditor
generate double sga_firm   = runiform() < 0.86      // reports SG&A
generate double rd_firm    = abs(rnormal(0, 0.4))   // R&D intensity

* Persistent traits of the firm's peers and second-degree peers.
* Second-degree peer traits are related to peer traits (peers of peers look
* somewhat like peers), but both are unrelated to the firm's own shocks.
generate double zsize2_firm = rnormal()
generate double zsga2_firm  = rnormal()
generate double zroa2_firm  = rnormal()
generate double zbig2_firm  = rnormal()

* Copy each firm 10 times, one row per year
expand 10

* Year: 1995, 1996, ..., 2004
bysort firm_id: generate int year = 1994 + _n


*------------------------------------------------------------------------------
* STEP 2. FIRM CHARACTERISTICS EACH YEAR (the paper's controls)
*------------------------------------------------------------------------------

* Firm size (log assets): persistent trait plus small year-to-year change
generate double size = size_firm + rnormal(0, 0.3)

* SG&A dummy: mostly persistent, occasionally switches
generate byte sga = sga_firm
replace sga = 1 - sga if runiform() < 0.03

* Return on assets: varies from year to year
generate double roa = rnormal(0.03, 0.15)

* R&D intensity
generate double rd = rd_firm + abs(rnormal(0, 0.1))

* Big Six auditor dummy: mostly persistent
generate byte big6 = big6_firm
replace big6 = 1 - big6 if runiform() < 0.02


*------------------------------------------------------------------------------
* STEP 3. PEER-GROUP AVERAGES (controls) AND SECOND-DEGREE PEER AVERAGES
*         (instruments)
*------------------------------------------------------------------------------

* Second-degree peer averages: persistent trait plus yearly noise,
* put on the scales reported in the paper
generate double size_2nd = 5.9  + 0.6*(zsize2_firm + 0.5*rnormal())
generate double sga_2nd  = 0.84 + 0.08*(zsga2_firm + 0.5*rnormal())
generate double roa_2nd  = 0.03 + 0.04*(zroa2_firm + 0.5*rnormal())
generate double big6_2nd = 0.87 + 0.05*(zbig2_firm + 0.5*rnormal())

* Peer-group averages: partly driven by second-degree peers, partly their own
generate double size_peer = 5.9  + 0.5*(size_2nd - 5.9)  + rnormal(0, 0.6)
generate double sga_peer  = 0.84 + 0.5*(sga_2nd - 0.84)  + rnormal(0, 0.10)
generate double roa_peer  = 0.03 + 0.5*(roa_2nd - 0.03)  + rnormal(0, 0.05)
generate double big6_peer = 0.87 + 0.5*(big6_2nd - 0.87) + rnormal(0, 0.05)


*------------------------------------------------------------------------------
* STEP 4. THE UNOBSERVED COMMON SHOCK
*------------------------------------------------------------------------------

* A shock shared by the firm and its peers in a given year (unobserved by
* the researcher). It raises both the firm's and its peers' disclosure.
generate double shock = rnormal(0, 0.06)


*------------------------------------------------------------------------------
* STEP 5. PEERS' DISCLOSURE (the endogenous variable)
*------------------------------------------------------------------------------

* Share of peers disclosing. Depends on:
*   - second-degree peer traits (instruments: they shape peers' choices;
*     ROA of second-degree peers matters very little, as in the paper)
*   - peer-group traits
*   - the common shock (this is what makes peer_disc endogenous)
*   - other noise
generate double peer_disc = 0.27 ///
    + 0.008*(size_2nd - 5.9)/0.6 ///
    + 0.010*(sga_2nd - 0.84)/0.08 ///
    + 0.001*(roa_2nd - 0.03)/0.04 ///
    + 0.012*(big6_2nd - 0.87)/0.05 ///
    + 0.010*(size_peer - 5.9) ///
    + 0.050*(sga_peer - 0.84) ///
    + 2.50*shock ///
    + rnormal(0, 0.08)

* A share must lie between 0 and 1
replace peer_disc = 0 if peer_disc < 0
replace peer_disc = 1 if peer_disc > 1


*------------------------------------------------------------------------------
* STEP 6. THE FIRM'S OWN DISCLOSURE DECISION (the outcome)
*------------------------------------------------------------------------------

* Probability of disclosing (a linear probability model, as in the paper).
* TRUE herding effect: 0.48. A 10-point rise in the share of peers
* disclosing raises the firm's probability of disclosing by 4.8 points.
generate double p_disclose = 0.27 ///
    + 0.48*(peer_disc - 0.27) ///
    + 0.010*(size - 5.7) ///
    + 0.100*(sga - 0.86) ///
    - 0.020*rd ///
    + 0.080*(big6 - 0.87) ///
    + 0.020*(size_peer - 5.9) ///
    + 0.060*(sga_peer - 0.84) ///
    + 1.20*shock

* Each firm-year's TRUE effect of peer disclosure. It is 0.48 wherever the
* probability lies between 0 and 1. For the few firm-years whose probability
* would fall below 0, it is held at 0, so peers cannot move them and their
* true effect is 0. The average of tau_i (about 0.46) is the benchmark for
* the estimates.
generate double tau_i = 0.48 if p_disclose > 0 & p_disclose < 1
replace tau_i = 0 if p_disclose <= 0 | p_disclose >= 1

* Keep the probability between 0 and 1
replace p_disclose = 0 if p_disclose < 0
replace p_disclose = 1 if p_disclose > 1

* Draw the disclosure decision: 1 with probability p_disclose
generate byte disclose = runiform() < p_disclose


*------------------------------------------------------------------------------
* STEP 7. A TEMPTING BUT INVALID INSTRUMENT (for teaching)
*------------------------------------------------------------------------------

* Industry advertising trend: shifts peers' disclosure, but it is also
* driven by the same unobserved common shock, so it violates the exclusion
* restriction. Used in the demo to show what a bad instrument does.
generate double ind_adtrend = 0.5*shock/0.06 + rnormal()


*------------------------------------------------------------------------------
* STEP 8. KEEP, LABEL, AND SAVE
*------------------------------------------------------------------------------

* Keep only what a researcher would observe (the shock and the true
* probability are dropped, as in real data)
keep firm_id year industry disclose peer_disc size sga roa rd big6 ///
     size_peer sga_peer roa_peer big6_peer ///
     size_2nd sga_2nd roa_2nd big6_2nd ind_adtrend tau_i

* Put the variables in a sensible order
order firm_id year industry disclose peer_disc size sga roa rd big6 ///
      size_peer sga_peer roa_peer big6_peer ///
      size_2nd sga_2nd roa_2nd big6_2nd ind_adtrend tau_i

* Describe each variable
label variable firm_id     "Firm identifier"
label variable year        "Fiscal year"
label variable industry    "Primary industry (1 to 20)"
label variable disclose    "Discloses advertising spending (1 = yes)"
label variable peer_disc   "Share of peers disclosing (endogenous)"
label variable size        "Firm size (log total assets)"
label variable sga         "Reports SG&A (1 = yes)"
label variable roa         "Return on assets"
label variable rd          "R&D intensity"
label variable big6        "Big Six auditor (1 = yes)"
label variable size_peer   "Peer average: size"
label variable sga_peer    "Peer average: SG&A dummy"
label variable roa_peer    "Peer average: ROA"
label variable big6_peer   "Peer average: Big Six auditor"
label variable size_2nd    "Second-degree peer average: size (instrument)"
label variable sga_2nd     "Second-degree peer average: SG&A dummy (instrument)"
label variable roa_2nd     "Second-degree peer average: ROA (instrument)"
label variable big6_2nd    "Second-degree peer average: Big Six (instrument)"
label variable ind_adtrend "Industry advertising trend (INVALID instrument)"
label variable tau_i       "TRUE effect of peer disclosure (simulation only)"

* Show three decimals for continuous variables
format peer_disc size roa rd size_peer sga_peer roa_peer big6_peer ///
       size_2nd sga_2nd roa_2nd big6_2nd ind_adtrend %9.3f

* Declare the panel structure (firm and year)
xtset firm_id year

* Store each variable in the smallest type that holds it
compress

* Save as a Stata file and as a CSV
save "disclosure_panel.dta", replace
export delimited using "disclosure_panel.csv", replace


*------------------------------------------------------------------------------
* STEP 9. CHECK THE DATA AGAINST THE PAPER
*------------------------------------------------------------------------------

* Paper (Table 2): disclosure mean .274, peer disclosure mean .273, SD .208
summarize disclose peer_disc size sga roa big6

* True average herding effect (the benchmark for every estimate)
summarize tau_i
