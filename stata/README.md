# Stata Code and Data

Stata demonstrations for the PhD seminar *Causal Identification with Observational Data* (Muzeeb Shaik, Florida State University, October 23, 2026).

## Folders

```
stata/
├── demo/          the demonstrations shown in the seminar
├── data/          the data (.dta for Stata, .csv for other software)
└── simulation/    code that generated the data (not needed to follow along)
```

| Topic | Demonstration (`demo/`) | Data (`data/`) |
|-------|-------------------------|----------------|
| Matching | `02_matching_demo.do` | `app_adoption` |
| Instrumental variables | `04_iv_demo.do` | `disclosure_panel` |
| Difference-in-differences (appendix) | `06_did_demo.do` | `did_rollout`, `app_adoption` |

## How to run

1. Set Stata's working directory to the `demo/` folder, for example `cd "C:/.../stata/demo"`.
2. Run `02_matching_demo.do`, `04_iv_demo.do`, and `06_did_demo.do`.

Each do-file runs from top to bottom in numbered steps, with a comment on every command. Each reads its data from `../data/` and saves its figures to the slides' `images/` folder.

## Requirements

- Official Stata commands only; no user-written packages are needed.
- `02_matching_demo.do` and `04_iv_demo.do` run in Stata 14 or later.
- `06_did_demo.do` needs Stata 18 or later (`xthdidregress`, `estat bdecomp`).

## The data

### `app_adoption` (matching)

Based on Gill, Sridhar, and Grewal (2017, *Journal of Marketing*). A tool manufacturer launches a free B2B mobile app, and buyers choose whether to adopt it. 1,148 buyers (522 adopters), one row per buyer.

| Variable | Description |
|----------|-------------|
| `buyer_id` | Buyer firm identifier |
| `app` | Adopted the app (1 = yes); the treatment |
| `sales_pre`, `sales_post` | Sales in the 15 months before and after launch ($10,000) |
| `dsales` | Change in sales, post minus pre ($10,000); the outcome |
| `firm_size` | Buyer firm size (employees / 100) |
| `buyer_power` | Buyer's share of the seller's division sales (x 100) |
| `competitiveness` | Buyer industry competitiveness (0 to 100) |
| `t0_sales`, `t0_freq` | Sales ($10,000) and number of purchases in the 5 months before the pre-period |
| `developing` | Located in a developing economy (1 = yes) |
| `division` | Industry division (3 categories) |
| `buying_units` | Number of buying units |
| `tau_i` | True effect of the app for each buyer |

True effect for adopters (ATT) = 15.85; for all buyers (ATE) = 14.63.

### `disclosure_panel` (instrumental variables)

Based on Shi, Grewal, and Sridhar (2021, *Journal of Marketing Research*). Do firms copy their peers' decisions to disclose advertising spending? 1,500 firms over 1995 to 2004 (15,000 firm-years).

| Variable | Description |
|----------|-------------|
| `firm_id`, `year`, `industry` | Firm, fiscal year, and primary industry (1 to 20) |
| `disclose` | Discloses advertising spending (1 = yes); the outcome |
| `peer_disc` | Share of the firm's peers that disclose; the endogenous variable |
| `size`, `sga`, `roa`, `rd`, `big6` | Firm's own traits: log assets, SG&A dummy, ROA, R&D intensity, Big Six auditor |
| `size_peer`, `sga_peer`, `roa_peer`, `big6_peer` | Average traits of the firm's peers (controls) |
| `size_2nd`, `sga_2nd`, `roa_2nd`, `big6_2nd` | Average traits of second-degree peers (the instruments) |
| `ind_adtrend` | Industry advertising trend (an invalid instrument, for teaching) |
| `tau_i` | True effect of peer disclosure |

True average effect = 0.459.

### `did_rollout` (difference-in-differences, appendix)

The app is rolled out region by region. 1,148 buyers in 8 sales regions over 12 quarters (13,776 buyer-quarters). Regions 1 and 2 get the app in quarter 5, regions 3 and 4 in quarter 7, regions 5 and 6 in quarter 9; regions 7 and 8 never do.

| Variable | Description |
|----------|-------------|
| `buyer_id`, `region`, `quarter` | Buyer, sales region (1 to 8), and quarter (1 to 12) |
| `rollout_q` | Quarter the app reached the region (missing = never) |
| `app_live` | App available in the buyer's region (1 = yes); the treatment |
| `event_time` | Quarters since rollout |
| `sales` | Quarterly sales ($10,000); the outcome |
| `tau_it` | True effect of the app |

True effect on treated buyer-quarters (ATT) = 2.31.

## References

- Gill, M., Sridhar, S., & Grewal, R. (2017). Return on engagement initiatives: A study of a business-to-business mobile app. *Journal of Marketing*, 81(4), 45-66.
- Shi, H., Grewal, R., & Sridhar, H. (2021). Organizational herding in advertising spending disclosures: Evidence and mechanisms. *Journal of Marketing Research*, 58(3), 515-538.

The data are constructed for teaching. They mirror the settings of these papers but are not the papers' data.
