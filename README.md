# Online-government-citizen-interaction-and-high-skilled-talent-migration
data
# Replication Data and Code for: "Online government-citizen interaction and high-skilled talent migration"

This repository contains the replication package for the research article: **"Online government-citizen interaction and high-skilled talent migration: Evidence from text mining of local leadership message boards in China"**.

The materials included here allow researchers to replicate the descriptive statistics, regression models (OLS & IV-2SLS), robustness checks, and heterogeneity analyses presented in the paper.

## 📂 Repository Structure

### 1. Data Files
* **`City_Year_Panel_Data.xlsx`**
    * **Description:** The aggregated city-level panel dataset covering 282 Chinese prefecture-level cities from 2023 to 2024. This is the main dataset used for regression analysis.
    * **Unit of Observation:** City-Year.
    * **Data Processing:** All continuous variables have been winsorized at the 1% and 99% levels to mitigate the influence of outliers. Missing values were handled via linear interpolation as described in the methodology.

* **`lda_results12.xlsx`**
    * **Description:** The output of the Latent Dirichlet Allocation (LDA) topic model ($k=12$).
    * **Contents:** Lists the top keywords (and their probability weights) for each of the 12 identified topics concerning talent policy. This corresponds to **Table 2** in the manuscript.

### 2. Code Files
* **`dataanlysis.do`
    * **Description:** The Stata script to reproduce all tables and regression results.
    * **Functionality:**
        * Imports `City_Year_Panel_Data.xlsx`.
        * Performs variable transformation (logarithms, ratios).
        * Constructs the instrumental variable (IV_Peer).
        * Runs OLS and 2SLS regressions.
        * Outputs Tables 1, 3, 4, and 5.

---
