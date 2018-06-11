/**
* Name: session 7
* Author: 
* Description: Model representing the sanility diffusion among the parcels of Binh Thanh village
*                      taking into account the different dikes and sluices
* Tags: 
*/ 
model session7

global
{
 	file parcel_shapefile <- shape_file("../includes/binhthanh_village_scale/parcels_binhthanh_village.shp");
	file river_shapefile <- shape_file("../includes/binhthanh_village_scale/rivers_chanels_dikes/rivers_binhthanh.shp");
	file sluice_shapefile <- shape_file("../includes/binhthanh_village_scale/rivers_chanels_dikes/sluice_binhthanh.shp");
	file dike_shapefile <- shape_file("../includes/binhthanh_village_scale/rivers_chanels_dikes/dikes_binhthanh.shp");
	file csv_lut <- csv_file("../includes/csv_datasets/lut.csv", true);
	file csv_price <- csv_file("../includes/csv_datasets/price.csv", false);
	file csv_suitability <- csv_file("../includes/csv_datasets/suitability_case.csv", true);
	file csv_transition <- csv_file("../includes/csv_datasets/transition.csv", false);
	file csv_cost <- csv_file("../includes/csv_datasets/cost.csv",false);
	float max_salinity <- 12.0;
	float min_salinity <- 2.0;
	float risk_control <- 1;
	float land_price <- 10^5;
	float max_price;	
	map<string, rgb> color_map <- ["BHK"::# darkgreen, "LNC"::# lightgreen, "TSL"::# orange, "LNQ"::# brown, "LUC"::# lightyellow, "LUK"::# gold, "LTM"::# cyan, "LNK"::# red];
	date starting_date <- date([2005, 1, 1, 0, 0, 0]);
	river the_main_river;
	float step <- 1 # month;
	geometry shape <- envelope(parcel_shapefile);
	list<sluice> openSluice ;
	list<parcel> parcels_not_diked update: parcel where (not each.diked);
	bool rain_season <- false update: current_date.month >= 6 and current_date.month < 11; 
	float weight_profit <- 0.5 parameter:true;
	float weight_risk <-0.5 parameter:true;
	float weight_implementation <-0.5 parameter:true;
	float weight_suitability <-0.5 parameter:true;
	float weight_neighborhood <-0.5 parameter:true;
	list criteria <- [["name"::"profit", "weight" :: weight_profit],["name"::"risk", "weight" :: weight_risk],["name"::"implementation", "weight" ::weight_implementation],["name"::"suitability", "weight" :: weight_suitability],["name"::"neigboorhood", "weight" :: weight_neighborhood]]; 
	float probability_changing <- 0.5 parameter: true;
	
	action load_land_use
	{
		create land_use from: csv_lut with: [name::get("landuse"),lu_code::get("lu_code"),
			average_yield_ha::float(get("avg_yield_ha")),risk::float(get("risk"))];
	}
	action load_price
	{
		matrix<string> data <- csv_price.contents;
		loop lu_row from: 1 to: data.rows - 1
		{
			string lu_code <- data[0, lu_row];
			land_use concerned <- first(land_use where (each.lu_code = lu_code));
			loop year from: 1 to: data.columns - 1
			{
				add float(data[year, lu_row]) to: concerned.price_map at: (year - 1) + 2005;
			}
		}
		max_price <- max(land_use accumulate(each.price_map.values));	
	}
	
	/**
	 * load the cost
	 */
	action load_cost {
		matrix<string> data <- csv_cost.contents;
		loop lu_row from: 1 to: data.rows - 1
		{
			string lu_code <- data[0, lu_row];
			land_use concerned <- first(land_use where (each.lu_code = lu_code));
			loop year from: 1 to: data.columns - 1
			{
				add float(data[year, lu_row]) to: concerned.cost_map at: (year - 1) + 2005;
			}
		}
	}
	
	action load_transition
	{
		matrix<string> data <- csv_transition.contents;
		loop lu_row from: 1 to: data.rows - 1
		{
			string lu_code <- data[0, lu_row];
			land_use concerned <- first(land_use where (each.lu_code = lu_code));
			loop col from: 1 to: data.columns - 1
			{
				add int(data[col, lu_row]) to: concerned.transition_map at: data[col, 0];
			}
		}
	}
	action load_suitability
	{
		create suitability_case from: csv_suitability with: [soil_type::get("soiltType"),acidity::get("acid_depth"), 
			salinity::int(get("salinity")), lu_code::get("lu_code"), suitability::int(get("landsuitability"))];
	}
	action load_parcel
	{
		create parcel from: parcel_shapefile
		{
			add read("lu05") to: lu_years at: 2005;
			add read("lu10") to: lu_years at: 2010;
			add read("lu14") to: lu_years at: 2014;
			soil_type <- read("soil");
			acidity <- read("acid_d");
			add float(read("sal_05")) to: salinity_years at: 2005;
			add float(read("sal_10")) to: salinity_years at: 2010;
			add float(read("sal_14")) to: salinity_years at: 2014;
			my_land_use <- first(land_use where (each.lu_code = lu_years[2005]));
			current_salinity <- salinity_years[2005];
			create farmer with:[my_parcel::self, location::location] {
				myself.owner <- self;	
			}
		}
		
		ask parcel {
			neighborhood <- parcel at_distance (10);
		}
		ask farmer
		{
			neighborhood <- farmer at_distance(200);
		}
		max_salinity <- max(parcel accumulate each.salinity_years.values);
		min_salinity <- min(parcel accumulate each.salinity_years.values);
	}
	action load_river
	{
		create river from: river_shapefile with:[is_main_river::(get("MAIN") = "T")] ;
		the_main_river <- river first_with each.is_main_river;
	}
		action load_dike
	{
		create dike from: dike_shapefile
		{
			contactParcel <- parcel at_distance (200);
			contactRiver <- river where (not each.is_main_river and (each.shape intersects (self.shape)));
	
			ask (contactParcel)
			{
				diked <- true;
			}

			ask (contactRiver)
			{
				diked <- true;
			}

		}
	}
	action load_sluice
	{
		create sluice from: sluice_shapefile with:[open::(read("OPEN") = "T")]
		{
			if (open=false)
			{
				ask contactRiver
				{
					diked <- true;
				}
			}
		}
		openSluice <- sluice where (each.open);
		ask openSluice
		{
			ask contactParcel
			{
				disableByDrain <- false;
				diked <- false;
			}
			ask contactRiver
			{
				diked <- false;
			}
		}
	}
	init
	{
		do load_land_use;
		do load_price;
		do load_cost;
		do load_transition;
		do load_suitability;
		do load_parcel;
		do load_river;
		do load_dike;
		do load_sluice;	
	}
	reflex salinity_diffusion 
	{
		ask parcels_not_diked {
			do diffusion;
		}
		ask parcels_not_diked {
			do update_salinity;
		}
		ask river {
			do diffusion;
		}
		ask river {
			do apply_diffusion;
		}
		ask river where(not(each.diked)) {
			do salt_intrusion;
		}
	}
	reflex salt_intrusion 
	{
		if (not rain_season)
		{
			the_main_river.river_salt_level <- 12.0;
			the_main_river.river_salt_level_tmp <- 12.0;
		} else
		{
			if (the_main_river.river_salt_level > 3)
			{
				the_main_river.river_salt_level <- the_main_river.river_salt_level - 1;
				the_main_river.river_salt_level_tmp <- the_main_river.river_salt_level - 1;
			}
		}
	}
	reflex end_simulation when: current_date.year = 2010 and current_date.month = 12 {
		do pause;
	}
	
	/**
	 *  compute the price and cost after 2010
	 */
	action compute_price_this_year {
		int current_year <- current_date.year;
		loop lu over: land_use {
			float current_price <- lu.price_map[current_year];
			if (current_price = 0) {
				lu.price_map[current_year] <- lu.price_map[current_year - 1] + rnd(0.5, 1.5) * current_price;
			}
			float current_cost <- lu.cost_map[current_year];
			if (current_cost = 0) {
				lu.cost_map[current_year] <- lu.cost_map[current_year - 1] + rnd(0.5, 1.5) * current_cost;
			}
		}
	}
	
	reflex farmer_action when: every(#year)
	{
		do compute_price_this_year;
		ask farmer parallel:true
		{
			if (self.my_parcel != nil) {
				do make_decision;
				do compute_money_earn;
			}
		}
	}
}
species land_use
{
	string lu_code;
	map<string, float> transition_map;
	float risk;
	float average_yield_ha;
	map<int, float> price_map;
	map<int, float> cost_map;
}

species suitability_case
{
	string soil_type;
	string acidity;
	int salinity;
	string lu_code;
	int suitability;
}

species parcel
{
	land_use my_land_use;
	map<int, string> lu_years;
	string soil_type;
	string acidity;
	
	// add owner for parcel
	farmer owner;
	
	map<int, float> salinity_years;
	float current_salinity max: 12.0;
	float current_salinity_tmp;
	bool diked <- false;
	bool disableByDrain <- false;
	
	float price <- shape.area * land_price;
	
	list<parcel> neighborhood;
	list<parcel> availableNeighbors -> {[] + self + self.neighborhood where (not each.diked)};
	
	action diffusion 
	{
		current_salinity_tmp <- current_salinity_tmp+min([12,mean((availableNeighbors) collect (each.current_salinity))] );
	}
	action update_salinity {
		current_salinity <- current_salinity_tmp;
		current_salinity_tmp <- 0.0;
	}

	aspect land_use
	{
		// if no owner then the land has the color black
		draw shape color: owner != nil ? color_map[my_land_use.lu_code] : #black border: #black;
	}
	aspect salinity
	{
		draw shape color: hsb(0.4 - 0.4 * (min([1.0, (max([0.0, current_salinity - min_salinity])) / max_salinity])), 1.0, 1.0);
	}

	aspect salinity2010
	{
		draw shape color: hsb(0.4 - 0.4 * (min([1.0, (max([0.0, salinity_years[2010] - min_salinity])) / max_salinity])), 1.0, 1.0);
	}
	aspect land_use2010
	{
		draw shape color: color_map[lu_years[2010]] border: #black;
	}
}
species river
{
	bool diked <- false;
	list<parcel> contactParcel <- parcel overlapping (self);
	list<parcel> availableParcel -> { contactParcel where (not each.diked) };
	list neighborhood <- river overlapping (self);
	list availableNeighbours -> { self.neighborhood where (not each.diked) };
	float river_salt_level <- 0.0;
	float river_salt_level_tmp <-0.0;
	bool is_main_river<-false;
	
	action diffusion
	{
		if(is_main_river=false)
		{
			ask (availableNeighbours)
			{
				myself.river_salt_level_tmp <-myself.river_salt_level_tmp + river_salt_level;
			}
		}
	}
	action apply_diffusion
	{
	   river_salt_level<-river_salt_level_tmp;
		river_salt_level_tmp <- river_salt_level;
	}
	action salt_intrusion
	{
		ask (availableParcel)
		{
			current_salinity_tmp <- current_salinity_tmp + myself.river_salt_level;
		}
	}
	aspect default
	{
		draw shape color: # blue;
	}
	aspect salinity
	{
		draw shape color: hsb(0.4 - 0.4 * (min([1.0, (max([0.0, self.river_salt_level - min_salinity])) / max_salinity])), 1.0, 1.0) border:#black;
	}
}

species dike
{
	list<parcel> contactParcel;
	list<river> contactRiver;
	aspect default
	{
		draw shape + 50 color: # green;
	}
}
species sluice
{
	bool open <- false;
	list<river> contactRiver <- river at_distance (50) where (not each.is_main_river);
	list<parcel> contactParcel <- parcel at_distance (50);
	list<dike> contactDike <- dike at_distance (50);
	aspect default
	{
		draw square(100) at: location color: open ? #green : #red;
	}
}
species farmer
{
	parcel my_parcel;
	
	// the richer you get the bigger you are
	float size <- 5.0 update: (money / 10^9) * 10 + 5;
	
	list<farmer> neighborhood;
	
	// set the initial money
	float money <- rnd(50 * 10^6, 200 * 10^6);
	
	aspect default {
		if (my_parcel != nil) {
			// only display the farmer if he/she owns this land
			draw circle(size) color: money > 0 ? #white : #black border: #black;
		}
	}
	
	
	float compute_expected_profit(land_use a_lu)
	{
		float price_of_product <- a_lu.price_map[current_date.year];
		return price_of_product/max_price;	
	}
	
	float compute_risk(land_use a_lu)
	{
		return 1.0 - a_lu.risk;
	}
	float compute_implementation(land_use a_lu)
	{
		return ((3-my_parcel.my_land_use.transition_map[a_lu.lu_code])/2);
	}
	float compute_suitability(land_use a_lu)
	{
		int f_salinity <- my_parcel.current_salinity<=2?2:
			(my_parcel.current_salinity<=4?4:
				(my_parcel.current_salinity<=8?8:12)
			);
			
		suitability_case sc <- first(suitability_case where(each.lu_code=a_lu.lu_code and each.soil_type=my_parcel.soil_type and each.acidity=my_parcel.acidity and each.salinity=f_salinity));
		return 1.0-(sc.suitability -1)/3.0;
	}
	float compute_neighborhood(land_use a_lu)
	{
		int nb_similars <- neighborhood count(each.my_parcel != nil and each.my_parcel.my_land_use = a_lu);
		return nb_similars/length(neighborhood);
	}
	list<list> land_use_eval(list<land_use> lus) {
		list<list> candidates;
		loop lu over: lus {
			list<float> cand;
			cand << compute_expected_profit(lu);
			cand << compute_risk(lu);
			cand << compute_implementation(lu);
			cand << compute_suitability(lu);
			cand << compute_neighborhood(lu);
			candidates << cand;
		}
		return candidates;
	}
	action make_decision {
		if(flip(probability_changing)) {
			list<list> cands <- land_use_eval(list(land_use));
		
			int choice <- weighted_means_DM(cands, criteria);
			my_parcel.my_land_use <- land_use[choice];
		}
	}
	
	/**
	 * Compute the money earned each year
	 */
	action compute_money_earn {
		land_use lu <- my_parcel.my_land_use;
		float area <- my_parcel.shape.area;
		// compute the revenue
		float price_of_product <- lu.price_map[current_date.year];
		float gain <- price_of_product * area * (1 - lu.risk * risk_control);
		
		// compute the expense
		float cost_of_product <- lu.cost_map[current_date.year];
		float expense <-  cost_of_product * area;
		float profit <- gain - expense;
		
		// update the money of farmer
		money <- money + profit;
		
		if (money < 0) {
			// if the farmer have no money left, he/she sells his/her parcel
			self.money <- self.money + self.my_parcel.price; //
			self.my_parcel.owner <- nil;
			self.my_parcel <- nil;
		}
	}
}
experiment display_map
{
	parameter "Risk control: " var: risk_control;
	output
	{
		display landuse background: #lightgray type: opengl
		{
			image file("../images/background.png") refresh: false;
			species parcel aspect: land_use;
			species river aspect: default;
			species sluice aspect: default;
			species dike aspect: default;
			species farmer aspect: default;
		}
		monitor "year" value: current_date.year;
		monitor "number of farmers with land: " value: (farmer count (each.my_parcel != nil));
//		display salinity
//		{
//			species parcel aspect: salinity;
//			species river aspect: default;
//			species dike aspect: default;
//			species sluice aspect: default;
//		}
//		display salinity2010
//		{ 
//			species parcel aspect: salinity2010;
//			species river aspect: default;
//			species dike aspect: default;
//			species sluice aspect: default;
//		}
//		display salinity_river
//		{ 
//			species river aspect: salinity;
//			species dike aspect: default;
//			species sluice aspect: default;
//		}
//		display landuse2010 background: #lightgray
//		{
//			image file("../images/background.png") refresh: false;
//			species parcel aspect: land_use2010;
//			species river aspect: default;
//			species sluice aspect: default;
//			species dike aspect: default;
//		}
	}
}