from app.data.population_data import AREA_DENSITY

def get_density(location_name):
    if not location_name:
        return 5000

    location_name = location_name.lower()

    for area in AREA_DENSITY:
        if area.lower() in location_name:
            return AREA_DENSITY[area]

    return 5000