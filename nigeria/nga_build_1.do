* Project: WB COVID
* Created on: August 2020
* Created by: jdm
* Edited by: amf, lirr (style edits)
* Last edited: 19 July 2022
* Stata v.17.0

* does
	* reads in first round of Nigeria data
	* reshapes and builds panel
	* outputs panel data 

* assumes
	* raw Nigeria data

* TO DO:
	* complete


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
	local			w = 1
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_0`w'" 
		
		
*************************************************************************
**# - format sections and save tempfiles
*************************************************************************


*************************************************************************
**# - section 2: household size and gender of HOH
*************************************************************************
	
* load data
	use				"$root/wave_0`w'/r`w'_sect_2.dta", clear
		*** obs == 12395

* rename other variables 
	rename 			indiv ind_id 
	rename 			s2q3 curr_mem
	replace 		curr_mem = 1 if s2q2 == 1
	rename 			s2q5 sex_mem
	rename 			s2q6 age_mem
	rename 			s2q7 relat_mem	
	replace			relat_mem = s2q9 if relat_mem == . 
	
* generate counting variables
	gen				hhsize = 1 if curr_mem == 1
	gen 			hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem == 1 & age_mem < 19 & age_mem != . 
	gen 			hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19
		*** obs == 12395
	
* create hh head gender
	gen 			sexhh = . 
	replace			sexhh = sex_mem if relat_mem == 1
	label var 		sexhh "Sex of household head"
	
* generate migration vars
	rename 			s2q2 new_mem
	replace 		new_mem = 0 if s2q8 == 10
	replace 		s2q8 = . if s2q8 == 10
	gen 			mem_left = 1 if curr_mem == 2
	replace 		new_mem = 0 if new_mem == 2
	replace 		mem_left = 0 if mem_left == 2
	
	* why member left
		preserve
			keep 		hhid s2q4 ind_id
				*** obs == 12395
			keep 		if s2q4 != .
				*** obs == 249
			duplicates 	drop hhid s2q4, force
				*** obs == 199
			reshape 	wide ind_id, i(hhid) j(s2q4)
				*** obs == 173
			ds 			ind_id*
			foreach 	var in `r(varlist)' {
				replace 	`var' = 1 if `var' != .
			}
			rename 		ind_id* mem_left_why_*
			tempfile 	mem_left
			save 		`mem_left'
		restore
	
	* why new member 
		preserve
			keep 		hhid s2q8 ind_id
				*** obs == 12395
			keep 		if s2q8 != .
				*** obs == 896
			duplicates 	drop hhid s2q8, force
				*** obs == 667
			reshape 	wide ind_id, i(hhid) j(s2q8)
				*** obs == 568
			ds 			ind_id*
			foreach 	var in `r(varlist)' {
				replace 	`var' = 1 if `var' != .
			}
			rename 		ind_id* new_mem_why_*
			tempfile 	new_mem
			save 		`new_mem'
		restore
	
* collapse data to hh level and merge in why vars
	collapse	(sum) hhsize hhsize_adult hhsize_child hhsize_schchild new_mem mem_left ///
				(max) sexhh, by(hhid)
		*** obs == 2010
	replace 	new_mem = 1 if new_mem > 0 & new_mem < .
	replace 	mem_left = 1 if mem_left > 0 & new_mem < .	
	merge 		1:1 hhid using `new_mem', nogen
		*** obs == 2010: 568 matched, 1442 unmatched
	merge 		1:1 hhid using `mem_left', nogen
		*** obs == 2010: 173 matched, 1837 unmatched
	ds 			new_mem_why_* 
	foreach		var in `r(varlist)' {
		replace 	`var' = 0 if `var' >= . & new_mem == 1
	}
	ds 			mem_left_why_* 
	foreach		var in `r(varlist)' {
		replace 	`var' = 0 if `var' >= . & mem_left == 1
	}
	lab var		hhsize "Household size"
	lab var 	hhsize_adult "Household size - only adults"
	lab var 	hhsize_child "Household size - children 0 - 18"
	lab var 	hhsize_schchild "Household size - school-age children 5 - 18"
	lab var 	mem_left "Member of household left since last call"
	lab var 	new_mem "Member of household joined since last call"

* save temp file
	tempfile		tempa
	save			`tempa'

	
*************************************************************************
**# - sections 3-6, 8-9, 12: respondant gender
*************************************************************************

* load data
	use				"$root/wave_0`w'/r`w'_sect_a_3_4_5_6_8_9_12", clear
		*** obs == 3000
	
* drop all but household respondant
	keep			hhid s12q9
		*** obs == 3000
	rename			s12q9 indiv
	isid			hhid
	
* merge in household roster
	merge 			1:1	hhid indiv using "$root/wave_0`w'/r`w'_sect_2.dta"
		*** obs == 13393: 2002 matched, 11391 unmatched
	keep 			if _merge == 3
		*** obs == 2002
	drop 			_merge
	
* rename variables and fill in missing values
	rename			s2q5 sex
	rename			s2q6 age
	rename			s2q7 relate_hoh
	replace			relate_hoh = s2q9 if relate_hoh == .
	rename			indiv PID
	
* drop all but gender and relation to HoH
	keep			hhid PID sex age relate_hoh
		*** obs == 2002

* save temp file
	tempfile		tempb
	save			`tempb'

	
*************************************************************************
**# - section 7: income
*************************************************************************

* load data
	use				"$root/wave_0`w'/r`w'_sect_7", clear
		*** obs == 23556

* reformat HHID
	format 			%5.0f hhid
	
* drop other source
	drop			source_cd_os zone state lga sector ea
		*** obs == 23556
	
* reshape data	
	reshape 		wide s7q1 s7q2, i(hhid) j(source_cd)
		*** obs == 1963
		
* save temp file
	tempfile		tempc
	save			`tempc'


*************************************************************************
**# - section 11: assistance
*************************************************************************

* load data - updated via convo with Talip 9/1
	use				"$root/wave_0`w'/r`w'_sect_11", clear
		*** obs == 5865

* reformat HHID
	format 			%5.0f hhid
	
* drop other 
	drop 			zone state lga sector ea s11q2 s11q3 s11q3_os
		*** obs == 5865
		
* reshape 
	reshape 		wide s11q1, i(hhid) j(assistance_cd)
		*** obs == 1955
	
* save temp file
	tempfile		tempd
	save			`tempd'

	
*************************************************************************
**# - section 10: shocks
*************************************************************************

* load data
	use				"$root/wave_0`w'/r`w'_sect_10", clear
		*** obs == 1955
		
* reformat HHID
	format 			%5.0f hhid

* drop other shock
	drop			shock_cd_os s10q3_os
		*** obs == 1955
		
* generate shock variables
	levelsof(shock_cd), local(id)
	foreach 			i in `id' {
		gen				shock_`i' = 1 if s10q1 == 1 & shock_cd == `i'
		replace			shock_`i' = 0 if s10q1 == 2 & shock_cd == `i'
		}

* collapse to household level
	collapse 		(max) s10q3__1- shock_96, by(hhid)		
		*** obs == 1958
		
* save temp file
	tempfile		tempe
	save			`tempe'

	
*************************************************************************
**# - FIES score
*************************************************************************

* not available for round

	
*************************************************************************
**# - merge sections into panel and save
*************************************************************************

* merge sections based on hhid
	use				"$root/wave_0`w'/r`w'_sect_a_3_4_5_6_8_9_12", clear
	foreach 		s in a b c d e {
	    merge		1:1 hhid using `temp`s'', nogen
	}
		*** obs == 3000: 2010 matched, 990 unmatched temp a
		*** obs == 3000: 2002 matched, 998 unmatched temp b
		*** obs == 3000: 1963 matched, 1037 unmatched temp c
		*** obs == 3000: 1955 matched, 1045 unmatched temp d
		*** obs == 3000: 1958 matched, 1042 unmatched temp e
		
* generate round variable
	gen				wave = `w'
	lab var			wave "Wave number"	
	
* clean variables inconsistent with other rounds
	rename			s6q15 farm_emp 
	rename			s6q16 farm_norm	
	
  * access
	* medicine
	rename 			s5q1a1 ac_med_need
	rename 			s5q1b1 ac_med
	gen 			ac_med_why = . 
	replace			ac_med_why = 1 if s5q1c1__1 == 1 
	replace 		ac_med_why = 2 if s5q1c1__2 == 1 
	replace 		ac_med_why = 3 if s5q1c1__3 == 1 
	replace 		ac_med_why = 4 if s5q1c1__4 == 1 
	replace 		ac_med_why = 5 if s5q1c1__5 == 1 
	replace 		ac_med_why = 6 if s5q1c1__6 == 1
	label var 		ac_med_why "reason unable to purchase medicine"
	
	* soap
	rename 			s5q1a2 ac_soap_need
	rename 			s5q1b2 ac_soap
	lab var 		ac_soap "Had Enough Handwashing Soap in Last 7 Day"
	gen 			ac_soap_why = .
	replace			ac_soap_why = 1 if s5q1c2__1 == 1 
	replace 		ac_soap_why = 2 if s5q1c2__2 == 1
	replace 		ac_soap_why = 3 if s5q1c2__3 == 1
	replace 		ac_soap_why = 4 if s5q1c2__4 == 1
	replace 		ac_soap_why = 5 if s5q1c2__5 == 1
	replace 		ac_soap_why = 6 if s5q1c2__6 == 1
	label var 		ac_soap_why "reason unable to purchase soap"
	
	* cleaning supplies								
	rename 			s5q1a3 ac_clean_need 
	rename 			s5q1b3 ac_clean
	gen 			ac_clean_why = . 
	replace			ac_clean_why = 1 if s5q1c3__1 == 1 
	replace 		ac_clean_why = 2 if s5q1c3__2 == 1
	replace 		ac_clean_why = 3 if s5q1c3__3 == 1
	replace 		ac_clean_why = 4 if s5q1c3__4 == 1
	replace 		ac_clean_why = 5 if s5q1c3__5 == 1
	replace 		ac_clean_why = 6 if s5q1c3__6 == 1
	label var 		ac_clean_why "reason unable to purchase cleaning supplies"
	
	* rice
	rename 			s5q1a4 ac_rice_need
	rename 			s5q1b4 ac_rice
	gen 			ac_rice_why = . 
	replace			ac_rice_why = 1 if s5q1c4__1 == 1 
	replace 		ac_rice_why = 2 if s5q1c4__2 == 1
	replace 		ac_rice_why = 3 if s5q1c4__3 == 1 
	replace 		ac_rice_why = 4 if s5q1c4__4 == 1 
	replace 		ac_rice_why = 5 if s5q1c4__5 == 1 
	replace 		ac_rice_why = 6 if s5q1c4__6 == 1 
	label var 		ac_rice_why "reason unable to purchase rice"
	
	* beans 	
	rename 			s5q1a5 ac_beans_need
	rename 			s5q1b5 ac_beans
	gen 			ac_beans_why = . 
	replace			ac_beans_why = 1 if s5q1c5__1 == 1 
	replace 		ac_beans_why = 2 if s5q1c5__2 == 1
	replace 		ac_beans_why = 3 if s5q1c5__3 == 1 
	replace 		ac_beans_why = 4 if s5q1c5__4 == 1 
	replace 		ac_beans_why = 5 if s5q1c5__5 == 1 
	replace 		ac_beans_why = 6 if s5q1c5__6 == 1 
	label var 		ac_beans_why "reason unable to purchase beans"
	
	* cassava 		
	rename 			s5q1a6 ac_cass_need
	rename 			s5q1b6 ac_cass
	gen 			ac_cass_why = . 
	replace			ac_cass_why = 1 if s5q1c6__1 == 1 
	replace 		ac_cass_why = 2 if s5q1c6__2 == 1
	replace 		ac_cass_why = 3 if s5q1c6__3 == 1 
	replace 		ac_cass_why = 4 if s5q1c6__4 == 1 
	replace 		ac_cass_why = 5 if s5q1c6__5 == 1 
	replace 		ac_cass_why = 6 if s5q1c6__6 == 1 
	label var 		ac_cass_why "reason unable to purchase cassava"
	
	* yam	
	rename 			s5q1a7 ac_yam_need
	rename 			s5q1b7 ac_yam
	gen 			ac_yam_why = . 
	replace			ac_yam_why = 1 if s5q1c7__1 == 1 
	replace 		ac_yam_why = 2 if s5q1c7__2 == 1
	replace 		ac_yam_why = 3 if s5q1c7__3 == 1 
	replace 		ac_yam_why = 4 if s5q1c7__4 == 1 
	replace 		ac_yam_why = 5 if s5q1c7__5 == 1 
	replace 		ac_yam_why = 6 if s5q1c7__6 == 1 
	label var 		ac_yam_why "reason unable to purchase yam"
	
	* sorghum 	
	rename 			s5q1a8 ac_sorg_need
	rename 			s5q1b8 ac_sorg
	gen 			ac_sorg_why = . 
	replace			ac_sorg_why = 1 if s5q1c8__1 == 1 
	replace 		ac_sorg_why = 2 if s5q1c8__2 == 1
	replace 		ac_sorg_why = 3 if s5q1c8__3 == 1 
	replace 		ac_sorg_why = 4 if s5q1c8__4 == 1 
	replace 		ac_sorg_why = 5 if s5q1c8__5 == 1 
	replace 		ac_sorg_why = 6 if s5q1c8__6 == 1 
	label var 		ac_sorg_why "reason unable to purchase sorghum"
	
	* medical service	
	rename 			s5q2 ac_medserv_need
	rename 			s5q3 ac_medserv
	rename 			s5q4 ac_medserv_why 
	replace 		ac_medserv_why = 7 if ac_medserv_why == 4
	replace 		ac_medserv_why = . if ac_medserv_why == 96 
	lab def			ac_medserv_why 1 "lack of money" 2 "no med personnel" ///
						3 "facility full" 4 "facility closed" 5 "not enough supplies" ///
						6 "lack of transportation" 7 "restriction to go out" ///
						8 "afraid to get virus" 9 "on suspicion of having virus" ///
						10 "refused treatment by facility"
	lab val 		ac_medserv_why ac_medserv_why
	lab var 		ac_med_why "reason for unable to access medical services"
	
	* education 
	rename 			s5q4a sch_child
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
	
	* credit 
	rename 			s5q8 ac_bank_need
	rename 			s5q9 ac_bank 
	rename 			s5q10 ac_bank_why 
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace

* close the log
	log	close
	
	
/* END */	