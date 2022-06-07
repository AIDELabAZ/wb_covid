* Project: WB COVID
* Created on: June 2022
* Created by: lirr
* Edited by: lirr
* Last edit: 07 June 2022
* Stata v.17.0

* does
	* reads in eleventh round of Ethiopia data
	* builds round 11
	* outputs round 11

* assumes
	* raw Ethiopia data
	* xfill.ado

* TO DO:
	* everything


************************************************************************
**# - setup
************************************************************************

* define 
	global	root	=	"$data/ethiopia/raw"
	global	export	=	"$data/ethiopia/refined"
	global	logout	=	"$data/ethiopia/logs"
	global  fies 	= 	"$data/analysis/raw/Ethiopia"

* open log
	cap log 		close
	log using		"$logout/eth_build", append

* set local wave number & file number
	local			w = 11	
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_`w'" 
	

*************************************************************************
**# - roster data - get household size and gender of household head  
*************************************************************************

* load roster data
	use				"$root/wave_`w'/WB_LSMS_HFPM_HH_Survey_Roster-Round`w'_Clean-Public", clear
		*** obs == 8813
	
* rename house roster variables
	rename			individual_id ind_id
	rename			bi2_hhm_new new_mem
	rename			bi3_hhm_stillm curr_mem
	rename			bi4_hhm_gender sex_mem
	rename			bi5_hhm_age age_mem
	rename			bi5_hhm_age_months age_month_mem
	rename			bi6_hhm_relhhh relat_mem

* generate counting variables
	gen				hhsize = 1 if curr_mem == 1
	gen				hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem -- 1 & age_mem < 19 & age_mem != .
	gen				hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19
	
* create hh head gender
	gen				sexhh = .
	replace			sexhh = sex_mem if relat_mem == 1
	lab var			sexhh "Sex of household head"

* collapse data
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild new_mem ///
						(max) sexhh, by(household_id)
						*** obs == 1982
	replace			new_mem = 1 if new_mem > 0 & new_mem < .
	lab var			hhsize "Household size"
	lab var 		hhsize_adult "Household size - only adults"
	lab var 		hhsize_child "Household size - children 0 - 18"
	lab var 		hhsize_schchild "Household size - school-age children 5 - 18"

* save temp file
	tempfile		temp_hhsize
	save			`temp_hhsize'


*************************************************************************
**# - format microdata 
*************************************************************************

* load microdata
	use				"$root/wave_`w'/WB_LSMS_HFPM_HH_Survey-Round`w'_Clean-microdata", clear
		*** obs == 1982

* generate round variable
	gen				wave = `w'
	lab var			wave "Wave number"

* save temp file
	tempfile		temp_micro
	save			`temp_micro'
	*** obs == 1982


*************************************************************************
**# - education data
*************************************************************************

* load education data
	use				"$root/wave_`w'/WB_LSMS_HFPM_HH_Survey-Round`w'_Education_Clean-microdata", clear
		*** obs == 3831

* format variables to match master
	rename			individual_id ind_id
	
	rename			inded1_attend_school sch_child
	rename			inded4_attend_edclose edu_act
	rename			inded5_register sch_child_reg
	rename			inded7_reopen sch_reopen
	rename			inded8_attend_fourwks sch_att
	
	gen				sch_child_reg_1 = 0 if inded10_register_reason != 1
	gen				sch_child_reg_2 = 0 if inded10_register_reason != 2
	gen				sch_child_reg_3 = 0 if inded10_register_reason != 3
	gen				sch_child_reg_4 = 0 if inded10_register_reason != 4
	gen				sch_child_reg_5 = 0 if inded10_register_reason != 5
	gen				sch_child_reg_6 = 0 if inded10_register_reason != 6
	gen				sch_child_reg_7 = 0 if inded10_register_reason != 7
	gen				sch_child_reg_8 = 0 if inded10_register_reason != 8
	gen				sch_child_reg_9 = 0 if inded10_register_reason != 9
	gen				sch_child_reg_11 = 0 if inded10_register_reason != 11
	gen				sch_child_reg_12 = 0 if inded10_register_reason != 12
	gen				sch_child_reg_other = 0 if inded10_register_reason != -96
	
	replace			sch_child_reg_1 = 1 if inded10_register_reason == 1
	replace			sch_child_reg_2 = 1 if inded10_register_reason == 2
	replace			sch_child_reg_3 = 1 if inded10_register_reason == 3
	replace			sch_child_reg_4 = 1 if inded10_register_reason == 4
	replace			sch_child_reg_5 = 1 if inded10_register_reason == 5
	replace			sch_child_reg_6 = 1 if inded10_register_reason == 6
	replace			sch_child_reg_7 = 1 if inded10_register_reason == 7
	replace			sch_child_reg_8 = 1 if inded10_register_reason == 8
	replace			sch_child_reg_9 = 1 if inded10_register_reason == 9
	replace			sch_child_reg_11 = 1 if inded10_register_reason == 11
	replace			sch_child_reg_12 = 1 if inded10_register_reason == 12
	replace			sch_child_reg_other = 1 if inded10_register_reason == -96
	
	
* save temp file
	tempfile		temp_ed
	save			`temp_ed'
	

*************************************************************************
**# - merge to build complete dataset for the round
*************************************************************************

* merge to build complete dataset for the round	
	use				`temp_hhsize', clear
	merge			1:1 household_id using `temp_micro', assert(3) nogen
	*** obs == 1982
	merge			1:1 household_id using `temp_ed', assert(3) nogen
	
* destring vars to match other rounds
	destring 		cs3c_* cs3b_kebeleid cs5_eaid cs6_hhid cs7_hhh_id ///
						cs7a_hhh_age, replace
						
* save round file
	save			"$export/wave_`w'/r`w'", replace
	