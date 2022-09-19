* Project: WB COVID
* Created on: April 2021
* Created by: amf
* Edited by: amf, lirr (style edits)
* Last edit: 09 Aug 2022 
* Stata v.17.0

* does
	* reads in eighth round of BF data
	* builds round 8
	* outputs round 8

* assumes
	* raw BF data

* TO DO:
	* GET FIES DATA


*************************************************************************
**# - setup
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
	local			w = 8
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir 	"$export/wave_0`w'" 


*************************************************************************
**# - get respondent data
*************************************************************************	

* load respondant id data	
	use 			"$root/wave_0`w'/r`w'_sec1a_info_entretien_tentative", clear
		*** obs == 2888
	keep 			if s01aq08 == 1
	rename 			s01aq09 membres__id
	duplicates 		drop hhid membres__id, force
		*** obs == 1968
	duplicates		tag hhid, gen(dups)
	replace 		membres__id = -96 if dups > 0
	duplicates 		drop hhid membres__id, force
		*** obs == 1967
	lab def 		mem -96 "multiple respondents"
	lab val 		membres__id mem
	keep 			hhid membres__id
		*** obs == 1967

* load roster data with gender
	merge 1:1		hhid membres__id using "$root/wave_0`w'/r`w'_sec2_liste_membre_menage"
		*** obs == 13171: 1966 matched, 11205 unmatched
	keep 			if _m == 1 | _m == 3
		*** obs == 1967
	keep 			hhid s02q05 membres__id s02q07 s02q06
		*** obs == 1967
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
		*** obs == 13170
	
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
		*** obs == 13170
	
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
				*** obs == 13170
			keep 		if s02q04 != .
				*** obs == 33
			duplicates 	drop hhid s02q04, force
				*** obs == 29
			reshape 	wide ind_id, i(hhid) j(s02q04)
				*** obs == 27
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
				*** obs == 13170
			keep 		if s02q08 != .
				*** obs == 47
			duplicates 	drop hhid s02q08, force
				*** obs == 43
			reshape 	wide ind_id, i(hhid) j(s02q08)
				*** obs == 37
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
		*** obs == 1967
	replace 	new_mem = 1 if new_mem > 0 & new_mem < .
	replace 	mem_left = 1 if mem_left > 0 & new_mem < .	
	merge 		1:1 hhid using `new_mem', nogen
		*** obs == 1967: 37 matched, 1930 unmatched
	merge 		1:1 hhid using `mem_left', nogen
		*** obs == 1967: 27 matched, 1940 unmatched
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
**# - other revenues
*************************************************************************		
	
* load data	
	use 		"$root/wave_0`w'/r`w'_sec8_autres_revenu", clear
		*** obs == 9835
	
* drop other vars
	keep 		hhid revenu__id s08q0*
		*** obs == 9835
	
* reshape 
	reshape 	wide s08q0*, i(hhid) j(revenu__id)
		*** obs == 1967
	
* format vars
	rename 		s08q011 oth_inc_1
	rename 		s08q012 oth_inc_2
	rename 		s08q013 oth_inc_3
	rename 		s08q014 oth_inc_4
	rename 		s08q015 oth_inc_5
	
	rename 		s08q021 oth_inc_chg_1
	rename 		s08q022 oth_inc_chg_2
	rename 		s08q023 oth_inc_chg_3
	rename 		s08q024 oth_inc_chg_4
	rename 		s08q025 oth_inc_chg_5
	
* save temp file
	tempfile		tempc
	save			`tempc'
	
	
*************************************************************************
**# - shocks
*************************************************************************		

* load data
	use 			"$root/wave_0`w'/r`w'_sec9_Chocs", clear
		*** obs == 25571

* drop other shock
	drop			s09q03_autre
		*** obs == 25571
	
* generate shock variables
	forval 			x = 1/13 {
		gen 		shock_`x' = s09q01 if chocs__id == `x'
	}

* collapse to household level	
	collapse 		(max) s09q03__1-shock_13, by(hhid)
		*** obs == 1967
	
* save temp file
	tempfile		tempd
	save			`tempd'	
	

*************************************************************************
**# - FIES
*************************************************************************	
/*
* load data
	use 			"$fies/BFA_FIES_round`w'", clear
	
* format hhid & vars
	destring 		HHID, gen(hhid)
	drop 			country round HHID
	
* save temp file
	tempfile		tempe
	save			`tempe'	

*/	
	

*************************************************************************
**# - merge
*************************************************************************

* load cover data
	use 		"$root/wave_0`w'/r`w'_sec0_cover", clear
		*** obs == 2011
	
* merge formatted sections
	foreach 		x in a b c d {
	    merge 		1:1 hhid using `temp`x'', nogen
	}
		*** obs == 2011: 1967 matched, 44 unmatched

* merge in other sections
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec2c_developpement_enfance", nogen
		*** obs == 2011: 1494 matched, 517 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec5_acces_service_base", nogen
		*** obs == 2011: 1967 matched, 44 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec6a_emplrev_general", nogen
		*** obs == 2011: 1967 matched, 44 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec6c_emplrev_nonagr", nogen
		*** obs == 2011: 1967 matched, 44 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec11_frag_confl_violence", nogen
		*** obs == 2011: 1967 matched, 44 unmatched

* clean variables inconsistent with other rounds
	* employment 
	rename 			s06q04_0 emp_chg_why
	drop 			s06q04_0_autre
	replace 		emp_chg_why = 96 if emp_chg_why == 13

* generate round variables
	gen				wave = `w'
		*** obs == 2011
	lab var			wave "Wave number"
	rename 			hhwcovid_r`w'_cs phw_cs
	rename 			hhwcovid_r`w'_pnl phw_pnl
	label var		phw_cs "sampling weights- cross section"
	label var		phw_pnl "sampling weights- panel"
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace

/* END */		