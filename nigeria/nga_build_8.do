* Project: WB COVID
* Created on: August 2020
* Created by: jdm
* Edited by: lirr
* Last edited: 19 June 2023
* Stata v.16.1

* does
	* reads in eight round of Nigeria data
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
	local			w = 8
	
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
			keep 		if s2q4 != .
			duplicates 	drop hhid s2q4, force
			reshape 	wide ind_id, i(hhid) j(s2q4)
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
			keep 		if s2q8 != .
			duplicates 	drop hhid s2q8, force
			reshape 	wide ind_id, i(hhid) j(s2q8)
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
	replace 	new_mem = 1 if new_mem > 0 & new_mem < .
	replace 	mem_left = 1 if mem_left > 0 & new_mem < .	
	merge 		1:1 hhid using `new_mem', nogen
	merge 		1:1 hhid using `mem_left', nogen
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
	

* ***********************************************************************
* 1b - sections 2, 5-6, 12: respondant gender
* ***********************************************************************

* load data
	use				"$root/wave_0`w'/r`w'_sect_a_2_5c_6_12", clear
	
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

* not available for round
	

* ***********************************************************************
* 1d - section 11: assistance
* ***********************************************************************

* not available for round				
		
		
* ***********************************************************************
* 1e - section 10: shocks
* ***********************************************************************

* load data
	use				"$root/wave_0`w'/r`w'_sect_10", clear

* reformat HHID
	format 			%5.0f hhid

* drop other shock
	drop			shock_cd_os s10q3_os

* generate shock variables
	levelsof(shock_cd), local(id)
	foreach 			i in `id' {
		gen				shock_`i' = 1 if s10q1 == 1 & shock_cd == `i'
		replace			shock_`i' = 0 if s10q1 == 2 & shock_cd == `i'
		}

* collapse to household level
	collapse 		(max) s10q3__1- shock_96, by(hhid)	
	
* save temp file
	tempfile		tempc
	save			`tempc'
	
	
* ***********************************************************************
* 2 - FIES score
* ***********************************************************************


* not available for round


*************************************************************************
**# 3 - Impute missing crop area values
*************************************************************************

* load data
	use				"$root/wave_0`w'/r`w'_sect_a_2_5c_6_12", clear
			*** obs == 1810
			
* isolate agriculture and crop variables	
	keep			zone state lga sector ea hhid s6a*
		*** obs == 1810
	sort			hhid
	
* merg in conversion factors
	merge			m:1 zone using "$root/wave_00/land-conversion"
		*** all 1810 obs match
		
* rename and replace important variables to match baseline
	rename			s6aq5b local_unit
	replace			acrecon = 0.404686 // matches acre conversion with baseline
		
* construc area measures
	gen				selfreport_ha = heapcon * s6aq5a if local_unit == 1
	replace			selfreport_ha = ridgecon * s6aq5a if local_unit == 2 ///
						& selfreport_ha == .
	replace			selfreport_ha = standcon * s6aq5a if local_unit == 3 ///		
						& selfreport_ha == .
	replace			selfreport_ha = acrecon * s6aq5a if local_unit == 5 ///		
						& selfreport_ha == .					
	replace			selfreport_ha = hectarecon * s6aq5a if local_unit == 6 ///		
						& selfreport_ha == .					
	replace			selfreport_ha = sqmcon * s6aq5a if local_unit == 7 ///		
						& selfreport_ha == .					
	sum				selfreport_ha, detail					

* drop observations with no crop response
	drop if			s6aq4 == .
		*** obs == 1291
	mdesc			selfreport_ha
		*** 26 missing obs 2.01%
		
* impute values	
	mi set			wide // declare data to be wide
	mi xtset,		clear // precautionary clear any xtset in place
	mi register		imputed selfreport_ha
	
	sort			zone state hhid, stable // sort to ensure same order as baseline and reporducibility
	mi impute		pmm selfreport_ha i.state, add(1) rseed(441244) ///
						noisily dots force knn(5) bootstrap
						
	mi unset
	
* look at data to evaluate
	tab				mi_miss
	
	tabstat			selfreport_ha selfreport_ha_1_ s6aq5a, by(mi_miss) ///
						statistics(n mean min max) columns(statistics) longstub ///
						format(%9.3g)
	
	sum				selfreport_ha_1_ selfreport_ha
	rename			selfreport_ha_1_ imp_crop_area
	rename			selfreport_ha ag_main_area_ha
	
* keep necessary variables
	keep			hhid imp_* ag_main* 

* save temp
	tempfile			temp_crop
	save				`temp_crop'
	
	
* ***********************************************************************
* 4 - merge sections into panel and save
* ***********************************************************************

* merge sections based on hhid
	use				"$root/wave_0`w'/r`w'_sect_a_2_5c_6_12", clear
	foreach 		s in a b c {
	    merge		1:1 hhid using `temp`s'', nogen
	}
	
* merge in crop data
	merge			1:1 hhid using `temp_crop', nogen
		*** obs == 1810; 1291 matched same # of obs in temp_crop

* generate round variable
	gen				wave = `w'
	lab var			wave "Wave number"	
	
* clean variables inconsistent with other rounds	
	* agriculture 
	rename			s6q16 ag_crop
	rename 			s6aq1_1 ag_crop_who
	drop 			s6aq2 s6aq3
	rename 			s6aq4 ag_main
	rename 			s6aq5a ag_main_area
	rename 			s6aq5b ag_main_area_unit
	rename 			s6aq6 ag_main_harv
	drop 			s6aq7* s6aq9
	rename 			s6aq8 ag_main_sell
	rename 			s6aq10 ag_main_rev
	rename 			s6aq11 harv_sell_rev
	replace 		harv_sell_rev = . if harv_sell_rev == 99
	rename 			s6aq12 ag_main_sell_plan
	rename 			s6aq13 harv_sell_rev_exp
	rename 			s6aq14 ag_main_harv_comp
	drop 			s6aq15*
	rename 			s6aq16a ag_use_infert
	rename 			s6aq16b ag_use_orfert
	rename 			s6aq16c ag_use_pest
	rename 			s6aq16d ag_use_lab
	rename 			s6aq16e ag_use_anim
	forval 			x = 1/7 {
	    rename 		s6aq17__`x' ag_ac_infert_why_`x'
		rename 		s6aq18__`x' ag_ac_orfert_why_`x'
		rename 		s6aq19__`x' ag_ac_pest_why_`x'
	}
	forval 			x = 1/5 {
	    rename 		s6aq20__`x' ag_ac_lab_why_`x'	
		rename 		s6aq21__`x' ag_ac_anim_why_`x' // data differ from survey response #s
	}
	rename 			s6aq20__7 ag_ac_lab_why_7
	rename 			s6aq21__7 ag_ac_anim_why_7	
	
	* generate ag_main_fao crop code variable and populate with corresponding crop code
	gen				ag_main_FAO = ag_main

	replace			ag_main_FAO = 704 if ag_main == 1010
	replace			ag_main_FAO = 503 if ag_main == 1020	
	replace			ag_main_FAO = 402 if ag_main == 1060
	replace			ag_main_FAO = 104 if ag_main == 1070
	replace			ag_main_FAO = 102 if ag_main == 1080
	replace			ag_main_FAO = 20502 if ag_main == 1090
	replace			ag_main_FAO = 108 if ag_main == 1100
	replace			ag_main_FAO = 103 if ag_main == 1110
	replace			ag_main_FAO = 504 if ag_main == 1124
	replace			ag_main_FAO = 40307 if ag_main == 2040
	replace			ag_main_FAO = 30103 if ag_main == 2170
	replace			ag_main_FAO = 401 if ag_main == 2220
	replace			ag_main_FAO = 60104 if ag_main == 3040
	replace			ag_main_FAO = 40403 if ag_main == 3180
	replace			ag_main_FAO = 9999 if ag_main == 9999
	
	drop 			s6aq*	
	
	* business
	rename 			s6q11b1 bus_other
	
	drop s5c* //no observations
	
* save round file
	save			"$export/wave_0`w'/r`w'", replace

* close the log
	log	close
	
	
/* END */	