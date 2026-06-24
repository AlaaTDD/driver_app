---
name: Cross-Project Consistency
description: Use this when making changes that affect both the Flutter taxi_app and the Next.js taxi_web admin dashboard to ensure consistency in data models, API contracts, localization, and behavior.
---

# Cross-Project Consistency

> The Flutter app and Next.js dashboard share the SAME database.
> Changes in one project MUST be reflected in the other.
> Never change a database column, table, or API without checking both projects.

---

## 1. Project Mapping

```
taxi/
├── taxi_app/     → Flutter mobile app (driver + user)
│   └── lib/
├── taxi_web/     → Next.js admin dashboard
│   └── src/
└── (shared)      → Supabase database (PostgreSQL)
```

### Shared Resources
| Resource | taxi_app uses via | taxi_web uses via |
|---|---|---|
| Database | `supabase_flutter` | `@supabase/ssr` |
| Auth | Supabase Auth (phone OTP) | Supabase Auth (email) |
| Storage | R2StorageService | Direct Supabase Storage |
| Realtime | Channel subscriptions | N/A (server-rendered) |

---

## 2. When to Check Both Projects

### ALWAYS check BOTH when:
```
□ Changing a database table or column
□ Changing trip status values or transitions
□ Changing wallet balance logic
□ Changing coupon rules or fields
□ Changing user/driver fields
□ Adding a new feature that admin manages
□ Changing notification payload format
□ Changing file upload paths/formats
□ Changing pricing calculation
```

### Check only taxi_app when:
```
□ UI-only changes (widget, animation, layout)
□ Map/GPS changes
□ App-specific BLoC logic
□ Navigation changes
```

### Check only taxi_web when:
```
□ Dashboard UI changes
□ Admin-only features (export, admin logs)
□ Dashboard chart/analytics changes
```

---

## 3. Data Model Consistency

### Database Field → Both Projects Must Agree

```
Database column: trips.status (text)

✅ Flutter (trip_model.dart):
   final String status;  // 'pending', 'accepted', 'in_progress', 'completed', 'cancelled'

✅ Next.js (trips/page.tsx):
   status === 'pending' | 'accepted' | 'in_progress' | 'completed' | 'cancelled'

❌ WRONG: Flutter uses 'canceled' (one L) but Next.js uses 'cancelled' (two L)
```

### Status Values Must Match
| Feature | Status Values |
|---|---|
| Trip | pending, accepted, in_progress, arrived, started, completed, cancelled |
| Withdrawal | pending, approved, rejected |
| Coupon | active, inactive (via is_active boolean) |
| Driver | pending, approved, revision, revoked |
| Complaint | open, resolved |
| Message ticket | open, closed |

---

## 4. API Contract Rules

When taxi_web has an API route that affects data taxi_app reads:

```
Example: POST /api/wallets/adjust

taxi_web sends: { user_id, amount, type }
  → Updates wallet balance in database
  → taxi_app's WalletCubit must handle this change

Checklist:
□ API validates all input (zod schema)
□ API uses correct column names matching Flutter model
□ Flutter model's fromJson handles all fields the API might return
□ Flutter BLoC refreshes data after changes might have occurred
□ Admin action is logged
```

---

## 5. Localization Consistency

### Flutter (ARB files)
```
Location: lib/core/localization/l10n/app_en.arb, app_ar.arb
Access: AppLocalizations.of(context)!.keyName
```

### Next.js (JSON files)
```
Location: messages/en.json, messages/ar.json
Access: useTranslations()('keyName') or getTranslations()
```

### Rules
- Same features should use similar key names
- Status labels must show the same text in both projects
- Currency formatting must be consistent (SAR, 2 decimals)
- Date formatting must be consistent

---

## 6. Currency Consistency

```
Flutter: CurrencyFormatter.getCurrencyFormat(context)
Next.js: getCurrencySettings() from src/lib/currency.ts

Both must:
- Use same currency symbol (from app_config table)
- Use same decimal places
- Use same number formatting (1,234.56 or ١٬٢٣٤٫٥٦)
```

---

## 7. Cross-Project Change Checklist

Before finishing any cross-project change:
```
□ Database schema matches both Flutter models and Next.js queries
□ Status strings are identical in both projects
□ Currency formatting is consistent
□ Date/time formatting is consistent
□ flutter analyze passes (0 errors)
□ npm run build passes (Next.js)
□ Both projects can read the same database rows correctly
```
