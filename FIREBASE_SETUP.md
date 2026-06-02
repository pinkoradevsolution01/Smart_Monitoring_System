# Firebase Setup Guide - Multi-Device Cloud Sync

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: **smart-monitoring-system**
4. Disable Google Analytics (optional for POS system)
5. Click "Create project"

## Step 2: Register Your Apps

### Android App
1. In Firebase Console, click Android icon
2. Package name: `com.example.smart_monitoring_system`
3. Download `google-services.json`
4. Place it in: `android/app/google-services.json`

### iOS App
1. Click iOS icon in Firebase Console
2. Bundle ID: `com.example.smartMonitoringSystem`
3. Download `GoogleService-Info.plist`
4. Place it in: `ios/Runner/GoogleService-Info.plist`

### Web App
1. Click Web icon in Firebase Console
2. App nickname: `Smart Monitoring Web`
3. Copy the Firebase configuration
4. We'll add it to `web/index.html`

### Windows/Linux/macOS
- Desktop platforms use the same Firebase credentials as web
- Configuration will be in Dart code

## Step 3: Enable Firebase Services

### Authentication
1. Go to **Authentication** → **Sign-in method**
2. Enable **Email/Password**
3. Enable **Anonymous** (for offline fallback)

### Firestore Database
1. Go to **Firestore Database** → **Create database**
2. Start in **Production mode** (we'll add security rules)
3. Choose closest region to your location

### Security Rules (IMPORTANT)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - only read own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Products - owners and admins can write, cashiers can read
    match /products/{productId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin']);
    }
    
    // Sales - authenticated users can create, only owners/admins can read all
    match /sales/{saleId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null && 
        (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin'] ||
         resource.data.cashierId == request.auth.uid);
    }
    
    // Inventory movements - same as products
    match /inventory_movements/{movementId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin']);
    }
  }
}
```

## Step 4: Install Flutter Dependencies

Run these commands:
```bash
flutter pub add firebase_core
flutter pub add firebase_auth
flutter pub add cloud_firestore
flutter pub add firebase_storage  # For product images
```

## Step 5: Initialize Firebase in Your App

The code will automatically initialize Firebase on app startup.

## Step 6: Migrate Existing Data (Optional)

If you have existing local data, we'll provide a migration tool to upload it to Firebase.

## Firebase Collections Structure

```
firestore/
├── users/
│   └── {userId}
│       ├── id: string
│       ├── name: string
│       ├── email: string
│       ├── role: string (owner/cashier/admin)
│       ├── isActive: bool
│       ├── createdAt: timestamp
│       └── updatedAt: timestamp
│
├── products/
│   └── {productId}
│       ├── id: string
│       ├── name: string
│       ├── barcode: string
│       ├── category: string
│       ├── description: string
│       ├── buyingPrice: number
│       ├── sellingPrice: number
│       ├── quantity: number
│       ├── reorderLevel: number
│       ├── imageUrl: string (Firebase Storage URL)
│       ├── createdAt: timestamp
│       ├── updatedAt: timestamp
│       └── updatedBy: string (userId)
│
├── sales/
│   └── {saleId}
│       ├── id: string
│       ├── cashierId: string
│       ├── cashierName: string
│       ├── totalAmount: number
│       ├── discount: number
│       ├── timestamp: timestamp
│       ├── items: array
│       │   └── {productId, name, quantity, price, discount}
│       └── syncStatus: string (synced/pending)
│
└── inventory_movements/
    └── {movementId}
        ├── id: string
        ├── productId: string
        ├── type: string (sale/restock/adjustment)
        ├── quantity: number
        ├── previousQuantity: number
        ├── newQuantity: number
        ├── userId: string
        ├── reason: string
        └── timestamp: timestamp
```

## Offline Support

Firebase automatically handles offline scenarios:
- ✅ Local cache stores data when offline
- ✅ Changes sync automatically when connection restored
- ✅ Optimistic updates for better UX
- ✅ Conflict resolution built-in

## Cost Estimation

**Firebase Free Tier (Spark Plan):**
- 50K reads/day
- 20K writes/day
- 1 GB storage
- 10 GB/month transfer

**Estimated usage for small business:**
- 10 transactions/hour × 12 hours = 120 sales/day
- 100 products × 5 devices = 500 reads/day
- Well within free tier! 💰

**If you exceed free tier:**
- Blaze Plan (Pay as you go)
- ~$0.06 per 100K reads
- ~$0.18 per 100K writes
- Very affordable for small-medium business

## Next Steps

1. Complete Firebase Console setup (Steps 1-3)
2. Download configuration files
3. Run the app - Firebase will initialize automatically
4. Test login on multiple devices
5. Watch data sync in real-time! 🚀
