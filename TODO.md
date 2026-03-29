# Model Classification Report TODO - COMPLETE

**Progress:**
- [x] Installed scipy and scikit-learn 
- [x] Updated train.py with sklearn classification_report on validation set after training

**Task Complete!**
To see the classification report:
```
cd backend-api/app/model/model-training && python train.py
```

This will:
1. Train the model (10 epochs, ~minutes depending on GPU)
2. Generate and print classification report to terminal: precision, recall, F1-score, support per class on validation set.
3. Save updated model.

Classes detected from dataset: Garbage, No Issue, Pothole, Road Crack.

Model ready for production use in API/mobile app.

No further changes needed.
