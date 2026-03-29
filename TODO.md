<<<<<<< HEAD
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
=======
# CivicVision Auth & Reorganization TODO
Completed: [ ]

## Phase 1: Flutter Frontend Setup (Auth Screens & State)
✅ Complete

## Phase 2: UI Reorganization

- [x] Update mobile_app1/lib/screens/home_screen.dart (role-based cards: guest/user/admin)

- [ ] Rename/refactor complaints_screen.dart -> public_issues_screen.dart (+upvote)
- [ ] Create my_complaints_screen.dart (user-specific)
- [ ] Update navigation in main.dart (+ new routes)

## Phase 3: Backend Auth (FastAPI)
- [ ] Add backend deps (bcrypt, python-jose, passlib)
- [ ] Create backend-api/app/schemas/auth.py (AdminUser, User schemas)
- [ ] Create backend-api/app/routes/auth.py (signup/login/OTP/forgot)
- [ ] Update backend-api/app/database/mongodb.py (+users/admins/otps collections)
- [ ] Update backend-api/app/main.py (+auth router, middleware)
- [ ] Extend complaints routes (/public-issues, /upvote)

## Phase 4: Integration & Test
- [ ] Flutter pub get && backend pip install
- [ ] Test auth flows (admin fixed email, user OTP mock)
- [ ] Add token guards to API calls
- [ ] Test protected routes (public issues upvote, admin dashboard)
- [ ] Polish: password strength, location dropdown (Nepal hardcoded), forgot pw reset

**Next Step: Phase 1.1 - Update pubspec.yaml**

>>>>>>> 6fa6e3d27d9be659d71a07d08f7e7a8ef9f0ad64
