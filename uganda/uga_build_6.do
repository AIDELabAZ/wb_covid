* Project: WB COVID
* Created on: August 2020
* Created by: lirr
* Edited by : lirr
* Last edited: 18 Aug 2022
* Stata v.17.0

* does
	* reads in sixth round of Uganda data
	* builds round 6
	* outputs round 6

* assumes
	* raw Uganda data

* TO DO:
	* 
	

*************************************************************************
**# - setup
*************************************************************************

* define
	global	root	=	"$data/uganda/raw"
	global	fies	=	"$data/analysis/raw/Uganda"
	global	export	=	"$data/uganda/refined"
	global	logout	=	"$data/uganda/logs"

* open log
	cap log 		close
	log using		"$logout/uga_build", append
	
* set local wave number & file number
	local			w = 6
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_0`w'" 	

	
*************************************************************************
**# - reshape section 6 (income loss) wide data
*************************************************************************

* load income data
	use				"$root/wave_0`w'/sec6", clear
		*** obs == 27300
	
* reformat HHID
	format 			%12.0f HHID

* replace value for "other"
	replace			income_loss__id = 96 if income_loss__id == -96

* reshape data
	reshape 		wide s6q01 s6q02 s6q03, i(HHID) j(income_loss__id)
		*** obs == 2100

* save temp file
	tempfile		temp1
	save			`temp1'
	

*************************************************************************
**# - reshape section 9 (shocks/coping) wide data
*************************************************************************

* load data
	use				"$root/wave_0`w'/SEC9A", clear
		*** obs == 29400

* reformat HHID
	format 			%12.0f HHID

* drop other shock
	drop			s9aq01_Other
		*** obs == 29400

* replace value for "other"
	replace			shocks__id = 96 if shocks__id == -96

* generate shock variables
	forval i = 1/13 {
		gen				shock_`i' = 0 if s9aq01 == 2 & shocks__id == `i'
		replace			shock_`i' = 1 if s9aq01 == 1 & shocks__id == `i'
		}

	gen				shock_14 = 0 if s9aq01 == 2 & shocks__id == 96
		*** obs == 29400
	replace			shock_14 = 1 if s9aq01 == 1 & shocks__id == 96

* format shock variables
	lab var			shock_1 "Death or disability of an adult working member of the household"
	lab var			shock_2 "Death of someone who sends remittances to the household"
	lab var			shock_3 "Illness of income earning member of the household"
	lab var			shock_4 "Loss of an important contact"
	lab var			shock_5 "Job loss"
	lab var			shock_6 "Non-farm business failure"
	lab var			shock_7 "Theft of crops, cash, livestock or other property"
	lab var			shock_8 "Destruction of harvest by insufficient labor"
	lab var			shock_9 "Disease/Pest invasion that caused harvest failure or storage loss"
	lab var			shock_10 "Increase in price of inputs"
	lab var			shock_11 "Fall in the price of output"
	lab var			shock_12 "Increase in price of major food items consumed"
	lab var			shock_13 "Floods"
	lab var			shock_14 "Other shock"

* generate cope variables
	gen				cope_1 = 0 if s9aq03 != 1
	replace			cope_1 = 1 if s9aq03 == 1
	lab var			cope_1 "Sale of assets (ag and no-ag)"
	
	gen				cope_2 = 0 if s9aq03 != 6
	replace			cope_2 = 1 if s9aq03 == 6
	lab var			cope_2 "Engaged in additional income generating activities"
	
	gen				cope_3 = 0 if s9aq03 != 7
	replace			cope_3 = 1 if s9aq03 == 7
	lab var			cope_3 "Received assistance from frends & family"
	
	gen				cope_4 = 0 if s9aq03 != 8
	replace			cope_4 = 1 if s9aq03 == 8
	lab var			cope_4 "Borrowed from friends & family"
	
	gen				cope_5 = 0 if s9aq03 != 9
	replace			cope_5 = 1 if s9aq03 == 9
	lab var			cope_5 "Took a loan from a financial institution"
	
	gen				cope_6 = 0 if s9aq03 != 11
	replace			cope_6 = 1 if s9aq03 == 11
	lab var			cope_6 "Credited purchases"
	
	gen				cope_7 = 0 if s9aq03 != 12
	replace			cope_7 = 1 if s9aq03 == 12
	lab var			cope_7 "Delayed payment obligations"
	
	gen				cope_8 = 0 if s9aq03 != 13
	replace			cope_8 = 1 if s9aq03 == 13
	lab var			cope_8 "Sold harvest in advance"
	
	gen				cope_9 = 0 if s9aq03 != 14
	replace			cope_9 = 1 if s9aq03 == 14
	lab var			cope_9 "Reduced food consumption"
	
	gen				cope_10 = 0 if s9aq03 != 15
	replace			cope_10 = 1 if s9aq03 == 15
	lab var			cope_10 "Reduced non-food consumption"
	
	gen				cope_11 = 0 if s9aq03 != 16
	replace			cope_11 = 1 if s9aq03 == 16
	lab var			cope_11 "Relied on savings"
	
	gen				cope_12 = 0 if s9aq03 != 17
	replace			cope_12 = 1 if s9aq03 == 17
	lab var			cope_12 "Received assistance from NGO"
	
	gen				cope_13 = 0 if s9aq03 != 18
	replace			cope_13 = 1 if s9aq03 == 18
	lab var			cope_13 "Took advanced payment from employer"
	
	gen				cope_14 = 0 if s9aq03 != 19
	replace			cope_14 = 1 if s9aq03 == 19
	lab var			cope_14 "Received assistance from government"
	
	gen				cope_15 = 0 if s9aq03 != 20
	replace			cope_15 = 1 if s9aq03 == 20
	lab var			cope_15 "Was covered by insurance policy"
	
	gen				cope_16 = 0 if s9aq03 != 21
	replace			cope_16 = 1 if s9aq03 == 21
	lab var			cope_16 "Did nothing"

	gen				cope_17 = 0 if s9aq03 != -96
	replace			cope_17 = 1 if s9aq03 == -96
	lab var			cope_17 "Other"

* drop unnecessary variables
	drop	shocks__id s9aq01 s9aq02 s9aq03_Other
		*** obs == 29400

* collapse to household level
	collapse (max) cope_* shock_*, by(HHID)
		*** obs == 2227
	
* generate any shock variable
	gen				shock_any = 1 if shock_1 == 1 | shock_2 == 1 | ///
						shock_3 == 1 | shock_4 == 1 | shock_5 == 1 | ///
						shock_6 == 1 | shock_7 == 1 | shock_8 == 1 | ///
						shock_9 == 1 | shock_10 == 1 | shock_11 == 1 | ///
						shock_12 == 1 | shock_13 == 1 | shock_14== 1
	replace			shock_any = 0 if shock_any == .
	lab var			shock_any "Experience some shock"

* save temp file
	tempfile		temp2
	save			`temp2'
 	

*************************************************************************
**# - reshape section 10 (safety nets) wide data 
*************************************************************************

* load safety net data 
	use				"$root/wave_0`w'/sec10", clear
		*** obs == 8396

* reformat HHID
	format 			%12.0f HHID

* drop other safety nets and missing values
	drop			s10q02 s10q03__1 s10q03__2 s10q03__3 s10q03__4 ///
						s10q03__5 s10q03__6 s10q00 s10q00_other
		*** obs == 8396
		
* reshape data
	reshape 		wide s10q01, i(HHID) j(safety_net__id)
	*** obs == 2099 | note that cash = 102, food = 101, in-kind = 103 (unlike wave 1)


* rename variables
	gen				asst_food = 1 if s10q01101 == 1
	replace			asst_food = 0 if s10q01101 == 2
	replace			asst_food = 0 if asst_food == .
	lab var			asst_food "Recieved food assistance"
	lab def			assist 0 "No" 1 "Yes"
	lab val			asst_food assist
	
	gen				asst_cash = 1 if s10q01102 == 1
	replace			asst_cash = 0 if s10q01102 == 2
	replace 		asst_cash = 1 if s10q01104 == 1
	replace			asst_cash = 0 if asst_cash == .
	lab var			asst_cash "Recieved cash assistance"
	lab val			asst_cash assist
	
	gen				asst_kind = 1 if s10q01103 == 1
	replace			asst_kind = 0 if s10q01103 == 2
	replace			asst_kind = 0 if asst_kind == .
	lab var			asst_kind "Recieved in-kind assistance"
	lab val			asst_kind assist
	
	gen				asst_any = 1 if asst_food == 1 | asst_cash == 1 | ///
					asst_kind == 1
	replace			asst_any = 0 if asst_any == .
	lab var			asst_any "Recieved any assistance"
	lab val			asst_any assist

* drop variables
	drop			s10q01101 s10q01102 s10q01103 s10q01104
		*** obs == 2099

* save temp file
	tempfile		temp3
	save			`temp3'
	

*************************************************************************
**# - get respondant gender
*************************************************************************

* load data
	use				"$root/wave_0`w'/interview_result", clear
		*** obs == 2100

* drop all but household respondent
	keep			HHID Rq09
		*** obs == 2100
	rename			Rq09 hh_roster__id
	
	isid			HHID

* merge in household roster
	merge 1:1		HHID hh_roster__id using "$root/wave_0`w'/SEC1"
		*** obs == 11595: 2096 matched, 9499 unmatched
	keep if			_merge == 3
		*** obs == 2096

* rename variables and fill in missing values
	rename			hh_roster__id PID
	rename			s1q05 sex
	rename			s1q06 age
	rename			s1q07 relate_hoh
	drop if			PID == .

* drop all but gender and relation to HoH
	keep			HHID PID sex age relate_hoh
		*** obs == 2096

* save temp file
	tempfile		temp4
	save			`temp4'
	
	
*************************************************************************
**# - get household size and gender of HOH
*************************************************************************

* load data 
	use				"$root/wave_0`w'/SEC1.dta", clear
		*** obs == 11591

* rename other variables 
	rename 			hh_roster__id ind_id 
	rename 			s1q03 curr_mem
	replace 		curr_mem = 1 if s1q02 == 1
	rename 			s1q05 sex_mem
	rename 			s1q06 age_mem
	rename 			s1q07 relat_mem
	
* generate counting variables
	gen				hhsize = 1 if curr_mem == 1
	gen 			hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem == 1 & age_mem < 19 & age_mem != . 
	gen 			hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19 
		*** obs == 11591
	
* create hh head gender
	gen 			sexhh = . 
	replace			sexhh = sex_mem if relat_mem == 1
	label var 		sexhh "Sex of household head"
		*** obs == 11591
	
* generate migration vars
	rename 			s1q02 new_mem
	replace 		new_mem = 0 if s1q08 == 10
	replace 		s1q08 = . if s1q08 == 10
	gen 			mem_left = 1 if curr_mem == 2
		*** obs == 11591
	replace 		new_mem = 0 if new_mem == 2
	replace 		mem_left = 0 if mem_left == 2
	
	* why member left 
		preserve
			keep 		HHID s1q04 ind_id
				*** obs == 11591
			keep 		if s1q04 < .
				*** obs == 172
			duplicates 	drop HHID s1q04, force
				*** obs == 145
			reshape 	wide ind_id, i(HHID) j(s1q04)
				*** obs == 133
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
			keep 		HHID s1q08 ind_id
				*** obs == 11591
			keep 		if s1q08 < .
				*** obs == 299
			duplicates 	drop HHID s1q08, force
				*** obs == 168
			replace 	s1q08 = 96 if s1q08 == -96
			reshape 	wide ind_id, i(HHID) j(s1q08)
				*** obs == 152
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
				(max) sexhh, by(HHID)
		*** obs == 2100
	replace 	new_mem = 1 if new_mem > 0 & new_mem < .
	replace 	mem_left = 1 if mem_left > 0 & new_mem < .	
	merge 		1:1 HHID using `new_mem', nogen
		*** obs == 2100: 152 matched, 1948 unmatched
	merge 		1:1 HHID using `mem_left', nogen
		*** obs == 2100: 133 matched, 1967 unmatched
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
	tempfile		temp5
	save			`temp5'
	
	
*************************************************************************
**# - livestock
*************************************************************************

* load  data
	use				"$root/wave_0`w'/SEC5D", clear
		*** obs == 6297
	drop 			if s5dq12 == 2
	drop 			s5dq12 
		*** obs == 734

* rename vars 
	forval 			x = 1/5 {
		rename 		s5dq14a__`x' s5cq14_2__`x'
		rename 		s5dq14__`x' s5cq14_1__`x'
	}
	rename 			s5dq14a__6 s5cq14_2__6
	rename 			s5d* s5c* 
	
* reshape wide
	gen 			product = cond(livestock == -96, "other", cond(livestock == 1, ///
					"milk",cond(livestock == 2, "eggs","meat")))
		*** obs == 734 
	drop 			livestock
		*** obs == 734
	reshape 		wide s5cq*, i(HHID) j(product) string
		*** obs == 557

* save temp file part 1
	tempfile		templs1
	save			`templs1'
	
* load data		
	use 			"$root/wave_0`w'/SEC5D", clear
		*** obs == 6297
	drop 			if s5dq12 == 2
	drop 			s5dq12 	
		*** obs == 734
		
* reshape wide
	keep 			livestock HHID
	gen 			product = cond(livestock == -96, "other", cond(livestock == 1, ///
					"milk",cond(livestock == 2, "eggs","meat")))
		*** obs == 734
	reshape 		wide livestock, i(HHID) j(product) string
		*** obs == 557
	collapse 		(sum) livestock*, by (HHID)
		*** obs == 557
	replace 		livestock_products__ideggs = 1 if livestock_products__ideggs != 0
	replace 		livestock_products__idmeat = 1 if livestock_products__idmeat != 0
	replace 		livestock_products__idmilk = 1 if livestock_products__idmilk != 0	

* save temp file
	merge			1:1 HHID using `templs1', nogen
		*** obs == 557
	tempfile		temp6
	save			`temp6'
	
	
*************************************************************************
**# - FIES
*************************************************************************

* load data
	use				"$fies/UG_FIES_round`w'.dta", clear
		*** obs == 2100

	drop 			country round
		*** obs == 2100
	destring 		HHID, replace

* save temp file
	tempfile		temp7
	save			`temp7'	

	
*************************************************************************
**# - education 
*************************************************************************
	
* generate edu_act = 1 if any child engaged in learning activities
	use				"$root/wave_0`w'/SEC1C", clear
		*** obs == 11596 
	keep 			if s1cq09 != .
		*** obs == 3819
	replace 		s1cq09  = 0 if s1cq09  == 2
	collapse		(sum) s1cq09, by(HHID)
		*** obs == 1570
	gen 			edu_act = 1 if s1cq09 > 0 
	replace 		edu_act = 0 if edu_act == .
	keep 			HHID edu_act
		*** obs == 1570
	tempfile 		tempany
	save 			`tempany'

* rename other variables 	
	* edu_act_why
	use				"$root/wave_0`w'/SEC1C", clear
		*** obs == 11596
	keep 			if s1cq09 == 2
		*** obs == 2544
	forval 			x = 1/11 {
		rename 		s1cq10__`x' edu_act_why_`x'
	}
	collapse 		(sum) edu* , by(HHID)
		*** obs == 1165
	forval 			x = 1/11 {
		replace 		edu_act_why_`x' = 1 if edu_act_why_`x' >= 1
	}
	tempfile 		tempactwhy
	save 			`tempactwhy'
		
	* edu & edu_chal
	use				"$root/wave_0`w'/SEC1C", clear
		*** obs == 11596
	keep 			if s1cq09 == 1
		*** obs == 1272
	rename 			s1cq11__1 edu_1
	rename 			s1cq11__2 edu_2
	replace 		edu_2 = 1 if s1cq11__3 == 1 | s1cq11__4 == 1 | ///
						s1cq11__5 == 1 | s1cq11__6 == 1
	rename 			s1cq11__7 edu_3
	rename 			s1cq11__8 edu_4
	rename 			s1cq11__9 edu_5
	rename 			s1cq11__10 edu_8
	rename 			s1cq11__11 edu_9
	rename 			s1cq11__12 edu_10
	rename 			s1cq11__13 edu_11
	rename 			s1cq11__14 edu_12
	rename 			s1cq11__15 edu_7
	rename 	 		s1cq11__n96 edu_other
	forval 			x = 1/13 {
	    replace 	s1cq12__`x' = 0 if s1cq12__`x' == 2
	    rename 		s1cq12__`x' edu_chal_`x'
	}
	collapse 		(sum) edu* , by(HHID)
		*** obs == 662
	ds edu* 
	foreach 		var in `r(varlist)' {
	    replace 		`var' = 1 if `var' >= 1
	}
	tempfile 		tempedu
	save 			`tempedu'
	
* merge data together 
	use				"$root/wave_0`w'/SEC1C", clear
		*** obs == 11596
	keep 			HHID 
	duplicates 		drop
		*** obs == 2100
	merge 			1:1 HHID using `tempany', nogen
		*** obs == 2100: 1570 matched, 530 unmatched
	merge 			1:1 HHID using `tempactwhy', nogen
		*** obs == 2100: 1165 matched, 935 unmatched
	merge 			1:1 HHID using `tempedu', nogen

		*** obs == 2100: 1438 matched, 662 unmatched

* save temp file
	tempfile		temp8
	save			`temp8'
	
			
*************************************************************************
**# - build uganda cross section
*************************************************************************	

* load cover data
	use				"$root/wave_0`w'/Cover", clear
		*** obs == 2100
		
* merge in other sections
	forval			x = 1/8{
		merge			1:1 HHID using `temp`x'', nogen
	}
		*** obs == 2100: 2100 matched, 0 unmatched temps 1, 2, 5, 7 ,8
		*** obs == 2100: 2099 matched, 1 unmatched temp 3
		*** obs == 2100: 2096 matched, 4 unmatched temp 4
		*** obs == 2100: 1543 matched, 557 unmatched temp 6
		
	merge 1:1			HHID using "$root/wave_0`w'/SEC1E", nogen
		*** obs == 2100: 1457 matched, 643 unmatched
	merge 1:1			HHID using "$root/wave_0`w'/SEC1G", nogen
		*** obs == 2100: 1457 matched, 643 unmatched
	merge 1:1			HHID using "$root/wave_0`w'/SEC3", nogen
		*** obs == 2100: 2100 matched, 0 unmatched
	merge 1:1			HHID using "$root/wave_0`w'/SEC4_1", nogen 
		*** obs == 2100: 2100 matched, 0 unmatched
	merge 1:1			HHID using "$root/wave_0`w'/SEC4_2", nogen
		*** obs == 2100: 1457 matched, 643 unmatched		
	merge 1:1			HHID using "$root/wave_0`w'/SEC4A", nogen
		*** obs == 2100: 2100 matched 0 unmatched
	* merge 1:1			HHID using "$root/wave_0`w'/SEC5_Other", nogen repeated questions of employment from other family member
		*** obs == 2100: 2020 matched, 80 unmatched
	merge 1:1			HHID using "$root/wave_0`w'/SEC5_Resp", nogen
		*** obs == 2100: 2100 matched, 0 unmatched
	merge 1:1			HHID using "$root/wave_0`w'/SEC5A", nogen
		*** obs == 2100: 2100 matched, 0 unmatched
	merge 1:1			HHID using "$root/wave_0`w'/SEC5B", nogen
		*** obs == 2100: 2100 matched, 0 unmatched
	merge 1:1			HHID using "$root/wave_0`w'/SEC8", nogen
		*** obs == 2100: 2100 matched, 0 unmatched
	merge 1:1			HHID using "$root/wave_0`w'/SEC9", nogen
		*** obs == 2100: 2100 matched, 0 unmatched

* reformat HHID
	format 			%12.0f HHID

* rename variables inconsistent with other waves
	* rename behavioral changes
		rename			s3q01 bh_1
		rename			s3q02 bh_2
		rename			s3q03 bh_3
		rename			s3q04 bh_4
		rename			s3q05 bh_5
		rename			s3q06 bh_freq_wash
		rename			s3q07_1 bh_freq_mask_oth
		rename			s3q07_2 mask
		rename 			s3q08 bh_freq_gath	
	
	* access	
		rename 			s4q04_1__1 ac_maize
		rename 			s4q04_1__2 ac_rice
		rename 			s4q04_1__3 ac_beans
		rename 			s4q04_2 hh_pr_maize_flr // note: similar to ag_pr but for households
		rename 			s4q04_3 hh_pr_rice
		rename 			s4q04_4 hh_pr_bean_fr
		rename 			s4q04_5 hh_pr_bean_dry
		rename 			s4q19 s4q09
		
		gen				s4q10 = 0
		replace			s4q10 = 1 if s4q21_1 == 1 | s4q21_2 == 1 | s4q21_3 == 1
		drop			s4q21_*
			*** obs == 2100
			
		* create medical service access type variables	
		forval			k = 1/7 {
			gen				ac_medserv_need_type_`k' = 0 if s4q09 == 1
			replace			ac_medserv_need_type_`k' = 1 if s4q20__`k' == 1  ///
								& s4q09 == 1
		}
		drop			s4q20_*
		
		* create reason unable to access med services
		forval			k = 1/7 {
			gen				ac_medserv_need_type_`k'_why = 0 if s4q09 == 1
			
				forvalues		j = 1/3 {
					replace 			ac_medserv_need_type_`k'_why = s4q22_`j' ///
								if medical_access__id_`j' == `k' & s4q22_`j' != .
				
			}
		}

	* SWIFT coding
		rename			s4aq02 s4q12__2
		rename			s4aq08 ac_internet
		
	* rename employment
		rename			s5q01 emp
		rename			s5q01a rtrn_emp
		rename			s5q01b rtrn_emp_when
		rename			s5q01c emp_why
		rename 			s5q03 emp_pre_why
		rename			s5q03a emp_search
		rename			s5q03b emp_search_how
		rename			s5q04a emp_same
		rename			s5q04b emp_chg_why
		rename			s5q05 emp_act
		rename			s5q06 emp_stat
		replace 		emp_stat = 6 if emp_stat == 5
		rename 			s5q06a emp_purp
	* non-farm income
		rename			s5aq11 bus_emp
		rename			s5aq11a bus_stat
		rename 			s5aq11b_1 bus_other
		rename			s5aq12 bus_sect
		rename			s5aq12_1 bus_sect_oth
		rename			s5aq13 bus_emp_inc
		rename			s5aq14_1 bus_why
	* rename agriculture
		rename			t0_s5bq16_R4 ag_crop	
		rename 			t0_s5bq18_1 ag_crop_1
		rename 			t0_s5bq18_2 ag_crop_2
		rename 			t0_s5bq18_3 ag_crop_3
		rename			s5bq21_1 ag_pr_ban_s
		rename			s5bq21_2 ag_pr_ban_m
		rename			s5bq21_3 ag_pr_ban_l
		rename			s5bq21_7 ag_pr_bean_dry
		rename			s5bq21_9 ag_pr_bean_fr
		rename			s5bq21_8 ag_pr_maize
		rename 			s5bq23 ag_sell_norm
		rename 			s5bq24 ag_sell_rev_exp
		rename			s5bq25 harv_sell_need
		rename 			s5bq26 s5aq31
		
	* rename food security
		rename			s8q01 fies_4
		lab var			fies_4 "Worried about not having enough food to eat"
		rename			s8q02 fies_5
		lab var			fies_5 "Unable to eat healthy and nutritious/preferred foods"
		rename			s8q03 fies_6
		lab var			fies_6 "Ate only a few kinds of food"
		rename			s8q04 fies_7
		lab var			fies_7 "Skipped a meal"
		rename			s8q05 fies_8
		lab var			fies_8 "Ate less than you thought you should"
		rename			s8q06 fies_1
		lab var			fies_1 "Ran out of food"
		rename			s8q07 fies_2
		lab var			fies_2 "Hungry but did not eat"
		rename			s8q08 fies_3
		lab var			fies_3 "Went without eating for a whole day"	
	* rename concerns
		rename			s9q01 concern_1
		rename			s9q02 concern_2
		rename 			s9q03a have_cov_oth
		rename 			s9q03b have_cov_self
		gen				have_symp = 1 if s9q03__1 == 1 | s9q03__2 == 1 | s9q03__3 == 1 | ///
							s9q03__4 == 1 | s9q03__5 == 1 | s9q03__6 == 1 | ///
							s9q03__7 == 1 | s9q03__8 == 1
		replace			have_symp = 2 if have_symp == .
		order			have_symp, after(concern_2)	
		rename 			s9q04 have_test
		rename			s9q06 concern_4
		rename			s9q09 concern_7
		
* save panel		
	* gen wave data
		rename			baseline_hhid baseline_HHID
		rename			wfinal phw_cs
		lab var			phw "sampling weights - cross section"	
		gen				wave = `w'
		lab var			wave "Wave number"
		order			baseline_HHID wave phw, after(HHID)

		
	* save file
		save			"$export/wave_0`w'/r`w'", replace

/* END */	