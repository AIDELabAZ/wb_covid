* Project: WB COVID
* Created on: Aug 2021
* Created by: amf
* Edited by: amf, lirr (style edits)
* Last edited: 13 July 2022
* Stata v.17.0

* does
	* merges together each section of malawi data
	* builds round 9
	* outputs round 9

* assumes
	* raw malawi data 

* TO DO:
	* ADD FIES DATA


*************************************************************************
**# - setup
*************************************************************************

* define
	global	root	=	"$data/malawi/raw"
	global	export	=	"$data/malawi/refined"
	global	logout	=	"$data/malawi/logs"
	global  fies 	= 	"$data/analysis/raw/Malawi"

* open log
	cap log 		close
	log using		"$logout/mal_build", append
	
* set local wave number & file number
	local			w = 9
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_0`w'" 	

	
*************************************************************************
**# - get respondant gender
*************************************************************************

* load data
	use				"$root/wave_0`w'/sect12_Interview_Result_r`w'", clear
		*** obs == 1545

* drop all but household respondant
	keep			HHID s12q9
		*** obs == 1545
	rename			s12q9 PID
	isid			HHID

* merge in household roster
	merge 1:1		HHID PID using "$root/wave_0`w'/sect2_Household_Roster_r`w'.dta"
		*** obs == 7944: 1545 matched, 6399 unmatched
	keep if			_merge == 3
		*** obs == 1545
	drop			_merge
		*** obs == 1545

* drop all but gender and relation to HoH
	keep			HHID PID s2q5 s2q6 s2q7 s2q9
		*** obs == 1545

* save temp file
	tempfile		tempc
	save			`tempc'
		
	
*************************************************************************
**# - get household size and gender of HOH
*************************************************************************

* load data
	use			"$root/wave_0`w'/sect2_Household_Roster_r`w'.dta", clear
		*** obs == 7944

* rename other variables 
	rename 			PID ind_id 
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
		*** obs == 7944
	
* create hh head gender
	gen 			sexhh = . 
	replace			sexhh = sex_mem if relat_mem == 1
	label var 		sexhh "Sex of household head"
		*** obs == 7944
	
* generate migration vars
	rename 			s2q2 new_mem
	replace 		new_mem = 0 if s2q8 == 10
	replace 		s2q8 = . if s2q8 == 10
	gen 			mem_left = 1 if curr_mem == 2
		*** obs == 7944
	replace 		new_mem = 0 if new_mem == 2
	replace 		mem_left = 0 if mem_left == 2
	
	* why member left
		preserve
			keep 		y4 s2q4 ind_id
				*** obs == 7944
			keep 		if s2q4 != .
				*** obs == 99
			duplicates 	drop y4 s2q4, force
				*** obs == 89
			reshape 	wide ind_id, i(y4) j(s2q4)
				*** obs == 78
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
			keep 		y4 s2q8 ind_id
				*** obs == 7944
			keep 		if s2q8 < .
				*** obs == 83
			duplicates 	drop y4 s2q8, force
				*** obs == 78
			reshape 	wide ind_id, i(y4) j(s2q8)
				*** obs == 76
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
				(max) sexhh, by(HHID y4)
		*** obs == 1545
	replace 	new_mem = 1 if new_mem > 0 & new_mem < .
	replace 	mem_left = 1 if mem_left > 0 & new_mem < .	
	merge 		1:1 y4 using `new_mem', nogen
		*** obs == 1545: 76 matched, 1469 unmatched
	merge 		1:1 y4 using `mem_left', nogen
		*** obs == 1545: 78 matched, 1467 unmatched
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
	drop 		y4
		*** obs == 1545

* save temp file
	tempfile		tempa
	save			`tempa'

	
*************************************************************************
**# - reshape section on income loss wide data
*************************************************************************

* load income_loss data
	use				"$root/wave_0`w'/sect7_Income_Loss_r`w'", clear
		*** obs == 18540
	
*reshape data
	reshape 		wide s7q1 s7q2, i(y4_hhid HHID) j(income_source)
		*** obs == 1545

* save temp file
	tempfile		tempb
	save			`tempb'
	
	
*************************************************************************
**# - merge to build complete dataset for the round 
*************************************************************************

* load cover data
	use				"$root/wave_0`w'/secta_Cover_Page_r`w'", clear
		*** obs == 1700
	
* merge formatted sections
	foreach 		x in a b c {
	    merge 		1:1 HHID using `temp`x'', nogen
	}
		*** obs == 1700: 1545 matched, 155 unmatched for temps a, b, c

* merge in other sections
	merge 1:1 		HHID using "$root/wave_0`w'/sect4_Behavior_r`w'.dta", nogen	
		*** obs == 1700: 1545 matched, 155 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/sect4b_patienthealth_r`w'.dta", nogen
		*** obs == 1700: 1545 matched, 155 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/sect5_Access_r`w'.dta", nogen
		*** obs == 1700: 1545 matched, 155 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/sect6a_Employment2_r`w'.dta", nogen
		*** obs == 1700: 1545 matched, 155 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/sect6b_NFE_r`w'.dta", nogen
		*** obs == 1700: 1545 matched, 155 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/sect8_food_security_r`w'.dta", nogen
		*** obs == 1700: 1545 matched, 155 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/sect9_Concerns_r`w'.dta", nogen
		*** obs == 1700: 1545 matched, 155 unmatched

* rename variables inconsistent with other waves	
	
	* behavior
		rename 			s4q7 bh_freq_wash
		rename 			s4q8 bh_freq_mask	
		rename 			s4q8b cov_vac_know
	
	* shops
		rename 			s5q6 ac_shops_need
		rename 			s5q6a ac_shops_mask
		rename 			s5q5b ac_shops_wash
		rename 			s5q5c ac_shops_san
		rename 			s5q5d ac_shops_line
		
	* employment 
		rename 			s6q3a emp_search
		rename 			s6q3b emp_search_how		
		rename 			s6q5 emp_act
		replace 		emp_act = 100 if emp_act == 13
		replace 		emp_act = 13 if emp_act == 8
		replace 		emp_act = 8 if emp_act == 6
		replace 		emp_act = 6 if emp_act == 100
		replace 		emp_act = 14 if emp_act == 9
		replace 		emp_act = 9 if emp_act == 11 | emp_act == 12
		replace 		emp_act = 11 if emp_act == 4
		replace 		emp_act = 12 if emp_act == 5
		replace 		emp_act = 4 if emp_act == 7
		replace 		emp_act = 7 if emp_act == 10
		replace 		emp_act = 16 if emp_act == 15
		replace 		emp_act = -96 if emp_act == 96
		rename			s6bq11 bus_emp
		
* generate round variables
	gen				wave = `w'
		*** obs == 1700
	lab var			wave "Wave number"
	rename			wt_round`w' phw_cs
	label var		phw "sampling weights - cross section"
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace

/* END */		