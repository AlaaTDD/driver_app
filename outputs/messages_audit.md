# Messages — Audit Report

---

## 1. What Is This Feature?

The **Messaging** feature provides **real-time chat** between users and drivers within the taxi_app. It supports two modes:

1. **Trip chat** — scoped to a specific `trip_id`; both parties can message while the trip is active.
2. **Direct chat** — user↔driver messaging without a trip context (gated by an active-trip guard).

Additionally, it includes a **Conversations list** (inbox) that aggregates all chats per counterpart with unread counts, last-message preview, and online status. The feature serves **both user and driver roles** identically via shared code.

---

## 2. File Map

| File | Layer | Role |
|------|-------|------|
| `conversations_screen.dart` | UI | Inbox / conversations list with search, shimmer loading, empty state, unread badges |
| `messages_screen.dart` | UI | 1-on-1 chat screen with bubbles, image sending, typing indicator, read receipts, pagination |
| `messages_cubit.dart` | State | Cubit managing conversations + chat states, subscriptions, presence, image upload |
| `messages_state.dart` | State | 5 states: MessagesInitial, ConversationsLoading, ConversationsLoaded, MessagesChatLoaded, MessagesError, MessagesSending |
| `messages_repository.dart` | Data | All Supabase queries, realtime subscriptions, FCM push, presence, file upload (761 lines) |
| `message_model.dart` | Data/Model | Equatable model with fromJson/toInsertJson, maps all 12 DB columns |
| `presence_service.dart` | Service | Supabase Presence channel tracking with heartbeat timer |
| `app_constants.dart` | Config | Table names, bucket name, message types, active trip statuses |
| `app_router.dart` | Routing | userMessages (L211) and driverMessages (L336) routes → ConversationsScreen |

> ⚠️ **Legacy/BAK files:** None found — clean.

> ⚠️ **ANTI_PATTERN detected:** `data/messages_repository.dart` lives inside `features/shared/presentation/messages/data/` — a **data layer inside the presentation folder**. This is a structural anti-pattern.

---

## 3. Data Flow

### Read — Conversations List
```
[User opens Conversations tab]
  → MessagesCubit.loadConversations()
    → MessagesRepository.loadConversations()
      → Supabase RPC: get_user_conversations(p_user_id)
        ← TABLE(other_user_id, other_user_name, other_user_avatar, other_user_role,
                 last_message, last_message_at, is_me_sender, is_read, unread_count)
      ← Fallback: SELECT messages + JOIN users (if RPC fails)
    ← List<Map>
  → emit(ConversationsLoaded(data))
  → _subscribeToConversationsRealtime()  // watchConversations() channel
  → _subscribeToPayloads()              // watchConversationPayloads() channel
```

### Read — Chat Messages
```
[User taps a conversation]
  → MessagesCubit.initDirectChat(otherUserId)
    → MessagesRepository.hasActiveTripWith()  // checks canSend guard
    → MessagesRepository.fetchUserInfo()      // name + avatar
    → MessagesRepository.loadDirectMessages() // SELECT * FROM messages, paginated
    ← List<MessageModel>
  → emit(MessagesChatLoaded(messages, otherName, canSend, ...))
  → _subscribeToDirectMessages()  // realtime channel
```

### Write — Send Message
```
[User taps send]
  → MessagesCubit.sendMessage(text, otherUserId, tripId)
    → emit(MessagesSending([optimistic, ...messages]))  // optimistic update
    → MessagesRepository.sendDirectMessage() OR sendTripMessageWithNotification()
      → INSERT INTO messages {sender_id, receiver_id, content, trip_id, type, attachment_url}
      → Edge Function: send-fcm {user_id, title, body, data}
    → Reload messages from DB
  → emit(MessagesChatLoaded(freshMessages))
```

### Realtime — Message Subscription
```
[Supabase Realtime]
  → channel('direct-messages-$userId-$otherUserId')
    .onPostgresChanges(table: 'messages', event: ALL)
      → INSERT: add to cached list, re-sort, emit
      → UPDATE: update is_read in cache, emit
      → DELETE: remove from cache, emit
```

---

## 4. Database Mapping

### `messages` table — 12 columns (verified against CSV)

| DB Column (CSV) | Position | Type | Nullable | Model Field | Used In Code |
|-----------------|----------|------|----------|-------------|--------------|
| `id` | 1 | uuid | NO | `id` | ✅ PK, gen_random_uuid() |
| `sender_id` | 2 | uuid | NO | `senderId` | ✅ FK → users.id (SET NULL) |
| `receiver_id` | 3 | uuid | NO | `receiverId` | ✅ FK → users.id (SET NULL) |
| `trip_id` | 4 | uuid | YES | `tripId` | ✅ FK → trips.id (SET NULL) |
| `content` | 5 | text | NO | `content` | ✅ |
| `is_read` | 6 | bool | YES | `isRead` | ✅ default false |
| `created_at` | 7 | timestamptz | YES | `createdAt` | ✅ default now() |
| `read_at` | 8 | timestamptz | YES | `readAt` | ✅ |
| `deleted_by_sender` | 9 | bool | YES | — (queried, not in model) | ✅ soft-delete filter |
| `deleted_by_receiver` | 10 | bool | YES | — (queried, not in model) | ✅ soft-delete filter |
| `type` | 11 | text | NO | `type` | ✅ CHECK: text/image/location/voice |
| `attachment_url` | 12 | text | YES | `attachmentUrl` | ✅ |

### RPC Functions

| RPC | Args | Returns | Verified in CSV |
|-----|------|---------|-----------------|
| `get_user_conversations` | `p_user_id uuid` | TABLE(other_user_id, other_user_name, other_user_avatar, other_user_role, last_message, last_message_at, is_me_sender, is_read, unread_count) | ✅ Line 644, SECURITY DEFINER |
| `get_unread_message_count` | `p_user_id uuid` | TABLE(other_user_id, unread_count) | ✅ Line 643, SECURITY DEFINER |

### Edge Functions

| Function | Purpose |
|----------|---------|
| `send-fcm` | Push notification via FCM when message is sent |

### RLS Policies on `messages` (6 policies)

| Policy | Command | Expression |
|--------|---------|------------|
| Users can read their messages | SELECT | `auth.uid() = sender_id OR receiver_id` + trip participant check + admin check |
| Users can send messages | INSERT | `auth.uid() = sender_id` + requires active trip for direct (NULL trip_id) messages |
| Users can send trip messages | INSERT | Requires trip participant |
| Users can mark messages as read | UPDATE | `auth.uid() = receiver_id` |
| Admins can read all messages | SELECT | `is_admin_user()` |
| Admins can delete messages | DELETE | `is_admin_user()` |

### RLS Policies on `support_messages` (4 policies)

| Policy | Command |
|--------|---------|
| Users can read own messages | SELECT |
| Users can send support messages | INSERT |
| Admins can read all messages | SELECT |
| Admins can delete messages | DELETE |

> **Known schema issues:** Duplicate CSV rows for every `messages` column (appears twice each). RPC functions have `anon` EXECUTE privilege — should be restricted to `authenticated` only.

---

## 5. State & Realtime

### States

| State | Fields | Emitted By |
|-------|--------|------------|
| `MessagesInitial` | — | Constructor |
| `ConversationsLoading` | — | `loadConversations()` |
| `ConversationsLoaded` | `conversations`, `onlineMap` | After RPC/fallback load |
| `MessagesChatLoaded` | `messages`, `otherName`, `otherAvatarUrl`, `otherUserId`, `tripId`, `isOtherOnline`, `isOtherTyping`, `canSend`, `hasMore` | Chat init, realtime updates, send |
| `MessagesSending` | `currentMessages` (with optimistic msg) | During send |
| `MessagesError` | `message` (error key) | On failure |

### Realtime Subscriptions (4 channels)

| Channel Name | Table | Events | Purpose |
|--------------|-------|--------|---------|
| `direct-messages-$userId-$otherUserId` | messages | ALL | Live chat updates (direct) |
| `trip-messages-$tripId` | messages | ALL | Live chat updates (trip) |
| `conversations-$userId` | messages | ALL | Conversations list auto-refresh |
| `unread-messages-$userId` | messages | ALL | Unread badge count updates |

### Presence

- `PresenceService` tracks typing status via Supabase Presence channels
- `MessagesRepository.ensureMyPresence()` upserts `user_presence` table every heartbeat
- `onPresenceSync()` wired in repository but **never consumed by the Cubit/UI** for online/typing status

### FCM

- `_sendFcmPush()` invokes Edge Function `send-fcm` on every message send
- Notification data includes `type: 'new_message'`, `senderId`, `senderName`, `screen: 'messages'`

---

## 6. Issues Found

| # | Code | File:Line | Description | Severity |
|---|------|-----------|-------------|----------|
| 1 | `ANTI_PATTERN` | `messages_repository.dart` (entire file) | Data layer (`data/messages_repository.dart`) lives inside `presentation/messages/data/` — should be at `features/shared/data/` or `features/messages/data/` | 🟡 |
| 2 | `DI_BYPASS` | `messages_cubit.dart:13` | `final MessagesRepository _repo = MessagesRepository();` — repository instantiated directly, not injected. Same at L14 for `PresenceService`. Prevents testing and overrides. | 🟡 |
| 3 | `DI_BYPASS` | `presence_service.dart:7` | `final MessagesRepository _repo = MessagesRepository();` — circular dependency smell: Service depends on Repository which is under `presentation/`. | 🟡 |
| 4 | `STREAM_LEAK` | `messages_repository.dart:730-758` | `watchConversationPayloads()` uses channel name `'conversations-$userId'` — **same name** as `watchConversations()` at L703. Supabase will reuse the channel, potentially causing one subscription to silently fail or override the other. | 🔴 |
| 5 | `BROKEN_FLOW` | `messages_cubit.dart:61-68` | `_subscribeToPayloads()` subscribes to `watchConversationPayloads()` but the callback body is **empty** (`// Handle optimistic update...`). The subscription consumes a realtime channel but does nothing. | 🟡 |
| 6 | `BROKEN_FLOW` | `messages_cubit.dart:376-384` | `startPresence()` and `updateTyping()` are called but the result (`isOtherOnline`, `isOtherTyping`) is **never written back to state**. `MessagesChatLoaded.isOtherOnline` and `isOtherTyping` are always `false`. The presence data from `onPresenceSync()` is never consumed. | 🔴 |
| 7 | `HARDCODED` | `messages_screen.dart:156` | `'تم القراءة'`, `'تم الإرسال'` — hardcoded Arabic strings. Should use `AppLocalizations`. | 🟡 |
| 8 | `HARDCODED` | `messages_screen.dart:410-422` | `'يكتب الآن...'`, `'متصل الآن'`, `'غير متصل'` — hardcoded Arabic. Should use localization. | 🟡 |
| 9 | `HARDCODED` | `messages_screen.dart:264` | `'📷 صورة'` in sendImage. Hardcoded Arabic text for image message content. | 🟢 |
| 10 | `HARDCODED` | `conversations_screen.dart:130-131` | `'بحث في المحادثات...'` — hardcoded Arabic search placeholder. | 🟡 |
| 11 | `HARDCODED` | `messages_cubit.dart:213` | `'رسالة من $name'` — hardcoded Arabic notification title inside Cubit. Should be localized. | 🟡 |
| 12 | `SCHEMA_MISMATCH` | `app_constants.dart:25-31` | `activeTripStatuses` includes `'pending'` but DB CHECK constraint on `trips.status` has `'searching'` not `'pending'`. The app uses `'pending'` which doesn't exist in the DB enum. The RLS INSERT policy for direct messages uses the same statuses — if the actual status is `'searching'`, the `hasActiveTripWith()` guard will never match, and the RLS policy will also block. | 🔴 |
| 13 | `MISSING_RLS` | `messages_repository.dart:494-506` | `deleteMessage()` performs UPDATE (`deleted_by_sender` or `deleted_by_receiver`) but the RLS UPDATE policy only allows `auth.uid() = receiver_id`. A **sender** trying to soft-delete their own message will be **blocked by RLS** — the update policy doesn't cover sender-side updates for `deleted_by_sender`. | 🔴 |
| 14 | `MISSING_RLS` | CSV Lines 842-843 | `get_user_conversations` and `get_unread_message_count` RPC functions grant EXECUTE to `anon` role. Unauthenticated callers can potentially query conversations of any user by passing arbitrary UUID. Both are `SECURITY DEFINER`. | 🔴 |
| 15 | `HARDCODED` | `conversations_screen.dart:282-291` | `'لا توجد نتائج'`, `'جرب البحث بكلمات أخرى'` — hardcoded Arabic. | 🟡 |
| 16 | `HARDCODED` | `conversations_screen.dart:498` | Day names array `['الإثنين', ...]` hardcoded instead of using `intl` or `AppLocalizations`. Same pattern in `messages_screen.dart:745`. | 🟢 |
| 17 | `NULL_CRASH` | `messages_repository.dart:545-546` | `tripData['user_id'] as String? ?? ''` — if the FK was SET NULL (user deleted), this returns `''` which is passed to the receiver. The `_resolveReceiverId` returns `null` if empty, but silently fails the send with no user feedback. | 🟢 |

---

## 7. Canonical Summary

- **Identity:** Messages (Trip Chat + Direct Messaging + Conversations Inbox)
- **Core job:** Real-time 1-on-1 chat between user and driver, scoped by trip or direct, with read receipts, image attachments, typing indicators (broken), and FCM push notifications.
- **Primary tables:** `messages`, `user_presence`, `users`, `trips`
- **RPCs:** `get_user_conversations`, `get_unread_message_count`
- **Edge Functions:** `send-fcm`
- **State manager:** `MessagesCubit` (Cubit, not Bloc)
- **Health:** 🟡 **Needs Work**

### Critical Issues Summary

| Priority | Count | Key Items |
|----------|-------|-----------|
| 🔴 Critical | 5 | Channel name collision (#4), Presence never wired to UI (#6), `activeTripStatuses` mismatch with DB (#12), Sender soft-delete blocked by RLS (#13), RPC anon access (#14) |
| 🟡 Moderate | 8 | Anti-pattern folder structure (#1), DI bypass ×2 (#2,#3), Empty payload handler (#5), Hardcoded Arabic ×4 (#7,#8,#10,#11,#15) |
| 🟢 Low | 3 | Minor hardcoded strings (#9,#16), Silent fail on deleted user (#17) |

### Recommendations (Priority Order)

1. **Fix channel name collision** — `watchConversations()` and `watchConversationPayloads()` must use distinct channel names (e.g., `conversations-updates-$userId` vs `conversations-payloads-$userId`)
2. **Wire presence to UI** — The `isOtherOnline`/`isOtherTyping` fields exist in state but are never updated. Connect `onPresenceSync` callbacks to emit updated states.
3. **Fix `activeTripStatuses`** — Replace `'pending'` with `'searching'` to match the DB CHECK constraint, or update the RLS policy to also include `'searching'`.
4. **Add RLS UPDATE policy for sender** — Allow `auth.uid() = sender_id` to update `deleted_by_sender` column.
5. **Revoke `anon` EXECUTE** on `get_user_conversations` and `get_unread_message_count` RPCs.
6. **Move `data/` out of `presentation/`** — Relocate `messages_repository.dart` to proper data layer.
7. **Inject dependencies** — Pass `MessagesRepository` and `PresenceService` via constructor for testability.
8. **Localize all hardcoded Arabic strings** — Add keys to `app_en.arb` and `app_ar.arb`.
