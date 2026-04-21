from app.routes.predict import compute_priority
from app.data.weights import data
import itertools
from app.data.final_weights import W1, W2, W3, W4, W5

def test_case(v, t, rho, category, confidence):
    score = compute_priority(v, t, rho, category, confidence, W1, W2, W3, W4, W5)
    label = get_label(score)
    print(f"{category} | v={v}, t={t}, rho={rho} → Score={round(score,3)} → {label}")

def get_label(score):
    if score > 0.7:
        return "High"
    elif score > 0.4:
        return "Medium"
    else:
        return "Low"

weight_options = [0.1, 0.2, 0.3, 0.4, 0.5]

best_acc = 0
best_weights = None

for w1, w2, w3, w4, w5 in itertools.product(weight_options, repeat=5):

    # normalize weights
    total = w1 + w2 + w3 + w4 + w5
    w1, w2, w3, w4, w5 = w1/total, w2/total, w3/total, w4/total, w5/total

    correct = 0

    for v, t, rho, category, confidence, expected in data:
        score = compute_priority(v, t, rho, category, confidence, w1, w2, w3, w4, w5)
        pred = get_label(score)

        if pred == expected:
            correct += 1

    acc = correct / len(data)

    if acc > best_acc:
        best_acc = acc
        best_weights = (w1, w2, w3, w4, w5)

print("Best weights:", best_weights)
print("Accuracy:", best_acc)

print("\n--- TESTING MODEL ---\n")

test_case(90, 1, 9000, "Pothole", 0.95)   # HIGH
test_case(10, 10, 1000, "Garbage", 0.7)   # LOW
test_case(50, 4, 5000, "Garbage", 0.85)   # MEDIUM
test_case(30, 10, 8000, "Garbage", 0.85)  # OVERDUE → HIGH
test_case(80, 2, 3000, "Garbage", 0.9)    # MEDIUM
test_case(30, 1, 9500, "Garbage", 0.8)    # MEDIUM
test_case(90, 8, 9000, "Pothole", 0.95)   # MEDIUM
test_case(0, 1, 0, "No Issue", 0.9)       # LOW