# radius_config.py

RADIUS_MAP = {
    "garbage": 50,
    "pothole": 30,
    "road crack": 25,
}

DEFAULT_RADIUS = 35


def get_radius(category: str) -> int:
    """
    Returns radius based on category
    """
    if not category:
        return DEFAULT_RADIUS

    category = category.strip().lower()
    return RADIUS_MAP.get(category, DEFAULT_RADIUS)