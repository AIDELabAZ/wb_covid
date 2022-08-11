* Project: WB COVID
* Created on: April 2021
* Created by: amf
* Edited by: amf, lirr (style edits)
* Last edit: 09 Aug 2022
* Stata v.17.0

* does
	* reads in ninth round of BF data
	* builds round 9
	* outputs round 9

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
	local			w = 9
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir 	"$export/wave_0`w'" 


*************************************************************************
**# - get respondent data
*************************************************************************

* load respondant id data	
	use 			"$root/wave_0`w'/r`w'_sec1a_info_entretien_tentative", clear
		*** obs == 2848
	keep 			if s01aq08 == 1
		*** obs == 1974
	rename 			s01aq09 membres__id
	duplicates 		drop hhid membres__id, force
		*** obs == 1971
	duplicates		tag hhid, gen(dups)
	replace 		membres__id = -96 if dups > 0
	duplicates 		drop hhid membres__id, force
		*** obs == 1971
	lab def 		mem -96 "multiple respondents"
	lab val 		membres__id mem
	keep 			hhid membres__id

* load roster data with gender
	merge 1:1		hhid membres__id using "$root/wave_0`w'/r`w'_sec2_liste_membre_menage"
		*** obs == 13241: 1971 matched, 11270 unmatched
	keep 			if _m == 1 | _m == 3
		*** obs == 1971
	keep 			hhid s02q05 membres__id s02q07 s02q06
		*** obs == 1971
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
		*** obs == 13241
	
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
		*** obs == 13241
	
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
				*** obs == 13241
			keep 		if s02q04 != .
				*** obs == 12
			duplicates 	drop hhid s02q04, force
				*** obs == 12
			reshape 	wide ind_id, i(hhid) j(s02q04)
				*** obs == 11
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
				*** obs == 13241
			keep 		if s02q08 != .
				*** obs == 53
			duplicates 	drop hhid s02q08, force
				*** obs == 42
			reshape 	wide ind_id, i(hhid) j(s02q08)
				*** obs == 38
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
		*** obs == 1971
	replace 	new_mem = 1 if new_mem > 0 & new_mem < .
	replace 	mem_left = 1 if mem_left > 0 & new_mem < .	
	merge 		1:1 hhid using `new_mem', nogen
		*** obs == 1971: 38 matched, 1933 unmatched
	merge 		1:1 hhid using `mem_left', nogen
		*** obs == 1971: 11 matched, 1960 unmatched
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
		*** obs == 15768
	
* drop other vars
	keep 		hhid revenu__id s08q0*
		*** obs == 15768
	
* reshape 
	reshape 	wide s08q0*, i(hhid) j(revenu__id)
		*** obs == 1971
	
* format vars
	rename 		s08q011 rem_for
	rename 		s08q012 rem_dom
	rename 		s08q013 asst_inc
	rename 		s08q014 isp_inc
	rename 		s08q015 pen_inc
	rename 		s08q016 farm_inc
	rename 		s08q017 bus_inc
	rename 		s08q018 wage_inc
	
	rename 		s08q021 rem_for_chg
	rename 		s08q022 rem_dom_chg
	rename 		s08q023 asst_chg
	rename 		s08q024 isp_chg
	rename 		s08q025 pen_chg
	rename 		s08q026 farm_chg
	rename 		s08q027 bus_chg
	rename 		s08q028 wage_chg
	
	rename 		s08q031 rem_for_chg_cov
	rename 		s08q032 rem_dom_chg_cov
	rename 		s08q033 asst_chg_cov
	rename 		s08q034 isp_chg_cov
	rename 		s08q035 pen_chg_cov
	rename 		s08q036 farm_chg_cov
	rename 		s08q037 bus_chg_cov
	rename 		s08q038 wage_chg_cov
	
* save temp file
	tempfile		tempc
	save			`tempc'
	

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
		*** obs == 1998
	
* merge formatted sections
	foreach 		x in a b c {
	    merge 		1:1 hhid using `temp`x'', nogen
	}
		*** obs == 1998: 1971 matched, 27 unmatched

* merge in other sections
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec5_acces_service_base", nogen
		*** obs == 1998: 1971 matched, 27 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec6a_emplrev_general", nogen
		*** obs == 1998: 1971 matched, 27 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec6b_emplrev_travailsalarie", nogen
		*** obs == 1998: 1971 matched, 27 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec6c_emplrev_nonagr", nogen
		*** obs == 1998: 1971 matched, 27 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec7_securite_alimentaire", nogen
		*** obs == 1998: 1971 matched, 27 unmatched

* clean variables inconsistent with other rounds
	
	* ac_med
	rename 			s05q01a ac_med
	replace 		ac_med = 1 if ac_med == 2 | ac_med == 3 | ac_med == 4
	replace 		ac_med = 2 if ac_med == 5
	replace 		ac_med = 3 if ac_med == 6
	
	* employment 
	rename 			s06q04_0 emp_chg_why
	drop 			s06q04_0_autre
		*** obs == 1998
	replace 		emp_chg_why = 96 if emp_chg_why == 13
	
* generate round variables
	gen				wave = `w'
	lab var			wave "Wave number"
	rename 			hhwcovid_r`w'_cs phw_cs
	rename 			hhwcovid_r`w'_pnl phw_pnl
	label var		phw_cs "sampling weights- cross section"
	label var		phw_pnl "sampling weights- panel"
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace

/* END */		