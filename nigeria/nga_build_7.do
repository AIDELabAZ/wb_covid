* Project: WB COVID
* Created on: August 2020
* Created by: jdm
* Edited by: amf
* Last edited: Dec 2020 
* Stata v.16.1

* does
	* reads in seventh round of Nigeria data
	* reshapes and builds panel
	* outputs panel data 

* assumes
	* raw Nigeria data

* TO DO:
	* add sections, pull together, waiting on questionaire 

	
* **********************************************************************
* 0 - setup
* **********************************************************************

* define 
	global	root	=	"$data/nigeria/raw"
	global	export	=	"$data/nigeria/refined"
	global	logout	=	"$data/nigeria/logs"
	global  fies 	= 	"$data/analysis/raw/Nigeria"

* open log
	cap log 		close
	log using		"$logout/nga_reshape", append

* set local wave number & file number
	local			w = 7
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_0`w'" 
		
	
* ***********************************************************************
* 1 - format secitons and save tempfiles
* ***********************************************************************	


* ***********************************************************************
* 1a - section 2: household size and gender of HOH
* ***********************************************************************
	
* load data
	use				"$root/wave_0`w'/r`w'_sect_2.dta", clear

* rename other variables 
	rename 			indiv ind_id 
	rename 			s2q2 new_mem
	rename 			s2q3 curr_mem
	rename 			s2q5 sex_mem
	rename 			s2q6 age_mem
	rename 			s2q7 relat_mem
	
* generate counting variables
	gen				hhsize = 1
	gen 			hhsize_adult = 1 if age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if age_mem < 19 & age_mem != . 
	gen 			hhsize_schchild = 1 if age_mem > 4 & age_mem < 19 
	
* create hh head gender
	gen 			sexhh = . 
	replace			sexhh = sex_mem if relat_mem == 1
	label var 		sexhh "Sex of household head"
	
* collapse data
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild (max) sexhh, by(hhid)
	lab var			hhsize "Household size"
	lab var 		hhsize_adult "Household size - only adults"
	lab var 		hhsize_child "Household size - children 0 - 18"
	lab var 		hhsize_schchild "Household size - school-age children 5 - 18"

* save temp file
	tempfile		tempa
	save			`tempa'
	

* ***********************************************************************
* 1b - respondant gender
* ***********************************************************************

* load data
	use				"$root/wave_0`w'/r`w'_sect_a_2_3a_6_9a_12", clear
	
* drop all but household respondant
	keep			hhid s12q9
	rename			s12q9 indiv
	isid			hhid
	
* merge in household roster
	merge 			1:1	hhid indiv using "$root/wave_0`w'/r`w'_sect_2.dta"
	keep 			if _merge == 3
	drop 			_merge
	
* rename variables and fill in missing values
	rename			s2q5 sex
	rename			s2q6 age
	rename			s2q7 relate_hoh
	replace			relate_hoh = s2q9 if relate_hoh == .
	rename			indiv PID
	
* drop all but gender and relation to HoH
	keep			hhid PID sex age relate_hoh

* save temp file
	tempfile		tempb
	save			`tempb'

	
* ***********************************************************************
* 1c - section 7: income
* ***********************************************************************

* not avaiable for round 
	
	
* ***********************************************************************
* 1d - section 11: assistance
* ***********************************************************************	
	
* load data  - updated via convo with Talip 9/1
	use				"$root/wave_0`w'/r`w'_sect_11", clear

* reformat HHID
	format 			%5.0f hhid
	
* drop other 
	drop 			zone state lga sector ea s11q2 s11q3__1 s11q3__2 ///
						s11q3__3 s11q3__4 s11q3__5 s11q3__6 s11q3__7 ///
						s11q3__96 s11q3_os s11q5 s11q6__1 s11q6__2 ///
						s11q6__3 s11q6__4 s11q6__6 s11q6__7 s11q6__96 ///
						s11q3_os s11q6_os s11q3__8

* reshape 
	reshape 		wide s11q1, i(hhid) j(assistance_cd)

* save temp file
	tempfile		tempc
	save			`tempc'					
	
		
* ***********************************************************************
* 1e - section 10: shocks
* ***********************************************************************

* not avaiable for round


* ***********************************************************************
* 1e - section 5c: education
* ***********************************************************************

* not avaiable for round
	

* ***********************************************************************
* 2 - FIES score
* ***********************************************************************

* not available for round 

	

* ***********************************************************************
* 3 - merge sections into panel and save
* ***********************************************************************

* merge sections based on hhid
	use				"$root/wave_0`w'/r`w'_sect_a_2_3a_6_9a_12", clear
	foreach 		s in a b c {
	    merge		1:1 hhid using `temp`s'', nogen
	}
	
* generate round variable
	gen				wave = `w'
	lab var			wave "Wave number"	

* clean variables inconsistent with other rounds
	* access	
	rename 			s5q1f ac_drink_src
	drop 			s5q1f_os 
	gen 			ac_drink = cond(s5q1g == 2, 1, cond(s5q1g == 1, 2,.))
	drop 			s5q1g
	rename 			s5q1h ac_drink_why
	replace 		ac_drink_why = 5 if ac_drink_why == 4
	replace 		ac_drink_why = ac_drink_why + 1 if (ac_drink_why > 5 & ac_drink_why < 10)
	rename 			s5q1i ac_water_src
	rename 			s5q1j ac_soap
	rename 			s5q1k ac_soap_why
	rename 			s5q1l ac_water
	rename 			s5q1m ac_water_why
	replace 		ac_water_why = ac_water_why + 1 if (ac_water_why > 3 & ac_water_why < 10)
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace

* close the log
	log	close
	
	
/* END */		
	