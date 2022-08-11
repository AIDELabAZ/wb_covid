* Project: WB COVID
* Created on: August 2020
* Created by: lirr
* Edited by : lirr
* Last edited: 11 Aug 2022
* Stata v.17.0

* does
	* reads in sixth round of Uganda data
	* builds round 6
	* outputs round 6

* assumes
	* raw Uganda data

* TO DO:
	* everything
	

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

* rename cope variables
	rename			s9aq03__1 cope_1
	rename			s9aq03__2 cope_2
	rename			s9aq03__3 cope_3
	rename			s9aq03__4 cope_4
	rename			s9aq03__5 cope_5
	rename			s9aq03__6 cope_6
	rename			s9aq03__7 cope_7
	rename			s9aq03__8 cope_8
	rename			s9aq03__9 cope_9
	rename			s9aq03__10 cope_10
	rename			s9aq03__11 cope_11
	rename			s9aq03__12 cope_12
	rename			s9aq03__13 cope_13
	rename			s9aq03__14 cope_14
	rename			s9aq03__15 cope_15
	rename			s9aq03__16 cope_16
	rename			s9aq03__n96 cope_17

* drop unnecessary variables
	drop	shocks__id s9aq01 s9aq02 s9aq03_Other
		*** obs == 31178

* collapse to household level
	collapse (max) cope_1- shock_14, by(HHID)
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
**# - build uganda cross section
*************************************************************************	


* save panel		
	* gen wave data
		rename			wfinal phw_cs
		lab var			phw "sampling weights - cross section"	
		gen				wave = `w'
		lab var			wave "Wave number"
		order			baseline_hhid wave phw, after(hhid)
		rename 			hhid HHID
		
	* save file
		save			"$export/wave_0`w'/r`w'", replace

/* END */	