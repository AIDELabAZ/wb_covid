* Project: WB COVID
* Created on: April 2021
* Created by: amf
* Edited by: lirr
* Last edit: 19 June 2023
* Stata v.17.0

* does
	* reads in third round of BF data
	* builds round 3
	* outputs round 3

* assumes
	* raw BF data

* TO DO:
	* complete


************************************************************************
**# - setup
************************************************************************

* define 
	global	root	=	"$data/burkina_faso/raw"
	global	export	=	"$data/burkina_faso/refined"
	global	logout	=	"$data/burkina_faso/logs"
	global  fies 	= 	"$data/analysis/raw/Burkina_Faso"

* open log
	cap log 		close
	log using		"$logout/bf_build", append

* set local wave number & file number
	local			w = 3
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir 	"$export/wave_0`w'" 

	
*************************************************************************
**# - get respondent data
*************************************************************************	

* load respondant id data	
	use 			"$root/wave_0`w'/r`w'_sec1a_info_entretien_tentative", clear
		*** obs == 3686
	keep 			if s01aq08 == 1
		*** obs == 2051
	rename 			s01aq09 membres__id
	duplicates 		drop hhid membres__id, force
		*** obs == 2019
	duplicates		tag hhid, gen(dups)
	replace 		membres__id = -96 if dups > 0
	duplicates 		drop hhid membres__id, force
		*** obs == 2013
	lab def 		mem -96 "multiple respondents"
	lab val 		membres__id mem
	keep 			hhid membres__id
		*** obs == 2013

* load roster data with gender
	merge 1:1		hhid membres__id using "$root/wave_0`w'/r`w'_sec2_liste_membre_menage"
		*** obs == 13455: 1999 matched, 11456 unmatched
	keep 			if _m == 1 | _m == 3
		*** obs == 2013
	keep 			hhid s02q05 membres__id s02q07 s02q06
		*** obs == 2013
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
		*** obs == 13441
	
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
		*** obs == 13441
	
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
				*** obs == 13441
			keep 		if s02q04 != .
				*** obs == 81
			duplicates 	drop hhid s02q04, force
				*** obs == 70
			reshape 	wide ind_id, i(hhid) j(s02q04)
				*** obs == 59
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
				*** obs == 13441
			keep 		if s02q08 != .
				*** obs == 154
			duplicates 	drop hhid s02q08, force
				*** obs == 111
			reshape 	wide ind_id, i(hhid) j(s02q08)
				*** obs == 98
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
		*** obs == 2011
	replace 	new_mem = 1 if new_mem > 0 & new_mem < .
	replace 	mem_left = 1 if mem_left > 0 & new_mem < .	
	merge 		1:1 hhid using `new_mem', nogen
		*** obs == 2011: 98 matched, 1913 unmatched
	merge 		1:1 hhid using `mem_left', nogen
		*** obs == 2011: 59 matched, 1952 unmatched
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
		*** obs == 10065
	
* drop other vars
	keep 		hhid revenu__id s08q0*
		*** obs == 10065
	
* reshape 
	reshape 	wide s08q0*, i(hhid) j(revenu__id)
		*** obs == 2013
	
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
**# - assistance
*************************************************************************

* load data	
	use 		"$root/wave_0`w'/r`w'_sec10_protection_sociale", clear
		*** obs == 6039
	
* drop other vars
	keep 		hhid assistance__id s10q01
		*** obs == 6039
	
* reshape 
	reshape 	wide s10q01, i(hhid) j(assistance__id)
		*** obs == 2013

* format vars
	rename 		s10q01101 asst_food
	rename 		s10q01102 asst_cash
	rename 		s10q01103 asst_kind
	
	replace 	asst_food = 0 if asst_food == 2
	replace 	asst_cash = 0 if asst_cash == 2
	replace 	asst_kind = 0 if asst_kind == 2
	
	gen				asst_any = 0 if asst_food == 0 | asst_cash == 0 | ///
						asst_kind == 0
	replace 		asst_any = 1 if asst_food == 1 | asst_cash == 1 | ///
						asst_kind == 1

* save temp file
	tempfile		tempd
	save			`tempd'
	

*************************************************************************
**# - FIES
*************************************************************************	

* load data
	use 			"$fies/BF_FIES_round`w'", clear
		*** obs == 2011
	
* format hhid & vars
	destring 		HHID, gen(hhid)
	drop 			country round HHID
		*** obs == 2011
	
* save temp file
	tempfile		tempe
	save			`tempe'	
	
	
*************************************************************************
**# - Top crops and cropcodes
*************************************************************************		
	
* load data
	use				"$data/burkina_faso/raw/wave_0`w'/r`w'_sec6d_emplrev_agr", clear
		*** obs == 2013

* keep variables with crop id codes
	keep			hhid s06q16_*
	drop			s06q16_autre

	forval			i = 1/55 {
		replace			s06q16__`i' = . if s06q16__`i' == 0
	}

	
* extract variables from list of crops
	ds				s06q16_* // creates r class variable for looping over crop vars
	gen				cc_1 = "." // itermediate step to get all crop codes
 

* create loop to extract variable name
	foreach			var in `r(varlist)' {
		replace				cc_1 = "`var'" if `var' == 1
	}
	
	ds				s06q16_*

* loop to replace variable to ensure all crops accounted for
	foreach			var in `r(varlist)' {
		replace			`var' = . if cc_1 == "`var'"
	}

* trim unnecessary string characters	
	ereplace		cc_1 = ends(cc_1), punct(__) last
	destring		cc_1, replace
	sort			cc_1
	
* extract variables from list of crops
	ds				s06q16_* // creates r class variable for looping over crop vars
	gen				cc_2 = "." // itermediate step to get all crop codes
 

* create loop to extract variable name
	foreach			var in `r(varlist)' {
		replace				cc_2 = "`var'" if `var' == 1
	}
	
	ds				s06q16_*

* loop to replace variable to ensure all crops accounted for
	foreach			var in `r(varlist)' {
		replace			`var' = . if cc_2 == "`var'"
	}
	
* trim unnecessary string characters	
	ereplace		cc_2 = ends(cc_2), punct(__) last
	destring		cc_2, replace
	sort			cc_2
	
* extract variables from list of crops
	ds				s06q16_* // creates r class variable for looping over crop vars
	gen				cc_3 = "." // itermediate step to get all crop codes
 

* create loop to extract variable name
	foreach			var in `r(varlist)' {
		replace				cc_3 = "`var'" if `var' == 1
	}
	
	ds				s06q16_*

* loop to replace variable to ensure all crops accounted for
	foreach			var in `r(varlist)' {
		replace			`var' = . if cc_3 == "`var'"
	}
	
* trim unnecessary string characters	
	ereplace		cc_3 = ends(cc_3), punct(__) last
	destring		cc_3, replace

* drop irrelevant variables
	drop			s06*
	
* generate FAO consistent variables
	gen				fao_1 = cc_1
	gen				fao_2 = cc_2
	gen				fao_3 = cc_3
	
* replace bf cc_1 with icc1.1 style crop codes
	replace			fao_1 = 108 if cc_1 == 1 
	replace			fao_1 = 104 if cc_1 == 2 
	replace			fao_1 = 103 if cc_1 == 3 
	replace			fao_1 = 102 if cc_1 == 4 
	replace			fao_1 = 59 if cc_1 == 5 
	replace			fao_1 = 102 if cc_1 == 6 
	replace			fao_1 = 111 if cc_1 == 7 
	replace			fao_1 = 704 if cc_1 == 8 
	replace			fao_1 = 709 if cc_1 == 9 
	replace			fao_1 = 402 if cc_1 == 10 
	
	replace			fao_1 = 20205 if cc_1 == 11 
	replace			fao_1 = 9020102 if cc_1 == 12 
	replace			fao_1 = 40307 if cc_1 == 13 
	replace			fao_1 = 503 if cc_1 == 14 
	replace			fao_1 = 504 if cc_1 == 15 
	replace			fao_1 = 501 if cc_1 == 16 
	replace			fao_1 = 6020201 if cc_1 == 17 
	replace			fao_1 = 6020205 if cc_1 == 18 
	replace			fao_1 = 6020204 if cc_1 == 19 
	replace			fao_1 = 9030101 if cc_1 == 20 

	replace			fao_1 = 20106 if cc_1 == 21 
	replace			fao_1 = 20190 if cc_1 == 22 
	replace			fao_1 = 6020102 if cc_1 == 23 
	replace			fao_1 = 6020101 if cc_1 == 24 
	replace			fao_1 = 20502 if cc_1 == 25 
	replace			fao_1 = 20501 if cc_1 == 26 
	replace			fao_1 = 20105 if cc_1 == 27 
	replace			fao_1 = 20103 if cc_1 == 28 
	replace			fao_1 = 20203 if cc_1 == 29 
	replace			fao_1 = 20301 if cc_1 == 30 
	
	replace			fao_1 = 20202 if cc_1 == 31 
	replace			fao_1 = 20202 if cc_1 == 32 
	replace			fao_1 = 20304 if cc_1 == 33 
	replace			fao_1 = 20201 if cc_1 == 34 
	replace			fao_1 = 20204 if cc_1 == 35 
	replace			fao_1 = 20303 if cc_1 == 36 
	replace			fao_1 = 701 if cc_1 == 37 
	replace			fao_1 = 20204 if cc_1 == 38 
	replace			fao_1 = 20309 if cc_1 == 39 
	replace			fao_1 = 20302 if cc_1 == 40 

	replace			fao_1 = 20305 if cc_1 == 41 
	replace			fao_1 = 9020101 if cc_1 == 43 
	replace			fao_1 = 801 if cc_1 == 44 
	replace			fao_1 = 20302 if cc_1 == 45 
	replace			fao_1 = 505 if cc_1 == 46 
	replace			fao_1 = 504 if cc_1 == 47 
	replace			fao_1 = 60104 if cc_1 == 48 
	replace			fao_1 = 60101 if cc_1 == 49 
	replace			fao_1 = 60102 if cc_1 == 50 
	
	replace			fao_1 = 40403 if cc_1 == 51 
	replace			fao_1 = 904 if cc_1 == 52 
	replace			fao_1 = 302 if cc_1 == 53 
	replace			fao_1 = 30106 if cc_1 == 54 
	replace			fao_1 = 99 if cc_1 == 55 
	
* replace bf cc_2 with icc1.1 style crop codes
	replace			fao_2 = 108 if cc_2 == 1 
	replace			fao_2 = 104 if cc_2 == 2 
	replace			fao_2 = 103 if cc_2 == 3 
	replace			fao_2 = 102 if cc_2 == 4 
	replace			fao_2 = 59 if cc_2 == 5 
	replace			fao_2 = 102 if cc_2 == 6 
	replace			fao_2 = 111 if cc_2 == 7 
	replace			fao_2 = 704 if cc_2 == 8 
	replace			fao_2 = 709 if cc_2 == 9 
	replace			fao_2 = 402 if cc_2 == 10 
	
	replace			fao_2 = 20205 if cc_2 == 11 
	replace			fao_2 = 9020102 if cc_2 == 12 
	replace			fao_2 = 40307 if cc_2 == 13 
	replace			fao_2 = 503 if cc_2 == 14 
	replace			fao_2 = 504 if cc_2 == 15 
	replace			fao_2 = 501 if cc_2 == 16 
	replace			fao_2 = 6020201 if cc_2 == 17 
	replace			fao_2 = 6020205 if cc_2 == 18 
	replace			fao_2 = 6020204 if cc_2 == 19 
	replace			fao_2 = 9030101 if cc_2 == 20 

	replace			fao_2 = 20106 if cc_2 == 21 
	replace			fao_2 = 20190 if cc_2 == 22 
	replace			fao_2 = 6020102 if cc_2 == 23 
	replace			fao_2 = 6020101 if cc_2 == 24 
	replace			fao_2 = 20502 if cc_2 == 25 
	replace			fao_2 = 20501 if cc_2 == 26 
	replace			fao_2 = 20105 if cc_2 == 27 
	replace			fao_2 = 20103 if cc_2 == 28 
	replace			fao_2 = 20203 if cc_2 == 29 
	replace			fao_2 = 20301 if cc_2 == 30 
	
	replace			fao_2 = 20202 if cc_2 == 31 
	replace			fao_2 = 20202 if cc_2 == 32 
	replace			fao_2 = 20304 if cc_2 == 33 
	replace			fao_2 = 20201 if cc_2 == 34 
	replace			fao_2 = 20204 if cc_2 == 35 
	replace			fao_2 = 20303 if cc_2 == 36 
	replace			fao_2 = 701 if cc_2 == 37 
	replace			fao_2 = 20204 if cc_2 == 38 
	replace			fao_2 = 20309 if cc_2 == 39 
	replace			fao_2 = 20302 if cc_2 == 40 

	replace			fao_2 = 20305 if cc_2 == 41 
	replace			fao_2 = 9020101 if cc_2 == 43 
	replace			fao_2 = 801 if cc_2 == 44 
	replace			fao_2 = 20302 if cc_2 == 45 
	replace			fao_2 = 505 if cc_2 == 46 
	replace			fao_2 = 504 if cc_2 == 47 
	replace			fao_2 = 60104 if cc_2 == 48 
	replace			fao_2 = 60101 if cc_2 == 49 
	replace			fao_2 = 60102 if cc_2 == 50 
	
	replace			fao_2 = 40403 if cc_2 == 51 
	replace			fao_2 = 904 if cc_2 == 52 
	replace			fao_2 = 302 if cc_2 == 53 
	replace			fao_2 = 30106 if cc_2 == 54 
	replace			fao_2 = 99 if cc_2 == 55 
		
* replace bf cc_3 with icc1.1 style crop codes
	replace			fao_3 = 108 if cc_3 == 1 
	replace			fao_3 = 104 if cc_3 == 2 
	replace			fao_3 = 103 if cc_3 == 3 
	replace			fao_3 = 102 if cc_3 == 4 
	replace			fao_3 = 59 if cc_3 == 5 
	replace			fao_3 = 102 if cc_3 == 6 
	replace			fao_3 = 111 if cc_3 == 7 
	replace			fao_3 = 704 if cc_3 == 8 
	replace			fao_3 = 709 if cc_3 == 9 
	replace			fao_3 = 402 if cc_3 == 10 
	
	replace			fao_3 = 20205 if cc_3 == 11 
	replace			fao_3 = 9020102 if cc_3 == 12 
	replace			fao_3 = 40307 if cc_3 == 13 
	replace			fao_3 = 503 if cc_3 == 14 
	replace			fao_3 = 504 if cc_3 == 15 
	replace			fao_3 = 501 if cc_3 == 16 
	replace			fao_3 = 6020201 if cc_3 == 17 
	replace			fao_3 = 6020205 if cc_3 == 18 
	replace			fao_3 = 6020204 if cc_3 == 19 
	replace			fao_3 = 9030101 if cc_3 == 20 

	replace			fao_3 = 20106 if cc_3 == 21 
	replace			fao_3 = 20190 if cc_3 == 22 
	replace			fao_3 = 6020102 if cc_3 == 23 
	replace			fao_3 = 6020101 if cc_3 == 24 
	replace			fao_3 = 20502 if cc_3 == 25 
	replace			fao_3 = 20501 if cc_3 == 26 
	replace			fao_3 = 20105 if cc_3 == 27 
	replace			fao_3 = 20103 if cc_3 == 28 
	replace			fao_3 = 20203 if cc_3 == 29 
	replace			fao_3 = 20301 if cc_3 == 30 
	
	replace			fao_3 = 20202 if cc_3 == 31 
	replace			fao_3 = 20202 if cc_3 == 32 
	replace			fao_3 = 20304 if cc_3 == 33 
	replace			fao_3 = 20201 if cc_3 == 34 
	replace			fao_3 = 20204 if cc_3 == 35 
	replace			fao_3 = 20303 if cc_3 == 36 
	replace			fao_3 = 701 if cc_3 == 37 
	replace			fao_3 = 20204 if cc_3 == 38 
	replace			fao_3 = 20309 if cc_3 == 39 
	replace			fao_3 = 20302 if cc_3 == 40 

	replace			fao_3 = 20305 if cc_3 == 41 
	replace			fao_3 = 9020101 if cc_3 == 43 
	replace			fao_3 = 801 if cc_3 == 44 
	replace			fao_3 = 20302 if cc_3 == 45 
	replace			fao_3 = 505 if cc_3 == 46 
	replace			fao_3 = 504 if cc_3 == 47 
	replace			fao_3 = 60104 if cc_3 == 48 
	replace			fao_3 = 60101 if cc_3 == 49 
	replace			fao_3 = 60102 if cc_3 == 50 
	
	replace			fao_3 = 40403 if cc_3 == 51 
	replace			fao_3 = 904 if cc_3 == 52 
	replace			fao_3 = 302 if cc_3 == 53 
	replace			fao_3 = 30106 if cc_3 == 54 
	replace			fao_3 = 99 if cc_3 == 55 
		
	
* save temp file
	tempfile		tempf
	save			`tempf'	
			

*************************************************************************
**# - merge
*************************************************************************

* load cover data
	use 		"$root/wave_0`w'/r`w'_sec0_cover", clear
		*** obs == 2120
	
* merge formatted sections
	foreach 		x in a b c d e f {
	    merge 		1:1 hhid using `temp`x'', nogen
	}
		*** obs == 2120: 2013 matched, 107 unmatched temps a, c, d, f
		*** obs == 2120: 2011 matched, 109 unmatched temps b, e

* merge in other sections
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec3_connaisance_covid19", nogen
		*** obs == 2120: 2013 matched, 107 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec4_comportaments", nogen
		*** obs == 2120: 2013 matched, 107 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec5_acces_service_base", nogen
		*** obs == 2120: 2013 matched, 107 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec6a_emplrev_general", nogen
		*** obs == 2120: 2013 matched, 107 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec6b_emplrev_travailsalarie", nogen
		*** obs == 2120: 2013 matched, 107 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec6c_emplrev_nonagr", nogen
		*** obs == 2120: 2013 matched, 107 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec6d_emplrev_agr", nogen
		*** obs == 2120: 2013 matched, 107 unmatched
	merge 1:1 	hhid using "$root/wave_0`w'/r`w'_sec7_securite_alimentaire", nogen
		*** obs == 2120: 2013 matched, 107 unmatched

* clean variables inconsistent with other rounds
	* ac_med
	rename 			s05q01a ac_med		
	replace 		ac_med = 1 if ac_med == 2 | ac_med == 3
	replace 		ac_med = 2 if ac_med == 4
	replace 		ac_med = 3 if ac_med == 5
	
	rename 			s05q03e ac_medserv_why
	replace 		ac_medserv_why = . if ac_medserv_why == 4
	rename 			s05q03d ac_medserv_oth
	
	* employment 
	rename 			s06q04_0 emp_chg_why
	replace 		emp_chg_why = 96 if emp_chg_why == 13
	
	* agriculture
	rename 			s06q23 ag_crop_lost
	rename 			s06q24 ag_live
	rename 			s06q25 ag_live_chg
	forval 			x = 1/7 {
		rename 		s06q26__`x' ag_live_chg_`x'
	}
	rename 			s06q27 ag_live_loc
	rename 			s06q14 ag_crop
	rename			cc_1 ag_crop_a // using a to denote that there is no hierarchy
	rename			cc_2 ag_crop_aa
	rename			cc_3 ag_crop_aaa
	rename			fao_1 ag_FAO_a
	rename			fao_2 ag_FAO_aa
	rename			fao_3 ag_FAO_aaa
	
	drop			s06q16* // these are y/n crop variables 

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