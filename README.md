# Causal Identification with Observational Data

PhD seminar, Florida State University. Muzeeb Shaik, Kelley School of Business, Indiana University.

**Slides:** https://muzeeb-shaik.github.io/causal-identification-fsu/

## Contents

- `Causal_FSU.qmd`: Quarto (reveal.js) source of the slides; `Causal_FSU.html` is the rendered deck.
- `stata/`: Stata do-files and simulated data for every demonstration in the slides.

| File | What it does |
|------|--------------|
| `01_simulate_app_data.do` | Simulates buyer data modeled on Gill, Sridhar, and Grewal (2017, *Journal of Marketing*) |
| `02_matching_demo.do` | Propensity score matching, IPW, and doubly robust estimators |
| `03_simulate_iv_data.do` | Simulates a firm-year panel modeled on Shi, Grewal, and Sridhar (2021, *Journal of Marketing Research*) |
| `04_iv_demo.do` | Two-stage least squares, first-stage diagnostics, weak and invalid instruments |
| `05_simulate_did_data.do` | Simulates a staggered rollout panel |
| `06_did_demo.do` | Two-period DiD, TWFE, Goodman-Bacon decomposition, Callaway and Sant'Anna (appendix) |

The data are simulated, so each data set stores the true effect for comparison with the estimates. Run the do-files from the `stata/` folder. They use official Stata commands only; the DiD appendix needs Stata 18 or later.

## Readings

The example papers are Gill, M., Sridhar, S., & Grewal, R. (2017), *Journal of Marketing*, 81(4), 45-66, and Shi, H., Grewal, R., & Sridhar, H. (2021), *Journal of Marketing Research*, 58(3), 515-538. Full reading lists are in the slides.
