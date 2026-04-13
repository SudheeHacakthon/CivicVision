data = [
    # (v, t, rho, category, confidence, expected_priority)

    (95, 1, 9000, "Pothole", 0.95, "High"),
    (85, 2, 8500, "Pothole", 0.92, "High"),
    (80, 1, 7000, "Road Crack", 0.90, "High"),
    (70, 2, 8000, "Pothole", 0.93, "High"),

    (60, 3, 6000, "Garbage", 0.88, "Medium"),
    (55, 4, 5000, "Garbage", 0.85, "Medium"),
    (50, 3, 5500, "Road Crack", 0.87, "Medium"),
    (45, 5, 4000, "Garbage", 0.82, "Medium"),

    (35, 6, 3000, "Road Crack", 0.78, "Low"),
    (30, 7, 2500, "Garbage", 0.75, "Low"),
    (25, 8, 2000, "Road Crack", 0.72, "Low"),
    (20, 9, 1500, "Garbage", 0.70, "Low"),

    (90, 5, 9000, "Pothole", 0.95, "High"),   # high v but older
    (65, 6, 7000, "Pothole", 0.90, "Medium"), # urgency reduced due to time
    (75, 2, 3000, "Garbage", 0.85, "Medium"), # high v but less severe category

    (40, 2, 8000, "Garbage", 0.80, "Medium"), # high density effect
    (30, 1, 9000, "Garbage", 0.78, "Medium"), # crowd-driven priority

    (15, 10, 1000, "Road Crack", 0.65, "Low"),
    (10, 12, 500, "Garbage", 0.60, "Low"),

    (0, 1, 0, "No Issue", 0.50, "Low"),
    (0, 1, 0, "No Issue", 0.90, "Low"),
]