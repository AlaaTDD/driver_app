# Complete System X-Ray Analysis — Taxi App Ecosystem

> **Scope** : Supabase/PostgreSQL · Flutter Mobile · Next.js Admin  **Generated** : 2026-05-14  **Status** : Production Audit — Gap Analysis + Implementation Plan

---

## 1. System Inventory Summary

### 1.1 Database Schema (PostgreSQL/Supabase)

| Category                        | Count     | Details                                                                                                                                                       |
| ------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tables**                | 31        | Core + financial + routing + support                                                                                                                          |
| **Views**                 | 17        | Admin dashboards + public profiles + route views                                                                                                              |
| **Custom Functions/RPCs** | 80+       | Trip lifecycle, pricing, wallet, coupons, admin ops                                                                                                           |
| **Triggers**              | 31        | Status transitions, wallet auto-creation, pricing validation                                                                                                  |
| **RLS Policies**          | 170+      | All 31 tables covered (2-14 policies each)                                                                                                                    |
| **Enums**                 | 6         | `route_plan_status`, `route_waypoint_role`, `wallet_transaction_status/type`, `withdrawal_method/status`                                              |
| **Extensions**            | 7         | PostGIS, pgcrypto, pg_cron, pg_stat_statements, uuid-ossp, supabase_vault, plpgsql                                                                            |
| **Realtime**              | 12 tables | trips, trip_offers, trip_route_plans/waypoints, messages, notifications, support_messages, driver/user_wallets, drivers_profile, user_presence, vehicle_types |

### 1.2 Flutter Mobile App

| Feature Module               | Screens                                                                 | Blocs/Cubits                         | Repositories                                     |
| ---------------------------- | ----------------------------------------------------------------------- | ------------------------------------ | ------------------------------------------------ |
| **Auth**               | 6 (splash, onboarding, login, register, register_user, register_driver) | 2 (AuthBloc, VehicleTypesCubit)      | 1 (AuthRepositoryImpl)                           |
| **User Home**          | 1                                                                       | 1 (UserHomeBloc)                     | —                                               |
| **Location Selection** | 1                                                                       | 1 (LocationBloc)                     | —                                               |
| **Pricing**            | 1                                                                       | 1 (PricingBloc)                      | 1 (CouponRepository)                             |
| **Meeting Point**      | 1                                                                       | 1 (MeetingBloc)                      | 1 (MeetingPointRepository)                       |
| **Searching**          | 1                                                                       | 1 (SearchingBloc)                    | —                                               |
| **Tracking**           | 1                                                                       | 1 (TrackingBloc)                     | —                                               |
| **User Trips**         | 2 (list + details)                                                      | 1 (TripsBloc)                        | 1 (TripsRepository)                              |
| **User Profile**       | 1                                                                       | 1 (ProfileBloc)                      | 1 (UserProfileRepository)                        |
| **Driver Home**        | 1                                                                       | 1 (DriverHomeBloc)                   | 1 (DriverHomeRepository)                         |
| **Driver Trips**       | 2 (list + details)                                                      | 2 (DriverTripsBloc, TripDetailsBloc) | 2 (DriverTripsRepository, TripDetailsRepository) |
| **Driver Profile**     | 1                                                                       | 1 (DriverProfileBloc)                | 1 (DriverProfileRepository)                      |
| **Wallet**             | 2 (user + driver)                                                       | 1 (WalletCubit)                      | 1 (WalletRepository)                             |
| **Messages**           | 2 (conversations + chat)                                                | 1 (MessagesCubit)                    | 1 (MessagesRepository)                           |
| **Notifications**      | 1                                                                       | —                                   | 1 (NotificationsRepository)                      |
| **Rating**             | 1                                                                       | 1 (RatingBloc)                       | 1 (RatingRepository)                             |
| **Complaints**         | 1                                                                       | —                                   | —                                               |
| **Chatbot**            | 1                                                                       | —                                   | —                                               |
| **Ride Offer**         | 1 (overlay)                                                             | 1 (RideOfferBloc)                    | —                                               |
| **Shared**             | 1 (pending verification)                                                | 1 (LocationPermissionCubit)          | —                                               |

### 1.3 Next.js Admin Panel

| Dashboard Section | Page Exists | Data Source                                           |
| ----------------- | ----------- | ----------------------------------------------------- |
| Overview / KPIs   | ✅          | `admin_dashboard` view, `admin_recent_trips` view |
| Users             | ✅          | `users` table                                       |
| Drivers           | ✅          | `drivers_profile` + `users`                       |
| Driver Locations  | ✅          | `driver_locations`                                  |
| Trips             | ✅          | `trips`                                             |
| Trip Offers       | ✅          | `trip_offers`                                       |
| Ratings           | ✅          | `ratings`                                           |
| Complaints        | ✅          | `complaints`                                        |
| Pricing           | ✅          | `pricing_config`, `vehicle_types`                 |
| Coupons           | ✅          | `coupons`                                           |
| User Coupons      | ✅          | `user_coupons`                                      |
| Coupon Analytics  | ✅          | `admin_coupon_analytics` view                       |
| Wallets           | ✅          | `driver_wallets`, `user_wallets`                  |
| Withdrawals       | ✅          | `withdrawal_requests`                               |
| Vehicle Types     | ✅          | `vehicle_types`                                     |
| Notifications     | ✅          | `notifications`                                     |
| Messages          | ✅          | `messages`                                          |
| Admin Logs        | ✅          | `admin_logs`                                        |
| Settings          | ✅          | Configuration                                         |

---

## 2. Critical Gap Analysis

### 🔴 PRIORITY 1 — Structural / Data Gaps

#### GAP-01: `trips.service_area_id` NOT in Flutter TripEntity/TripModel

* **DB** : `trips` table has `service_area_id` column (FK to `service_areas`)
* **Flutter** : `TripEntity` and `TripModel` do NOT include `service_area_id`
* **Impact** : Trip data is incomplete on the mobile side; service area filtering is database-only
* **Fix** : Add `service_area_id` to `TripEntity` + `TripModel.fromJson`/`toJson`

#### GAP-02: `trip_route_plans` / `trip_route_waypoints` — No Flutter Integration

* **DB** : Full multi-route schema exists: `trip_route_plans` (12 cols) + `trip_route_waypoints` (15 cols) + 2 enums + 2 views + 2 triggers + 2 RPCs (`fn_add_route_stopover`, `fn_create_route_plan_from_legacy`)
* **Flutter** : Zero models, zero repositories, zero UI for routes/stopovers
* **Web** : No route management pages in admin panel
* **Impact** : The entire multi-route/stopover system is database-only with no consumer
* **Fix** : Create `TripRoutePlanModel`, `TripRouteWaypointModel`, `RouteRepository`, and integrate into trip details screens

#### GAP-03: `bonus_rules` / `driver_bonus_ledger` — No Mobile UI

* **DB** : Tables exist, `award_daily_bonus` RPC exists, `admin_bonus_summary` view exists, `get_my_bonus_progress` RPC exists
* **Flutter** : No bonus/incentive screen for drivers
* **Web** : No bonus management page in admin sidebar
* **Impact** : Bonus system is entirely backend-only; drivers can't see their progress
* **Fix** : Add `DriverBonusScreen` + `BonusCubit` in Flutter; add `/dashboard/bonuses` page in Next.js

#### GAP-04: `driver_revision_requests` — Partial Mobile Integration

* **DB** : Table exists with full schema (7 cols), `request_driver_revision` RPC exists, RLS policies present
* **Flutter** : No UI for drivers to see or respond to revision requests
* **Web** : No admin page for managing revision requests (only exists in `admin_pending_verifications` view)
* **Impact** : Admin can request document revisions but drivers have no way to see them
* **Fix** : Add revision notification handling in `PendingVerificationScreen` + driver profile

#### GAP-05: `coupon_audit_log` / `coupon_usages` — No Admin Detail Views

* **DB** : Both tables exist with proper FKs and triggers
* **Web** : `coupon-analytics` page uses `admin_coupon_analytics` view but doesn't show per-coupon audit trail or usage details
* **Impact** : Admin can see aggregate analytics but not individual coupon lifecycle events
* **Fix** : Add drill-down views in coupon analytics page

### 🟡 PRIORITY 2 — Logic / Flow Gaps

#### GAP-06: No `estimated_duration` on trips

* **DB** : `trips` table has `distance_km` but NO `estimated_duration_min` or `duration_min`
* **Flutter** : No duration field in `TripEntity`
* **Impact** : ETA cannot be shown to rider/driver from stored data
* **Fix** : Add `estimated_duration_min` column to `trips`; populate from Directions API during trip creation

#### GAP-07: `meeting_lat/meeting_lng/meeting_address` — Created but Not in Meeting Point View

* **DB** : Fields exist on `trips` table
* **Flutter** : `MeetingPointRepository.createTrip()` does NOT populate meeting_lat/lng/address (sends pickup coords instead)
* **Impact** : Meeting point selection UI exists but meeting point data is never stored as such — it overwrites as pickup
* **Fix** : Add explicit meeting point fields to `createTrip` params

#### GAP-08: No `cancel_reason` Collection UI

* **DB** : `trips.cancel_reason` and `trips.cancelled_by` exist
* **Flutter** : `cancelTrip()` in `TripsRepository` sends `cancelled_by: 'user'` but never collects or sends `cancel_reason`
* **SearchingBloc** : Only sends `cancel_reason: 'timeout'` for system cancellation
* **Impact** : All user cancellations have null reason — no analytics on why trips are cancelled
* **Fix** : Add cancellation reason picker in cancel flow

#### GAP-09: `support_messages` — Dead Table

* **DB** : Table exists with 6 columns, 6 RLS policies, realtime enabled
* **Flutter** : No repository or screen uses `support_messages`; the `ComplaintsScreen` uses `complaints` table
* **Impact** : Two overlapping support systems; `support_messages` appears unused
* **Fix** : Either deprecate `support_messages` or build a ticket-based support chat using it

#### GAP-10: `user_ratings` Table — Fragile Integration

* **DB** : `user_ratings` table exists (driver rates user)
* **Flutter** : `RatingRepository.submitRating()` has a try-catch with "table might not exist" comment
* **Impact** : Driver-to-user ratings are unreliable; no trigger to recalculate user rating
* **Fix** : Add `_fn_recalculate_user_rating` trigger on `user_ratings` insert; remove defensive catch

#### GAP-11: No Scheduled/Future Ride Support

* **DB** : No `scheduled_at` field on `trips`; no scheduling logic
* **Flutter** : No schedule ride UI
* **Impact** : Riders cannot book rides in advance
* **Fix** : Add `scheduled_at TIMESTAMPTZ` to `trips`; add scheduling flow in mobile app

#### GAP-12: No Fare Estimate History

* **DB** : Price is calculated via `calculate_trip_price` RPC but not stored until trip creation
* **Flutter** : Price shown in `PricingScreen` but if user navigates away, it's lost
* **Impact** : No price quotation audit trail
* **Fix** : Consider `fare_estimates` table or use client-side caching

#### GAP-13: `pricing_config` vs `vehicle_types` — Redundant Pricing

* **DB** : Both `pricing_config` and `vehicle_types` have `base_fare` and `price_per_km`
* **Flutter** : `PricingBloc` loads from `vehicle_types`; `calculate_trip_price` RPC uses `pricing_config`
* **Impact** : If admin updates `vehicle_types` pricing but not `pricing_config`, prices will be inconsistent
* **Fix** : Deduplicate — make `calculate_trip_price` read from `vehicle_types` OR sync them via trigger

### 🟢 PRIORITY 3 — Feature Completeness Gaps

#### GAP-14: No Referral/Promo System

* **DB** : No `referrals` or `promo_codes` table
* **Flutter** : No referral UI
* **Impact** : No viral growth mechanism

#### GAP-15: No Payment Gateway Integration

* **DB** : `trips.payment_method` and `trips.payment_source` exist but are free-text
* **Flutter** : `payment_method` is collected but no actual payment processing
* **Impact** : All payments are cash-only effectively

#### GAP-16: No Dispute Resolution Flow

* **DB** : `complaints` table has `admin_reply` and `resolved_at` but no dispute lifecycle
* **Flutter** : Users can submit complaints but can't see admin replies
* **Web** : No admin reply UI visible in complaints page
* **Impact** : One-way complaint system

#### GAP-17: No Feature Toggles

* **DB** : No `feature_flags` or `app_config` table
* **Flutter** : Hardcoded feature flags
* **Impact** : Cannot remotely enable/disable features

#### GAP-18: No App Version Enforcement

* **DB** : No minimum version config
* **Flutter** : No force-update check
* **Impact** : Cannot enforce app updates

#### GAP-19: `driver_service_areas` — No Mobile UI

* **DB** : Full table + `assign_driver_to_area`/`remove_driver_from_area` RPCs
* **Flutter** : No UI for drivers to see/manage their service areas
* **Impact** : Service area assignment is admin-only; drivers unaware of their zones

#### GAP-20: No `service_areas` Admin CRUD Page

* **Web** : No `/dashboard/service-areas` route in sidebar
* **Impact** : Admin cannot create/edit service areas from the web panel

#### GAP-21: No Driver Document Expiry Tracking

* **DB** : `drivers_profile` has document URLs but no expiry dates
* **Impact** : Cannot auto-flag expired licenses

#### GAP-22: Missing `trips.trip_route_plan_id` Column (Route-Plan Binding)

* **DB** : `trip_route_plans.trip_id` → trips (FK exists), but `v_trip_active_route` view uses a JOIN
* **Impact** : Minor — query performance could benefit from denormalized FK on trips, but current design is fine

#### GAP-23: No Admin Push Notification Sender

* **Web** : `notifications` page likely shows list but no "Send Notification" action
* **Impact** : Admin can't broadcast push notifications to users/drivers

---

## 3. Cross-Platform Consistency Map

### Flutter ↔ Supabase Alignment

| Supabase Table/RPC                           | Flutter Repo/Bloc                                  | Status                           |
| -------------------------------------------- | -------------------------------------------------- | -------------------------------- |
| `trips` + 14 columns                       | `TripEntity` (33 fields)                         | ⚠️ Missing `service_area_id` |
| `trip_offers`                              | `TripOfferModel`, `RideOfferBloc`              | ✅ Complete                      |
| `trip_route_plans`                         | —                                                 | ❌**Not implemented**      |
| `trip_route_waypoints`                     | —                                                 | ❌**Not implemented**      |
| `users`                                    | `UserModel`, `AuthRepositoryImpl`              | ✅ Complete                      |
| `drivers_profile`                          | `DriverProfileModel`, `DriverProfileBloc`      | ✅ Complete                      |
| `driver_locations`                         | `DriverHomeRepository.pushLocation`              | ✅ Complete                      |
| `driver_wallets`                           | `DriverWalletModel`, `WalletCubit`             | ✅ Complete                      |
| `user_wallets`                             | `UserWalletModel`, `WalletCubit`               | ✅ Complete                      |
| `wallet_transactions`                      | `WalletTransactionModel`, `WalletRepository`   | ✅ Complete                      |
| `withdrawal_requests`                      | `WithdrawalRequestModel`, `WalletRepository`   | ✅ Complete                      |
| `messages`                                 | `MessageModel`, `MessagesRepository`           | ✅ Complete                      |
| `notifications`                            | `NotificationModel`, `NotificationsRepository` | ✅ Complete                      |
| `ratings` / `user_ratings`               | `RatingRepository`                               | ⚠️ Fragile (see GAP-10)        |
| `complaints`                               | `TripsRepository.submitComplaint`                | ⚠️ No view/reply UI            |
| `support_messages`                         | —                                                 | ❌**Unused** (see GAP-09)  |
| `coupons` / `user_coupons`               | `CouponRepository`                               | ✅ Validate only                 |
| `coupon_usages` / `coupon_audit_log`     | —                                                 | ⚠️ No mobile visibility        |
| `pricing_config`                           | — (uses `vehicle_types`)                        | ⚠️ Redundancy (GAP-13)         |
| `vehicle_types`                            | `PricingBloc.LoadVehicleTypes`                   | ✅ Complete                      |
| `service_areas` / `driver_service_areas` | —                                                 | ❌**No mobile UI**         |
| `bonus_rules` / `driver_bonus_ledger`    | —                                                 | ❌**No mobile UI**         |
| `driver_revision_requests`                 | —                                                 | ❌**No mobile UI**         |
| `admin_logs`                               | —                                                 | N/A (admin only)                 |
| `user_presence`                            | `MessagesRepository.ensureMyPresence`            | ✅ Complete                      |

### Web Admin ↔ Supabase Alignment

| Admin View/Table                | Web Page                        | Status                         |
| ------------------------------- | ------------------------------- | ------------------------------ |
| `admin_dashboard`             | `/dashboard`                  | ✅                             |
| `admin_recent_trips`          | `/dashboard`                  | ✅                             |
| `admin_users_list`            | `/dashboard/users`            | ✅                             |
| `admin_pending_verifications` | `/dashboard/drivers`          | ⚠️ Partial (in drivers page) |
| `admin_coupon_analytics`      | `/dashboard/coupon-analytics` | ✅                             |
| `admin_bonus_summary`         | —                              | ❌**No page**            |
| `admin_audit_log`             | `/dashboard/admin-logs`       | ✅                             |
| `service_areas`               | —                              | ❌**No page**            |
| `driver_revision_requests`    | —                              | ❌**No page**            |
| `trip_route_plans`            | —                              | ❌**No page**            |
| `bonus_rules`                 | —                              | ❌**No page**            |

---

## 4. Database Health Notes

### RLS Coverage: ✅ EXCELLENT

All 31 tables have RLS enabled with policies. Coverage ranges from 2 to 14 policies per table.

### Trigger Coverage: ✅ GOOD

31 triggers covering critical flows:

* Trip lifecycle: 10 triggers on `trips`
* Wallet auto-creation: 2 triggers (users + drivers)
* Rating recalculation: 1 trigger on `ratings`
* Timestamp updates: 8 triggers across tables
* Coupon lifecycle: 3 triggers
* Route enforcement: 2 triggers

### Missing Trigger: `user_ratings` → recalculate user average rating

Currently `_fn_recalculate_driver_rating` fires on `ratings` insert, but there's no equivalent for `user_ratings` to update `users.rating` for riders.

### Index Recommendations from CSV

The schema has appropriate indexes. No critical missing indexes detected from the X-Ray data. Some unused indexes were flagged but are likely recent additions.

---

## 5. Prioritized Implementation Roadmap

### Phase 1 — Critical Data Alignment (DB + Flutter)

1. Add `service_area_id` to `TripEntity` + `TripModel`
2. Add `estimated_duration_min` to `trips` table + Flutter models
3. Fix `pricing_config` vs `vehicle_types` redundancy
4. Create `_fn_recalculate_user_rating` trigger
5. Wire `cancel_reason` collection in Flutter cancel flow

### Phase 2 — Multi-Route Integration (DB → Flutter → Web)

1. Create `TripRoutePlanModel` + `TripRouteWaypointModel` in Flutter
2. Create `RouteRepository` with RPC calls
3. Add route visualization in trip details screens
4. Add route management in admin trips page

### Phase 3 — Missing Admin Pages (Web)

1. `/dashboard/service-areas` — CRUD for service areas
2. `/dashboard/bonuses` — Bonus rules management + driver bonus summary
3. `/dashboard/revision-requests` — Driver document revision workflow
4. Enhance `/dashboard/complaints` — Add admin reply functionality
5. Add "Send Notification" action to notifications page

### Phase 4 — Mobile Feature Completeness

1. Driver bonus progress screen (`get_my_bonus_progress` RPC)
2. Driver service area display
3. Driver revision requests notification
4. Complaint reply viewing for users
5. Coupon usage history for users

### Phase 5 — Strategic Features

1. Scheduled/future ride support
2. Feature toggle system (`app_config` table)
3. App version enforcement
4. Referral system
5. Payment gateway integration skeleton

---

## 6. Safe Migration Strategy

IMPORTANT

All changes must be **additive-first** — no column drops, no table drops, no enum value removals.

### Migration Principles

1. New columns → `ALTER TABLE ADD COLUMN ... DEFAULT ...` (never NOT NULL without default)
2. New tables → `CREATE TABLE IF NOT EXISTS`
3. New functions → `CREATE OR REPLACE FUNCTION`
4. New triggers → `DROP TRIGGER IF EXISTS ... ; CREATE TRIGGER`
5. New enums → `ALTER TYPE ... ADD VALUE IF NOT EXISTS`
6. New RLS policies → `DROP POLICY IF EXISTS ... ; CREATE POLICY`
7. All DDL wrapped in idempotent blocks

---

## 7. Files to Create/Modify

### Flutter (taxi_app)

| Action | File                                                            | Purpose                                         |
| ------ | --------------------------------------------------------------- | ----------------------------------------------- |
| MODIFY | `lib/features/trips/domain/entities/trip_entity.dart`         | Add `serviceAreaId`, `estimatedDurationMin` |
| MODIFY | `lib/features/trips/data/models/trip_model.dart`              | Add new fields to fromJson/toJson               |
| CREATE | `lib/core/models/trip_route_plan_model.dart`                  | Route plan model                                |
| CREATE | `lib/core/models/trip_route_waypoint_model.dart`              | Waypoint model                                  |
| CREATE | `lib/features/driver/data/repositories/bonus_repository.dart` | Bonus progress                                  |
| CREATE | `lib/features/driver/presentation/bonus/bonus_screen.dart`    | Bonus UI                                        |
| MODIFY | `lib/features/user/data/repositories/trips_repository.dart`   | Add cancel reason param                         |
| MODIFY | `lib/core/router/app_router.dart`                             | Add new routes                                  |

### Next.js (taxi_web)

| Action | File                                             | Purpose               |
| ------ | ------------------------------------------------ | --------------------- |
| CREATE | `src/app/dashboard/service-areas/page.tsx`     | Service areas CRUD    |
| CREATE | `src/app/dashboard/bonuses/page.tsx`           | Bonus rules + summary |
| CREATE | `src/app/dashboard/revision-requests/page.tsx` | Driver revisions      |
| MODIFY | `src/components/sidebar.tsx`                   | Add new nav items     |

### Supabase (migrations)

| Action                                                  | Purpose            |
| ------------------------------------------------------- | ------------------ |
| `ALTER TABLE trips ADD COLUMN estimated_duration_min` | ETA storage        |
| `CREATE TRIGGER trg_recalculate_user_rating`          | User rating recalc |
| Sync `pricing_config` → `vehicle_types` trigger    | Price consistency  |
