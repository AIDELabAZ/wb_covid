* Project: WB COVID
* Created on: July 2022
* Created by: lirr
* Edited by: lirr
* Last edited: 18 July 2022
* Stata v.17.0

* does
	* merges together each section of malawi data
	* builds round 1
	* outputs round 1

* assumes
	* raw malawi data 

* TO DO:
	* everything
	

************************************************************************
**# - setup
************************************************************************

* define
	global	root	=	"$data/malawi/raw"
	global	export	=	"$data/malawi/refined"
	global	logout	=	"$data/malawi/logs"
	global  fies 	= 	"$data/analysis/raw/Malawi"

* open log
	cap log 		close
	log using		"$logout/mal_build", append
	
* set local wave number & file number
	local			w = 12
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_`w'" 	
	

*************************************************************************
**# - reshape section on income loss wide data
*************************************************************************	

* no data


*************************************************************************
**# - reshape section on safety nets wide data
*************************************************************************

* no data
	
*************************************************************************
**# - get respondent gender
*************************************************************************	
	
* load data
	use				"$root/wave_`w'/sect12_Interview_result_r`w'", clear
		***obs == 1533

* drop all but household respondant
	keep			HHID s12q9
	rename			s12q9 PID
	isid			HHID

* merge in household roster
	merge 1:1 HHID PID using "$root/wave_`w'/sect2_Household_Roster_r`w'"
		***obs == 7793 | from master not matched - 1  | from using not matched - 6260 | matched == 1532
	keep if			_merge == 3
		*** obs == 1532
	drop			_merge
		*** obs == 1532
		
* drop all but gender and relation to HoH
	keep			HHID PID s2q5 s2q6 s2q7 s2q9

* save temp file
	tempfile		tempc
	save			`tempc'
	
	
*************************************************************************
**# - get household size and gender of HOH
*************************************************************************

* load data
	use				"$root/wave_`w'/sect2_Household_Roster_r`w'", clear
		*** obs == 7792

* rename other variables
	rename			PID ind_id
	rename			s2q3 curr_mem
	replace			curr_mem = 1 if s2q2 == 1
	rename			s2q5 sex_mem
	rename			s2q6 age_mem
	rename			s2q7 relat_mem
	replace			relat_mem = s2q9 if relat_mem == .

* generate counting variables
	gen				hhsize = 1 if curr_mem == 1
	gen				hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem == 1 & age_mem < 19 & age_mem != .
	gen				hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19
		*** obs == 7792

* create hh head gender
	gen				sexhh = .
	replace			sexhh = sex_mem if relat_mem == 1
	lab var			sexhh "Sex of household head"

* generate migration vars
	rename			s2q2 new_mem
	replace			new_mem = 0 if s2q8 == 10
	replace			s2q8 = . if s2q8 == 10
	gen				mem_left = 1 if curr_mem == 2
	replace			new_mem = 0 if new_mem == 2
	replace			mem_left = 0 if mem_left == 2
	
	* why member left
		preserve
			keep		y4 s2q4 ind_id
				*** obs == 7792
			keep		if s2q4 != .
				*** obs == 64
			duplicates drop	y4 s2q4, force
				*** obs == 57
			reshape		wide ind_id, i(y4) j(s2q4)
				*** obs == 54
			ds			ind_id*
			foreach		var in `r(varlist)' {
				replace		`var' = 1 if `var' != .
			}
			rename		ind_id* mem_left_why_*
			tempfile	mem_left
			save		`mem_left'
		restore

	* why new member
		preserve
			keep		y4 s2q8 ind_id
				*** obs == 7792
			keep		if s2q8 < .
				*** obs == 29
			duplicates drop y4 s2q8, force
				*** obs == 28
			reshape		wide ind_id, i(y4) j(s2q8)
				*** obs == 28
			ds			ind_id*
			foreach		var in `r(varlist)' {
				replace		`var' = 1 if `var' != .
			}
			rename		ind_id* new_mem_why_*
			tempfile	new_mem
			save		`new_mem'
		restore

* collapse data to hh level and merge in why vars
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild ///
		new_mem mem_left (max) sexhh, by(HHID y4)
			*** obs == 1533

	replace			new_mem = 1 if new_mem > 0 & new_mem < .
	replace			mem_left = 1 if mem_left >0 & new_mem < .
	merge			1:1 y4 using `new_mem', nogen
		*** obs == 1533: 28 matched, 1505 unmatched
	merge			1:1 y4 using `mem_left', nogen
		*** obs == 1533: 54 matched, 1479 unmatched
	ds				new_mem_why_*
	foreach			var in `r(varlist)' {
		replace			`var' = 0 if `var' >= . & mem_left == 1
	}
	lab var		hhsize "Household size"
	lab var 	hhsize_adult "Household size - only adults"
	lab var 	hhsize_child "Household size - children 0 - 18"
	lab var 	hhsize_schchild "Household size - school-age children 5 - 18"
	lab var 	mem_left "Member of household left since last call"
	lab var 	new_mem "Member of household joined since last call"
	drop 		y4
		*** obs == 1533
	
* save temp file
	tempfile	tempd
	save		`tempd'
	

*************************************************************************
**# - FIES score
*************************************************************************
/*
* load data
	use				"$fies/MW_FIES_round`w'.dta", clear
	drop 			country round 

* merge in other data to get HHID to match 
	rename 			HHID y4_hhid 
	merge 			1:1 y4_hhid using "$root/wave_`w'/secta_Cover_Page_r`w'"
	keep 			HHID hhsize wt_hh p_mod urban weight Above_18 wt_18 p_sev

* save temp file
	tempfile		tempe
	save			`tempe'
*/

*************************************************************************
**# - reshape section on coping wide data
*************************************************************************

* not available for round
	

*************************************************************************
**# - reshape section on livestock
*************************************************************************

* load data
	use				"$root/wave_`w'/sect6e_Livestock_Products_r`w'", clear
		*** obs == 6132

* reshape wide
	gen 			product = cond(LivestockPr == 555, "other", cond(LivestockPr == 1, ///
					"milk",cond(LivestockPr == 2, "eggs",cond(LivestockPr == 3, "meat","manure"))))
		*** obs == 6132
		
	drop 			Livestock
	
	reshape 		wide s6qe*, i(HHID y4_hhid) j(product) string
		*** obs == 1533

* save temp file
	tempfile		tempg
	save			`tempg'
	

*************************************************************************
**# - merge to build complete dataset for the round 
*************************************************************************

* load cover data
	use				"$root/wave_`w'/secta_Cover_Page_r`w'", clear
		*** obs == 1698

* merge formated sections
	foreach		x in c d g {
		merge		1:1 HHID using `temp`x'', nogen
	}
		*** obs == 1698: 1532 matched, 166 unmatched temp c
		*** obs == 1698: 1533 matched, 165 unmatched temps d, g

* merge in other sections
	merge 1:1		HHID using "$root/wave_`w'/sect4_Behavior_r`w'", nogen
		*** obs == 1698: 1533 matched, 165 unmatched
	merge 1:1		HHID using "$root/wave_`w'/sect5_Access_r`w'", nogen
		*** obs == 1698: 1533 matched, 165 unmatched
	merge 1:1		HHID using "$root/wave_`w'/sect5d_ChildDevt_r`w'", nogen
		*** obs == 16898: 1533 matched, 165 unmatched
	merge 1:1		HHID using "$root/wave_`w'/sect6a_Employment2_r`w'", nogen
		*** obs == 1698: 1533 matched, 165 unmatched
	merge 1:1		HHID using "$root/wave_`w'/sect6b_NFE_r`w'", nogen
		*** obs == 1698: 1533 matched, 165 unmatched
	merge 1:1		HHID using "$root/wave_`w'/sect6e_Agriculture_r`w'", nogen
		*** obs == 1698: 1533 matched, 165 unmatched
	merge 1:1		HHID using "$root/wave_`w'/sect8_food_security_r`w'", nogen
		*** obs == 1698: 1533 matched, 165 unmatched
	merge 1:1		HHID using "$root/wave_`w'/sect9_Concerns_r`w'", nogen
		*** obs == 16898: 1533 matched, 165 unmatched

* rename variables inconsistent with other waves
	* behavior
		rename			s4q7 bh_freq_wash
		rename			s4q8 bh_freq_mask
		
	* child development
		rename			s5dq7 s5eq1
		rename			s5dq8 s5eq2
		rename			s5dq9 s5eq3
		rename			s5dq10 s5eq4
		rename			s5dq11 s5eq5
		rename			s5dq12 s5eq6
		rename			s5dq13 s5eq7
		
		rename			s5dq14 s5fq1
		rename			s5dq15 s5fq2
		rename			s5dq16 s5fq3
		rename			s5dq17 s5fq4
		rename			s5dq18 s5fq5
		rename			s5dq19 s5fq6

		rename			s5dq20 ac_internet
		
		rename			s5dq21 s5gq21
		rename			s5dq22 s5gq22
		rename			s5dq23 s5gq23
		rename			s5dq24 s5gq24
		rename			s5dq25 s5gq25
		rename			s5dq26 s5gq26
		rename			s5dq27 s5gq27
		rename			s5dq28 s5gq28
		
		rename			s5dq29 s5iq1
		rename			s5dq30 s5iq2
		rename			s5dq31 s5iq3
		rename			s5dq32 s5iq4
		rename			s5dq33 s5iq5
		rename			s5dq34 s5iq6
		
		rename			s5dq35 s5jq1
		rename			s5dq36 s5jq2
		rename			s5dq37 s5jq3
		rename			s5dq38 s5jq4
		rename			s5dq39 s5jq5
		rename			s5dq40 s5jq6
		rename			s5dq41 s5jq7
	
	* employment
		rename			s6q3a emp_search
		rename			s6q3b emp_search_how
		rename			s6q5 emp_act
		replace 		emp_act = -96 if emp_act == 96
		replace 		emp_act = 16 if emp_act == 15
		replace 		emp_act = 14 if emp_act == 9
		replace 		emp_act = 9 if emp_act == 11 | emp_act == 12
		replace 		emp_act = 11 if emp_act == 4
		replace 		emp_act = 4 if emp_act == 7
		replace 		emp_act = 7 if emp_act == 10
		replace 		emp_act = 13 if emp_act == 8
		replace 		emp_act = 8 if emp_act == 6
		replace 		emp_act = 13 if emp_act == 8
	
		lab val 		emp_act emp_act
		
	* agriculture
		rename			preload_agric ag_crop
		replace			ag_crop = s6aq2 if ag_crop >= .
		replace			ag_crop = . if ag_crop == 4
		rename			s6aq3__1 ag_crop_who
		rename			s6aq5 ag_main
		rename			s6aq6 ag_main_harv_comp
		rename			s6aq7 ag_main_sell // note there might be sme issues for total ag revenue not sure how to proceed
		rename			s6aq9 harv_sell_need
		rename			s6aq10 harv_sell
		
		gen				s6eq4__1 = . // note this is home/farm sale
		replace			s6eq4__1 = 1 if s6aq11 == 1
		replace			s6eq4__1 = 0 if s6eq4__1 == .
		
		gen				s6qe4__2 = . // note this is daily market
		replace			s6qe4__2 = 1 if s6aq11 == 2
		replace			s6qe4__2 = 0 if s6qe4__2 == .
		
		gen				s6qe4__3 = . // note this is weekly market
		replace			s6qe4__3 = 1 if s6aq11 == 3
		replace			s6qe4__3 = 0 if s6qe4__3 == .
		
		drop			s6aq3a s6aq4 s6aq5_* s6aq3__2 /// note unsure of what to do with q8/8b in 6e-12
	
* generate round variables
	gen				wave = `w'
		*** obs == 1698
	lab var			wave "Wave number"
	rename			wt_round`w' phw_cs
	label var		phw "sampling weights - cross section"
	
* save round file
	save			"$export/wave_`w'/r`w'", replace
	
/* END */
	
	