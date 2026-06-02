# CCTV Timestamp Tracking Feature

## Overview
This feature allows users to save and manage CCTV timestamps with descriptions, similar to the sales recording system in the POS.

## Implementation Details

### Database Changes
- **Database Version**: Updated from v4 to v5
- **New Table**: `cctv_timestamps`
  - `id`: INTEGER PRIMARY KEY AUTOINCREMENT
  - `timestamp`: TEXT NOT NULL (ISO 8601 format)
  - `description`: TEXT (optional)
  - `createdAt`: TEXT NOT NULL (ISO 8601 format)
- **Index**: Created on `timestamp` column for performance

### New Files
1. **`lib/models/cctv_timestamp.dart`**
   - CCTVTimestamp model with serialization
   - Helper methods: `formattedTimestamp`, `formattedDate`, `formattedTime`

### Modified Files

#### 1. `lib/services/database_service_io.dart`
- Added `cctv_timestamps` table creation in `_createTables()`
- Added upgrade logic for v5 in `_upgradeTables()`
- Added CRUD operations:
  - `insertCCTVTimestamp()`
  - `getAllCCTVTimestamps()`
  - `getCCTVTimestampsByDateRange()`
  - `deleteCCTVTimestamp()`
  - `deleteAllCCTVTimestamps()`

#### 2. `lib/services/cctv_service.dart`
- Added DatabaseService integration
- Added `_savedTimestamps` list to track saved timestamps
- Updated `seekTo()` method to save timestamps with optional descriptions
- New methods:
  - `loadTimestamps()` - Load all saved timestamps from database
  - `deleteTimestamp(int id)` - Delete a specific timestamp
  - `clearAllTimestamps()` - Delete all saved timestamps
- Getter: `savedTimestamps` - Access saved timestamps list

#### 3. `lib/screens/owner/cctv_screen.dart`
- Added floating action button "Timestamps Log" to view saved timestamps
- Updated `_seek()` method to show description dialog before saving
- Added `_saveCurrentTimestamp()` method to manually save current timestamp
- Added "Save Current Timestamp" button for live monitoring
- Added `_openTimestampsLog()` method that displays:
  - List of all saved timestamps
  - Timestamp with date and optional description
  - "View Footage" button to navigate to that timestamp
  - "Delete" button to remove individual timestamp
  - "Clear All" button to remove all timestamps

#### 4. `lib/utils/app_localizations.dart`
- Added English translations:
  - `timestamps_log`: "Timestamps Log"
  - `saved_timestamps`: "Saved CCTV Timestamps"
  - `no_timestamps_saved`: "No timestamps saved yet"
  - `view_footage`: "View Footage"
  - `delete`: "Delete"
  - `confirm_delete`: "Confirm Delete"
  - `delete_timestamp_confirm`: "Are you sure you want to delete this timestamp?"
  - `clear_all`: "Clear All"
  - `clear_all_timestamps_confirm`: "Are you sure you want to clear all saved timestamps?"
- Added Filipino translations for all above keys

## User Experience

### Saving Timestamps
1. **From Sales (Cashier POS)**:
   - Sales recorded with timestamps automatically link to CCTV
   - Clicking videocam icon in sales log opens CCTV with that timestamp
   - Timestamp can be saved with description from CCTV screen

2. **Manual Save (Live Monitoring)**:
   - Click "Save Current Timestamp" button in live view
   - Dialog prompts for optional description
   - Current time is saved to database

3. **From Linked Timestamp**:
   - When navigating from sales log, timestamp is displayed
   - "Seek to Timestamp" button saves it with optional description

### Viewing Timestamps Log
- Click floating action button "Timestamps Log"
- Dialog displays all saved timestamps in card format
- Each entry shows:
  - Timestamp (formatted time)
  - Date
  - Description (if provided)
  - View Footage button (navigates to CCTV at that time)
  - Delete button (removes individual timestamp)
- "Clear All" button at bottom to remove all timestamps

### Data Persistence
- All timestamps saved to SQLite database
- Survives app restarts
- Can be deleted individually or cleared all at once

## Similar to Sales Recording
The implementation mirrors the cashier POS sales log:
- FloatingActionButton to open log
- AlertDialog with scrollable ListView
- Card-based UI for each entry
- Expansion tiles for details
- Action buttons (view/delete)
- Confirmation dialogs for destructive actions
- Bilingual support (English/Filipino)

## Future Enhancements
- Export timestamps to CSV/PDF
- Search/filter timestamps by date range
- Add thumbnail previews of footage
- Link timestamps to specific events or sales
- Share timestamps with other users
- Add tags/categories for timestamps
