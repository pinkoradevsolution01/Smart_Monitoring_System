# Activation Code Request Feature

## Overview
This feature allows customers to request activation codes directly from the app, which then notifies the developer with the subscriber details.

## How It Works

### For Customers:

1. **Access the Feature:**
   - Click "Get Started" on any package → See "Request Code" button in activation dialog
   - Click "Start Free Trial" → See "Request Code" button for upgrading to full access

2. **Submit Request:**
   - Fill in business details:
     - Business Name *
     - Contact Email *
     - Contact Phone *
     - Additional Notes (optional)
   - Click "Submit Request"

3. **Confirmation:**
   - Request is sent to developer
   - Customer receives confirmation
   - Activation code is emailed by the developer, then the 24-hour activation window starts only after the email is successfully sent

### For Developers:

1. **View Requests:**
   - Access Developer Dashboard (tap store icon 7 times → enter password)
   - View pending activation code requests with customer details

2. **Fulfill Requests:**
   - Generate/assign activation code
   - Mark request as fulfilled
   - Send the code by email to the customer
   - The code becomes valid for 24 hours only after the email is successfully sent

## Database Setup

**Run this SQL in Supabase:**

```sql
-- See: ACTIVATION_CODE_REQUESTS_TABLE.sql
```

This creates the `activation_code_requests` table to store:
- Customer business info
- Package selection
- Request status (pending/fulfilled/cancelled)
- Activation code (when fulfilled)
- Timestamps

## Code Components

### New Files:
- `lib/services/code_request_service.dart` - Handles request submission and retrieval
- `ACTIVATION_CODE_REQUESTS_TABLE.sql` - Database schema

### Modified Files:
- `lib/screens/shared/package_selection_screen.dart`:
  - Added "Request Code" button in activation dialog
  - Added "Request Code" button in free trial dialog
  - Added `_showRequestCodeDialog()` method

## Request Types

- **`monthly`**: Customer wants to pay monthly and needs activation code
- **`trial_upgrade`**: Customer wants to upgrade from free trial to paid

## Testing

1. **Restart the app**
2. Go to Package Selection screen
3. Click "Get Started" or "Free Trial"
4. Click "Request Code" button
5. Fill in test business details
6. Submit request
7. Check Supabase database for new entry

## Developer Dashboard Integration

To view requests in the developer dashboard, add a new screen/section that:
1. Fetches pending requests using `CodeRequestService().getPendingRequests()`
2. Displays in a list with customer details
3. Provides button to mark as fulfilled
4. Optionally sends email with activation code

## Future Enhancements

- [ ] Auto-email notification to developer
- [ ] Auto-email activation code to customer
- [ ] In-app notification system
- [ ] Request tracking for customers
- [ ] Payment integration
- [ ] Bulk code generation

## Troubleshooting

**Request fails to submit:**
- Check Supabase configuration in `lib/services/supabase_config.dart`
- Verify database table exists
- Check internet connection
- Falls back to local storage in offline mode

**Developer not receiving notifications:**
- Implement email integration (e.g., via Supabase Edge Functions)
- Add webhook to external notification service
- Check database for pending requests manually

## Security Notes

- Table uses Row Level Security (RLS)
- Anyone can submit requests (to support guests)
- Only authenticated developers can update/fulfill
- Email validation should be added client-side
- Consider rate limiting for abuse prevention
