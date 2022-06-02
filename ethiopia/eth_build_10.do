* Project: WB COVID
* Created on: June 2022
* Created by: lirr
* Edited by: amf
* Last edit: 01 June 2022
* Stata v.17.0

* does
	* reads in tenth round of Ethiopia data
	* builds round 10
	* outputs round 10

* assumes
	* raw Ethiopia data
	* xfill.ado

* TO DO:
	* complete


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
	local			w = 10	
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_`w'" 
	


*************************************************************************
**# - roster data - get household size and gender of household head  
*************************************************************************

* load roster data
	use 			"$root/wave_`w'/R`w'_WB_LSMS_HFPM_HH_Survey_Public_Roster", clear
	
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
	replace			sexhh = sex_mem if relat_mem -- 1
	lab var			sexhh "Sex of household head"

* collapse data
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild new_mem ///
						(max) sexhh, by(household_id)

	replace			new_mem = 1 if new_mem > 0 & new_mem < .
	lab var			hhsize "Household size"
	lab var 		hhsize_adult "Household size - only adults"
	lab var 		hhsize_child "Household size - children 0 - 18"
	lab var 		hhsize_schchild "Household size - school-age children 5 - 18"

* save temp file
	tempfile 		temp_hhsize
	save 			`temp_hhsize'
	
				

	
	



	