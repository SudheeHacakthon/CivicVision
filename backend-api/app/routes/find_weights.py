from app.routes.predict import compute_priority
from app.data.weights import data
import itertools

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

for w1, w2, w3, w4 in itertools.product(weight_options, repeat=4):
    
    total = w1 + w2 + w3 + w4
    w1, w2, w3, w4 = w1/total, w2/total, w3/total, w4/total

    correct = 0

    for v, t, rho, category, confidence, expected in data:
        score = compute_priority(v, t, rho, category, confidence, w1, w2, w3, w4)
        pred = get_label(score)

        if pred == expected:
            correct += 1

    acc = correct / len(data)

    if acc > best_acc:
        best_acc = acc
        best_weights = (w1, w2, w3, w4)

print("Best weights:", best_weights)
print("Accuracy:", best_acc)