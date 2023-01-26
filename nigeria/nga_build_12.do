* Project: WB COVID
* Created on: July 2022
* Created by: lirr
* Edited by: lirr
* Last edited: 23 August 2022
* Stata v.17.0

* does
	* reads in first round of Nigeria data
	* reshapes and builds panel
	* outputs panel data 

* assumes
	* raw Nigeria data

* TO DO:
	* everything
	

*************************************************************************
**# - setup
*************************************************************************

* define 
	global	root	=	"$data/nigeria/raw"
	global	export	=	"$data/nigeria/refined"
	global	logout	=	"$data/nigeria/logs"
	global  fies 	= 	"$data/analysis/raw/Nigeria"

* open log
	cap log 		close
	log using		"$logout/nga_reshape", append

* set local wave number & file number
	local			w = 12
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_`w'"

	
*************************************************************************
**# - section 2: household size and gender of HOH
*************************************************************************

* load data
	use				"$root/wave_`w'/r`w'_sect_2", clear
		*** obs == 7884

* rename other variables
	rename			indiv ind_id
	rename			s2q3_r11 curr_mem // making assumption that questions are equivalent
	rename			s2q5_r11 sex_mem 
	rename			s2q6_r11 age_mem
	rename			s2q7_r11 relat_mem

* generate counting variables
	gen				hhsize = 1 if curr_mem == 1
	gen				hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem == 1 & age_mem < 19 & age_mem != . 
	gen 			hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19
		*** obs == 7884		
		
* generate migration variables	
		/// I have questions, there s2q3_r11 could be proxy but unsure no reason for leaving or gaining members. 
		
* create hh head gender
	gen				sexhh = .
	replace			sexhh = sex_mem if relat_mem == 1
	label var		sexhh "Sex of household head"

* collapse data to hh level
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild ///
						(max) sexhh, by(hhid)
		*** obs == 986
	lab var			hhsize "Household size"
	lab var			hhsize_adult "Household size - only adults"
	lab var			hhsize_child "Household size - children 0 - 18"
	lab var			hhsize_schchild "Household size - school-age children 5 - 18"
	
* save temp file
	tempfile		tempa
	save			`tempa'

	
*************************************************************************
**# - merge sections into panel and save
*************************************************************************

* merge sections based on hhid
	use				"$root/wave_`w'/r`w'_sect_5e_9a", clear
		*** obs == 974
	merge			1:1 hhid using "$root/wave_`w'/r`w'_sect_a_12", nogen
		*** obs == 1238: 974 matched, 264 unmatched

* merge in other section
	merge			1:1 hhid using `tempa', nogen
		*** obs == 1238: 986 matched, 252 unmatched
		
* generate round variable
	gen				wave = `w'
	lab var			wave "Wave number"

* clean variables inconsistent with other rounds
	
	* youth aspirations
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
		

		
		* create loops to extract yae_ed_cons values
			gen				yae_ed_cons_1 = .
			forval 			i = 1/20 {	
				replace 		yae_ed_cons_1 = `i' if  s5eq23__`i' == 1 ///
					& yae_ed_cons_1 == .
			}
			
			gen				yae_ed_cons_2 = .
			forval			j = 1/20 {
				replace			yae_ed_cons_2 = `j' if s5eq23__`j' == 1 ///
					& `j' > yae_ed_cons_1
			}
			
			replace			yae_ed_cons_1 = 96 if yae_ed_cons_1 == .
			replace			yae_ed_cons_2 = 96 if yae_ed_cons_2 == . & ///
								yae_ed_cons_1 != 96
								
		rename 			s5eq24b yae_dream_job
		
		* create loops to extract yae_dream_char values
			gen				yae_dream_char_1 = .
			forval 			k = 1/13 {	
				replace 		yae_dream_char_1 = `k' if  s5eq25__`k' == 1 ///
					& yae_dream_char_1 == .
			}
			
			gen				yae_dream_char_2 = .
			forval			l = 1/13 {
				replace			yae_dream_char_2 = `l' if s5eq25__`l' == 1 ///
					& `l' > yae_dream_char_1
			}
			
			replace			yae_dream_char_1 = 96 if yae_dream_char_1 == .
			replace			yae_dream_char_2 = 96 if yae_dream_char_2 == . & ///
								yae_dream_char_1 != 96
								
		rename 			s5eq26__* yae_dream_fac_*
		rename 			s5eq27 yae_dream_curr
		rename 			s5eq28 yae_dream_lik
		
		* create loops to extract yae dream constraint vaules
			gen				yae_dream_cons_1 = .
			forval 			x = 1/18 {	
				replace 		yae_dream_cons_1 = `x' if  s5eq29__`x' == 1 ///
					& yae_dream_cons_1 == .
			}
			
			gen				yae_dream_cons_2 = .
			forval			y = 1/18 {
				replace			yae_dream_cons_2 = `y' if s5eq29__`y' == 1 ///
					& `y' > yae_dream_cons_1
			}
			
			replace			yae_dream_cons_1 = 96 if yae_dream_cons_1 == .
			replace			yae_dream_cons_2 = 96 if yae_dream_cons_2 == . & ///
								yae_dream_cons_1 != 96
		
		rename 			s5eq30 yae_dream_knw
		rename 			s5eq31 yae_dream_knw_wom
		rename 			s5eq32 yae_dream_knw_wom_mar
		rename 			s5eq33 yae_wrk_wom
		rename 			s5eq34 yae_wrk_wom_comm
		rename 			s5eq35 yae_mon
		rename 			s5eq36 yae_mig
		rename 			s5eq37__* yae_mig_where_*
		
		drop			s5eq* Sec5e_StartTime
	
	* covid vaccine likelihood to receive when advised
		rename			s9aq4__* cov_vac_more_lik_*
	
	* rename weight variables NOTE: these are only for youth panel
		rename			wt_youth_r12 wt_round12
		rename			wt_youth_r12_panel wt_r12panel
	
* save round file
	save			"$export/wave_`w'/r`w'", replace

* close the log
	log	close
	
	
/* END */	