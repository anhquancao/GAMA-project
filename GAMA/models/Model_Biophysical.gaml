/**
* Name: session 6
* Author: 
* Description: Model representing the sanility diffusion among the parcels of Binh Thanh village
*                      taking into account the different dikes and sluices
* Tags: 
*/ 
model session6

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
	float max_salinity <- 12.0;
	float min_salinity <- 2.0;
	float max_price;	
	map<string, rgb> color_map <- ["BHK"::# darkgreen, "LNC"::# lightgreen, "TSL"::# orange, "LNQ"::# brown, "LUC"::# lightyellow, "LUK"::# gold, "LTM"::# cyan, "LNK"::# red];
	date starting_date <- date([2005, 1, 1, 0, 0, 0]);
	river the_main_river;
	float step <- 1 # month;
	geometry shape <- envelope(parcel_shapefile);
	list<sluice> openSluice ;
	list<parcel> parcels_not_diked update: parcel where (not each.diked);
	bool rain_season <- false update: current_date.month >= 6 and current_date.month < 11; 
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
		}
		
		ask parcel {
			neighborhood <- parcel at_distance (10);
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
}
species land_use
{
	string lu_code;
	map<string, float> transition_map;
	float risk;
	float average_yield_ha;
	map<int, float> price_map;
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
	map<int, float> salinity_years;
	float current_salinity max: 12.0;
	float current_salinity_tmp;
	bool diked <- false;
	bool disableByDrain <- false;
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
		draw shape color: color_map[my_land_use.lu_code] border: #black;
	}
	aspect salinity
	{
		draw shape color: hsb(0.4 - 0.4 * (min([1.0, (max([0.0, current_salinity - min_salinity])) / max_salinity])), 1.0, 1.0);
	}

	aspect salinity2010
	{
		draw shape color: hsb(0.4 - 0.4 * (min([1.0, (max([0.0, salinity_years[2010] - min_salinity])) / max_salinity])), 1.0, 1.0);
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
experiment display_map
{
	output
	{
		display landuse background: #lightgray
		{
			image file("../images/background.png") refresh: false;
			species parcel aspect: land_use;
			species river aspect: default;
			species sluice aspect: default;
			species dike aspect: default;
		}
		display salinity
		{
			species parcel aspect: salinity;
			species river aspect: default;
			species dike aspect: default;
			species sluice aspect: default;
		}
		display salinity2010
		{ 
			species parcel aspect: salinity2010;
			species river aspect: default;
			species dike aspect: default;
			species sluice aspect: default;
		}
		display salinity_river
		{ 
			species river aspect: salinity;
			species dike aspect: default;
			species sluice aspect: default;
		}
	}
}