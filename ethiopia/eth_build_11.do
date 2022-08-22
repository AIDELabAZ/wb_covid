* Project: WB COVID
* Created on: June 2022
* Created by: lirr
* Edited by: lirr
* Last edit: 08 Jul 2022
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
	
	rename			wfinal phw11

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
	
	rename			inded1_attend_school ac3_sch_child
	rename			inded4_attend_edclose edu_act
	rename			inded5_register ac3_sch_child_reg
	rename			inded7_reopen ac3_sch_reopen

	
/*
	gen				ac3_sch_child_reg_1 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 1
	gen				ac3_sch_child_reg_2 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 2
	gen				ac3_sch_child_reg_3 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 3
	gen				ac3_sch_child_reg_4 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 4
	gen				ac3_sch_child_reg_5 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 5
	gen				ac3_sch_child_reg_6 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 6
	gen				ac3_sch_child_reg_7 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 7
	gen				ac3_sch_child_reg_8 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 8
	gen				ac3_sch_child_reg_9 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 9
	gen				ac3_sch_child_reg_11 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 11
	gen				ac3_sch_child_reg_12 = 0 if inded10_register_reason != . ///
						& inded10_register_reason != 12
	gen				ac3_sch_child_reg_other = 0 if inded10_register_reason != . ///
						& inded10_register_reason != -96
	
	replace			ac3_sch_child_reg_1 = 1 if inded10_register_reason == 1
	replace			ac3_sch_child_reg_2 = 1 if inded10_register_reason == 2
	replace			ac3_sch_child_reg_3 = 1 if inded10_register_reason == 3
	replace			ac3_sch_child_reg_4 = 1 if inded10_register_reason == 4
	replace			ac3_sch_child_reg_5 = 1 if inded10_register_reason == 5
	replace			ac3_sch_child_reg_6 = 1 if inded10_register_reason == 6
	replace			ac3_sch_child_reg_7 = 1 if inded10_register_reason == 7
	replace			ac3_sch_child_reg_8 = 1 if inded10_register_reason == 8
	replace			ac3_sch_child_reg_9 = 1 if inded10_register_reason == 9
	replace			ac3_sch_child_reg_11 = 1 if inded10_register_reason == 11
	replace			ac3_sch_child_reg_12 = 1 if inded10_register_reason == 12
	replace			ac3_sch_child_reg_other = 1 if inded10_register_reason == -96
		
	gen				ac3_sch_att_why_1 = 0 if inded11_attend_reason != . ///
						& inded11_attend_reason != 1
	gen				ac3_sch_att_why_6 = 0 if inded11_attend_reason != . ///
						& inded11_attend_reason != 2
	gen				ac3_sch_att_why_16 = 0 if inded11_attend_reason != . ///
						& inded11_attend_reason != 3
	gen				ac3_sch_att_why_17 = 0 if inded11_attend_reason != . ///
						& inded11_attend_reason != 4
	gen				ac3_sch_att_why_8 = 0 if inded11_attend_reason != . ///
						& inded11_attend_reason != 5
	gen				ac3_sch_att_why_18 = 0 if inded11_attend_reason != . ///
						& inded11_attend_reason != 6
	gen				ac3_sch_att_why_7 = 0 if inded11_attend_reason != . ///
						& inded11_attend_reason != 7
	gen				ac3_sch_att_why_19 = 0 if inded11_attend_reason != . ///
						& inded11_attend_reason != 8						
	gen				ac3_sch_att_why_3 = 0 if inded11_attend_reason != . ///
						& inded11_attend_reason != 9
	gen				ac3_sch_att_why_5 = 0 if inded11_attend_reason != . /// note: could be coded as own number 
						& inded11_attend_reason != 11
	gen				ac3_sch_att_why_13 = 0 if inded11_attend_reason != . /// note: 12 := due to lack of stability assuming this refers to conflict
						& inded11_attend_reason != 12
	
	replace			ac3_sch_att_why_1 = 1 if inded11_attend_reason == 1
	replace			ac3_sch_att_why_6 = 1 if inded11_attend_reason == 2
	replace			ac3_sch_att_why_16 = 1 if inded11_attend_reason == 3
	replace			ac3_sch_att_why_17 = 1 if inded11_attend_reason == 4
	replace			ac3_sch_att_why_8 = 1 if inded11_attend_reason == 5
	replace			ac3_sch_att_why_18 = 1 if inded11_attend_reason == 6
	replace			ac3_sch_att_why_7 = 1 if inded11_attend_reason == 7
	replace			ac3_sch_att_why_19 = 1 if inded11_attend_reason == 8
	replace			ac3_sch_att_why_3 = 1 if inded11_attend_reason == 9
	replace			ac3_sch_att_why_5 = 1 if inded11_attend_reason == 11	
	replace			ac3_sch_att_why_13 = 1 if inded11_attend_reason == 12
	*/
* collapse by max
	collapse		(max) `r(varlist)' , by(household_id)
		*** obs == 1537
		
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
	merge			1:1 household_id using `temp_ed', nogen
	*** obs = 
	
* destring vars to match other rounds
	destring 		cs3c_* cs3b_kebeleid cs5_eaid cs6_hhid cs7_hhh_id ///
						cs7a_hhh_age ii*, replace
						
* rename sampling weight
	
						
* save round file
	save			"$export/wave_`w'/r`w'", replace
	