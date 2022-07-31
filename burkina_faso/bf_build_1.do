* Project: WB COVID
* Created on: April 2021
* Created by: amf
* Edited by: amf, lirr (style edits)
* Last edit: 25 July 2022
* Stata v.17.0

* does
	* reads in first round of BF data
	* builds round 1
	* outputs round 1

* assumes
	* raw BF data

* TO DO:
	* complete


*************************************************************************
**#- setup
*************************************************************************

* define 
	global	root	=	"$data/burkina_faso/raw"
	global	export	=	"$data/burkina_faso/refined"
	global	logout	=	"$data/burkina_faso/logs"
	global  fies 	= 	"$data/analysis/raw/Burkina_Faso"

* open log
	cap log 		close
	log using		"$logout/bf_build", append

* set local wave number & file number
	local			w = 1
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir 	"$export/wave_0`w'" 

	
*************************************************************************
**# - get respondent data
*************************************************************************	

* load respondant id data	
	use 			"$root/wave_0`w'/r`w'_sec1a_info_entretien_tentative", clear
		*** obs == 4494
	keep 			if s01aq08 == 1
		*** obs == 2039
	rename 			s01aq09 membres__id
	duplicates 		drop hhid membres__id, force
		*** obs == 1979
	duplicates		tag hhid, gen(dups)
	replace 		membres__id = -96 if dups > 0
	duplicates 		drop hhid membres__id, force
		*** obs == 1968
	lab def 		mem -96 "multiple respondents"
	lab val 		membres__id mem
	keep 			hhid membres__id
		*** obs == 1968

* load roster data with gender
	merge 1:1		hhid membres__id using "$root/wave_0`w'/r`w'_sec2_liste_membre_menage"
		*** obs == 13249: 1930 matched, 11319 unmatched
	keep 			if _m == 1 | _m == 3
		*** obs == 1968
	keep 			hhid s02q05 membres__id s02q07 s02q06
		*** obs == 1968
	rename 			membres__id resp_id
	rename 			s02q05 sex
	rename 			s02q06 age
	rename 			s02q07 relate_hoh

* save temp file
	tempfile		tempa
	save			`tempa'
	

*************************************************************************
**# - get household size and gender of HOH
*************************************************************************	

* load roster data	
	use 			"$root/wave_0`w'/r`w'_sec2_liste_membre_menage", clear
		*** obs == 13211

* rename other variables 
	rename 			membres__id ind_id 
	rename 			s02q03 curr_mem
	replace 		curr_mem = 1 if s02q02 == 1
	rename 			s02q05 sex_mem
	rename 			s02q06 age_mem
	rename 			s02q07 relat_mem
	replace			relat_mem = s02q09b if relat_mem == . 
	
* generate counting variables
	gen				hhsize = 1 if curr_mem == 1
	gen 			hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem == 1 & age_mem < 19 & age_mem != . 
	gen 			hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19 
		*** obs == 13211
		
* generate hh head gender variable
	gen 			sexhh = .
	replace 		sexhh = sex_mem if relat_mem== 1
	lab var 		sexhh "Sex of household head"
	
* generate migration vars
	rename 			s02q02 new_mem
	replace 		new_mem = 0 if s02q08 == 10
	replace 		s02q08 = . if s02q08 == 10
	gen 			mem_left = 1 if curr_mem == 2
	replace 		new_mem = 0 if new_mem == 2
	replace 		mem_left = 0 if mem_left == 2
	
	replace 		s02q04 = 123 if s02q04 == 2
	replace 		s02q04 = 2 if s02q04 == 3
	replace 		s02q04 = 3 if s02q04 == 123
	
	* why member left
		preserve
			keep 		hhid s02q04 ind_id
				*** obs == 13211
			keep 		if s02q04 != .
				*** obs == 593
			duplicates 	drop hhid s02q04, force
				*** obs == 391
			reshape 	wide ind_id, i(hhid) j(s02q04)
				*** obs == 326
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
			keep 		hhid s02q08 ind_id
				*** obs == 13211
			keep 		if s02q08 != .
				*** obs == 823
			duplicates 	drop hhid s02q08, force
				*** obs == 629
			reshape 	wide ind_id, i(hhid) j(s02q08)
				*** obs == 512
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
		*** obs == 1968
	replace 	new_mem = 1 if new_mem > 0 & new_mem < .
	replace 	mem_left = 1 if mem_left > 0 & new_mem < .	
	merge 		1:1 hhid using `new_mem', nogen
		*** obs == 1968: 512 matched, 1456 unmatched
	merge 		1:1 hhid using `mem_left', nogen
		*** obs == 1968: 326 matched, 1642 unmatched
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
	tempfile		tempb
	save			`tempb'
	
	
*************************************************************************
**# - merge
*************************************************************************

* load cover data
	use 		"$root/wave_0`w'/r`w'_sec0_cover", clear
		*** obs == 1968
	
* merge formatted sections
	foreach 		x in a b {
	    merge 		1:1 hhid using `temp`x'', nogen
	}
		*** obs == 1968: 1968 matched, 0 unmatched for temp a and b
		
* merge in other sections
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec3_connaisance_covid19", nogen
		*** obs == 1968: 1968 matched, 0 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec4_comportaments", nogen
		*** obs == 1968: 1968 matched, 0 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec5_acces_service_base", nogen
		*** obs == 1968: 1968 matched, 0 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec6_emploi_revenue", nogen
		*** obs == 1968: 1968 matched, 0 unmatched
		
* clean variables inconsistent with other rounds
	* ac_med
	rename 			s05q01 ac_med
	
	rename 			s05q03e ac_medserv_why
	replace 		ac_medserv_why = . if ac_medserv_why == 4
	rename 			s05q03d ac_medserv_oth
	
	* farming
	rename 			s06q16__1 farm_why_1
	rename 			s06q16__2 farm_why_2
	rename 			s06q16__3 farm_why_3
	rename 			s06q16__4 farm_why_4
	rename 			s06q16__5 farm_why_5
	rename 			s06q16__6 farm_why_6
	rename 			s06q16__7 farm_why_8
	drop  			s06q16_autre 
	rename 			s06q14 farm_emp
	
	* education 
	rename 			s05q05 sch_child
	rename 			s05q06__1 edu_1
	replace 		edu_1 = 1 if s05q06__7 == 1
	rename 			s05q06__2 edu_other 
	replace 		edu_other = 1 if s05q06__8 == 1
	rename 			s05q06__3 edu_13
	rename 			s05q06__4 edu_14
	rename 			s05q06__5 edu_2
	rename 			s05q06__6 edu_3
	rename 			s05q06__9 edu_15
	rename 			s05q06__10 edu_4
	rename 			s05q06__11 edu_16
	rename 			s05q06__12 edu_9
	rename 			s05q06__13 edu_7
	gen 			edu_act = 1 if s05q06__14 == 0
	replace 		edu_act = 0 if s05q06__14 == 1
	drop 			s05q06__7 s05q06__8 s05q06__14 
	rename 			s05q07 edu_cont
	
	forval 			x = 1/8 {
		rename 		s05q08__`x' edu_cont_`x'
	}
		
* generate round variables
	gen				wave = `w'
	lab var			wave "Wave number"
	rename 			hhwcovid_r`w' phw_cs
	label var		phw_cs "sampling weights - cross section"
		*** obs == 1968
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace

/* END */		