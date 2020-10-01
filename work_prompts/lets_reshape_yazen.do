/*******************************************************************************
Let's Reshape
GPRL coding prompts: Prompt 1

Created by: Yazen (ykashlan@poverty-action.org)
Date created: 9/23/2020
Date updated: 9/30/2020 (added/cleaned up comments and added timer command)
Stata version: 15.1
Reshape run time: 932.55 seconds, ~16 mins ...be careful XD

Outline:

// 1   Explore variables
// 2   Adjustments
// 2.1 rename to year_month
// 2.2 reorder vars by year, month for convenience

// 3     Reshape
// 3.1   set up
// 3.2   loop on stubs (wide variables)
// 3.3   loop on observations within each stub
// 3.4   loop on variables within observations within stubs
// 3.4.1 fill in new observations 

*******************************************************************************/

pause on
timer clear 

local reshape_folder "C:\Users\YKashlan\Dropbox\GPRL Monthly Coding Challenge\Prompts\lets_reshape"
use "`reshape_folder'\sample.dta", clear

// 1 Explore variables
qui ds cas_DQL12_*
local cas_n : word count `r(varlist)'
dis "`cas_n'"
dis 7*12 // all months in 7 years 2012-2018

qui ds conf_pca_DQL12_*
local conf_n : word count `r(varlist)'
dis "`conf_n'"
dis 7*12 // all months in 7 years 2012-2018

qui ds lumindex_count_DQL12_*
local lum_n : word count `r(varlist)'
dis "`lum_n'"
dis 6*12 + 1*3 // all months in 6 years 2012-2017 & 3 in 2018

qui desc
local all_n `r(k)'
dis "`r(k)'"
assert `lum_n' + `conf_n' + `cas_n' + 1 == `all_n'


// 2 Adjustments
// 2.1 rename to year_month
forval year = 2012/2018 {
	rename cas_DQL12_*_`year' cas_DQL12_`year'_*
	rename conf_pca_DQL12_*_`year' conf_pca_DQL12_`year'_*
	rename lumindex_count_DQL12_*_`year' lumindex_count_DQL12_`year'_*
}
rename individualcodification id
keep id cas_DQL12* conf_pca_DQL12* lumindex_count_DQL12*
isid id
// keep if _n <= 200

// 2.2 reorder wide vars chronologically for convenience
local years 2012 2013 2014 2015 2016 2017 2018
local n_years : word count `years'
local months 1 2 3 4 5 6 7 8 9 10 11 12
local n_months : word count `months'
foreach stub in cas_DQL12 conf_pca_DQL12 lumindex_count_DQL12 {
	foreach year in `years' {
		foreach month in `months' {
			capture confirm var `stub'_`year'_`month'
			if (_rc == 0) order `stub'_`year'_`month', last
		}
	}
}


// 3 Reshape
timer on 1
// 3.1 set up
gen year = ., after(id)
gen month = ., after(year)
local original_N `=_N' 	 // (used as 3.3 loop. Must set here since this changes later)
local counter_stub 1 	 // set stub counter and insobs only at first stub (used in 3.3)

qui {
	// 3.2 loop on stubs (wide variables)
	foreach stub in cas_DQL12 conf_pca_DQL12 lumindex_count_DQL12 {

		// within each stub:
		gen `stub' = ., after (month)   // generate placeholder for stub
		qui ds `stub'_* 				// list vars to reshape within stub
		local var_list `r(varlist)'
		local `stub'_n : word count `var_list' 	// collect length
		local `stub'_n = ``stub'_n' - 1 // new obs needed = 1 less than no. of vars in wide stub

		
		// 3.3 loop on observations within each stub
		forval obs_i = 1/`original_N' {
		
			// within each observation:
			// set obs number after which new observations will be added
			local add_after_this_i = (`obs_i'-1)*`n_months'*`n_years' + 1
			
			// insert as many variables as there are to reshape only for first stub
			if (`counter_stub' == 1) insobs ``stub'_n', after(`add_after_this_i') 
			
			// start new counter to replace missings in stub (used in 3.4.1)
			local counter 0
			
			// 3.4 loop on variables within observations within stubs
			foreach var in `var_list' {
			
				// within each var:
				// collect year and month from varname
				local var_name "`var'" 
				local var_year = substr("`var_name'", strlen("`stub'_")+1, 4)
				local var_month = substr("`var_name'", strlen("`stub'_xxxx_")+1, .)
				
				// collect variable at that obs
				local obs
				local obs  `"`=`var'[`add_after_this_i']'"' 
				
				// collect id at that obs
				local id
				local id  `"`=id[`add_after_this_i']'"' 

// 				// sanity checks
// 				dis as error "For person, `id'"
// 				dis as error "on `var_month'-`var_year'"
// 				dis as error "reshape obs `add_after_this_i'"
// 				dis as error "for `var_name'"
// 				dis as error "with value `obs'"
			
				// 3.4.1 fill in new observations 
				local i_replace   = `add_after_this_i' + `counter' // update replacement i using counter
				
				replace `stub' 	  = `obs'       in `i_replace'
				replace year      = `var_year'  in `i_replace'
				replace month     = `var_month' in `i_replace'
				replace id        = "`id'"      in `i_replace' // fill in missing ids

				// update counter
				local counter = `counter' + 1 // this runs over new empty obs (used in 3.4.1)
			}
		}
		local counter_stub = `counter_stub' + 1 // this runs over the 3 wide vars (used in 3.3)
	}
}

timer off 1 
timer list 1 // display timer 1



local final_vars id year month cas_DQL12 conf_pca_DQL12 lumindex_count_DQL12 
keep `final_vars'
order `final_vars'



