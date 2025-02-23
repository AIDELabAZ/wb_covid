* Project: WB COVID
* Created on: Oct 2020
* Created by: jdm
* Edited by: lirr
* Last edit: 06 June 2022 
* Stata v.17.0

* does
	* reads in seventh round of Ethiopia data
	* builds round 7
	* outputs round 7

* assumes
	* raw Ethiopia data
	* xfill.ado

* TO DO:
	* complete

	
*************************************************************************
**# - setup
*************************************************************************

* define 
	global	root	=	"$data/ethiopia/raw"
	global	export	=	"$data/ethiopia/refined"
	global	logout	=	"$data/ethiopia/logs"
	global  fies 	= 	"$data/analysis/raw/Ethiopia"

* open log
	cap log 		close
	log using		"$logout/eth_build", append

* set local wave number & file number
	local			w = 7	
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_0`w'" 
	

*************************************************************************
**# - roster data - get household size and gender of household head  
*************************************************************************

* load roster data
	use				"$root/wave_0`w'/201111_WB_LSMS_HFPM_HH_Survey_Roster-Round`w'_Clean-Public", clear
		*** obs == 11289
		
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
						*** obs == 2536
	replace 		new_mem = 1 if new_mem > 0 & new_mem < .
	lab var			hhsize "Household size"
	lab var 		hhsize_adult "Household size - only adults"
	lab var 		hhsize_child "Household size - children 0 - 18"
	lab var 		hhsize_schchild "Household size - school-age children 5 - 18"

* save temp file
	tempfile 		temp_hhsize
	save 			`temp_hhsize'	
	
	
*************************************************************************
**# - format microdata 
*************************************************************************

* load microdata
	use				"$root/wave_0`w'/201116_WB_LSMS_HFPM_HH_Survey-Round`w'_Clean-Public_Microdata", clear
		*** obs == 2537

* generate round variable
	gen				wave = `w'
	lab var			wave "Wave number"
		*** obs == 2537
* save temp file
	tempfile 		temp_micro
	save 			`temp_micro'	
	
	
*************************************************************************
**# - FIES score
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
**# - merge to build complete dataset for the round
*************************************************************************	
	
* merge household size, microdata, and FIES
	use 			`temp_hhsize', clear
	merge 			1:1 household_id using `temp_micro', nogen
		*** obs == 2537, 1 unmatched from using
	//merge 			1:1 household_id using `temp_fies', nogen

* drop vars
	drop 			ac2_atb_med_why_other ac2_atb_teff_why_other ///
						ac2_atb_wheat_why_other ac2_atb_maize_why_other ///
						ac2_atb_oil_why_other em14_work_cur_notable_why_other ///
						em22_farm_norm_why_other as4_food_source_other ///
						as4_forwork_source_other as4_cash_source_other ///
						as4_other_source_other ir1_whyendearly_other
						*** obs == 2537
		
	destring 		cs3b_kebeleid cs5_eaid, replace	
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace		
	
	
/* END */