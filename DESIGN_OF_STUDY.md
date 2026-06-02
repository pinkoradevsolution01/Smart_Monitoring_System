# Design of the Study
## Smart Monitoring System with Integrated POS and CCTV

---

## 1. Introduction

### 1.1 Background of the Study
Traditional retail stores face challenges in managing inventory, processing sales, and monitoring premises simultaneously. Manual systems are prone to errors, inefficient, and lack real-time insights. This study presents an integrated Smart Monitoring System that combines Point-of-Sale (POS) functionality with Closed-Circuit Television (CCTV) monitoring capabilities, providing a comprehensive solution for modern retail management.

### 1.2 Statement of the Problem
Retail businesses struggle with:
- **Fragmented Systems**: Separate POS and monitoring systems that don't communicate
- **Inefficient Inventory Management**: Manual stock tracking leading to errors
- **Limited Access Control**: No role-based permissions for different staff levels
- **Poor Visibility**: Lack of real-time sales analytics and security monitoring
- **Multi-Platform Needs**: Requirement for mobile, desktop, and web access

### 1.3 Objectives of the Study

**General Objective:**
To develop a cross-platform Smart Monitoring System that integrates POS operations with CCTV monitoring to enhance retail business management efficiency.

**Specific Objectives:**
1. To design a role-based access control system for Admin, Owner, and Cashier users
2. To implement real-time inventory management with automated stock tracking
3. To integrate CCTV monitoring with multi-camera support and timestamp markers
4. To develop comprehensive sales analytics and reporting features
5. To create a responsive cross-platform application for mobile, desktop, and web
6. To provide AI-powered assistance for user guidance and troubleshooting

### 1.4 Significance of the Study
This system benefits:
- **Retail Owners**: Unified platform for sales and security monitoring
- **Cashiers**: Streamlined POS interface with barcode scanning
- **Administrators**: Centralized user and product management
- **IT Developers**: Reference architecture for Flutter cross-platform applications
- **Academic Community**: Research framework for integrated retail systems

### 1.5 Scope and Limitations

**Scope:**
- POS terminal with barcode scanning and cart management
- Multi-user system with role-based access (Admin, Owner, Cashier)
- Real-time inventory tracking with movement history
- CCTV integration supporting RTSP/HTTP streams
- Sales analytics with charts and reports
- Cross-platform deployment (Android, iOS, Windows, Linux, macOS, Web)
- AI-powered help assistant
- Multi-language support (English/Filipino)

**Limitations:**
- Offline-first design (no cloud synchronization)
- Local database storage only
- Camera recording limited by storage capacity
- Password encryption not implemented (development phase)
- Receipt printing feature planned but not implemented
- Single-store operation (no multi-branch support)

---

## 2. System Architecture

### 2.1 Architectural Pattern
The system follows a **layered architecture** pattern with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                  PRESENTATION LAYER                      │
│            (UI Screens & User Interaction)               │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│               STATE MANAGEMENT LAYER                     │
│         (Controllers & Reactive State)                   │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              BUSINESS LOGIC LAYER                        │
│           (Services & Domain Rules)                      │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│               DATA ACCESS LAYER                          │
│         (Database Service & Queries)                     │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              PERSISTENCE LAYER                           │
│            (SQLite Database)                             │
└─────────────────────────────────────────────────────────┘
```

### 2.2 System Flow Diagram

```
START: Application Launch
         │
         ▼
┌─────────────────────┐
│  Initialize Platform │
│  • Detect OS         │
│  • Setup Database    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Load Settings       │
│  • Theme            │
│  • Language         │
│  • Accessibility    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Register Services   │
│  • POS Service      │
│  • User Service     │
│  • Admin Service    │
│  • CCTV Service     │
│  • AI Help Service  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Show Splash Screen │
│  (Animated Logo)    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Login Screen      │
│  • Email/Password   │
│  • PIN Auth         │
└──────────┬──────────┘
           │
           ├──────────────────────────┐
           │                          │
           ▼                          ▼
    ┌─────────────┐          ┌──────────────┐
    │ Admin Login │          │  User Login  │
    └──────┬──────┘          └──────┬───────┘
           │                        │
           ▼                        ▼
    ┌─────────────┐          ┌──────────────┐
    │   Admin     │          │  Role Check  │
    │  Dashboard  │          └──────┬───────┘
    └─────────────┘                 │
                         ┌──────────┴──────────┐
                         │                     │
                         ▼                     ▼
                  ┌─────────────┐      ┌─────────────┐
                  │   Owner     │      │  Cashier    │
                  │  Dashboard  │      │  Dashboard  │
                  └─────────────┘      └─────────────┘
```

### 2.3 User Role Flow

```
┌──────────────────────────────────────────────────────────┐
│                    USER ROLES                             │
└──────────────────────────────────────────────────────────┘

ADMIN                    OWNER                    CASHIER
  │                        │                        │
  ├─► Manage Users         ├─► View Sales Reports  ├─► Access POS
  ├─► Manage Products      ├─► Monitor CCTV        ├─► View Inventory
  ├─► View Reports         ├─► Manage Inventory    ├─► Process Sales
  ├─► System Settings      ├─► Damage Reports      │
  └─► Account Management   └─► Analytics           └─► (Limited Access)
```

### 2.4 Data Flow Architecture

```
USER ACTION
    │
    ├─► Tap/Click/Scan
    │
    ▼
UI WIDGET
    │
    ├─► Event Handler
    │
    ▼
SERVICE LAYER
    │
    ├─► Business Logic
    ├─► Validation
    │
    ▼
DATABASE SERVICE
    │
    ├─► SQL Query
    │
    ▼
SQLite DATABASE
    │
    ├─► Execute/Return
    │
    ▼
SERVICE LAYER
    │
    ├─► Process Result
    ├─► notifyListeners()
    │
    ▼
UI UPDATE
    │
    └─► Display Result
```

### 2.5 Module Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    CORE MODULES                          │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ POS Module   │  │ Inventory    │  │ CCTV Module  │ │
│  │              │  │ Module       │  │              │ │
│  │ • Product    │  │              │  │ • Multi-Cam  │ │
│  │   Catalog    │  │ • Stock      │  │ • Recording  │ │
│  │ • Cart       │  │   Tracking   │  │ • Playback   │ │
│  │ • Checkout   │  │ • Movements  │  │ • Timestamp  │ │
│  │ • Barcode    │  │ • Alerts     │  │              │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Reports      │  │ User Mgmt    │  │ AI Help      │ │
│  │ Module       │  │ Module       │  │ Module       │ │
│  │              │  │              │  │              │ │
│  │ • Sales      │  │ • RBAC       │  │ • Chat       │ │
│  │   Analytics  │  │ • Auth       │  │ • Context    │ │
│  │ • Charts     │  │ • Roles      │  │ • Gemini API │ │
│  │ • Export     │  │              │  │              │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### 2.6 Database Schema

```
┌─────────────────────────────────────────────────────────┐
│                  DATABASE TABLES                         │
└─────────────────────────────────────────────────────────┘

products
  ├─ id (PK)
  ├─ name
  ├─ barcode
  ├─ category
  ├─ selling_price
  ├─ quantity
  └─ image_path

sales                   sale_items
  ├─ id (PK)              ├─ id (PK)
  ├─ total                ├─ sale_id (FK)
  ├─ discount             ├─ product_id (FK)
  ├─ timestamp            ├─ quantity
  └─ payment_method       ├─ price
                          └─ discount

users                   inventory_movements
  ├─ id (PK)              ├─ id (PK)
  ├─ name                 ├─ product_id (FK)
  ├─ email                ├─ type
  ├─ password             ├─ quantity
  ├─ pin                  ├─ timestamp
  ├─ role                 └─ reason
  └─ is_active

cameras                 damage_reports
  ├─ id (PK)              ├─ id (PK)
  ├─ name                 ├─ product_id (FK)
  ├─ url                  ├─ description
  ├─ type                 ├─ quantity
  └─ is_active            ├─ reported_by
                          └─ status
```

### 2.7 Technology Stack

```
┌─────────────────────────────────────────────────────────┐
│                 TECHNOLOGY LAYERS                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Frontend Framework:    Flutter 3.x (Dart)              │
│  UI Design:            Material Design 3                │
│  State Management:     ValueNotifier, ChangeNotifier    │
│  Dependency Injection: GetIt                            │
│  Database:             SQLite (sqflite)                 │
│  Video Streaming:      video_player                     │
│  Barcode Scanning:     mobile_scanner                   │
│  Charts/Analytics:     fl_chart                         │
│  AI Integration:       Google Gemini API                │
│  Persistence:          SharedPreferences                │
│                                                          │
│  Supported Platforms:                                   │
│    • Android, iOS (Mobile)                              │
│    • Windows, Linux, macOS (Desktop)                    │
│    • Web (Chrome, Firefox, Safari)                      │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Development Methodology

### 3.1 Software Development Model
**Agile - Iterative Development**

**Sprint 1**: Core POS functionality (product management, cart, checkout)  
**Sprint 2**: User authentication and role-based access  
**Sprint 3**: Inventory management and tracking  
**Sprint 4**: CCTV integration and monitoring  
**Sprint 5**: Reports and analytics  
**Sprint 6**: AI help assistant and multi-language support  
**Sprint 7**: Testing, optimization, and deployment  

### 3.2 System Requirements

**Hardware Requirements:**
- **Mobile**: Android 5.0+ / iOS 12+, 2GB RAM, 100MB storage
- **Desktop**: Windows 10+/Linux/macOS, 4GB RAM, 500MB storage
- **Camera**: IP cameras with RTSP/HTTP support
- **Scanner**: Barcode scanner (optional, camera can be used)

**Software Requirements:**
- Flutter SDK 3.0+
- Dart 3.0+
- SQLite 3.x
- Modern web browser (for web deployment)

### 3.3 Testing Strategy

```
Unit Testing
    ├─ Service layer methods
    ├─ Data model serialization
    └─ Business logic validation

Widget Testing
    ├─ UI component rendering
    ├─ User interaction handling
    └─ State updates

Integration Testing
    ├─ End-to-end user flows
    ├─ Database operations
    └─ Multi-screen navigation

Platform Testing
    ├─ Android devices
    ├─ iOS devices
    ├─ Windows desktop
    └─ Web browsers
```

---

## 4. Expected Outcomes

### 4.1 Deliverables
1. **Functional Application**
   - Mobile apps (Android/iOS)
   - Desktop applications (Windows/Linux/macOS)
   - Web application

2. **Documentation**
   - System architecture documentation
   - User manual
   - Developer guide
   - API documentation

3. **Source Code**
   - Complete Flutter codebase
   - Database schema scripts
   - Configuration files

### 4.2 Success Metrics
- **Performance**: Transaction processing < 2 seconds
- **Reliability**: 99% uptime for core POS functions
- **Usability**: User task completion rate > 90%
- **Security**: Role-based access enforcement 100%
- **Cross-platform**: Consistent experience across all platforms

### 4.3 Future Enhancements
- Cloud synchronization for multi-branch operations
- Advanced AI analytics and predictions
- Mobile app for managers (remote monitoring)
- Integration with accounting software
- E-commerce integration
- Customer loyalty program
- SMS/Email notifications
- Biometric authentication

---

## 5. Conclusion

The Smart Monitoring System demonstrates the feasibility of integrating POS operations with security monitoring in a unified, cross-platform application. By leveraging Flutter's capabilities and modern software architecture patterns, the system provides an efficient, scalable solution for retail business management. The role-based access control ensures security, while the intuitive interface promotes user adoption. This study serves as a foundation for further research in integrated retail management systems.

---

**Research Team:** [Your Name/Team]  
**Institution:** [Your Institution]  
**Date:** December 2025  
**Status:** Active Development
