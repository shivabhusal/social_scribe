# SocialScribe - HubSpot Integration Features

This document summarizes all the features added to the SocialScribe project, specifically focusing on HubSpot integration and AI-powered contact management.

## Table of Contents
1. [HubSpot OAuth Integration](#hubspot-oauth-integration)
2. [AI-Powered Contact Suggestions](#ai-powered-contact-suggestions)
3. [Contact Management](#contact-management)
4. [User Interface Features](#user-interface-features)
5. [Data Caching & Performance](#data-caching--performance)
6. [Meeting Integration](#meeting-integration)

---

## HubSpot OAuth Integration

### OAuth Token Refresh
- **Automatic token refresh** to prevent `EXPIRED_AUTHENTICATION` errors
- Handles token expiration gracefully with automatic renewal
- Prevents API calls from failing due to expired tokens

### OAuth Scope Management
- **Corrected OAuth scopes** to include all necessary permissions:
  - `crm.schemas.contacts.write`
  - `crm.objects.contacts.write`
  - `crm.schemas.contacts.read`
  - `crm.objects.contacts.read`
- Ensures the OAuth flow requests all required permissions for full functionality

### Integration Management
- **Disconnect feature** for Facebook and HubSpot integrations
- Allows users to disconnect and reconnect accounts from settings page
- Useful for troubleshooting connection issues

---

## AI-Powered Contact Suggestions

### Gemini AI Integration
- **AI-generated contact update suggestions** based on meeting transcripts
- Uses Google Gemini API to analyze meeting transcripts
- Extracts explicit contact information changes mentioned in meetings
- Returns structured suggestions with:
  - Field name (firstname, lastname, email, phone, company, jobtitle, etc.)
  - Current value (from HubSpot)
  - Suggested new value (from transcript)
  - Evidence (exact quote from transcript)
  - Timestamp (when mentioned in meeting)

### Suggestion Caching
- **Database-backed caching** of AI suggestions to avoid repeated API calls
- Saves suggestions with meeting ID and contact ID
- Supports meeting-level suggestions (without specific contact)
- Reduces costs by caching Gemini API responses
- "Refetch from AI" button to regenerate suggestions when needed

### Suggestion Display
- **Categorized suggestions** grouped by:
  - Name (firstname, lastname)
  - Contact Information (email, phone)
  - Company (company, jobtitle)
  - Address (address, city, state, zip, country)
  - Other
- **Expandable/collapsible categories** with "Show details" / "Hide details"
- **Individual field selection** with checkboxes
- **Category-level selection** to select/deselect all fields in a category
- **Update count badges** showing "X updates selected" with grey background

---

## Contact Management

### Contact Search & Selection
- **Autocomplete search** for HubSpot contacts
- Search by name or email (debounced after 3 characters)
- **Local contact cache** for faster autocomplete
- **Fresh data fetch** when contact is selected (always fetches latest from HubSpot API)
- **Contact profile pictures** fetched and cached from HubSpot
- **Initials fallback** when profile picture is unavailable or fails to load
- **One-line display** of selected contact (name • email) to maintain consistent height

### Contact Information Display
- **Current value display** with:
  - Strikethrough effect for existing values
  - "No existing value" placeholder when field is empty
  - No strikethrough when field is empty
- **Suggested value display** with:
  - Editable field (when "Update mapping" is clicked)
  - Disabled state by default
  - Active styling when enabled (white background, normal border)
  - Disabled styling (grey background, cursor-not-allowed)

### Contact Updates
- **Bulk update capability** to update multiple fields at once
- **Selective updates** - users can choose which suggestions to apply
- **Edit suggested values** before updating
- **Update mapping** feature to enable/disable editing of suggested values
- **Cache refresh** after successful updates to keep local cache in sync

---

## User Interface Features

### HubSpot Update Modal
- **Modal dialog** for reviewing and applying contact updates
- **Contact search** with dropdown that hovers above content (doesn't push content down)
- **Visual layout** matching design specifications:
  - Current value field on left
  - Arrow separator (→) centered between fields
  - Suggested value field on right
  - "Update mapping" link below current value (left-aligned)
  - Evidence text below suggested value

### Evidence & Timestamps
- **Evidence display** showing exact quotes from transcript
- **Timestamp formatting** in MM:SS format (e.g., "00:05" with leading zeros)
- **Clickable timestamps** to view full evidence in tooltip
- **Tooltip display** with:
  - Full transcript quote
  - Proper z-index to appear above all content
  - Close button
  - Dark background for visibility

### Form Interactions
- **Update mapping toggle** to enable/disable editing of suggested values
- **Field-level editing** - each field can be independently enabled for editing
- **Visual feedback**:
  - Disabled fields: grey background, grey text
  - Enabled fields: white background, dark text, focus ring
  - Active "Update mapping" link: bold font

### Summary & Actions
- **Footer summary** showing total selected fields
- **Action buttons**:
  - Cancel button (secondary)
  - Update HubSpot button (primary, green)
  - Close button (after successful update)
- **Success state** - hides action buttons and shows only "Close" after update

---

## Data Caching & Performance

### HubSpot Contact Cache
- **Local contact cache** stored in database
- **TTL-based expiration** (configurable cache duration)
- **Automatic cache refresh** when contact is selected
- **Cache invalidation** after successful updates
- **Profile picture caching** included in contact cache

### Suggestion Cache
- **Meeting-level suggestions** cached with placeholder contact ID
- **Contact-specific suggestions** cached with actual contact ID
- **Timestamp tracking** for cache freshness
- **User-specific caching** to maintain data privacy

---

## Meeting Integration

### Meeting Page Features
- **AI suggestions display** on meeting details page
- **Refresh AI suggestions button** to regenerate suggestions
- **Timestamp display** with timezone information (e.g., "December 14, 2025 at 09:51 AM EST/EDT")
- **Evidence display** with formatted timestamps
- **Meeting selector** in settings modal to choose which meeting's suggestions to view

### Seed Data
- **Past meeting records** with transcripts
- **Realistic test data** with contact information changes
- **Participant information** in transcripts for AI analysis

### Transcript Processing
- **Timestamp extraction** from transcript segments
- **Speaker identification** in evidence quotes
- **Time formatting** for display (minutes:seconds with leading zeros)

---

## Technical Implementation Details

### Components
- `HubspotUpdateComponent` - Main LiveComponent for HubSpot update modal
- `HubspotUpdateModal` - Settings page modal for HubSpot updates
- Integration with existing meeting LiveView components

### Context Modules
- `HubspotAISuggestions` - AI suggestion generation using Gemini
- `HubspotSuggestions` - Database operations for cached suggestions
- `HubspotContactCache` - Contact caching functionality
- `HubspotApi` - HubSpot API client with token refresh

### Database Schema
- `hubspot_suggestions` - Stores cached AI suggestions
- `hubspot_contact_cache` - Stores cached contact information
- Both include timestamps for cache expiration

### API Integrations
- **HubSpot API**: Contact search, retrieval, and updates
- **Google Gemini API**: AI-powered suggestion generation
- **OAuth2**: Token management and refresh

---

## UI/UX Improvements

### Visual Design
- Consistent color scheme (slate greys, indigo accents)
- Rounded corners and shadows for depth
- Proper spacing and alignment
- Responsive layout

### User Experience
- Loading states for async operations
- Error handling with user-friendly messages
- Flash messages for success/error feedback
- Smooth transitions and interactions
- Accessible form controls

### Performance Optimizations
- Debounced search inputs
- Asynchronous API calls using Task.start
- Database caching to reduce API calls
- Efficient query patterns

---

## Future Enhancements (Potential)

- Batch updates across multiple contacts
- Update history/audit trail
- Undo/redo functionality
- Export suggestions to CSV
- Integration with other CRM platforms
- Real-time collaboration on suggestions
- Advanced filtering and sorting of suggestions

---

## Notes

- All features are fully integrated with the existing SocialScribe application
- OAuth token refresh prevents authentication errors
- Caching significantly reduces API costs
- UI matches provided design specifications
- All user interactions are handled through Phoenix LiveView
- Database migrations included for new tables
