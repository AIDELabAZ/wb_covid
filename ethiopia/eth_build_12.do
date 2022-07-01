* Project: WB COVID
* Created on: July 2022
* Created by: lirr
* Edited by: lirr
* Last edit: 01 July 2022
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
	local			w = 12	
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_`w'" 
	
	
*************************************************************************
**# - roster data - get household size and gender of household head  
*************************************************************************
	
* load roster data
	use				"$root/wave_`w'/210628_WB_LSMS_HFPM_HH_Survey_Roster-Round`w'_Clean-Public", clear
		*** obs == 4512
	
* rename house roster variables
	rename			individual_id ind_id
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
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild  ///
						(max) sexhh, by(household_id)
						*** obs == 888
	lab var			hhsize "Household size"
	lab var 		hhsize_adult "Household size - only adults"
	lab var 		hhsize_child "Household size - children 0 - 18"
	lab var 		hhsize_schchild "Household size - school-age children 5 - 18"

* save temp file
	tempfile		temp_hhsize
	save			`temp_hhsize'
	

*************************************************************************
**# - format survey weights
*************************************************************************	
	
* load microdata
	use "$root/wave_`w'/HFPS-HH_weights_cross-section_R`w'", clear
			*** obs == 881

* save temp file
	tempfile		temp_weights
	save			`temp_weights'
		*** obs == 881


*************************************************************************
**# - format microdata 
*************************************************************************

* load microdata
	use "$root/wave_`w'/210623_WB_LSMS_HFPM_HH_Survey-Round12_Clean-Public", clear
			*** obs == 888
	
* generate round variable
	gen				wave = `w'
	lab var			wave "Wave number"

* save temp file
	tempfile		temp_micro
	save			`temp_micro'
	*** obs == 888 NOTE: there is data on educational aspirations for youth that I do not know what we would care to do with


*************************************************************************
**# - merge to build complete dataset for the round
*************************************************************************

* merge to build complete dataset for the round	
	use				`temp_hhsize', clear
	merge			1:1 household_id using `temp_micro', assert(3) nogen
		*** obs == 888
	merge			1:1 household_id using `temp_weights', nogen
		*** obs == 881 NOTE: there are 8 households w/o r12 weights
		
* destring vars to match other rounds
	destring 		cs3c_* cs3b_kebeleid cs5_eaid, replace
						
* save round file
	save			"$export/wave_`w'/r`w'", replace
	
	

	