/* Let's Reshape
Author: Yazen
Date created: 9/23/2020
*/
pause on

local reshape_folder "C:\Users\YKashlan\Dropbox\GPRL Monthly Coding Challenge\Prompts\lets_reshape"
use "`reshape_folder'\sample.dta", clear

// 1 Exploration
// capture all vars
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
dis 6*12 + 1*3 // all months in 6 years 2012-2017 &  

qui desc
local tot_n `r(k)'
dis "`r(k)'"
assert `lum_n' + `conf_n' + `cas_n' + 1 == `tot_n'

// 2 Adjustments
// 2.1 rename to year_month
forval year = 2012/2018 {
	rename cas_DQL12_*_`year' cas_DQL12_`year'_*
	rename conf_pca_DQL12_*_`year' conf_pca_DQL12_`year'_*
	rename lumindex_count_DQL12_*_`year' lumindex_count_DQL12_`year'_*
}
rename individualcodification id

// 2.2 Keep 1% of data for convenience
// keep 1 year of cas
keep id cas_DQL12* conf_pca_DQL12* lumindex_count_DQL12*
keep if _n <= 200


// 2.2 reorder vars by year, month for convenience
local years 2012 2013 2014 2015 2016 2017 2018
local n_years : word count `years'
local months 1 2 3 4 5 6 7 8 9 10 11 12
local n_months : word count `months'
foreach stub in cas_DQL12 conf_pca_DQL12 lumindex_count_DQL12 { // conf_pca_DQL12 lumindex_count_DQL12
	foreach year in `years' {
		foreach month in `months' {
			capture confirm var `stub'_`year'_`month'
			if (_rc == 0) order `stub'_`year'_`month', last
		}
	}
}

// 3 Reshape
gen year = ., after(id)
gen month = ., after(year)

// count stubs to insobs only at first one
local count_stub 1
local original_N `=_N'

foreach stub in cas_DQL12 conf_pca_DQL12 lumindex_count_DQL12 {

	gen `stub' = ., after (month)
	qui ds `stub'_*
	local var_list `r(varlist)'
	// collect length
	local `stub'_n : word count `r(varlist)'
	local `stub'_n = ``stub'_n' - 1

	forval obs_i = 1/`original_N' {
		local add_after_12x_less11 = (`obs_i'-1)*`n_months'*`n_years' + 1
		dis "`add_after_12x_less11'"

		// foreach observation insert as many variables are there are to reshape
		// only for first stub
		if (`count_stub' == 1) insobs ``stub'_n', after(`add_after_12x_less11') 
		
		// start new counter for replacement
		local counter 0
		foreach var in `var_list' {
			// collect year and month from varname
			local var_name "`var'"
			local var_year = substr("`var_name'", strlen("`stub'_")+1, 4)
			local var_month = substr("`var_name'", strlen("`stub'_xxxx_")+1, .)
			// collect variable at that obs
			local obs
			local obs  `"`=`var'[`add_after_12x_less11']'"' 
			// collect id at that obs
			local id
			local id  `"`=id[`add_after_12x_less11']'"' 
			dis "`id'"
			dis as error "person: `id'"
			dis as error "`var_name'"
			dis as error "obs to reshape `add_after_12x_less11'"
			dis as error "`var_year', `var_month'"
			dis as error "val `obs'"
			
			// reshaping
			local i_replace   = `add_after_12x_less11' + `counter' // update replacement i using counter
			replace `stub' 	  = `obs' in `i_replace'
			replace year      = `var_year' in `i_replace'
			replace month     = `var_month' in `i_replace'
			replace id        = "`id'" in `i_replace' // fill in missing ids
// pause // pause here to see observations being replaced within each variable

			// update counter
			local counter = `counter' + 1
		}
// pause // pause here to see observations being replaced within each individual
	}
	local count_stub = `count_stub' + 1
}

local final_vars id year month cas_DQL12 conf_pca_DQL12 lumindex_count_DQL12 
keep `final_vars'
order `final_vars'


