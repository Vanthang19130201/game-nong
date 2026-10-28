extends RefCounted

# Central timing/appearance scale for all farm livestock. Tests may temporarily
# lower the multiplier; it is intentionally not exposed through player UI.
static var animal_time_scale: float = 1.0

const SPECIES: Dictionary = {
	"chicken": {"baby_seconds":120.0, "young_seconds":180.0, "baby_scale":0.54, "young_scale":0.76, "adult_scale":1.0, "adult_size":40.0, "speed":28.0, "radius":8.0},
	"cow": {"baby_seconds":240.0, "young_seconds":360.0, "baby_scale":0.56, "young_scale":0.78, "adult_scale":1.0, "adult_size":64.0, "speed":20.0, "radius":12.0},
	"pig": {"baby_seconds":420.0, "young_seconds":780.0, "baby_scale":0.56, "young_scale":0.79, "adult_scale":1.0, "adult_size":56.0, "speed":22.0, "radius":11.0},
	"sheep": {"baby_seconds":360.0, "young_seconds":540.0, "baby_scale":0.55, "young_scale":0.78, "adult_scale":1.0, "adult_size":58.0, "speed":20.0, "radius":11.0}
}
const PRODUCT_PRICES: Dictionary = {
	"pork": 420,
	"wool": 190
}

static func stage_for(animal_type: String, born_at: float, now: float = -1.0) -> int:
	if not SPECIES.has(animal_type):
		return 3
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var scale: float = animal_time_scale if is_finite(animal_time_scale) and animal_time_scale > 0.0 else 1.0
	var age: float = maxf(0.0, now - born_at) / scale
	var data: Dictionary = SPECIES[animal_type]
	if age < float(data["baby_seconds"]):
		return 1
	if age < float(data["baby_seconds"]) + float(data["young_seconds"]):
		return 2
	return 3

static func scale_for(animal_type: String, stage: int) -> float:
	if not SPECIES.has(animal_type):
		return 1.0
	var data: Dictionary = SPECIES[animal_type]
	return float(data["baby_scale"] if stage == 1 else data["young_scale"] if stage == 2 else data["adult_scale"])

static func adult_born_at(animal_type: String, now: float = -1.0) -> float:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	if not SPECIES.has(animal_type):
		return now
	var data: Dictionary = SPECIES[animal_type]
	return now - float(data["baby_seconds"]) - float(data["young_seconds"]) - 1.0

static func stable_seed(value: String) -> int:
	var result: int = 2166136261
	for byte_value in value.to_utf8_buffer():
		result = int((result ^ int(byte_value)) * 16777619) & 0x7fffffff
	return maxi(1, result)

static func lucky_pig(animal_id: String) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = stable_seed("lucky:" + animal_id)
	return rng.randf() < 0.1
