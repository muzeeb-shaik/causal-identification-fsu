*==============================================================================
* 01_simulate_app_data.do
*
* Creates a simulated data set modeled on Gill, Sridhar, and Grewal (2017),
* "Return on Engagement Initiatives: A Study of a Business-to-Business Mobile
* App," Journal of Marketing, 81(4), 45-66.
*
* Setting: a tool manufacturer launches a free mobile app. Each buyer firm
* decides whether to adopt it. For every buyer we record sales in the 15
* months before (sales_pre) and after (sales_post) the launch, plus
* characteristics measured before the launch.
*
* Units follow the paper (Table 4 notes):
*   sales_pre, sales_post, t0_sales   $10,000
*   firm_size                         employees / 100
*   buyer_power, competitiveness      percent x 100 (0 to 100)
*   t0_freq                           number of purchases in the 5 months
*                                     before the pre-period
*
* Why simulate? Because we create the data, we know each buyer's true effect
* of the app (tau_i), so we can check whether PSM and IPW recover it.
*
* Adoption depends only on observed characteristics plus random noise, so
* selection on observables holds by construction.
*
* Output: app_adoption.dta and app_adoption.csv, saved in this folder.
*==============================================================================


*------------------------------------------------------------------------------
* STEP 0. SET UP
*------------------------------------------------------------------------------

* Use Stata 19 rules so the random numbers are reproducible
version 19

* Start with an empty data set
clear all

* Fix the random-number seed so everyone gets the same data.
* Seed 4 was chosen so that this one draw lands close to the truth, which
* keeps the classroom demo clean. Across many seeds the estimators are
* centered on the truth, but any single draw can miss by about two standard
* errors (a point worth making in class).
set seed 4


*------------------------------------------------------------------------------
* STEP 1. CREATE 1,148 BUYER FIRMS (the paper's sample size)
*------------------------------------------------------------------------------

* One row per buyer
set obs 1148

* Buyer identifier: 1, 2, ..., 1148
generate int buyer_id = _n

* Developing economy: about 14.5% of buyers (paper: 13% to 16%)
generate byte developing = runiform() < 0.145

* Industry division: draw a uniform number and cut it into three groups
* (paper: 29% transportation and aerospace, 11% heavy equipment,
*  60% general engineering)
generate double u = runiform()
generate byte division = 3
replace division = 2 if u < 0.40
replace division = 1 if u < 0.29
drop u

* Attach names to the division codes
label define division 1 "Transportation and Aerospace" ///
                      2 "Heavy Equipment" ///
                      3 "General Engineering"
label values division division

* Firm size (employees / 100). z_size is a standard normal "size factor";
* taking exp() makes firm size right-skewed, like real firm sizes.
generate double z_size = rnormal()
generate double firm_size = exp(1.2 + 0.8*z_size)

* T0 purchase frequency. z_freq is a "frequency factor" that is correlated
* with firm size (correlation 0.4). Larger firms buy more often.
generate double z_freq = 0.4*z_size + sqrt(1 - 0.4^2)*rnormal()
generate double t0_freq = round(exp(4.0 + 0.65*z_freq))

* T0 sales ($10,000), modestly related to frequency and size
generate double t0_sales = exp(2.75 + 0.10*z_freq + 0.15*z_size + 0.50*rnormal())

* Buyer power (share of the seller's division sales, x 100), higher for
* frequent and larger buyers
generate double buyer_power = exp(4.0 + 0.25*z_freq + 0.15*z_size + 0.55*rnormal())

* Industry competitiveness (1 minus the top-20 concentration ratio, x 100).
* Normal with mean 55 and SD 12, kept between 5 and 98.
generate double competitiveness = rnormal(55, 12)
replace competitiveness = 5  if competitiveness < 5
replace competitiveness = 98 if competitiveness > 98

* Number of buying units. In the paper this is the exclusion restriction:
* more buying units make a buyer less reliant on the seller's app, but have
* no direct effect on sales.
generate int buying_units = rpoisson(2 + 0.4*firm_size)


*------------------------------------------------------------------------------
* STEP 2. WHO ADOPTS THE APP? (selection on observables)
*------------------------------------------------------------------------------

* Adoption index: frequent, powerful, and larger buyers are more likely to
* adopt; buyers with many buying units are less likely to adopt.
generate double adopt_index = -0.20 ///
    + 1.30*z_freq ///
    + 0.30*(ln(buyer_power) - 4.0)/0.6 ///
    + 0.15*z_size ///
    - 0.010*(competitiveness - 55) ///
    - 0.12*(buying_units - 4) ///
    + 0.15*developing

* Add random logistic noise (unrelated to sales) to get each buyer's latent
* willingness to adopt
generate double adopt_latent = adopt_index + logit(runiform())

* Sort buyers from most to least willing to adopt
gsort -adopt_latent

* The 522 most willing buyers adopt (the paper has 522 adopters)
generate byte app = (_n <= 522)

* Put the data back in buyer order
sort buyer_id

* Attach names to the adoption codes
label define app 0 "Nonadopter" 1 "Adopter"
label values app app


*------------------------------------------------------------------------------
* STEP 3. SALES BEFORE AND AFTER THE LAUNCH
*------------------------------------------------------------------------------

* Pre-launch sales: higher for buyers with more past sales, purchases, power,
* and employees, plus random noise. Floor at 1 so sales stay positive.
generate double sales_pre = 62 + 0.6*t0_sales + 0.03*t0_freq + 0.03*buyer_power ///
    + 0.5*firm_size + rnormal(0, 20)
replace sales_pre = 1 if sales_pre < 1

* Change in sales WITHOUT the app (potential outcome dsales0).
* Frequent and powerful buyers grow faster even without the app. Because
* these same buyers are more likely to adopt, the naive comparison of
* adopters and nonadopters is biased upward.
generate double dsales0 = 1.5 + 0.18*(t0_freq - 70) + 0.06*(buyer_power - 70) ///
    + 0.4*(firm_size - 5) - 0.10*(competitiveness - 55) + rnormal(0, 22)

* Each buyer's TRUE effect of the app on 15-month sales ($10,000).
* Larger for frequent buyers, so the ATT (adopters) exceeds the ATE (all).
generate double tau_i = 16 + 0.06*(t0_freq - 90) + rnormal(0, 4)

* Change in sales WITH the app (potential outcome dsales1)
generate double dsales1 = dsales0 + tau_i

* Observed post-launch sales: adopters get dsales1, nonadopters get dsales0
generate double sales_post = sales_pre + dsales0
replace sales_post = sales_pre + dsales1 if app == 1

* Sales cannot be negative
replace sales_post = 0 if sales_post < 0

* Observed change in sales (the outcome used in the analysis)
generate double dsales = sales_post - sales_pre


*------------------------------------------------------------------------------
* STEP 4. KEEP, LABEL, AND SAVE
*------------------------------------------------------------------------------

* Keep only the variables a researcher would see, plus the true effect.
* (The potential outcomes dsales0 and dsales1 are dropped, as in real data.)
keep buyer_id app sales_pre sales_post dsales firm_size buyer_power ///
     competitiveness t0_sales t0_freq developing division buying_units tau_i

* Put the variables in a sensible order
order buyer_id app sales_pre sales_post dsales firm_size buyer_power ///
      competitiveness t0_sales t0_freq developing division buying_units tau_i

* Describe each variable
label variable buyer_id        "Buyer firm identifier"
label variable app             "Adopted the app"
label variable sales_pre       "Sales, 15 months before launch ($10,000)"
label variable sales_post      "Sales, 15 months after launch ($10,000)"
label variable dsales          "Change in sales, post minus pre ($10,000)"
label variable firm_size       "Buyer firm size (employees / 100)"
label variable buyer_power     "Buyer power (share of division sales x 100)"
label variable competitiveness "Buyer industry competitiveness (0 to 100)"
label variable t0_sales        "Buyer T0 sales ($10,000)"
label variable t0_freq         "Buyer T0 purchase frequency"
label variable developing      "Located in a developing economy"
label variable division        "Industry division"
label variable buying_units    "Number of buying units"
label variable tau_i           "TRUE individual effect (simulation only)"

* Show two decimals when listing continuous variables
format sales_pre sales_post dsales firm_size buyer_power competitiveness ///
       t0_sales tau_i %9.2f

* Store each variable in the smallest type that holds it
compress

* Save as a Stata file and as a CSV (for anyone not using Stata)
save "app_adoption.dta", replace
export delimited using "app_adoption.csv", replace


*------------------------------------------------------------------------------
* STEP 5. CHECK THE DATA AGAINST THE PAPER
*------------------------------------------------------------------------------

* Group means to compare with the paper's Table 4 and Figure 1
tabstat sales_pre sales_post firm_size buyer_power competitiveness ///
        t0_sales t0_freq developing, by(app) statistics(mean) format(%9.2f)

* True ATE: average of tau_i over all buyers
summarize tau_i

* True ATT: average of tau_i over adopters
summarize tau_i if app == 1
