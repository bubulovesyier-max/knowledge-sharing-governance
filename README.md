# Knowledge-sharing platform governance: MATLAB replication materials

This repository contains MATLAB simulation implementations and plotting materials for the study *How does platform governance shape the online knowledge-sharing ecosystem? An evolutionary analysis of knowledge contribution and acquisition*.

## Scope

The model examines four participation strategies under three governance regimes:

| Strategy | Contribution | Acquisition |
| --- | --- | --- |
| A | Yes | No |
| B | Yes | Yes |
| C | No | Yes |
| D | No | No |

Governance regimes: free access (`free`), per-transaction revenue sharing (`revenue_sharing`), and membership subscription (`membership`).

**No empirical individual-level dataset was used.** he `.xlsx` files under `fig01/` through `fig09/` are saved *simulation-output/plotting inputs*, not empirical observations. They are supplied so that the provided plotting scripts can be used without rerunning every parameter combination.

## Baseline simulation settings
- Network: 50 × 50 periodic Moore lattice; 8 neighbors; N = 2500.
- Asynchronous strategy updates: T = 80000 update steps, one randomly selected participant per step.
- Initial probabilities: A = B = C = D = 0.25.
- Independent simulation runs: 10 per configuration; seed convention in the supplied scripts begins at 20260710.
- Steady-state statistics: mean over the final 10% of steps in each run, then mean across the 10 runs.
- Common parameters: c = 1, u = 2, alpha = 0.25, kappa = 0.2, sigma = 0.15.
- Paid-governance parameters: p = 0.6, theta = 0.6, s = 4, r = 0.45.
- Non-monetary benefit coefficients: hF = 0.25, hD = 0.5, hM = 0.5.
- Baseline membership duration: Q = 2500 asynchronous update steps; not a calendar period.

## Files and running the model

The nine scripts under `simulations/` implement the combinations of three governance regimes and three topologies:

| Regime | Regular lattice | WS small-world | BA scale-free |
| --- | --- | --- | --- |
| Free access | `free_regular.m` | `free_WS.m` | `free_BA.m` |
| Revenue sharing | `revenue_sharing_regular.m` | `revenue_sharing_WS.m` | `revenue_sharing_BA.m` |
| Membership | `membership_regular.m` | `membership_WS.m` | `membership_BA.m` |

Each script is self-contained and saves results in a folder located next to that script. In MATLAB, navigate to the repository root and run, for example:

```matlab
run('simulations/free_regular.m');
run('simulations/revenue_sharing_regular.m');
run('simulations/membership_regular.m');
```

The WS scripts use a rewiring probability of 0.20; the BA scripts initialize with a 9-node complete graph and attach each new node to 4 existing nodes. Both alternative networks have an average degree of approximately 8.

The scripts use built-in MATLAB table, network, and plotting functions such as readcell, readmatrix, writetable and exportgraphics. MATLAB R2020a or later is a suggested starting point, **not a tested compatibility guarantee**. The full package has not been execution-tested in this environment.

## Recreating figures

Most figure-specific `.m` scripts load the single `.xlsx` workbook stored in the same directory. In MATLAB, navigate to the script's folder, or call `run('figures/figXX/.../plot_....m')` from the repository root. Note that the spreadsheets retain the original workbook *cell contents*, including some Chinese-language headers expected by the plotting parsers; only the filenames and author metadata have been cleaned.

| Manuscript figure | Plot script location | Input | What it shows |
| --- | --- | --- | --- |
| Fig. 1 | `fig01/{free,revenue_sharing,membership}/` | `*_baseline.xlsx` | Baseline strategy trajectories |
| Fig. 2 | `fig02/plot_knowledge_price.m` | `knowledge_price_sweep.xlsx` | Varying knowledge price p |
| Fig. 3 | `fig03/plot_membership_fee.m` | `membership_fee_sweep.xlsx` | Varying membership fee s |
| Fig. 4 | `fig04/plot_revenue_share.m` | `contributor_share_sweep.xlsx` | Varying contributor share theta |
| Fig. 5 | `fig05/plot_membership_allocation.m` | `membership_allocation_sweep.xlsx` | Varying membership allocation r |
| Fig. 6 | `fig06/{free,revenue_sharing,membership}/` | `*_nonmonetary_sweep.xlsx` | Varying non-monetary benefit coefficients |
| Fig. 7 | `fig07/plot_network_strategy_{b,c}.m` | Numeric steady-state values in source scripts | Network-topology comparison |
| Fig. 8 | `fig08/plot_platform_revenue.m` | `platform_revenue_comparison.xlsx` | Revenue trajectories under three regimes |
| Fig. 9 | `fig09/plot_revenue_heatmap.m` | `revenue_price_share_grid.xlsx` | Joint p-theta revenue map |

The workbooks archive the data used for plotting, but the regular simulation scripts are not automatic parameter-sweep drivers. Recomputing Figs. 2–6 or the full Fig. 9 grid from scratch requires running the model at the respective parameter combinations and organizing the outputs into the plotting input format. Fig. 7 plotting scripts have hard-coded summary proportions rather than automatically reading the baseline output files.
