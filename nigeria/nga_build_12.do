* Project: WB COVID
* Created on: July 2022
* Created by: lirr
* Edited by: lirr
* Last edited: 19 July 2022
* Stata v.17.0

* does
	* reads in first round of Nigeria data
	* reshapes and builds panel
	* outputs panel data 

* assumes
	* raw Nigeria data

* TO DO:
	* everything
	

*************************************************************************
**# - setup
*************************************************************************

* define 
	global	root	=	"$data/nigeria/raw"
	global	export	=	"$data/nigeria/refined"
	global	logout	=	"$data/nigeria/logs"
	global  fies 	= 	"$data/analysis/raw/Nigeria"

* open log
	cap log 		close
	log using		"$logout/nga_reshape", append

* set local wave number & file number
	local			w = 12
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_`w'"

	
*************************************************************************
**# - section 2: household size and gender of HOH
*************************************************************************

* load data
	use				"$root/wave_`w'/r`w'_sect_2", clear
		*** obs == 7884

* rename other variables
	rename			indiv ind_id
	rename			s2q3_r11 curr_mem // making assumption that questions are equivalent
	rename			s2q5_r11 sex_mem 
	rename			s2q6_r11 age_mem
	rename			s2q7_r11 relat_mem

* generate counting variables
	gen				hhsize = 1 if curr_mem == 1
	gen				hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem == 1 & age_mem < 19 & age_mem != . 
	gen 			hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19
		*** obs == 7884		
		
* generate migration variables	
		/// I have questions, there s2q3_r11 could be proxy but unsure no reason for leaving or gaining members. 
		
* create hh head gender
	gen				sexhh = .
	replace			sexhh = sex_mem if relat_mem == 1
	label var		sexhh "Sex of household head"

* collapse data to hh level
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild ///
						(max) sexhh, by(hhid)
		*** obs == 986
	lab var			hhsize "Household size"
	lab var			hhsize_adult "Household size - only adults"
	lab var			hhsize_child "Household size - children 0 - 18"
	lab var			hhsize_schchild "Household size - school-age children 5 - 18"
	
* save temp file
	tempfile		tempa
	save			`tempa'

	
*************************************************************************
**# - sections 3-6, 8-9, 12: respondant gender
*************************************************************************

* load data
	
	
	
*************************************************************************
**# - merge sections into panel and save
*************************************************************************
	
* save round file
	save			"$export/wave_`w'/r`w'", replace

* close the log
	log	close
	
	
/* END */	