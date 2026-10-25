extends RefCounted

# All crop rules live here. Sell prices must exceed seed prices.
const CROPS: Dictionary = {
	"WHEAT": {
		"name": "Wheat", "unlock_level": 1, "grow_time": 10.0,
		"seed_buy_price": 5, "sell_price": 10, "harvest_exp": 10
	},
	"CORN": {
		"name": "Corn", "unlock_level": 2, "grow_time": 20.0,
		"seed_buy_price": 10, "sell_price": 22, "harvest_exp": 20
	},
	"CARROT": {
		"name": "Carrot", "unlock_level": 3, "grow_time": 30.0,
		"seed_buy_price": 15, "sell_price": 35, "harvest_exp": 30
	}
}