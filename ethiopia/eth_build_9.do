* Project: WB COVID
* Created on: Oct 2020
* Created by: jdm
* Edited by: lirr
* Last edit:  20 June 2023
* Stata v.18.0

* does
	* reads in ninth round of Ethiopia data
	* builds round 9
	* outputs round 9

* assumes
	* raw Ethiopia data
	* xfill.ado

* TO DO:
	* complete


* **********************************************************************
* 0 - setup
* **********************************************************************

* define 
	global	root	=	"$data/ethiopia/raw"
	global	export	=	"$data/ethiopia/refined"
	global	logout	=	"$data/ethiopia/logs"
	global  fies 	= 	"$data/analysis/raw/Ethiopia"

* open log
	cap log 		close
	log using		"$logout/eth_build", append

* set local wave number & file number
	local			w = 9	
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_0`w'" 
	

* ***********************************************************************
*  1 - roster data - get household size and gender of household head  
* ***********************************************************************

* load roster data
	use				"$root/wave_0`w'/210125_WB_LSMS_HFPM_HH_Survey_Roster-Round`w'_Clean-Public", clear
	*** obs == 9207
	
* rename other variables 
	rename 			individual_id ind_id 
	rename 			bi2_hhm_new new_mem
	rename 			bi3_hhm_stillm curr_mem
	rename 			bi4_hhm_gender sex_mem
	rename 			bi5_hhm_age age_mem
	rename 			bi5_hhm_age_months age_month_mem
	rename 			bi6_hhm_relhhh relat_mem

* generate counting variables
	gen				hhsize = 1 if curr_mem == 1
	gen 			hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem == 1 & age_mem < 19 & age_mem != . 
	gen 			hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19 
	
* create hh head gender
	gen 			sexhh = . 
	replace			sexhh = sex_mem if relat_mem == 1
	label var 		sexhh "Sex of household head"
	
* collapse data
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild new_mem ///
						(max) sexhh, by(household_id)
	*** obs == 2077					
	replace 		new_mem = 1 if new_mem > 0 & new_mem < .
	lab var			hhsize "Household size"
	lab var 		hhsize_adult "Household size - only adults"
	lab var 		hhsize_child "Household size - children 0 - 18"
	lab var 		hhsize_schchild "Household size - school-age children 5 - 18"

* save temp file
	tempfile 		temp_hhsize
	save 			`temp_hhsize'
	*** obs == 2077
	
	
*************************************************************************
**# 2 - format microdata
*************************************************************************

* load microdata
	use				"$root/wave_0`w'/r`w'_wb_lsms_hfpm_hh_survey_public_microdata", clear
	*** obs == 2077

* generate round variable
	gen				wave = `w'
	lab var			wave "Wave number"

* save temp file
	tempfile 		temp_micro
	save 			`temp_micro'	

	
*************************************************************************
**# 3 - FIES score
*************************************************************************	
/*	
* load FIES score data
	use				"$fies/ET_FIES_round`w'.dta", clear
	
* format variables
	drop 			country round 
	rename 			HHID household_id
	
* save temp file	
	tempfile 		temp_fies
	save 			`temp_fies'
	
*/	

	
*************************************************************************
**# 4 - Crop data score
*************************************************************************	

* load microdata
	use				"$root/wave_0`w'/r`w'_wb_lsms_hfpm_hh_survey_public_microdata", clear
		*** obs == 2077

* replace variable names to match conversion factor
	gen 			region = cs1_region 
	gen				zone = cs2_zoneid 
	gen				woreda = cs3_woredaid  
	gen				local_unit = ph3_crops_area_u
	
	
* keep necessary variables
	keep			household_id region zone woreda local_ ph1_* ph2_* ph3_*
		*** obs == 2077
		
* drop observations with no crops
	drop if			ph2_crops_main == .
		*** obs == 649
		
* merge in conversion factors
	merge			m:1 region zone woreda local_unit ///
							using "$root/wave_00/ET_local_area_unit_conversion"
			*** obs == 870; 103 matched, 546 unmatched from master
		
* drop obs from using only
	drop if			_merge == 2
		*** obs == 649 
	drop			_m
		
* set up for imputation
	sort			household_id
	egen			district_id = group(region zone)
	lab var			district_id "Unique region identifier"
	distinct		region zone, joint // unique vals of dist should be same as this value
		*** 80 distinct districts

* construct conversion factors	
	replace			conversion = 10000 if local_unit == 1 & conversion == .
		*** 253 changes made
	replace			conversion = 1 if local_unit == 2 & conversion == .
		*** 2 changes made
	gen				crop_area_sqm = conversion * ph3_crops_area_q
		*** 291 missing values little less than half of all observations

	gen				selfreport_ha = crop_area_sqm * 0.0001
	lab var			selfreport_ha "Crop Area (ha) self reported"
	gen				plotsize_sr = selfreport_ha
	
* check summary stats of crop area varaibles
	sum				plotsize_sr
		*** mean = 1.409, min 0.0025 max 10
	
* impute missing plot sizes with predictive mean matching
	mi set			wide // declare data to be wide
	mi xtset,		clear // precautionary clear of xtset
	mi register		imputed plotsize_sr // identify self reported plotsize as variable to be imputed
	
	sort			household_id, stable // sorts for reproducibility
	
	mi impute		pmm plotsize_sr i.district_id i.local_unit, add(1) rseed(441244) ///
						noisily dots force knn(5) bootstrap
	
	mi				unset					
	
* summarize imputation results
	tab				mi_miss // binary = 1 for full set where plotsize_sr is missng
	tabstat			plotsize_sr plotsize_sr_1_ crop_area_sqm selfreport_ha, ///
						by(mi_miss) statistics(n mean min max) columns(statistics) longstub ///
						format(%9.3g)
		*** 291 values imputed				
		
* drop and replace plotsize variables to match other variables

	rename			plotsize_sr_1_ imp_crop_area
	lab var			imp_crop_area "Imputed crop area (ha) self reported r9"
	sum				imp_crop_area, detail
	
* check correlation between imp_crop_area and selfreport_ha
	corr			imp_crop_area selfreport_ha plotsize_sr
		*** corr = 1 very high, worringly high maybe

* drop	unncessary variables
	drop			region zone* woreda* local_unit district_id mi_miss conv_id ph* ///
						conversion
	
* save temp
	tempfile		temp_crops
	save			`temp_crops'
	


* ***********************************************************************
* 4 - merge to build complete dataset for the round 
* ***********************************************************************	
	
* merge household size, microdata, and FIES
	use 			`temp_hhsize', clear
	merge 			1:1 household_id using `temp_micro', assert(3) nogen
	//merge 			1:1 household_id using `temp_fies', nogen
					*** obs == 2077
	merge			1:1 household_id using `temp_crops',  nogen
		*** obs == 2077; 649 matched as seen above

* rename variables inconsistent with other rounds	
	* livestock 
		rename 		ph9_livestock ag_live
		rename 		ph10_livestock_type_1 ag_live_1
		rename 		ph10_livestock_type_2 ag_live_2
		rename 		ph10_livestock_type_3 ag_live_3
		rename 		ph10_livestock_type_4 ag_live_5
		rename 		ph10_livestock_type_5 ag_live_4
		drop 		ph10_livestock_type_*
		rename 		ph11_livestock_covid ag_live_affect
		rename 		ph12_livestock_covid_how_* ag_live_affect_*
		drop 		ag_live_affect__96
		rename 		ph13_farm_sell ag_sell_norm
		replace 	ag_sell_norm = 0 if ag_sell_norm == -97
		rename 		ph14_farm_sell_expect ag_sell_rev_exp
		
* drop vars
	drop 			em14_work_cur_notable_why_other as4_food_source_other ///
						as4_forwork_source_other as4_cash_source_other ///
						as4_other_source_other 
						*** obs == 2077
						
	destring 		cs5_eaid cs3b_kebeleid, replace
					*** obs == 2077
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace		
	
	
/* END */