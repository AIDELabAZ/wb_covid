* Project: WB COVID
* Created on: Aug 2021
* Created by: amf
* Edited by: amf
* Last edited: Aug 2021
* Stata v.17

* does
	* reads in baseline Malawi data
	* pulls FIES data questions

* assumes
	* raw malawi data 

* TO DO:
	* complete


* **********************************************************************
**# setup
* **********************************************************************

* define
	global	root	=	"$data/malawi/raw"
	global	export	=	"$data/malawi/refined"
	global	logout	=	"$data/malawi/logs"

* open log
	cap log 		close
	log using		"$logout/mal_fies", append

	
* ***********************************************************************
**#  FIES data
* ***********************************************************************
		
* load data
	use 			"$root/wave_00/HH_MOD_H", clear

* replace counts with binary indicators	
	lab def 		yesno 1 "Yes" 0 "No" 
	foreach 		x in a b c d e {
		replace 		hh_h02`x' = 1 if hh_h02`x' > 1 & hh_h02`x' < .
		lab val 		hh_h02`x' yesno
	}
	replace 		hh_h01 = 0 if hh_h01 == 2
	lab val 		hh_h01 yesno
	
* rename variables
	rename 			hh_h01 fies_4
	rename 			hh_h02a fies_5
	rename 			hh_h02b fies_8
	rename 			hh_h02c fies_7
	rename 			hh_h02d fies_2
	rename 			hh_h02e fies_9

* keep relevant
	keep 			y4_ HHID* fies_* 
	
* save 
	save			"$export/wave_00/r0_fies", replace

/* END */	