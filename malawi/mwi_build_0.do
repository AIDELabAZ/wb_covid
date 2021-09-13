* Project: WB COVID
* Created on: June 2021
* Created by: amf
* Edited by: jdm, amf
* Last edited: Nov 2020
* Stata v.16.1

* does
	* reads in baseline Malawi data
	* builds data for LD 
	* outputs HH income dataset

* assumes
	* raw malawi data 

* TO DO:
	* complete


* **********************************************************************
**# setup
* **********************************************************************

* define
	global	root	=	"$data/malawi/raw"
	global	export	=	"$data/malawi/refined"
	global	logout	=	"$data/malawi/logs"
	global  fies 	= 	"$data/analysis/raw/Malawi"

* open log
	cap log 		close
	log using		"$logout/mal_build", append
	
* set local wave number & file number
	local			w = 0
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_0`w'" 	
	

* ***********************************************************************
**# household data
* ***********************************************************************

* load data
	use 			"$root/wave_0`w'/HH_MOD_B", clear	
	
* rename other variables 
	rename 			PID ind_id 
	rename 			hh_b03 sex_mem
	rename 			hh_b05a age_mem
	rename 			hh_b04 relat_mem	
	gen 			curr_mem = 0 if hh_b06_2 == 3 | hh_b06_2 == 4
	replace 		curr_mem = 1 if hh_b06_2 < 3
	replace 		curr_mem = 1 if hh_b06_2 == .
	gen 			new_mem = 0 if hh_b06_2 != 2 & hh_b06_2 < .
	replace 		new_mem = 1 if hh_b06_2 == 2
	gen 			mem_left = 0 if hh_b06_2  != 3 & hh_b06_2  < .
	replace 		mem_left = 1 if hh_b06_2 == 3
	
* generate counting variables
	drop 			hhsize 
	gen				hhsize = 1 if curr_mem == 1
	gen 			hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem == 1 & age_mem < 19 & age_mem != . 
	gen 			hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19	

* create hh head gender
	gen 			sexhh = . 
	replace			sexhh = sex_mem if relat_mem == 1
	label var 		sexhh "Sex of household head"
	
* collapse data to hh level and merge in why vars
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild new_mem ///
					mem_left (max) sexhh, by(y4)	

* save tempfile 
	tempfile 		temp0
	save 			`temp0'

	
* ***********************************************************************
**# other income  
* ***********************************************************************
		
* load data
	use 			"$root/wave_0`w'/HH_MOD_P", clear	
	
* rename variables
	replace 		hh_p0a = hh_p0a - 100
	egen 			temp = rowtotal(hh_p03a-hh_p03c) if hh_p02 == . & hh_p01 == 1
	replace 		hh_p02 = temp if hh_p02 == . & temp < .
	rename 			hh_p01 inc_
	rename 			hh_p02 amnt_
	keep 			y4 HHID* inc_ hh_p0a amnt_
	
* reshape data and rename vars
	reshape 		wide inc_ amnt_, i(y4) j(hh_p0a)
	lab	def			yesno 0 "No" 1 "Yes", replace
	
	ds inc_* 
	foreach 		var in `r(varlist)' {
		replace 		`var' = 0 if `var' == 2
		lab val 		`var' yesno
	}
	ds amnt_* 
	foreach 		var in `r(varlist)' {
		replace 		`var' = 0 if `var' == . 
	}

	rename 			inc_1 cash_trans_0
	rename 			amnt_1 cash_trans_amnt_0
	rename 			inc_2 food_trans_0
	rename 			amnt_2 food_trans_amnt_0
	rename 			inc_3 kind_trans_0
	rename 			amnt_3 kind_trans_amnt_0
	rename 			inc_4 save_inc_0
	rename 			amnt_4 save_inc_amnt_0
	rename 			inc_5 pen_pub_0
	rename 			amnt_5 pen_pub_amnt_0
	rename 			inc_6 rent_nonag_0
	rename 			amnt_6 rent_nonag_amnt_0
	rename 			inc_7 rent_0
	rename 			amnt_7 rent_amnt_0
	rename 			inc_8 rent_shop_0
	rename 			amnt_8 rent_shop_amnt_0
	rename 			inc_9 rent_veh_0
	rename 			amnt_9 rent_veh_amnt_0
	rename 			inc_10 sales_re_0
	rename 			amnt_10 sales_re_amnt_0
	rename 			inc_11 asset_nonag_0
	rename 			amnt_11 asset_nonag_amnt_0
	rename 			inc_12 asset_ag_0
	rename 			amnt_12 asset_ag_amnt_0
	rename 			inc_13 inherit_0
	rename 			amnt_13 inherit_amnt_0
	rename 			inc_14 gamb_0
	rename 			amnt_14 gamb_amnt_0	
	rename 			inc_15 oth_inc1_0
	rename 			amnt_15 oth_inc1_amnt_0
	rename 			inc_16 pen_priv_0
	rename 			amnt_16 pen_priv_amnt_0	

* save tempfile 
	tempfile 		temp1
	save 			`temp1'	
	
	
* ***********************************************************************
**# transfers form children
* ***********************************************************************	
	
* load data
	use 			"$root/wave_0`w'/HH_MOD_O", clear
	
* rename vars
	rename 			hh_o11 cash_child_0
	replace 		cash_child_0 = 0 if cash_child_0 == 2
	rename 			hh_o14 cash_child_amnt_0
	rename 			hh_o15 kind_child_0
	replace 		kind_child_0 = 0 if kind_child_0 == 2
	rename 			hh_o17 kind_child_amnt_0
	replace 		cash_child_0 = 0 if hh_o0a == 2
	replace 		kind_child_0 = 0 if hh_o0a == 2
	
* collapse vars to hh level
	collapse 		(max) cash_child_0  kind_child_0 ///
						(sum) cash_child_amnt_0 kind_child_amnt_0, by(y4)
						
* save tempfile 
	tempfile 		temp2
	save 			`temp2'	
	

* ***********************************************************************
**# safety nets/assistance
* ***********************************************************************	

* load data
	use 			"$root/wave_0`w'/HH_MOD_R", clear

*format and reshape 
	rename 			hh_r01 inc_
	replace 		hh_r02a = hh_r02a + hh_r02b if hh_r02a != . & hh_r02b != .
	replace 		hh_r02a = hh_r02b if hh_r02a == . & hh_r02b != .
	replace 		hh_r02a = hh_r02c if hh_r02a == . 
	rename 			hh_r02a amnt_
	keep 			inc_ amnt_ y4 hh_r0a	
	reshape 		wide inc_ amnt_, i(y4) j(hh_r0a)		
	drop 			inc_105 inc_108 amnt_105 amnt_106 amnt_107 amnt_108

* rename variables 
	rename 			inc_101 asst_maize_0
	rename 			amnt_101 kg_maize_0
	rename 			inc_102 asst_food_0
	rename 			amnt_102 asst_food_amnt_0
	rename 			inc_104 input_for_wrk_0
	rename 			amnt_104 input_for_wrk_amnt_0
	rename 			inc_106 tnp_0 
	rename 			inc_107 supp_feed_0
	rename 			inc_111 cash_gov_0
	rename 			amnt_111 cash_gov_amnt_0
	rename 			inc_112 cash_ngo_0
	rename 			amnt_112 cash_ngo_amnt_0
	rename 			inc_113 oth_inc2_0
	rename 			amnt_113 oth_inc2_amnt_0
	rename 			inc_1031 masaf_0
	rename 			amnt_1031 masaf_amnt_0
	rename 			inc_1032 cash_for_wrk_0
	rename 			amnt_1032 cash_for_wrk_amnt_0
	
* save tempfile 
	tempfile 		temp3
	save 			`temp3'	
	
	
* ***********************************************************************
**# labor & time use  
* ***********************************************************************	
	
* load data
	use 			"$root/wave_0`w'/HH_MOD_E", clear

* rename indicator vars	
	rename 			hh_e06_4 wage_emp_0
	rename 			hh_e06_6 casual_emp_0	
	foreach 		var in wage casual {
		replace 		`var'_emp_0 = 0 if `var'_emp_0 == 2	
	}

* calc wage income	
	* generate conversion variables
		gen 			days_per_month = 365/12
		gen 			weeks_per_month = 365/7/12
		
	* rename main wage job variables	
		rename 			hh_e22 main_months
		rename 			hh_e25 main_pay
		rename 			hh_e26a main_pay_period
		rename 			hh_e26b main_pay_unit
		rename 			hh_e27 main_pay_kind
		rename 			hh_e28a main_pay_kind_period
		rename 			hh_e28b main_pay_kind_unit
		rename 			hh_e31 main_cost
		
	* convert all main income to monthly 
		* salary payments
		gen 			main_pay_per_month = (main_pay / main_pay_period) if main_pay_unit == 5
		replace 		main_pay_per_month = (main_pay / main_pay_period) * days_per_month if main_pay_unit == 3
		replace 		main_pay_per_month = (main_pay / main_pay_period) * weeks_per_month if main_pay_unit == 4
		* in-kind payments
		gen 			main_pay_kind_per_month = (main_pay_kind / main_pay_kind_period) if main_pay_kind_unit == 5
		replace 		main_pay_kind_per_month = (main_pay_kind / main_pay_kind_period) * days_per_month if main_pay_kind_unit == 3
		replace 		main_pay_kind_per_month = (main_pay_kind / main_pay_kind_period) * weeks_per_month if main_pay_kind_unit == 4		
		*combine salary and in-kind
		replace 		main_pay_per_month = main_pay_per_month + main_pay_kind_per_month if main_pay_kind_per_month != .
		
	* calc annual mian income (subtract $ paid for apprenticeships)
		gen				main_pay_annual = (main_pay_per_month * main_months) 
		replace 		main_pay_annual = main_pay_annual - main_cost if main_cost !=.

	/* NOTE: the respondents who reported salaries on a weekly basis have significantly lower annual salaries than 
		other respondents (less than half) - this seems strange but is left as-is becuase we see no obvious errors
		sum main_pay_annual if main_pay_unit == 5
		sum main_pay_annual if main_pay_unit == 4
		sum main_pay_annual if main_pay_unit == 3
	*/

	* rename seocndary wage job variables	
		rename 			hh_e36 sec_months
		rename 			hh_e39 sec_pay
		rename 			hh_e40a sec_pay_period
		rename 			hh_e40b sec_pay_unit
		rename 			hh_e41 sec_pay_kind
		rename 			hh_e42a sec_pay_kind_period
		rename 			hh_e42b sec_pay_kind_unit
		rename 			hh_e45 sec_cost
		
	* convert all incomes to monthly (already month in this case)
		* salary payments
		gen 			sec_pay_per_month = (sec_pay / sec_pay_period) if sec_pay_unit == 5
		* in-kind payments
		gen 			sec_pay_kind_per_month = (sec_pay_kind / sec_pay_kind_period) if sec_pay_kind_unit == 5
		*combine salary and in-kind
		replace 		sec_pay_per_month = sec_pay_per_month + sec_pay_kind_per_month if sec_pay_kind_per_month != .
		
	* calc annual income (subtract $ paid for apprenticeships)
		gen				sec_pay_annual = (sec_pay_per_month * sec_months) 
		replace 		sec_pay_annual = sec_pay_annual - sec_cost if sec_cost !=.

	* combine main and secondary job incomes
		gen 			wage_emp_amnt_0 = main_pay_annual + sec_pay_annual if sec_pay_annual != .
		replace 		wage_emp_amnt_0 = main_pay_annual if wage_emp_amnt_0 == .

	* NOTE: significant outliers that should probably be dropped 

* calc income from casual labor
	* rename variables 
		rename 			hh_e56 cas_months_per_year
		rename 			hh_e57 cas_wks_per_month
		rename 			hh_e58 cas_days_per_wk
		rename 			hh_e59 cas_pay_per_day
		
	* calc annual casual salary
		gen 			casual_emp_amnt_0 = cas_pay_per_day * cas_days_per_wk * ///
							cas_wks_per_month * cas_months_per_year

* drop irrelevant 	
	keep 				y4 *emp*

* collapse to hh level (note that this makes missing values 0)
	collapse 			(sum) *amnt* (max) wage_emp_0 casual_emp_0, by (y4)

* save tempfile 
	tempfile 		temp4
	save 			`temp4'	

	
* ***********************************************************************
**# crop & tree income
* ***********************************************************************	

* load & format rainy data
	use 			"$root/wave_0`w'/AG_MOD_I", clear

	rename 			ag_i01 rainy
	replace 		rainy = 0 if rainy == 2
	collapse 		(sum) ag_i03 (max) rainy, by(y4)
	rename 			ag_i03 rainy_sales

preserve 

* load & format dimba data
	use 			"$root/wave_0`w'/AG_MOD_O", clear

	rename 			ag_o01 dimba
	replace 		dimba = 0 if dimba == 2
	collapse 		(sum) ag_o03 (max) dimba, by(y4)
	rename 			ag_o03 dimba_sales	
	
	* save tempfile 
		tempfile 		tempd
		save 			`tempd'	
	
* combine rainy & dimba crop sales 
restore
	
	merge 			1:1 y4 using `tempd', nogen
	
	gen 			crop_inc_amnt_0 = rainy_sales
	replace 		crop_inc_amnt_0 = rainy_sales + dimba_sales if dimba_sales != .
	gen 			crop_inc_0 = 0 
	replace 		crop_inc_0 = 1 if rainy == 1 | dimba == 1
	
	* save tempfile 
		tempfile 		tempc
		save 			`tempc'	
		
* load & format tree data
	use 			"$root/wave_0`w'/AG_MOD_Q", clear	

	rename 			ag_q01 tree_inc_0
	replace 		tree_inc_0 = 0 if tree_inc_0 == 2
	rename 			ag_q03 tree_inc_amnt_0
	collapse 		(sum) tree_inc_amnt_0 (max) tree_inc_0, by(y4)

* merge crop & tree 	
	merge 			1:1 y4 using `tempc', nogen
	
* save tempfile 
	tempfile 		temp5
	save 			`temp5'	

	
* ***********************************************************************
**# livestock 
* ***********************************************************************	

* load & format tree data
	use 			"$root/wave_0`w'/AG_MOD_R1", clear	
	
	rename 			ag_r17 live_inc_amnt_0 
	collapse		(sum) live_inc_amnt_0, by(y4)
	gen 			live_inc_0 = cond(live_inc_amnt_0 > 0, 1,0)

* save tempfile 
	tempfile 		temp6
	save 			`temp6'	

	
* ***********************************************************************
**# livestock products
* ***********************************************************************	

* load & format tree data
	use 			"$root/wave_0`w'/AG_MOD_S", clear	
	
	rename 			ag_s04 live_prod_0
	replace 		live_prod_0 = 0 if live_prod_0 == 2
	rename 			ag_s06 live_prod_amnt_0
	collapse 		(sum) live_prod_amnt_0 (max) live_prod_0, by(y4)
	replace 		live_prod_0 = 0 if live_prod_0 == .

* save tempfile 
	tempfile 		temp
	save 			`temp7'	
	

* ***********************************************************************
**# fishery income
* ***********************************************************************	

* ***********************************************************************
**# NFE income 
* ***********************************************************************	

* ***********************************************************************
**# plot rental  
* ***********************************************************************	
	
* ***********************************************************************
**# merge  
* ***********************************************************************	
	
* combine dataset 
	use 			`temp0', clear
	merge 			1:1 y4 using `temp0', assert(3) nogen
	merge 			1:1 y4 using `temp1', assert(3) nogen
	merge 			1:1 y4 using `temp2', assert(3) nogen
	merge 			1:1 y4 using `temp3', assert(3) nogen
	merge 			1:1 y4 using `temp4', assert(3) nogen
	
* add country & wave 
	gen 			wave = 0
	gen 			country = 2
	rename 			y4_hhid hhid_mwi
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace

/* END */		