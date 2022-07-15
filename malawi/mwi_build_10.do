* Project: WB COVID
* Created on: Aug 2021
* Created by: amf
* Edited by: amf, lirr (style edits)
* Last edited: 13 July 2022
* Stata v.17.0

* does
	* merges together each section of malawi data
	* builds round 10
	* outputs round 10

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
	local			w = 10
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_`w'" 	

	
*************************************************************************
**# - get respondant gender
*************************************************************************

* load data
	use				"$root/wave_`w'/sect12_Interview_Result_r`w'", clear
		*** obs == 919

* drop all but household respondant
	keep			HHID s12q9
		*** obs == 919
	rename			s12q9 PID
	isid			HHID

* merge in household roster
	merge 1:1		HHID PID using "$root/wave_`w'/sect2_Household_Roster_r`w'.dta"
		*** obs == 5553: 918 matched, 4635 unmatched
	keep if			_merge == 3
		*** obs == 918
	drop			_merge
		*** obs == 918

* drop all but gender and relation to HoH, rename to match other rounds 
	keep			HHID PID preload_sex preload_relation current_age
		*** obs == 918
	rename 			preload_sex s2q5
	rename 			preload_relation s2q7
	rename 			current_age s2q6

* save temp file
	tempfile		tempc
	save			`tempc'
		
	
*************************************************************************
**# - get household size and gender of HOH
*************************************************************************

* load data
	use			"$root/wave_`w'/sect2_Household_Roster_r`w'.dta", clear
		*** obs == 5552

* rename other variables 
	rename 			PID ind_id 
	rename 			preload_sex sex_mem
	rename 			preload_relation relat_mem	

* generate counting variables
	gen				hhsize = 1 
	
* create hh head gender
	gen 			sexhh = . 
	replace			sexhh = sex_mem if relat_mem == 1
	label var 		sexhh "Sex of household head"
		*** obs == 5552
	
* collapse data to hh level and merge in why vars
	collapse	(sum) hhsize (max) sexhh, by(HHID y4)
		*** obs == 919
	
* save temp file
	tempfile		tempa
	save			`tempa'

	
*************************************************************************
**# - merge to build complete dataset for the round 
*************************************************************************

* load cover data
	use				"$root/wave_`w'/secta_Cover_Page_r`w'", clear
		*** obs == 1136
	
* merge formatted sections
	merge 			1:1 HHID using `tempa', nogen
		*** obs == 1136: 919 matched, 217 unmatched
	merge 			1:1 HHID using `tempc', nogen
		*** obs == 1136: 918 matched, 218 unmatched
	
* merge in other sections
	merge 1:1 		HHID using "$root/wave_`w'/sect4_behavior_r`w'.dta", nogen	
		*** obs == 1136: 919 matched, 217 unmatched
	merge 1:1 		HHID using "$root/wave_`w'/sect5e_youth_r`w'.dta", nogen
		*** obs == 1136: 919 matched, 217 unmatched

* rename variables inconsistent with other waves	
	
	* behavior
		rename 			s4q8b cov_vac_know
	
	* youth aspirations and employment 
		rename 			s5eq2a yae_age
		rename 			s5eq2 yae_sch
		rename 			s5eq3 yae_sch_why
		rename 			s5eq4 yae_curr_act
		replace 		yae_curr_act = s5eq14 if yae_curr_act >= .
		rename 			s5eq6 yae_age_wrk
		replace 		yae_age_wrk = s5eq16 if yae_age_wrk >=.
		rename 			s5eq7 yae_age_sch
		rename 			s5eq8 yae_ed
		rename 			s5eq9 yae_ed_yr
		rename 			s5eq10 yae_ed_curr
		rename 			s5eq11 yae_ed_lvl
		rename 			s5eq12 yae_ed_fin_yr
		rename 			s5eq13 yae_sch_curr_why
		rename 			s5eq15 yae_wrk
		replace 		yae_wrk = 1 if yae_age_wrk < .
		rename 			s5eq17 yae_ed_plan
		rename 			s5eq18 yae_ed_plan_why
		rename 			s5eq19 yae_bus
		rename 			s5eq20 yae_job
		rename 			s5eq21 yae_job_how
		rename 			s5eq22 yae_ed_asp
		rename 			s5eq23a yae_ed_cons_1
		rename 			s5eq23b yae_ed_cons_2
		rename 			s5eq24b yae_dream_job
		rename 			s5eq25a yae_dream_char_1
		rename 			s5eq25b yae_dream_char_2
		rename 			s5eq26__* yae_dream_fac_*
		rename 			s5eq27 yae_dream_curr
		rename 			s5eq28 yae_dream_lik
		rename 			s5eq29a yae_dream_cons_1
		rename 			s5eq29b yae_dream_cons_2
		rename 			s5eq30 yae_dream_knw
		rename 			s5eq31 yae_dream_knw_wom
		rename 			s5eq32 yae_dream_knw_wom_mar
		rename 			s5eq33 yae_wrk_wom
		rename 			s5eq34 yae_wrk_wom_comm
		rename 			s5eq35 yae_mon
		rename 			s5eq36 yae_mig
		rename 			s5eq37__* yae_mig_where_*
		
		drop 			*_os s5eq5 s5eq8_oth s5eq14 s5eq16 s5eq24a yae_dream_fac_96 ///
							yae_mig_where_96 preload_sex preload_relation
			*** obs == 1136
							
* generate round variables
	gen				wave = `w'
		*** obs == 1136
	lab var			wave "Wave number"
	rename			wt_round`w' phw_cs
	label var		phw "sampling weights - cross section"
	
* save round file
	save			"$export/wave_`w'/r`w'", replace

/* END */		