# CivicVision - Project Implementation Plan

## Team Members
- **Rithwik** (Team Lead)
- **Priyanshu**
- **Jahnavi**

## Tech Stack Identified
- **Frontend (Citizen & Admin Apps):** Flutter
- **Backend:** FastAPI (Python)
- **ML/AI:** TensorFlow/Keras (MobileNetV2)
- **Database:** MongoDB
- **PDF Generation:** ReportLab
- **Maps:** OpenStreetMap / Mapbox
- **Storage:** Local uploads folder (can migrate to AWS S3 later)

---

## Current Status Analysis

### ✅ Already Implemented (Citizen App)
1. Home screen with multiple options
2. Camera capture with live preview
3. GPS location capture
4. Backend API for image prediction
5. AI classification (Garbage, No Issue, Pothole, Road Crack)
6. Complaint letter generation
7. PDF generation and download
8. Complaints list view
9. Admin dashboard (basic)
10. Analytics screen
11. Heatmap visualization

### 🔲 Work Required
1. **Split into 2 separate apps** - Citizen App & Admin App
2. **Add authentication to Admin app**
3. **Improve Citizen app flow** - Direct camera open (no home screen)
4. **Spam detection system**
5. **Priority/severity scoring system**
6. **Enhanced Admin features** - Image viewing, status management, spam detection

---

## Feature Implementation Plan

### Phase 1: Split Apps & Authentication (Priority: HIGH)

#### 1.1 Create Citizen App (Simplified)
- **Task:** Modify existing app to open camera directly on launch
- **File:** `mobile_app1/lib/main.dart`
- **Change:** Remove home screen, go directly to capture screen

#### 1.2 Create Admin App
- **New Directory:** `admin_app/`
- **Screens needed:**
  - Login screen (simple username/password)
  - Dashboard with all complaints
  - Complaint detail view with image
  - Status update functionality
  - Spam detection indicators

### Phase 2: Spam Detection System (Priority: HIGH)

#### 2.1 Backend - Duplicate Detection
- **File:** `backend-api/app/services/spam_detector.py` (NEW)
- **Features:**
  - Store image hashes in MongoDB
  - Detect duplicate submissions within radius (e.g., 50 meters)
  - Flag as "potential spam" if duplicate found

#### 2.2 Backend - Confidence-Based Detection
- **File:** `backend-api/app/routes/predict.py` (MODIFY)
- **Features:**
  - If AI confidence < 0.6, flag as "needs review"
  - Add "confidence" field to complaint data

#### 2.3 Admin - Spam Review
- **Screen:** Admin dashboard shows spam-flagged items
- **Action:** Admin can mark as "Valid" or "Spam"

### Phase 3: Priority System (Priority: HIGH)

#### 3.1 Backend - Priority Calculation
- **File:** `backend-api/app/services/priority_calculator.py` (NEW)
- **Algorithm:**
  
```
  Priority Score = 
    (AI Severity * 0.4) + 
    (Votes * 0.3) + 
    (Time Factor * 0.2) + 
    (Location Density * 0.1)
  
```

#### 3.2 Severity Detection
- **File:** `backend-api/app/model/model_loader.py` (MODIFY)
- **Add:** Return severity level (Low/Medium/High/Critical) based on:
  - Image clarity
  - Issue size estimation
  - Category risk level

#### 3.3 Admin - Priority View
- **Screen:** Sort complaints by priority in admin dashboard

### Phase 4: Enhanced Admin Features (Priority: MEDIUM)

#### 4.1 Complaint Image Viewing
- Display full complaint image in admin detail view

#### 4.2 Bulk Actions
- Select multiple complaints
- Batch status update

#### 4.3 Statistics Dashboard
- Complaints by category pie chart
- Complaints by status bar chart
- Resolution time metrics

---

## Detailed Task Assignment

### Rithwik (Team Lead) - MORE WORK
**Tasks:**
1. Create Admin App structure with authentication
2. Implement login screen for Admin
3. Create Admin dashboard with all complaints list
4. Create complaint detail screen with image view
5. Implement status update functionality
6. Set up backend routes for admin operations
7. Integrate admin app with backend API
8. Test and fix any integration issues

**Files to create/modify:**
- `admin_app/lib/main.dart` (NEW)
- `admin_app/lib/screens/login_screen.dart` (NEW)
- `admin_app/lib/screens/admin_home_screen.dart` (NEW)
- `admin_app/lib/screens/complaint_detail_screen.dart` (NEW)
- `admin_app/lib/services/api_service.dart` (NEW)
- `backend-api/app/routes/admin.py` (NEW - admin-specific endpoints)
- `backend-api/app/routes/predict.py` (MODIFY - add spam detection)

**Estimated files:** 7 files

---

### Priyanshu - MODERATE WORK
**Tasks:**
1. Implement spam detection in backend
2. Create priority calculation service
3. Enhance AI model to return severity
4. Modify MongoDB schema for new fields
5. Add image hash storage for duplicate detection
6. Create analytics endpoints
7. Enhance admin dashboard with charts

**Files to create/modify:**
- `backend-api/app/services/spam_detector.py` (NEW)
- `backend-api/app/services/priority_calculator.py` (NEW)
- `backend-api/app/model/model_loader.py` (MODIFY)
- `backend-api/app/routes/predict.py` (MODIFY)
- `backend-api/app/routes/analytics.py` (NEW - enhanced analytics)
- `backend-api/app/database/mongodb.py` (MODIFY - if needed)

**Estimated files:** 6 files

---

### Jahnavi - LESS WORK
**Tasks:**
1. Modify Citizen App to open camera directly (simplify flow)
2. Add app icon and splash screen
3. Test existing features work correctly
4. Update README with instructions
5. Create basic user documentation

**Files to create/modify:**
- `mobile_app1/lib/main.dart` (MODIFY)
- `mobile_app1/pubspec.yaml` (MODIFY - add app name/icon)
- `README.md` (UPDATE)
- `docs/user_guide.md` (NEW)

**Estimated files:** 4 files

---

## 8-Weekend Timeline

### Weekend 1: Foundation & Admin App Setup
| Day | Rithwik | Priyanshu | Jahnavi |
|-----|---------|-----------|---------|
| Sat | Create admin_app structure, basic screens | Study existing backend code | Review citizen app code |
| Sun | Implement login screen | Plan spam detection approach | Test existing citizen app |

### Weekend 2: Admin API Integration
| Day | Rithwik | Priyanshu | Jahnavi |
|-----|---------|-----------|---------|
| Sat | Connect admin app to backend | Implement image hash storage | Create app icon/assets |
| Sun | Test admin CRUD operations | Create duplicate detection logic | Test camera functionality |

### Weekend 3: Spam Detection
| Day | Rithwik | Priyanshu | Jahnavi |
|-----|---------|-----------|---------|
| Sat | Add spam flag display in admin | Implement spam detection algorithm | Update README |
| Sun | Test spam detection flow | Test with sample images | Fix minor citizen app issues |

### Weekend 4: Priority System
| Day | Rithwik | Priyanshu | Jahnavi |
|-----|---------|-----------|---------|
| Sat | Add priority display in admin | Implement priority calculation | Test complete citizen flow |
| Sun | Sort complaints by priority | Add severity detection to AI | Document features |

### Weekend 5: Testing & Integration
| Day | Rithwik | Priyanshu | Jahnavi |
|-----|---------|-----------|---------|
| Sat | Full admin app testing | Backend bug fixes | End-to-end testing |
| Sun | Fix integration issues | Performance optimization | UI polish |

### Weekend 6: Analytics & Dashboard
| Day | Rithwik | Priyanshu | Jahnavi |
|-----|---------|-----------|---------|
| Sat | Add charts to admin dashboard | Create analytics endpoints | Create user documentation |
| Sun | Test analytics display | Verify data accuracy | Review documentation |

### Weekend 7: Polish & Demo Prep
| Day | Rithwik | Priyanshu | Jahnavi |
|-----|---------|-----------|---------|
| Sat | Demo preparation | Model accuracy check | Prepare presentation |
| Sun | Final testing | Bug fixes | Final review |

### Weekend 8: Hackathon Submission
| Day | Rithwik | Priyanshu | Jahnavi |
|-----|---------|-----------|---------|
| Sat | Final polish | Final testing | Submission |
| Sun | Backup & documentation | Backup & documentation | Backup & documentation |

---

## MongoDB Schema Updates

Add these new fields to complaint collection:

```
javascript
{
  complaint_id: "uuid",
  category: "Pothole",
  confidence: 0.95,
  severity: "High", // NEW: Low/Medium/High/Critical
  priority_score: 75, // NEW: Calculated priority
  latitude: 17.3850,
  longitude: 78.4867,
  image_hash: "sha256_hash", // NEW: For spam detection
  location_hash: "geohash", // NEW: For nearby duplicate detection
  is_spam: false, // NEW: Spam flag
  spam_reason: null, // NEW: Reason if flagged
  votes: 0, // NEW: Upvote count
  status: "Submitted",
  created_at: datetime,
  updated_at: datetime,
  image_path: "uploads/...",
  pdf_path: "uploads/...",
  letter: "...",
  authority: "...",
  department: "..."
}
```

---

## API Endpoints Summary

### Existing Endpoints (Keep)
- `POST /predict` - Submit new complaint
- `GET /complaints` - Get all complaints
- `GET /complaint/{id}` - Get single complaint
- `GET /download/{id}` - Download PDF
- `GET /admin/dashboard` - Dashboard stats
- `GET /analytics` - Category analytics
- `GET /heatmap` - Map data
- `PUT /complaint/{id}/status` - Update status
- `GET /health` - Health check

### New Endpoints to Add (Priyanshu)
- `GET /admin/complaints/spam` - Get spam-flagged complaints
- `PUT /complaint/{id}/spam` - Mark as spam/valid
- `GET /complaints/priority` - Get sorted by priority
- `GET /analytics/detailed` - Enhanced analytics

### New Endpoints for Admin App (Rithwik)
- `POST /admin/login` - Admin authentication
- `GET /admin/stats` - Dashboard statistics

---

## Key Points to Avoid Merge Conflicts

1. **Rithwik** works on: `admin_app/` directory + `backend-api/app/routes/admin.py`
2. **Priyanshu** works on: `backend-api/app/services/` + `backend-api/app/model/`
3. **Jahnavi** works on: `mobile_app1/lib/` (except main.dart changes after Rithwik)

**Important:** 
- Don't modify same files simultaneously
- Rithwik: Create new files in `admin_app/`
- Priyanshu: Modify backend files only
- Jahnavi: Test and document only (minimal code changes)

---

## Questions for Clarification

1. **Admin credentials:** Use hardcoded (admin/admin123) for demo?
2. **MongoDB connection:** Is it already configured? Need .env file?
3. **API base URL:** Same for both apps or different?
4. **Deployment:** Local testing or need to deploy?

---

*Plan created for CivicVision Hackathon Team*
*Team: Rithwik, Priyanshu, Jahnavi*
