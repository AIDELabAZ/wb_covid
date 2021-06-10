* Project: WB COVID
* Created on: August 2020
* Created by: jdm
* Edited by: amf
* Last edited: Nov 2020 
* Stata v.16.1

* does
	* reads in second round of Nigeria data
	* reshapes and builds panel
	* outputs panel data 

* assumes
	* raw Nigeria data

* TO DO:
	* complete


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
	local			w = 2
	
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
* 1b - sections 2, 5-6, 8, 12: respondant gender
* ***********************************************************************

* load data
	use				"$root/wave_0`w'/r`w'_sect_a_2_5_6_8_12", clear
	
* drop all but household respondant
	keep			hhid s12q9
	rename			s12q9 indiv
	isid			hhid
	
* merge in household roster
	merge 1:1		hhid indiv using "$root/wave_0`w'/r`w'_sect_2.dta"
	keep if			_merge == 3
	drop	 		_merge
	
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

* load data
	use				"$root/wave_0`w'/r`w'_sect_7", clear

* reformat HHID
	format 			%5.0f hhid
	
* drop other source
	drop			zone state lga sector ea
	
* reshape data	
	reshape 		wide s7q1, i(hhid) j(source_cd)
 
	rename			s7q14 oth_inc_1
	lab var 		oth_inc_1 "Other Income: Remittances from abroad"
	rename			s7q15 oth_inc_2
	lab var 		oth_inc_2 "Other Income: Remittances from family in the country"
	rename			s7q16 oth_inc_3
	lab var 		oth_inc_3 "Other Income: Assistance from non-family"
	rename			s7q17 oth_inc_4
	lab var 		oth_inc_4 "Other Income: Income from properties, investments, or savings"
	rename			s7q18 oth_inc_5
	lab var 		oth_inc_5 "Other Income: Pension"	
	
* save temp file
	tempfile		tempc
	save			`tempc'

	
* ***********************************************************************
* 1d - section 11: assistance
* ***********************************************************************

* load data - updated via convo with Talip 9/1
	use				"$root/wave_0`w'/r`w'_sect_11", clear

* reformat HHID
	format 			%5.0f hhid
	
* drop other 
	drop 			zone state lga sector ea s11q2 s11q3__1 s11q3__2 ///
						s11q3__3 s11q3__4 s11q3__5 s11q3__6 s11q3__7 ///
						s11q3__96 s11q3_os s11q5 s11q6__1 s11q6__2 ///
						s11q6__3 s11q6__4 s11q6__6 s11q6__7 s11q6__96 s11q6_os
	
* reshape 
	reshape 		wide s11q1, i(hhid) j(assistance_cd)


* save temp file
	tempfile		tempd
	save			`tempd'	
	
	
* ***********************************************************************
* 1e - section 10: shocks
* ***********************************************************************

* not avaiable for round

	
* ***********************************************************************
* 2 - FIES score
* ***********************************************************************

* load and format data
	use				"$fies/NG_FIES_round`w'.dta", clear
	drop 			country round
	rename 			HHID hhid 
	destring 		hhid, replace

* save temp file
	tempfile		tempe
	save			`tempe'

	
* ***********************************************************************
* 3 - merge sections into panel and save
* ***********************************************************************

* merge sections based on hhid
	use				"$root/wave_0`w'/r`w'_sect_a_2_5_6_8_12", clear
	foreach 		s in a b c d e {
	    merge		1:1 hhid using `temp`s'', nogen
	}
	
* generate round variable
	gen				wave = `w'
	lab var			wave "Wave number"	
	
* clean variables inconsistent with other rounds
	rename			s6q16 ag_crop
	rename 			s6q23 ag_live
	rename 			s6q15a bus_beh
  * access
	* drinking water
	gen 			ac_drink = cond(s5q1e == 2, 1, cond(s5q1e == 1, 2,.))
	lab var 		ac_drink "Had Enough Drinking Water in Last 7 Days"
	drop 			s5q1e 
	rename 			s5q1f ac_drink_why 
	replace 		ac_drink_why = 5 if ac_drink_why == 4
	replace 		ac_drink_why = ac_drink_why + 1 if (ac_drink_why > 5 & ac_drink_why < 10)
	lab var 		ac_drink_why "Main Reason Not Enough Drinking Water in Last 7 Days"
	lab def 		ac_drink_why 1 "water supply not available" 2 "water supply reduced" ///
						3 "unable to access communal supply" ///
						4 "unable to access water tanks" 5 "shops ran out" ///
						 6 "markets not operating" 7 "no transportation" ///
						8 "restriction to go out" 9 "increase in price" 10 "cannot afford"
	lab val 		ac_drink_why ac_drink_why
	* soap 
	rename 			s5q1a ac_soap	
	rename 			s5q1a1 ac_soap_why
	* water
	rename 			s5q1b ac_water
	lab var 		ac_water "Had Enough Handwashing Water in Last 7 Days"
	rename 			s5q1b1 ac_water_why
	replace 		ac_water_why = ac_water_why + 1 if (ac_water_why > 3 & ac_water_why < 10)
	lab var 		ac_water_why "Main Reason Not Enough Handwashing Water in Last 7 Days"
	lab def 		ac_water_why 1 "water supply not available" 2 "water supply reduced" ///
						3 "unable to access communal supply" ///
						4 "unable to access water tanks" 5 "shops ran out" ///
						6 "markets not operating" 7 "no transportation" ///
						8 "restriction to go out" 9 "increase in price" ///
						10 "cannot afford" 11 "afraid to get viurs" ///
						12 "water source too far" 13 "too many people at water source" ///
						14 "large household size" 15 "lack of money", replace
	lab val 		ac_water_why ac_water_why
	* medical service	
	rename 			s5q2 ac_medserv_need
	rename 			s5q3 ac_medserv
	rename 			s5q4 ac_medserv_why 
	replace 		ac_medserv_why = 7 if ac_medserv_why == 4
	replace 		ac_medserv_why = . if ac_medserv_why == 96 
	* education 
	rename 			s5q4b edu_act
	rename 			s5q5__1 edu_1 
	rename 			s5q5__2 edu_2  
	rename 			s5q5__3 edu_3 
	rename 			s5q5__4 edu_4 
	rename 			s5q5__7 edu_5 
	rename 			s5q5__5 edu_6 
	rename 			s5q5__6 edu_7 	
	rename 			s5q5__96 edu_other 
	rename 			s5q6 edu_cont
	rename			s5q7__1 edu_cont_1
	rename 			s5q7__2 edu_cont_2 
	rename 			s5q7__3 edu_cont_3 
	rename 			s5q7__4 edu_cont_5 
	rename 			s5q7__5 edu_cont_6 
	rename 			s5q7__6 edu_cont_7 
	rename 			s5q7__7	edu_cont_8 
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace

* close the log
	log	close
	
	
/* END */		