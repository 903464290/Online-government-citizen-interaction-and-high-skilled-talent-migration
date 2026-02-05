/* ====================================================================
   Paper Title: Digital governance signals and talent migration
   Data Source: 282 prefecture-level cities in China (2023-2024)
   Description: Replication code with IV Strategy (Clean Version)
   ==================================================================== */

clear all
set more off
capture log close

// ====================================================================
// 1. 导入数据 (Import Data)
// ====================================================================
// 请修改为你的实际文件路径
import excel "City_Year_Panel_Data.xlsx", sheet("Sheet1") firstrow clear

// ====================================================================
// 2. 数据清洗与变量构造 (Data Preparation)
// ====================================================================

// 2.1 基础变量重命名
// 对应论文变量定义
capture rename Total_Message_Volume MsgVol      // Interaction Volume
capture rename L_perGDP GDP_Per_Capita          // Economic development
capture rename L_Internet Internet_Penetration  // Digital infrastructure
capture rename policyQD Talent_Policy           // Strength of talent policies
capture rename L_BOOK Public_Library            // Cultural public services
capture rename L_cityrate Tertiary_Share        // Industrial structure
capture rename Year year

// 2.2 面板设置
// 将城市名转为数值ID用于聚类标准误
capture confirm string variable city
if _rc == 0 {
    encode city, gen(city_id)
}

// 将区域转为数值ID (用于 Region FE)
capture confirm string variable region
if _rc == 0 {
    encode region, gen(region_id)
}

// 设置面板结构 (City-Year Panel)
xtset city_id year

// 2.3 变量转化与缩尾 (Transformation & Winsorization)
// 对连续变量进行 1% 和 99% 缩尾，排除极端值干扰
winsor2 TMI MsgVol GDP_Per_Capita Internet_Penetration Talent_Policy Public_Library Tertiary_Share, cuts(1 99) replace

// 取对数 (Log-transformation)
gen ln_MsgVol = log(MsgVol + 1)               // Interaction Intensity
gen ln_GDP = log(GDP_Per_Capita + 1)          // Econ Dev
gen ln_Library = log(Public_Library + 1)      // Public Services

// 定义控制变量宏 (Global Macros)
global controls "ln_GDP Internet_Penetration Talent_Policy ln_Library Tertiary_Share"

// --------------------------------------------------------------------
// [新增] 工具变量 (IV) 处理方式
// 方法：同省其他城市互动均值 (Leave-One-Out Mean)
// --------------------------------------------------------------------
// 1. 确保有省份ID (Province ID)
capture confirm variable province
if _rc == 0 {
    capture confirm string variable province
    if _rc == 0 {
        encode province, gen(province_id)
    }
}

// 2. 计算同省同年的总互动量 (Sum) 和 城市数量 (Count)
bysort province_id year: egen total_msg_prov = sum(ln_MsgVol)
bysort province_id year: egen count_city_prov = count(city_id)

// 3. 计算 IV_Peer = (省总和 - 自身) / (省城市数 - 1)
// 逻辑：排除自身，只计算同省"peers"的平均水平，满足排他性
gen IV_Peer = (total_msg_prov - ln_MsgVol) / (count_city_prov - 1)

// 4. 处理孤立样本 (若某省某年只有1个城市，无法计算Peer均值，设为缺失)
replace IV_Peer = . if count_city_prov <= 1

// ====================================================================
// 3. 描述性统计 (Table 1: Descriptive statistics)
// ====================================================================
logout, save(Table1_Descriptive) word replace: ///
    tabstat TMI MsgVol IV_Peer GDP_Per_Capita Internet_Penetration Talent_Policy Public_Library Tertiary_Share, ///
    stat(count mean sd min p50 max) format(%9.4f) columns(statistics)

// ====================================================================
// 4. 主回归分析 (Table 3: Regression Results)
// ====================================================================

// Model (1): 总量效应 (OLS Volume)
reg TMI ln_MsgVol $controls i.year i.region_id, vce(cluster city_id)
outreg2 using "Table3_Main_Results.doc", replace ctitle(OLS_Volume) ///
    addtext(Region FE, YES, Year FE, YES) dec(3)

// Model (2): 结构效应 (OLS Structure)
reg TMI Topic_Count_1 Topic_Count_2 Topic_Count_3 Topic_Count_4 ///
        Topic_Count_5 Topic_Count_6 Topic_Count_7 Topic_Count_8 ///
        Topic_Count_9 Topic_Count_10 Topic_Count_11 Topic_Count_12 ///
        $controls i.year i.region_id, vce(cluster city_id)
outreg2 using "Table3_Main_Results.doc", append ctitle(OLS_Structure) ///
    addtext(Region FE, YES, Year FE, YES) dec(3)

// Model (3): 工具变量法 (IV-2SLS Volume)
// 解决内生性问题，使用 IV_Peer
ivregress 2sls TMI $controls i.year i.province_id (ln_MsgVol = IV_Peer), vce(cluster city_id)
est store IV_Model

// 输出 IV 结果
esttab IV_Model using "Table3_Main_Results.doc", append ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    stats(N r2_a, fmt(0 3) labels("Observations" "R-squared")) ///
    mtitles("IV-2SLS") star(* 0.1 ** 0.05 *** 0.01)

// IV 强度检验 (输出 F值)
estat firststage

// ====================================================================
// 5. 稳健性检验 (Table 4: Stability Test)
// ====================================================================

// Check 1: 剔除一线城市 (Exclude Mega Cities)
preserve
    // 排除: 北京、上海、天津、重庆、深圳、广州
    drop if inlist(city, "北京市", "上海市", "天津市", "重庆市", "深圳市", "广州市")
    
    // (1) Volume 模型复现
    reg TMI ln_MsgVol $controls i.year i.region_id, vce(cluster city_id)
    outreg2 using "Table4_Robustness.doc", replace ctitle(ExclBig_Vol) addtext(Region FE, YES)
    
    // (2) Topic 模型复现
    reg TMI Topic_Count_1 Topic_Count_2 Topic_Count_3 Topic_Count_4 ///
            Topic_Count_5 Topic_Count_6 Topic_Count_7 Topic_Count_8 ///
            Topic_Count_9 Topic_Count_10 Topic_Count_11 Topic_Count_12 ///
            $controls i.year i.region_id, vce(cluster city_id)
    outreg2 using "Table4_Robustness.doc", append ctitle(ExclBig_Topic) addtext(Region FE, YES)
restore

// Check 2: 分位数回归 (Quantile Regression)
qreg TMI ln_MsgVol $controls i.year i.region_id, quantile(0.5)
outreg2 using "Table4_Robustness.doc", append ctitle(QREG_Median) addtext(Region FE, YES)


qreg TMI Topic_Count_1 Topic_Count_2 Topic_Count_3 Topic_Count_4 ///
            Topic_Count_5 Topic_Count_6 Topic_Count_7 Topic_Count_8 ///
            Topic_Count_9 Topic_Count_10 Topic_Count_11 Topic_Count_12 ///
            $controls i.year i.region_id, quantile(0.5)
outreg2 using "Table4_Robustness.doc", append ctitle(QREG_Median) addtext(Region FE, YES)

// Check 3: 关键话题占比 (Share of Key Topics)
// 构造占比变量
forvalues k = 1/12 {
    capture drop Topic_Share_`k'
    gen Topic_Share_`k' = Topic_Count_`k' / MsgVol
    replace Topic_Share_`k' = 0 if MsgVol == 0
}

// 联合回归: 总量 + 关键话题占比
reg TMI ln_MsgVol Topic_Share_2 Topic_Share_3 Topic_Share_5 ///
        Topic_Share_9 Topic_Share_10 Topic_Share_12 ///
        $controls i.year i.region_id, vce(cluster city_id)
outreg2 using "Table4_Robustness.doc", append ctitle(Share_KeyTopics) addtext(Region FE, YES)

// ====================================================================
// 6. 区域异质性分析 (Table 5: Heterogeneity Analysis)
// ====================================================================

// 6.1 生成区域分组变量 (East, Central, West)
gen zone = .
replace zone = 1 if inlist(region, "华东地区", "华南地区", "华北地区")
replace zone = 2 if inlist(region, "华中地区", "东北地区") 
replace zone = 3 if inlist(region, "西北地区", "西南地区")

label define zone_lab 1 "East" 2 "Central" 3 "West"
label values zone zone_lab

// 6.2 分组回归 (Sub-sample Regressions)
levelsof zone, local(z_levels)
foreach z of local z_levels {
    quietly reg TMI ln_MsgVol Topic_Count_2 Topic_Count_3 ///
            Topic_Count_5 Topic_Count_9 Topic_Count_10 Topic_Count_12 ///
            $controls i.year if zone == `z', vce(cluster city_id)
    est store Zone_`z'
}

// 导出 Table 5
esttab Zone_* using "Table5_Heterogeneity.rtf", replace ///
    b(%9.3f) t(%9.2f) star(* 0.1 ** 0.05 *** 0.01) ///
    ar2 compress nogap title("Table 5. Heterogeneity Analysis") ///
    mtitles("East" "Central" "West") ///
    indicate("Year FE = *.year")