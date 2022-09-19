* Project: WB COVID
* Created on: August 2020
* Created by: lirr
* Edited by : lirr
* Last edited: 20 Aug 2022
* Stata v.17.0

* does
	* reads in seventh round of Uganda data
	* builds round 7
	* outputs round 7

* assumes
	* raw Uganda data

* TO DO:
	* a whole lot but a whole lot less than there was
	

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
	local			w = 7
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_0`w'" 	

	
*************************************************************************
**# - reshape section 10 (safety nets) wide data 
*************************************************************************

* load safety net data 
	use				"$root/wave_0`w'/SEC10_1", clear
		*** obs == 7800

* reformat HHID
	format 			%12.0f HHID

* drop other safety nets and missing values
	drop			s10q02 s10q03__1 s10q03__2 s10q03__3 s10q03__4 ///
						s10q03__5 s10q03__6 
		*** obs == 7800
		
* reshape data
	reshape 		wide s10q01, i(HHID) j(safety_net__id)
	*** obs == 1950 | note that cash = 102, food = 101, in-kind = 103 (unlike wave 1)


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
		*** obs == 1950

* save temp file
	tempfile		temp1
	save			`temp1'
	
	
*************************************************************************
**# - get respondant gender
*************************************************************************

* load data
	use				"$root/wave_0`w'/interview_result", clear
		*** obs == 1950

* drop all but household respondent
	keep			HHID Rq09
		*** obs == 1950
	rename			Rq09 hh_roster__id
	
	isid			HHID

* merge in household roster
	merge 1:1		HHID hh_roster__id using "$root/wave_0`w'/SEC1"
		*** obs == 11121: 1942 matched, 9179 unmatched
	keep if			_merge == 3
		*** obs == 1942

* rename variables and fill in missing values
	rename			hh_roster__id PID
	rename			s1q05 sex
	rename			s1q06 age
	rename			s1q07 relate_hoh
	drop if			PID == .

* drop all but gender and relation to HoH
	keep			HHID PID sex age relate_hoh
		*** obs == 1942

* save temp file
	tempfile		temp2
	save			`temp2'	
	

	
*************************************************************************
**# - get household size and gender of HOH
*************************************************************************

* load data 
	use				"$root/wave_0`w'/SEC1.dta", clear
		*** obs == 11113

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
		*** obs == 11113
		
* create hh head gender
	gen 			sexhh = . 
	replace			sexhh = sex_mem if relat_mem == 1
	label var 		sexhh "Sex of household head"
		*** obs == 11113
		
* generate migration vars
	rename 			s1q02 new_mem
	replace 		new_mem = 0 if s1q08 == 10
	replace 		s1q08 = . if s1q08 == 10
	gen 			mem_left = 1 if curr_mem == 2
	replace 		new_mem = 0 if new_mem == 2
	replace 		mem_left = 0 if mem_left == 2
	
	* why member left
			* no members lft
			
	* why new member 
		preserve
			keep 		HHID s1q08 ind_id
				*** obs == 11113
			keep 		if s1q08 < .	
				*** obs == 114
			duplicates 	drop HHID s1q08, force
				*** obs == 86
			replace 	s1q08 = 96 if s1q08 == -96
			reshape 	wide ind_id, i(HHID) j(s1q08)
				*** obs == 63
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
		*** obs == 1950
	replace 	new_mem = 1 if new_mem > 0 & new_mem < .
	replace 	mem_left = 1 if mem_left > 0 & new_mem < .	
	merge 		1:1 HHID using `new_mem', nogen
		*** obs == 1950: 63 matched, 1887 unmatched
	ds 			new_mem_why_* 
	foreach		var in `r(varlist)' {
		replace 	`var' = 0 if `var' >= . & new_mem == 1
	}
	lab var		hhsize "Household size"
	lab var 	hhsize_adult "Household size - only adults"
	lab var 	hhsize_child "Household size - children 0 - 18"
	lab var 	hhsize_schchild "Household size - school-age children 5 - 18"
	lab var 	mem_left "Member of household left since last call"
	lab var 	new_mem "Member of household joined since last call"
	
* save temp file
	tempfile		temp3
	save			`temp3'	
	
	
	
*************************************************************************
**# - education 
*************************************************************************
	
* generate edu_act = 1 if any child engaged in learning activities
	use				"$root/wave_0`w'/SEC1C", clear
		*** obs == 11478
	keep 			if s1cq09b != .
		*** obs == 5406
	replace 		s1cq09b  = 0 if s1cq09b  == 2
	collapse		(sum) s1cq09b, by(HHID)
		*** obs == 1676
	gen 			edu_act = 1 if s1cq09b > 0 
	replace 		edu_act = 0 if edu_act == .
	keep 			HHID edu_act
		*** obs == 1676
	tempfile 		tempany
	save 			`tempany'

* rename other variables 	
	* edu_act_why
	use				"$root/wave_0`w'/SEC1C", clear
		*** obs == 11478
	keep 			if s1cq09b == 2
		*** obs == 3672
	forval 			x = 1/11 {
		rename 		s1cq10__`x' edu_act_why_`x'
	}
	collapse 		(sum) edu* , by(HHID)
		*** obs == 1403
	forval 			x = 1/11 {
		replace 		edu_act_why_`x' = 1 if edu_act_why_`x' >= 1
	}
	tempfile 		tempactwhy
	save 			`tempactwhy'
		
	* edu & edu_chal
	use				"$root/wave_0`w'/SEC1C", clear
		*** obs == 11478
	keep 			if s1cq09b == 1
		*** obs == 1721
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
		*** obs == 769
	ds edu* 
	foreach 		var in `r(varlist)' {
	    replace 		`var' = 1 if `var' >= 1
	}
	tempfile 		tempedu
	save 			`tempedu'
	
* merge data together 
	use				"$root/wave_0`w'/SEC1C", clear
		*** obs == 11478
	keep 			HHID 
	duplicates 		drop
		*** obs == 1950
	merge 			1:1 HHID using `tempany', nogen
		*** obs == 1950: 1676 matched, 274 unmatched
	merge 			1:1 HHID using `tempactwhy', nogen
		*** obs == 1950: 1403 matched, 547 unmatched
	merge 			1:1 HHID using `tempedu', nogen
		*** obs == 1950: 769 matched, 1181 unmatched

* save temp file
	tempfile		temp4
	save			`temp4'	
	

*************************************************************************
**# - reshape section 4 (access: access to med services)
*************************************************************************	
	
* load data
	use				"$root/wave_0`w'/SEC4_2", clear
		*** obs == 15600
	
* reformat HHID
	format			%12.0f HHID

* reshape data
	replace			medical_access__id = 96 if medical_access__id == -96
	reshape			wide s4q2*, i(HHID) j(medical_access__id)
		*** obs == 1950
	
* rename variables to match
	forval			k = 1/7 {
		gen				ac_medserv_type_`k' = 0 if s4q20`k' != .
		replace			ac_medserv_type_`k' = 1 if s4q20`k' == 1
	}

	forval			k = 1/7 {
		gen 			ac_medserv_type_`k'_why = 0 if s4q21`k' != .
		replace			ac_medserv_type_`k'_why = s4q22`k' if s4q21`k' == 0
	}
	
	drop s4q2*
		*** obs == 1950

* save temp file
	tempfile		temp5
	save			`temp5'

	
*************************************************************************
**# - reshape planting section
*************************************************************************	
/* NOTE: I am UNSURE what this adds that is not in other data, also very oddly organized will 
* load data
	use				"$root/wave_0`w'/SEC6E_2", clear
		*** obs == 4312
	
* reformat HHID
	format			%12.0f HHID
	
* generate ag_crop variable
	replace			crop__id = 96 if crop__id == -96
	gen				ag_crop = crop__id
	
* drop for stuff
	*drop			s6eq21* interview__id
	
* reshape data to extract ag crops	
	reshape			wide crop__id s6eq21*, i(HHID) j(ag_crop)

*/	
	
*************************************************************************
**# - build uganda cross section
*************************************************************************	

* load cover data
	use				"$root/wave_0`w'/Cover", clear
		*** obs == 1950
		
* merge in other section
	forval			x = 1/5 {
		merge			1:1 HHID using `temp`x'', nogen
	}
		*** obs == 1950: 1950 matched, 0 unmatched temp 1,3,4,5
		*** obs == 1950: 1942 matched, 8 unmatched temp 2
		
	merge 1:1 		HHID using "$root/wave_0`w'/SEC2.dta", nogen
		*** obs == 1950: 1950 matched, 0 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/SEC2B.dta", nogen
		*** obs == 1950: 1950 matched, 0 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/SEC3.dta", nogen
		*** obs == 1950: 1950 matched, 0 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/SEC4_1.dta", nogen
		*** obs == 1950: 1950 matched, 0 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/SEC5.dta", nogen
		*** obs == 1950: 1950 matched, 0 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/SEC5A.dta", nogen
		*** obs == 1950: 1950 matched, 0 unmatched
	merge 1:1		HHID using "$root/wave_0`w'/SEC6E_1", nogen
		*** obs == 1950: 1950 matched, 0 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/SEC8.dta", nogen
		*** obs == 1950: 1950 matched, 0 unmatched
	merge 1:1 		HHID using "$root/wave_0`w'/SEC9.dta", nogen	
		*** obs == 1950: 1950 matched, 0 unmatched
	merge 1:1		HHID using "$root/wave_0`w'/SEC10.dta", nogen
		*** obs == 1950: 1950 matched, 0 unmatched
		
* reformat HHID
	format			%12.0f HHID
	
* rename variables to match other rounds or countries
	* rename govt actions 
		rename 			s2q01 cvd_lockdwn // note: asks if 2nd lockdown easement was good idea
		rename 			s2q02 cvd_sch
		rename 			s2q03 cvd_church
		rename			s2q04 vac_prev_sent
	
	* rename myths
		rename			s2bq2a_1 s2q02a_1
		rename			s2bq2a_3 s2q02a_2
		rename			s2bq2a_4 s2q02a_3
		rename			s2bq2a_5 s2q02a_4
		rename			s2bq2a_6 s2q02a_5
		rename			s2bq2a_7 s2q02a_6
		rename			s2bq2a_8 s2q02a_7
		rename			s2bq2a_2 myth_8
		
	* rename symptoms
		rename			s2bq1b__* s2q01b__*
		
	* rename behavioral changes
		rename			s3q01 bh_1
		rename			s3q02 bh_2
		rename			s3q03 bh_3
		rename			s3q06 bh_freq_wash
		rename			s3q07_1 bh_freq_mask_oth
		rename			s3q07_2 mask
		rename 			s3q08 bh_freq_gath
		
	* rename access to medicine
		rename			s4q15 s4q08
		
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
		replace 		emp_stat = 100 if emp_stat == 5
		replace 		emp_stat = 5 if emp_stat == 6
		replace 		emp_stat = 6 if emp_stat == 100
		rename 			s5q06a emp_purp
		rename			s5q8b1 emp_hrs
		rename			s5q8c1 emp_hrs_chg
		rename			s5q08f_* emp_saf*
		rename 			s5q08g emp_saf_fol
		rename 			s5q08g_1 emp_saf_fol_per
		
	* non-farm income
		rename			s5aq11 bus_emp	
		rename			s5aq11a bus_stat
		rename 			s5aq11b_1 bus_other
		rename			s5aq12 bus_sect
		rename			s5aq12_1 bus_sect_oth
		rename			s5aq13 bus_emp_inc
		rename			s5aq14_1 bus_why
		
	* rename agriculture

		rename			s6eq21a__1 ag_nocrop_1
		rename			s6eq21a__2 ag_nocrop_2
		rename			s6eq21a__3 ag_nocrop_3
		rename			s6eq21a__4 ag_nocrop_4
		rename			s6eq21a__5 ag_nocrop_5
		rename			s6eq21a__6 ag_nocrop_6
		rename			s6eq21a__7 ag_nocrop_7
		rename			s6eq21a__8 ag_nocrop_8
		rename			s6eq21a__9 ag_nocrop_12
		rename			s6eq21a__n96 ag_nocrop_9
		rename 			s5bq18__0 ag_crop_1
		rename 			s5bq18__1 ag_crop_2
		rename 			s5bq18__2 ag_crop_3
		rename 			s6eq19 ag_chg
		rename			s6eq20__1 ag_chg_1
		rename			s6eq20__2 ag_chg_2
		rename			s6eq20__3 ag_chg_3
		rename			s6eq20__4 ag_chg_4
		rename			s6eq20__5 ag_chg_5
		rename			s6eq20__6 ag_chg_6
		rename			s6eq20__7 ag_chg_7
		rename			s6eq21__1 ag_covid_1
		rename			s6eq21__2 ag_covid_2
		rename			s6eq21__3 ag_covid_3
		rename			s6eq21__4 ag_covid_4
		rename			s6eq21__5 ag_covid_5
		rename			s6eq21__6 ag_covid_6
		rename			s6eq21__7 ag_covid_7
		rename			s6eq21__8 ag_covid_8
		rename			s6eq21__9 ag_covid_9
		rename			s6eq21c ag_main_plots
		rename 			s6eq23 ag_sell_norm
		rename 			s6eq24 ag_sell_rev_exp 
		rename			s6eq25 harv_sell_need
		rename			s6eq26 s5aq31
		rename			s6eq27__* s5bq27_*
		
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
		rename 			s9q03a have_cov_oth
		rename 			s9q03b have_cov_self
		rename 			s9q04 have_test
		rename			s9q10 cov_vac_know
		rename			s9q10b__* know_vac_*
		rename			s9q11 have_vac
		rename			s9q12 vac_type
		rename			s9q13 cov_vac
		
		gen				cov_vac_dk_why_1 = 1 if s9q14 == 1 & cov_vac == 3
		gen				cov_vac_dk_why_3 = 1 if s9q14 == 2 & cov_vac == 3
		gen				cov_vac_dk_why_6 = 1 if s9q14 == 4 & cov_vac == 3
		gen				cov_vac_dk_why_4 = 1 if s9q14 == 5 & cov_vac == 3
		gen				cov_vac_dk_why_5 = 1 if s9q14 == 6 & cov_vac == 3
		gen				cov_vac_dk_why_10= 1 if s9q14 == 7 & cov_vac == 3
		gen				cov_vac_dk_why_11 = 1 if s9q14 == 8 & cov_vac == 3
		gen				cov_vac_dk_why_12 = 1 if s9q14 == 9 & cov_vac == 3
		
		gen				cov_vac_no_why_1 = 1 if s9q14 == 1 & cov_vac == 3
		gen				cov_vac_no_why_3 = 1 if s9q14 == 2 & cov_vac == 3
		gen				cov_vac_no_why_6 = 1 if s9q14 == 4 & cov_vac == 3
		gen				cov_vac_no_why_4 = 1 if s9q14 == 5 & cov_vac == 3
		gen				cov_vac_no_why_5 = 1 if s9q14 == 6 & cov_vac == 3
		gen				cov_vac_no_why_10= 1 if s9q14 == 7 & cov_vac == 3
		gen				cov_vac_no_why_11 = 1 if s9q14 == 8 & cov_vac == 3
		gen				cov_vac_no_why_12 = 1 if s9q14 == 9 & cov_vac == 3
		
	* drop variables
			*** note: these variables relate to covid and should be inspected in documentation r7s9 if determined needed
		drop			 s9q10c s9q10d s9q11b s9q11c s9q11d s9q14 

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