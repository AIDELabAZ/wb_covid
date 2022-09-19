* Project: WB COVID
* Created on: July 2022
* Created by: lirr
* Edited by: lirr
* Last edit: 21 July 2022
* Stata v.17.0

* does
	* reads in twelfth round of Ethiopia data
	* builds round 12
	* outputs round 12

* assumes
	* raw Ethiopia data
	* xfill.ado

* TO DO:
	* Educational Aspirations

	
************************************************************************
**# - setup
************************************************************************

* define 
	global	root	=	"$data/ethiopia/raw"
	global	export	=	"$data/ethiopia/refined"
	global	logout	=	"$data/ethiopia/logs"
	global  fies 	= 	"$data/analysis/raw/Ethiopia"

* open log
	cap log 		close
	log using		"$logout/eth_build", append

* set local wave number & file number
	local			w = 12	
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_`w'" 
	
	
*************************************************************************
**# - roster data - get household size and gender of household head  
*************************************************************************
	
* load roster data
	use				"$root/wave_`w'/210628_WB_LSMS_HFPM_HH_Survey_Roster-Round`w'_Clean-Public", clear
		*** obs == 4512
	
* rename house roster variables
	rename			individual_id ind_id
	rename			bi3_hhm_stillm curr_mem
	rename			bi4_hhm_gender sex_mem
	rename			bi5_hhm_age age_mem
	rename			bi5_hhm_age_months age_month_mem
	rename			bi6_hhm_relhhh relat_mem

* generate counting variables
	gen				hhsize = 1 if curr_mem == 1
	gen				hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem -- 1 & age_mem < 19 & age_mem != .
	gen				hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19
	
* create hh head gender
	gen				sexhh = .
	replace			sexhh = sex_mem if relat_mem == 1
	lab var			sexhh "Sex of household head"

* collapse data
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild  ///
						(max) sexhh, by(household_id)
						*** obs == 888
	lab var			hhsize "Household size"
	lab var 		hhsize_adult "Household size - only adults"
	lab var 		hhsize_child "Household size - children 0 - 18"
	lab var 		hhsize_schchild "Household size - school-age children 5 - 18"

* save temp file
	tempfile		temp_hhsize
	save			`temp_hhsize'
	

*************************************************************************
**# - format survey weights
*************************************************************************	
	
* load microdata
	use "$root/wave_`w'/HFPS-HH_weights_cross-section_R`w'", clear
			*** obs == 881

* save temp file
	tempfile		temp_weights
	save			`temp_weights'
		*** obs == 881


*************************************************************************
**# - format microdata 
*************************************************************************

* load microdata
	use "$root/wave_`w'/210623_WB_LSMS_HFPM_HH_Survey-Round12_Clean-Public", clear
			*** obs == 888
	
* generate round variable
	gen				wave = `w'
	lab var			wave "Wave number"

* save temp file
	tempfile		temp_micro
	save			`temp_micro'
	*** obs == 888 NOTE: there is data on educational aspirations for youth that I do not know what we would care to do with


*************************************************************************
**# - merge to build complete dataset for the round
*************************************************************************

* merge to build complete dataset for the round	
	use				`temp_hhsize', clear
	merge			1:1 household_id using `temp_micro', assert(3) nogen
		*** obs == 888
	merge			1:1 household_id using `temp_weights', nogen
		*** obs == 881 NOTE: there are 8 households w/o r12 weights
	merge			1:1 household_id using "$root/wave_`w'/HFPS-HH_weights_cross-section_R12", nogen
	
	rename			wfinal phw12

* label variables for youth aspirations & employment
	rename			ii4_resp_age yae_age
	rename			ya2_sch_attend yae_sch
	rename			ya3_sch_attend_no yae_sch_why
	rename			ya4_activity_cur yae_curr_act
	replace			yae_curr_act = ya14_activity_cur if yae_curr_act >= .
	rename			ya6_work_age yae_age_work
	rename			ya7_sch_age yae_age_sch
	rename			ya8_sch_qual yae_ed
	rename			ya9_sch_qual_when yae_ed_yr
	rename			ya10_sch_attend_cur yae_ed_curr
	rename			ya11_sch_attend_cur_level yae_ed_lvl
	rename			ya12_sch_finish yae_ed_fin_yr
	rename			ya13_sch_attend_cur_no yae_sch_curr_why
	rename			ya15_work_cur yae_wrk
	replace			yae_wrk = 1 if yae_age_work < .
	rename			ya17_plan yae_ed_plan
	rename			ya18_plan_work_reason yae_ed_plan_why
	rename			ya19_plan_bus yae_bus
	rename			ya20_plan_intern yae_job
	rename			ya21_plan_4w yae_job_how // note change in wording of question b/w eth and mwi
	rename			ya22_edu_imagine yae_ed_asp
	rename			ya23_edu_constr_1 yae_ed_cons_1
	rename			ya23_edu_constr_2 yae_ed_cons_2
	rename			ya24_job_30yrs_code yae_dream_job
	rename			ya25_job_char_1 yae_dream_char_1
	rename			ya25_job_char_2 yae_dream_char_2
	
	* create dream job factor variables to match mwi youth aspirations in r10
		forval 			i = 1/6 {
			gen				yae_fac_`i' = 1 if ya26_job_factor == `i'
			replace			yae_fac_`i' = 0 if yae_fac_`i' == .
		}
		
		gen				yae_fac_96 = 1 if ya26_job_factor == -96
		replace			yae_fac_96 = 0 if yae_fac_96 == .
	
	rename			ya27_job_cur yae_dream_curr
	rename			ya28_job_likely yae_dream_lik
	rename			ya29_job_constr_1 yae_dream_cons_1
	rename			ya29_job_constr_2 yae_dream_cons_2
	rename			ya30_job_com yae_dream_knw
	rename			ya31_job_com_f yae_dream_knw_wom
	rename			ya32_job_com_f_mar yae_dream_knw_wom_mar
	rename			ya33_job_ok_f_mar yae_wrk_wom
	rename			ya34_job_bad_f_mar yae_wrk_wom_comm
	rename			ya35_money yae_mon
	rename			ya36_leave yae_mig
	
	* create migration variables to match mwi r10
		forval			j = 1/5 {
			gen				yae_mig_where_`j' = 1 if ya37_leave_where == `j'
			replace			yae_mig_where_`j' = 0 if yae_mig_where_`j' == .
		}
		
		gen				yae_mig_where_96 = 1 if ya37_leave_where == -96
		replace			yae_mig_where_96 = 0 if yae_mig_where_96 == .
	
	drop			*_other ya5_work_cur ya14_*
	
* destring vars to match other rounds

	split			ii4_resp_id, p("-")
	replace			ii4_resp_id = ii4_resp_id2
	drop			ii4_resp_id1 ii4_resp_id2 
	destring 		cs3c_* cs3b_kebeleid cs5_eaid  ii*, replace
						
* save round file
	save			"$export/wave_`w'/r`w'", replace
	
	

	