data = [
    # =========================
    # 🔥 HIGH PRIORITY CASES
    # =========================
    # Fresh + severe + high density
    (95, 1, 9000, "Pothole", 0.95, "High"),
    (90, 2, 8500, "Pothole", 0.92, "High"),
    (85, 1, 7000, "Road Crack", 0.91, "High"),

    # High due to category + votes
    (80, 2, 6000, "Pothole", 0.93, "High"),

    # 🔥 Deadline overrides density (IMPORTANT)
    (20, 10, 2000, "Garbage", 0.85, "High"),   # overdue garbage
    (30, 12, 1500, "Road Crack", 0.80, "Medium"),  # overdue but moderate
    (40, 15, 3000, "Pothole", 0.90, "High"),   # strongly overdue

    # =========================
    # ⚖️ MEDIUM PRIORITY
    # =========================
    # Balanced cases
    (60, 3, 6000, "Garbage", 0.88, "Medium"),
    (55, 4, 5000, "Garbage", 0.85, "Medium"),
    (50, 3, 5500, "Road Crack", 0.87, "Medium"),

    # Density but low severity
    (40, 2, 9000, "Garbage", 0.80, "Medium"),
    (35, 1, 9500, "Garbage", 0.78, "Medium"),

    # Same condition → different category (teaches category importance)
    (60, 2, 6000, "Pothole", 0.90, "High"),
    (60, 2, 6000, "Garbage", 0.90, "Medium"),

    # =========================
    # 🧊 LOW PRIORITY
    # =========================
    # Low everything
    (20, 8, 2000, "Garbage", 0.70, "Low"),
    (25, 9, 2500, "Road Crack", 0.72, "Low"),

    # Very low impact
    (10, 10, 1000, "Garbage", 0.65, "Low"),
    (15, 9, 1200, "Road Crack", 0.68, "Low"),

    # =========================
    # ⏳ TIME DECAY EFFECT
    # =========================
    # High votes but old → should drop
    (90, 10, 9000, "Pothole", 0.95, "Medium"),
    (80, 9, 8000, "Road Crack", 0.90, "Medium"),

    # =========================
    # 🔥 DEADLINE DOMINANCE (CRITICAL)
    # =========================
    # Low votes but overdue → HIGH
    (25, 10, 3000, "Garbage", 0.85, "High"),
    (30, 12, 2000, "Road Crack", 0.82, "Medium"),

    # =========================
    # ⚠️ EDGE CASES
    # =========================
    # High votes but low severity
    (75, 2, 3000, "Garbage", 0.85, "Medium"),

    # Density-only should not dominate
    (30, 1, 9000, "Garbage", 0.78, "Medium"),

    # =========================
    # 🚫 NO ISSUE
    # =========================
    (0, 1, 0, "No Issue", 0.50, "Low"),
    (0, 1, 0, "No Issue", 0.90, "Low"),
    # High priority but medium confidence
    (90, 1, 9000, "Pothole", 0.6, "High"),
    
    # Low priority but high confidence
    (20, 8, 2000, "Garbage", 0.95, "Low"),

    (20, 12, 2000, "Garbage", 0.7, "High"),
    (25, 15, 1500, "Road Crack", 0.8, "Medium"),
    ]