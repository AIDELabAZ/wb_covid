* Project: WB COVID
* Created on: July 2022
* Created by: lirr
* Edited by: lirr
* Last edited: 07 July 2022
* Stata v.17.0

* does
	* merges together each section of malawi data
	* builds round 1
	* outputs round 1

* assumes
	* raw malawi data 

* TO DO:
	* everything
	

************************************************************************
**# - setup
************************************************************************

* define
	global	root	=	"$data/malawi/raw"
	global	export	=	"$data/malawi/refined"
	global	logout	=	"$data/malawi/logs"
	global  fies 	= 	"$data/analysis/raw/Malawi"

* open log
	cap log 		close
	log using		"$logout/mal_build", append
	
* set local wave number & file number
	local			w = 12
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_`w'" 	
	

*************************************************************************
** - reshape section on income loss wide data
*************************************************************************	

* no data


*************************************************************************
**# - reshape section on safety nets wide data
*************************************************************************

* no data
	
*************************************************************************
** - get respondent gender
*************************************************************************	
	
* load data
	use				"$root/wave_`w'/sect12_Interview_result_r`w'", clear
		***obs == 1533

* drop all but household respondant
	keep			HHID s12q9
	rename			s12q9 PID
	isid			HHID

* merge in household roster
	merge 1:1 HHID PID using "$root/wave_`w'/sect2_Household_Roster_r`w'"
		***obs == 7793 | from master not matched - 1  | from using not matched - 6260 | matched == 1532
	keep if			_merge == 3
		*** obs == 1532
	drop			_merge
		*** obs == 1532
		
* drop all but gender and relation to HoH
	keep			HHID PID s2q5 s2q6 s2q7 s2q9

* save temp file
	tempfile		tempc
	save			`tempc'
	

	
		
		