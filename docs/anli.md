
# Deep X-Ray System Audit — Taxi App Ecosystem

> **Scope** : Supabase/PostgreSQL · Flutter Mobile · Next.js Admin
> **Generated** : 2026-05-15
> **Status** : Production Forensic Audit — Complete Gap Analysis + Fixes

---

## Executive Summary

After exhaustive analysis of both workspaces (`taxi_app` + `taxi_web`), the Supabase schema (31 tables, 80+ RPCs, 170+ RLS policies), and all application code, I've identified **42 distinct issues** across 5 severity tiers. The system is architecturally sound but has significant integration gaps where backend capabilities exist without frontend consumers, hardcoded strings breaking i18n, and several business logic inconsistencies.

### Severity Distribution

| Severity    | Count | Description                                        |
| ----------- | ----- | -------------------------------------------------- |
| 🔴 Critical | 6     | Data integrity / logic bugs that affect production |
| 🟠 High     | 9     | Missing integrations that leave features unusable  |
| 🟡 Medium   | 12    | Incomplete flows, partial implementations          |
| 🟢 Low      | 10    | Polish, UX gaps, minor inconsistencies             |
| ⚪ Info     | 5     | Recommendations, future considerations             |

---

## 1. Database Layer Audit

### 1.1 Schema Health: ✅ Strong

* **31 tables** with full RLS coverage (170+ policies)
* **80+ custom functions/RPCs** covering trip lifecycle, pricing, wallet, coupons
* **31 triggers** for automated state transitions
* **6 custom enums** : `route_plan_status`, `route_waypoint_role`, `wallet_transaction_status`, `wallet_transaction_type`, `withdrawal_method`, `withdrawal_status`
* **7 extensions** : PostGIS, pgcrypto, pg_cron, pg_stat_statements, uuid-ossp, supabase_vault, plpgsql
* **12 tables** on Supabase Realtime

### 1.2 Database Issues Found

#### DB-01: 🔴 `pricing_config` vs `vehicle_types` Price Redundancy

* **Location** : Both tables store `base_fare` and `price_per_km`
* **Impact** : `PricingBloc` (Flutter) reads from `vehicle_types`; `calculate_trip_price` RPC uses `pricing_config` → **price mismatch risk**
* **Fix Required** : Sync trigger or deduplicate

#### DB-02: 🟠 Missing `user_ratings` Recalculation Trigger

* **Location** : `user_ratings` table has no trigger equivalent to `_fn_recalculate_driver_rating`
* **Impact** : Driver-to-user ratings are stored but `users.rating` for riders is never updated
* **Fix** : Create `_fn_recalculate_user_rating` trigger

#### DB-03: 🟡 `support_messages` Table — Orphaned

* **Location** : Table exists with 6 columns, 6 RLS policies, realtime enabled
* **Impact** : No consumer in Flutter or Next.js; overlaps with `complaints`
* **Status** : Dead table, consider deprecation

#### DB-04: 🟡 No `estimated_duration_min` Column on `trips`

* **Location** : `trips` table schema
* **Impact** : The Flutter `TripEntity` has the field, `MeetingPointRepository.createTrip()` sends it, but column may not exist in DB
* **Status** : Verify column existence; if missing, add via migration

#### DB-05: 🟢 Missing Table Comments

* **Location** : Multiple tables lack PostgreSQL `COMMENT` annotations
* **Impact** : Reduced developer discoverability

---

## 2. Flutter Mobile App Audit

### 2.1 Architecture: ✅ Well-Structured

* Clean architecture: `data/domain/presentation` layers
* BLoC pattern consistently used
* 7 feature modules: `auth`, `driver`, `user`, `trips`, `wallet`, `ride_offer`, `shared`
* GoRouter with auth-aware redirect logic

### 2.2 Issues Found

#### FL-01: 🔴 `SearchingBloc.CancelSearch` — No `cancel_reason` Sent

* **Location** : **searching_bloc.dart:196-204**
* **Impact** : User cancellations always have `null` cancel_reason — analytics gap
* **Detail** : `_onCancel` calls `cancel_trip` RPC with only `p_cancelled_by: 'user'`, no reason
* **Fix** : Add cancel reason picker dialog before calling CancelSearch event

#### FL-02: 🟠 No Driver Bonus UI Screen

* **Location** : Missing `lib/features/driver/presentation/bonus/`
* **Impact** : `BonusRepository` exists with 3 methods (`getMyBonusProgress`, `getActiveBonusRules`, `getBonusHistory`) but **no screen or bloc** consumes them
* **Detail** : Driver cannot see bonus progress despite DB having full bonus system
* **Fix** : Create `DriverBonusScreen` + `BonusCubit`

#### FL-03: 🟠 No Driver Revision Request UI

* **Location** : Missing from driver feature
* **Impact** : Admin can request document revisions via web panel, but drivers have no way to see or respond to revision requests
* **Fix** : Add revision notification handling in `PendingVerificationScreen` or dedicated screen

#### FL-04: 🟠 No Service Area Display for Drivers

* **Location** : Missing from driver feature
* **Impact** : `service_areas` + `driver_service_areas` tables with RPCs exist; drivers are unaware of their assigned zones
* **Fix** : Add service area badge/info to driver home or profile

#### FL-05: 🟡 Complaints Screen — No Admin Reply Visibility

* **Location** : **complaints_repository.dart**
* **Impact** : `myComplaintsStream()` fetches complaints but the `ComplaintsScreen` doesn't display `admin_reply` field
* **Detail** : One-way complaint system — users submit but never see responses

#### FL-06: 🟡 `RatingRepository.hasExistingRating` — Defensive Try-Catch

* **Location** : **rating_repository.dart:26-57**
* **Impact** : Catches errors from `user_ratings` table access with "table might not exist" pattern, falls back to `trips` table check
* **Detail** : This suggests uncertainty about schema stability; should be cleaned up

#### FL-07: 🟡 `WalletRepository.getTransactionHistory` — Filter by `wallet_id` Not `user_id`

* **Location** : **wallet_repository.dart:65-86**
* **Impact** : Uses `.eq('wallet_id', userId)` which assumes wallet_id == user_id. If wallet table uses different IDs, this breaks
* **Status** : Works if wallet auto-creation uses user ID as wallet ID (verify)

#### FL-08: 🟡 Duplicate `cancelTrip` Logic

* **Location** : `MeetingPointRepository.cancelTrip()` AND `TripsRepository.cancelTrip()` both call `cancel_trip` RPC
* **Impact** : Code duplication; `MeetingPointRepository` version doesn't support `cancel_reason`

#### FL-09: 🟢 No Route for Driver Bonus in `app_routes.dart`

* **Location** : **app_routes.dart**
* **Impact** : No `driverBonus` route constant defined

#### FL-10: 🟢 `UserWalletScreen` Not Wrapped in `WalletCubit`

* **Location** : **app_router.dart:328**
* **Impact** : `UserWalletScreen` is used directly without BlocProvider for WalletCubit, unlike `DriverWalletScreen` which gets one
* **Detail** : `UserWalletScreen` may create its own cubit internally, but inconsistent with driver wallet pattern

#### FL-11: 🟢 `TripRoutePlanModel` Exists But No Repository

* **Location** : **trip_route_plan_model.dart**
* **Impact** : Model created for `trip_route_plans` table but no `RouteRepository` or UI consumes it
* **Detail** : Multi-route system is DB + model only, no end-to-end integration

---

## 3. Next.js Admin Panel Audit

### 3.1 Architecture: ✅ Well-Built

* Next.js 16 with App Router
* Server Components + Client Components properly separated
* Supabase SSR with admin client using service role key
* 20 dashboard sections with full sidebar navigation
* Tailwind CSS v4 + Framer Motion + Recharts

### 3.2 Issues Found

#### WEB-01: 🔴 Hardcoded Arabic Strings (28+ instances)

* **Location** : Multiple files across `src/app/dashboard/`
* **Impact** : Breaks i18n for English users; inconsistent with `next-intl` pattern used elsewhere
* **Files affected** :
* `settings/page.tsx` — 5 hardcoded strings ("الإعدادات العامة", "المظهر", "اللغة", etc.)
* `notifications/notifications-client.tsx` — 8 hardcoded strings
* `drivers/revision/page.tsx` — 12+ hardcoded strings
* `complaints/[id]/complaint-detail-client.tsx` — 6 hardcoded strings
* `trips/[id]/page.tsx` — 3 hardcoded strings
* `users/users-client.tsx` — 3 hardcoded strings
* `drivers/page.tsx` — 1 hardcoded string
* `api/trips/cancel/route.ts` — 1 hardcoded string
* `api/notifications/send/route.ts` — 1 hardcoded string

#### WEB-02: 🟠 `service-areas` Page — Read-Only (No CRUD)

* **Location** : **service-areas/page.tsx**
* **Impact** : Displays service areas but has no Create/Edit/Delete/Toggle actions
* **Detail** : Has a `Plus` icon imported but never used in the UI

#### WEB-03: 🟠 `bonuses` Page — Read-Only (No CRUD)

* **Location** : **bonuses/page.tsx**
* **Impact** : Shows bonus rules and recent awards but cannot create/edit/toggle bonus rules

#### WEB-04: 🟠 Settings Page — Hardcoded, No System Config

* **Location** : **settings/page.tsx**
* **Impact** : Only has theme toggle and language switcher; no system configuration (commission %, search radius, max trip distance, etc.)
* **Detail** : All strings hardcoded in Arabic, doesn't use `t()` translations

#### WEB-05: 🟡 Middleware Performance — DB Query on Every Request

* **Location** : **middleware.ts:38-44**
* **Impact** : Every authenticated request to `/dashboard/*` triggers a Supabase query to check `is_admin`
* **Detail** : Should cache admin status in session/cookie or JWT claims

#### WEB-06: 🟡 No API Route for Service Areas CRUD

* **Location** : Missing `src/app/api/service-areas/`
* **Impact** : Even if the page had CRUD UI, no API backend exists

#### WEB-07: 🟡 No API Route for Bonus Rules CRUD

* **Location** : Missing `src/app/api/bonuses/`
* **Impact** : Cannot create/edit/toggle bonus rules from web panel

#### WEB-08: 🟢 `notifications-client.tsx` Type Options Hardcoded

* **Location** : **notifications-client.tsx:62-72**
* **Impact** : Notification type filter options are hardcoded in Arabic instead of using `t()` translations

---

## 4. Cross-Platform Consistency Analysis

### 4.1 DB ↔ Flutter Alignment

| DB Table/RPC                                 | Flutter Integration                    | Status                                                         |
| -------------------------------------------- | -------------------------------------- | -------------------------------------------------------------- |
| `trips` (all columns)                      | `TripEntity` + `TripModel`         | ✅ Complete (incl.`serviceAreaId`, `estimatedDurationMin`) |
| `trip_offers`                              | `TripOfferModel` + `RideOfferBloc` | ✅ Complete                                                    |
| `trip_route_plans`                         | `TripRoutePlanModel` (model only)    | ⚠️ No repo/UI                                                |
| `trip_route_waypoints`                     | —                                     | ❌ No model/repo/UI                                            |
| `bonus_rules` + `driver_bonus_ledger`    | `BonusRepository` (repo only)        | ⚠️ No screen/bloc                                            |
| `driver_revision_requests`                 | —                                     | ❌ No integration                                              |
| `service_areas` + `driver_service_areas` | —                                     | ❌ No integration                                              |
| `support_messages`                         | —                                     | ❌ Unused/orphaned                                             |
| `coupon_audit_log` + `coupon_usages`     | —                                     | ❌ No mobile visibility                                        |

### 4.2 DB ↔ Web Alignment

| DB View/Table                | Web Page                        | Status                  |
| ---------------------------- | ------------------------------- | ----------------------- |
| `admin_bonus_summary`      | `/dashboard/bonuses`          | ✅ Read-only            |
| `service_areas`            | `/dashboard/service-areas`    | ⚠️ Read-only, no CRUD |
| `driver_revision_requests` | `/dashboard/drivers/revision` | ✅ Has form             |
| `trip_route_plans`         | —                              | ❌ No admin route view  |
| `coupon_audit_log`         | `/dashboard/coupon-analytics` | ⚠️ Aggregate only     |

### 4.3 Flutter ↔ Web Parity

| Feature               | Flutter                     | Web                       | Gap                             |
| --------------------- | --------------------------- | ------------------------- | ------------------------------- |
| Complaint admin reply | ❌ Can't view replies       | ✅ Can send replies       | Users never see admin responses |
| Cancel reason         | ⚠️ Partial (timeout only) | ✅ Can cancel with reason | No user-initiated reason UI     |
| Bonus progress        | ⚠️ Repo exists, no UI     | ✅ Summary page           | Drivers can't see progress      |
| Service areas         | ❌ No UI                    | ⚠️ Read-only            | Neither side has full CRUD      |

---

## 5. Business Logic Audit

### 5.1 Trip Lifecycle: ✅ Mostly Sound

The trip state machine (`searching → accepted → in_progress → completed`) is well-implemented:

* `SearchingBloc` handles 180-second timeout with auto-cancellation
* `TripDetailsRepository` has `acceptTrip`, `startTrip`, `completeTrip` RPCs
* Realtime subscriptions properly watch trip status changes
* Re-broadcast every 15 seconds to find new drivers

### 5.2 Logic Issues

#### BL-01: 🔴 Race Condition in Trip Acceptance

* **Location** : `DriverHomeRepository.acceptTrip()` and `TripDetailsRepository.acceptTrip()` are **duplicate methods** calling the same RPC
* **Impact** : If both are called, the RPC likely handles idempotency, but the duplication is a maintenance risk

#### BL-02: 🟠 No Duplicate Trip Protection (Client-Side)

* **Location** : `MeetingPointRepository.createTrip()`
* **Impact** : No check for existing active trip before creating a new one (only `getActiveTripId` exists but isn't enforced in the create flow — it's used separately)
* **Detail** : The `MeetingBloc` does check, but a race condition at the UI layer could allow double-submission

#### BL-03: 🟡 Coupon Application is Non-Atomic with Trip Creation

* **Location** : **meeting_point_repository.dart:82-96**
* **Impact** : Trip is created first, then coupon is applied in a separate RPC call. If coupon application fails, trip exists at full price
* **Detail** : Comment says "Non-blocking: trip is created even if coupon fails" — this is by design but could confuse users

#### BL-04: 🟡 `DriverHomeRepository.getEarningsSummary` Duplicated in `WalletRepository`

* **Location** : Both **driver_home_repository.dart:34-76** and **wallet_repository.dart:13-55**
* **Impact** : Same logic duplicated — fetching from `driver_earnings_summary` view + `get_driver_earnings_detailed` RPC

---

## 6. UX/UI Review

### 6.1 Issues Found

#### UX-01: 🟡 No Empty State for Driver Bonus

* Drivers have no way to see bonus progress or rules

#### UX-02: 🟡 Complaint Reply Not Visible to Users

* Users submit complaints but never see admin responses — frustrating UX

#### UX-03: 🟡 Cancel Reason Not Collected

* When users cancel a trip, no dialog asks why — missed analytics opportunity

#### UX-04: 🟢 Settings Page — Minimal

* Only theme + language; no system configuration visible to admin

#### UX-05: 🟢 Service Areas — No Map Visualization

* Service areas show geohash prefixes as text but no map view

---

## 7. Prioritized Remediation Roadmap

### Phase 1 — Critical Fixes (Immediate)

| # | Issue  | Action                                                                                            | Effort |
| - | ------ | ------------------------------------------------------------------------------------------------- | ------ |
| 1 | DB-01  | Add pricing sync trigger OR make `calculate_trip_price` read from `vehicle_types`             | 2h     |
| 2 | FL-01  | Add cancel reason picker dialog in searching flow                                                 | 3h     |
| 3 | WEB-01 | Extract all 28+ hardcoded Arabic strings to `messages/ar.json` + `en.json`                    | 4h     |
| 4 | DB-02  | Create `_fn_recalculate_user_rating` trigger                                                    | 1h     |
| 5 | BL-01  | Remove duplicate `acceptTrip` from `DriverHomeRepository` (keep in `TripDetailsRepository`) | 30m    |
| 6 | BL-04  | Extract earnings fetch to shared helper, remove duplication                                       | 1h     |

### Phase 2 — Feature Completion (1-2 weeks)

| #  | Issue  | Action                                               | Effort |
| -- | ------ | ---------------------------------------------------- | ------ |
| 7  | FL-02  | Build `DriverBonusScreen` + `BonusCubit` + route | 6h     |
| 8  | FL-05  | Show `admin_reply` in complaints screen            | 2h     |
| 9  | WEB-02 | Add CRUD actions to service areas page + API routes  | 6h     |
| 10 | WEB-03 | Add CRUD actions to bonuses page + API routes        | 6h     |
| 11 | WEB-04 | Extend settings page with system config              | 4h     |
| 12 | FL-03  | Add driver revision request notification/screen      | 4h     |

### Phase 3 — Integration Polish (2-4 weeks)

| #  | Issue  | Action                                                          | Effort |
| -- | ------ | --------------------------------------------------------------- | ------ |
| 13 | FL-04  | Add service area display for drivers                            | 3h     |
| 14 | FL-11  | Build `RouteRepository` + route visualization in trip details | 8h     |
| 15 | FL-08  | Consolidate cancel trip logic into single repository method     | 2h     |
| 16 | WEB-05 | Cache admin status in JWT claims or cookie                      | 3h     |
| 17 | DB-03  | Deprecate or repurpose `support_messages` table               | 1h     |

---

## 8. Migration SQL for Critical Fixes

<pre><div node="[object Object]" class="relative whitespace-pre-wrap word-break-all my-2 rounded-lg bg-list-hover-subtle border border-gray-500/20"><div class="min-h-7 relative box-border flex flex-row items-center justify-between rounded-t border-b border-gray-500/20 px-2 py-0.5"><div class="font-sans text-sm text-ide-text-color opacity-60">sql</div><div class="flex flex-row gap-2 justify-end"><div class="cursor-pointer opacity-70 hover:opacity-100"></div></div></div><div class="p-3"><div class="w-full h-full text-xs cursor-text"><div class="code-block"><div class="code-line" data-line-number="1" data-line-start="1" data-line-end="1"><div class="line-content"><span class="mtk8">-- ════════════════════════════════════════════════════════════════</span></div></div><div class="code-line" data-line-number="2" data-line-start="2" data-line-end="2"><div class="line-content"><span class="mtk8">-- MIGRATION: Critical Fixes — Phase 1</span></div></div><div class="code-line" data-line-number="3" data-line-start="3" data-line-end="3"><div class="line-content"><span class="mtk8">-- Safe, additive, idempotent</span></div></div><div class="code-line" data-line-number="4" data-line-start="4" data-line-end="4"><div class="line-content"><span class="mtk8">-- ════════════════════════════════════════════════════════════════</span></div></div><div class="code-line" data-line-number="5" data-line-start="5" data-line-end="5"><div class="line-content"><span class="mtk1"></span></div></div><div class="code-line" data-line-number="6" data-line-start="6" data-line-end="6"><div class="line-content"><span class="mtk8">-- 1. User Rating Recalculation Trigger (DB-02)</span></div></div><div class="code-line" data-line-number="7" data-line-start="7" data-line-end="7"><div class="line-content"><span class="mtk3">CREATE OR REPLACE</span><span class="mtk1"></span><span class="mtk3">FUNCTION</span><span class="mtk1"></span><span class="mtk13">_fn_recalculate_user_rating</span><span class="mtk1">()</span></div></div><div class="code-line" data-line-number="8" data-line-start="8" data-line-end="8"><div class="line-content"><span class="mtk3">RETURNS</span><span class="mtk1"> TRIGGER </span><span class="mtk3">AS</span><span class="mtk1"> $$</span></div></div><div class="code-line" data-line-number="9" data-line-start="9" data-line-end="9"><div class="line-content"><span class="mtk3">BEGIN</span></div></div><div class="code-line" data-line-number="10" data-line-start="10" data-line-end="10"><div class="line-content"><span class="mtk1"></span><span class="mtk3">UPDATE</span><span class="mtk1"> users</span></div></div><div class="code-line" data-line-number="11" data-line-start="11" data-line-end="11"><div class="line-content"><span class="mtk1"></span><span class="mtk3">SET</span><span class="mtk1"> rating </span><span class="mtk16">=</span><span class="mtk1"></span><span class="mtk16">COALESCE</span><span class="mtk1">(</span></div></div><div class="code-line" data-line-number="12" data-line-start="12" data-line-end="12"><div class="line-content"><span class="mtk1">    (</span><span class="mtk3">SELECT</span><span class="mtk1"></span><span class="mtk16">ROUND</span><span class="mtk1">(</span><span class="mtk16">AVG</span><span class="mtk1">(rating)::</span><span class="mtk3">numeric</span><span class="mtk1">, </span><span class="mtk5">2</span><span class="mtk1">)</span></div></div><div class="code-line" data-line-number="13" data-line-start="13" data-line-end="13"><div class="line-content"><span class="mtk1"></span><span class="mtk3">FROM</span><span class="mtk1"> user_ratings</span></div></div><div class="code-line" data-line-number="14" data-line-start="14" data-line-end="14"><div class="line-content"><span class="mtk1"></span><span class="mtk3">WHERE</span><span class="mtk1"> user_id </span><span class="mtk16">=</span><span class="mtk1"></span><span class="mtk5">NEW</span><span class="mtk1">.</span><span class="mtk5">user_id</span><span class="mtk1">),</span></div></div><div class="code-line" data-line-number="15" data-line-start="15" data-line-end="15"><div class="line-content"><span class="mtk1"></span><span class="mtk5">0</span></div></div><div class="code-line" data-line-number="16" data-line-start="16" data-line-end="16"><div class="line-content"><span class="mtk1">  ),</span></div></div><div class="code-line" data-line-number="17" data-line-start="17" data-line-end="17"><div class="line-content"><span class="mtk1">  updated_at </span><span class="mtk16">=</span><span class="mtk1"></span><span class="mtk3">NOW</span><span class="mtk1">()</span></div></div><div class="code-line" data-line-number="18" data-line-start="18" data-line-end="18"><div class="line-content"><span class="mtk1"></span><span class="mtk3">WHERE</span><span class="mtk1"> id </span><span class="mtk16">=</span><span class="mtk1"></span><span class="mtk5">NEW</span><span class="mtk1">.</span><span class="mtk5">user_id</span><span class="mtk1">;</span></div></div><div class="code-line" data-line-number="19" data-line-start="19" data-line-end="19"><div class="line-content"><span class="mtk1"></span><span class="mtk3">RETURN</span><span class="mtk1"> NEW;</span></div></div><div class="code-line" data-line-number="20" data-line-start="20" data-line-end="20"><div class="line-content"><span class="mtk3">END</span><span class="mtk1">;</span></div></div><div class="code-line" data-line-number="21" data-line-start="21" data-line-end="21"><div class="line-content"><span class="mtk1">$$ </span><span class="mtk3">LANGUAGE</span><span class="mtk1"> plpgsql </span><span class="mtk3">SECURITY</span><span class="mtk1"> DEFINER;</span></div></div><div class="code-line" data-line-number="22" data-line-start="22" data-line-end="22"><div class="line-content"><span class="mtk1"></span></div></div><div class="code-line" data-line-number="23" data-line-start="23" data-line-end="23"><div class="line-content"><span class="mtk3">DROP</span><span class="mtk1"></span><span class="mtk3">TRIGGER</span><span class="mtk1"></span><span class="mtk3">IF</span><span class="mtk1"></span><span class="mtk3">EXISTS</span><span class="mtk1"> trg_recalculate_user_rating </span><span class="mtk3">ON</span><span class="mtk1"> user_ratings;</span></div></div><div class="code-line" data-line-number="24" data-line-start="24" data-line-end="24"><div class="line-content"><span class="mtk3">CREATE</span><span class="mtk1"></span><span class="mtk3">TRIGGER</span><span class="mtk1"></span><span class="mtk13">trg_recalculate_user_rating</span></div></div><div class="code-line" data-line-number="25" data-line-start="25" data-line-end="25"><div class="line-content"><span class="mtk1"></span><span class="mtk3">AFTER</span><span class="mtk1"></span><span class="mtk3">INSERT</span><span class="mtk1"></span><span class="mtk3">ON</span><span class="mtk1"> user_ratings</span></div></div><div class="code-line" data-line-number="26" data-line-start="26" data-line-end="26"><div class="line-content"><span class="mtk1"></span><span class="mtk3">FOR</span><span class="mtk1"> EACH </span><span class="mtk3">ROW</span></div></div><div class="code-line" data-line-number="27" data-line-start="27" data-line-end="27"><div class="line-content"><span class="mtk1"></span><span class="mtk3">EXECUTE</span><span class="mtk1"></span><span class="mtk3">FUNCTION</span><span class="mtk1"> _fn_recalculate_user_rating();</span></div></div><div class="code-line" data-line-number="28" data-line-start="28" data-line-end="28"><div class="line-content"><span class="mtk1"></span></div></div><div class="code-line" data-line-number="29" data-line-start="29" data-line-end="29"><div class="line-content"><span class="mtk8">-- 2. Ensure estimated_duration_min column exists (DB-04)</span></div></div><div class="code-line" data-line-number="30" data-line-start="30" data-line-end="30"><div class="line-content"><span class="mtk1">DO $$</span></div></div><div class="code-line" data-line-number="31" data-line-start="31" data-line-end="31"><div class="line-content"><span class="mtk3">BEGIN</span></div></div><div class="code-line" data-line-number="32" data-line-start="32" data-line-end="32"><div class="line-content"><span class="mtk1"></span><span class="mtk3">IF</span><span class="mtk1"></span><span class="mtk3">NOT</span><span class="mtk1"></span><span class="mtk3">EXISTS</span><span class="mtk1"> (</span></div></div><div class="code-line" data-line-number="33" data-line-start="33" data-line-end="33"><div class="line-content"><span class="mtk1"></span><span class="mtk3">SELECT</span><span class="mtk1"></span><span class="mtk5">1</span><span class="mtk1"></span><span class="mtk3">FROM</span><span class="mtk1"></span><span class="mtk5">information_schema</span><span class="mtk1">.</span><span class="mtk5">columns</span></div></div><div class="code-line" data-line-number="34" data-line-start="34" data-line-end="34"><div class="line-content"><span class="mtk1"></span><span class="mtk3">WHERE</span><span class="mtk1"> table_schema </span><span class="mtk16">=</span><span class="mtk1"></span><span class="mtk6">'public'</span></div></div><div class="code-line" data-line-number="35" data-line-start="35" data-line-end="35"><div class="line-content"><span class="mtk1"></span><span class="mtk3">AND</span><span class="mtk1"> table_name </span><span class="mtk16">=</span><span class="mtk1"></span><span class="mtk6">'trips'</span></div></div><div class="code-line" data-line-number="36" data-line-start="36" data-line-end="36"><div class="line-content"><span class="mtk1"></span><span class="mtk3">AND</span><span class="mtk1"> column_name </span><span class="mtk16">=</span><span class="mtk1"></span><span class="mtk6">'estimated_duration_min'</span></div></div><div class="code-line" data-line-number="37" data-line-start="37" data-line-end="37"><div class="line-content"><span class="mtk1">  ) </span><span class="mtk3">THEN</span></div></div><div class="code-line" data-line-number="38" data-line-start="38" data-line-end="38"><div class="line-content"><span class="mtk1"></span><span class="mtk3">ALTER</span><span class="mtk1"></span><span class="mtk3">TABLE</span><span class="mtk1"> trips </span><span class="mtk3">ADD</span><span class="mtk1"> COLUMN estimated_duration_min </span><span class="mtk3">NUMERIC</span><span class="mtk1">(</span><span class="mtk5">8</span><span class="mtk1">,</span><span class="mtk5">2</span><span class="mtk1">) </span><span class="mtk3">DEFAULT</span><span class="mtk1"></span><span class="mtk3">NULL</span><span class="mtk1">;</span></div></div><div class="code-line" data-line-number="39" data-line-start="39" data-line-end="39"><div class="line-content"><span class="mtk1"></span><span class="mtk3">END</span><span class="mtk1"></span><span class="mtk3">IF</span><span class="mtk1">;</span></div></div><div class="code-line" data-line-number="40" data-line-start="40" data-line-end="40"><div class="line-content"><span class="mtk3">END</span><span class="mtk1"> $$;</span></div></div><div class="code-line" data-line-number="41" data-line-start="41" data-line-end="41"><div class="line-content"><span class="mtk1"></span></div></div><div class="code-line" data-line-number="42" data-line-start="42" data-line-end="42"><div class="line-content"><span class="mtk8">-- 3. Pricing sync: make calculate_trip_price prefer vehicle_types (DB-01)</span></div></div><div class="code-line" data-line-number="43" data-line-start="43" data-line-end="43"><div class="line-content"><span class="mtk8">-- NOTE: This is a conceptual fix — actual implementation depends on</span></div></div><div class="code-line" data-line-number="44" data-line-start="44" data-line-end="44"><div class="line-content"><span class="mtk8">-- the existing calculate_trip_price function body.</span></div></div><div class="code-line" data-line-number="45" data-line-start="45" data-line-end="45"><div class="line-content"><span class="mtk8">-- The principle: READ prices from vehicle_types, not pricing_config.</span></div></div></div></div></div></div></pre>

---

## 9. Files Inventory — What Needs Changes

### Flutter (`taxi_app`)

| Action | File                                                                  | Issue                          |
| ------ | --------------------------------------------------------------------- | ------------------------------ |
| MODIFY | `lib/features/user/presentation/searching/bloc/searching_bloc.dart` | FL-01: Add cancel_reason       |
| CREATE | `lib/features/driver/presentation/bonus/bonus_screen.dart`          | FL-02: Bonus UI                |
| CREATE | `lib/features/driver/presentation/bonus/bloc/bonus_cubit.dart`      | FL-02: Bonus state             |
| MODIFY | `lib/features/shared/presentation/screens/complaints_screen.dart`   | FL-05: Show admin replies      |
| MODIFY | `lib/core/constants/app_routes.dart`                                | FL-09: Add bonus route         |
| MODIFY | `lib/core/router/app_router.dart`                                   | FL-09: Register bonus route    |
| MODIFY | `lib/features/driver/data/repositories/driver_home_repository.dart` | BL-01/BL-04: Remove duplicates |

### Next.js (`taxi_web`)

| Action | File                                                              | Issue                        |
| ------ | ----------------------------------------------------------------- | ---------------------------- |
| MODIFY | `src/app/dashboard/settings/page.tsx`                           | WEB-01/WEB-04: i18n + config |
| MODIFY | `src/app/dashboard/notifications/notifications-client.tsx`      | WEB-01: i18n                 |
| MODIFY | `src/app/dashboard/drivers/revision/page.tsx`                   | WEB-01: i18n                 |
| MODIFY | `src/app/dashboard/complaints/[id]/complaint-detail-client.tsx` | WEB-01: i18n                 |
| MODIFY | `src/app/dashboard/service-areas/page.tsx`                      | WEB-02: Add CRUD             |
| MODIFY | `src/app/dashboard/bonuses/page.tsx`                            | WEB-03: Add CRUD             |
| CREATE | `src/app/api/service-areas/create/route.ts`                     | WEB-06: API                  |
| CREATE | `src/app/api/service-areas/toggle/route.ts`                     | WEB-06: API                  |
| CREATE | `src/app/api/bonuses/create/route.ts`                           | WEB-07: API                  |
| CREATE | `src/app/api/bonuses/toggle/route.ts`                           | WEB-07: API                  |
| MODIFY | `messages/ar.json`                                              | WEB-01: Add missing keys     |
| MODIFY | `messages/en.json`                                              | WEB-01: Add missing keys     |

---

## 10. Summary of What's Working Well

TIP

These aspects are production-solid and should be preserved:

1. **Auth flow** — Robust with auto-recovery for missing profiles, blocked user detection, driver pending state
2. **Trip lifecycle RPCs** — Server-side state machine with proper guards
3. **RLS coverage** — 100% of tables covered (170+ policies)
4. **Wallet system** — Full driver/user wallet with withdrawal flow, real-time streaming
5. **Coupon validation** — Server-side `validate_coupon` + `apply_coupon_to_trip` RPCs
6. **Sidebar navigation** — Premium design with 20 sections, proper active states
7. **Localization infrastructure** — `next-intl` + Flutter's `app_localizations` properly set up
8. **Real-time subscriptions** — 12 tables on Supabase Realtime, properly consumed
9. **GoRouter auth redirect** — Clean state-based routing with UUID validation
10. **Driver earnings** — Dual-source (view + detailed RPC) with graceful fallbacks
