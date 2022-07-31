* Project: WB COVID
* Created on: July 2022
* Created by: lirr
* Edited by: lirr
* Last edit: 25 July 2022
* Stata v.17.0

* does
	* reads in third round of BF data
	* builds round 11
	* outputs round 11

* assumes
	* raw BF data

* TO DO:
	* everything
	
	
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
	local			w = 11
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir 	"$export/wave_`w'" 

	
*************************************************************************
**# - get respondent data
*************************************************************************	

* load respondent id data
	use				"$root/wave_`w'/r`w'_sec1a_info_entretien_tentative", clear
		*** obs == 2552
	keep			if s01aq08 == 1
		*** obs == 1931
	rename			s01aq09 membres__id
	duplicates 		drop hhid membres__id, force
		*** obs == 1926
	duplicates		tag hhid, gen(dups)
	replace			membres__id = -96 if dups > 0
	duplicates 		drop hhid membres__id, force
		*** obs == 1924
	lab def			mem -96 "multiple respondents"
	lab val			membres__id mem
	keep			hhid membres__id
		*** obs == 1924
		
* load roster data with gender
	merge 1:1		hhid membres__id using "$root/wave_`w'/r`w'_sec2_liste_membre_menage"
		*** obs == 12964: 1922 matched, 11042 unmatched
	keep			if _m == 1 | _m == 3
		*** obs == 1924
	keep			hhid s02q05 membres__id s02q07 s02q06
		*** obs == 1924
		rename 			membres__id resp_id
	rename 			s02q05 sex
	rename 			s02q06 age
	rename 			s02q07 relate_hoh

* save temp file
	tempfile		tempa
	save			`tempa'
	
		
*************************************************************************
**# - merge
*************************************************************************
		
* generate round variables
	gen				wave = `w'
	lab var			wave "Wave number"
	rename 			hhwcovid_r`w'_cs phw_cs
	rename 			hhwcovid_r`w'_pnl phw_pnl
	label var		phw_cs "sampling weights- cross section"
	label var		phw_pnl "sampling weights- panel"
	
* save round file
	save			"$export/wave_`w'/r`w'", replace