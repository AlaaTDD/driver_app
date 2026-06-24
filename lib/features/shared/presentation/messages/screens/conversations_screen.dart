import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/constants/app_routes.dart';
import '../../../../../core/models/conversation_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/localization/generated/app_localizations.dart';
import '../screens/messages_screen.dart';
import '../bloc/messages_cubit.dart';
import '../bloc/messages_state.dart';
import 'package:shimmer/shimmer.dart';
import 'package:snapix/core/widgets/app_button.dart';
import 'package:snapix/core/utils/app_logger.dart';

class ConversationsScreen extends StatelessWidget {
  final String? tripId;
  final String? otherUserId;

  const ConversationsScreen({super.key, this.tripId, this.otherUserId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MessagesCubit()..loadConversations(),
      child: _ConversationsView(tripId: tripId, otherUserId: otherUserId),
    );
  }
}

class _ConversationsView extends StatefulWidget {
  final String? tripId;
  final String? otherUserId;

  const _ConversationsView({this.tripId, this.otherUserId});

  @override
  State<_ConversationsView> createState() => _ConversationsViewState();
}

class _ConversationsViewState extends State<_ConversationsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<ConversationModel> _filterConversations(
      List<ConversationModel> conversations) {
    if (_searchQuery.isEmpty) return conversations;
    return conversations.where((conv) {
      final name = conv.otherUserName.toLowerCase();
      final lastMsg = conv.lastMessage.toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          lastMsg.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: _buildAppBar(context, l),
      body: Column(
        children: [
          _buildSearchBar(context, l),
          Expanded(
            child: BlocBuilder<MessagesCubit, MessagesState>(
              builder: (context, state) {
                if (state is ConversationsLoading) {
                  return _buildShimmerList();
                }
                if (state is MessagesError) {
                  return _buildError(context, l, state.message);
                }
                if (state is ConversationsLoaded) {
                  final filtered = _filterConversations(state.conversations);
                  if (filtered.isEmpty && _searchQuery.isEmpty) {
                    return _buildEmpty(context, l);
                  }
                  if (filtered.isEmpty && _searchQuery.isNotEmpty) {
                    return _buildNoSearchResults(context, l);
                  }
                  return _buildConversationsList(context, l, filtered, state);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppLocalizations l) {
    return AppBar(
      backgroundColor: context.bgColor.withValues(alpha: 0.9),
      elevation: 0,
      centerTitle: true,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: AppColors.transparent),
        ),
      ),
      title: Text(
        l.messages,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      iconTheme: IconThemeData(color: context.textPrimary),
      actions: [
        IconButton(
          tooltip: l.supportAssistant,
          icon: const Icon(Icons.smart_toy_outlined),
          onPressed: () {
            final path = GoRouterState.of(context).uri.path;
            context.push(path.startsWith('/driver')
                ? AppRoutes.driverChatbot
                : AppRoutes.userChatbot);
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.elevatedColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: TextStyle(color: context.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchMessages,
            hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.search_rounded,
                  color: AppColors.primary, size: 24),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: context.textSecondary, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList(
    BuildContext context,
    AppLocalizations l,
    List<ConversationModel> conversations,
    ConversationsLoaded state,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<MessagesCubit>().loadConversations();
      },
      color: AppColors.primary,
      backgroundColor: context.elevatedColor,
      strokeWidth: 2.5,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conv = conversations[index];
          final isMeSender = conv.isMeSender;
          final convIsRead = isMeSender ? true : conv.isRead;
          final otherId = conv.otherUserId;
          final lastTime = conv.lastMessageAt;
          final unreadCount = conv.unreadCount;

          return _ConversationTile(
            key: ValueKey('conv_$otherId'),
            name: conv.otherUserName,
            lastMessage: conv.lastMessage,
            lastTime: lastTime,
            role: conv.otherUserRole,
            avatarUrl: conv.otherUserAvatar,
            isRead: convIsRead,
            isMeSender: isMeSender,
            unreadCount: unreadCount,
            isOnline: state.onlineMap[otherId] ?? false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MessagesScreen(
                    otherUserId: otherId,
                    otherUserName: conv.otherUserName,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 20,
      separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 86,
          color: context.divColor.withValues(alpha: 0.3)),
      itemBuilder: (_, __) => const _ShimmerTile(),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            l.noMessages,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              l.startChat,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults(BuildContext context, AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: context.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noResults,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.tryDifferentKeywords,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations l, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  size: 44, color: AppColors.error),
            ),
            const SizedBox(height: 24),
            Text(
              l.failedLoadMessages,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              text: l.retry,
              onPressed: () {
                context.read<MessagesCubit>().loadConversations();
              },
              leadingIcon: Icons.refresh_rounded,
              size: AppButtonSize.md,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  const _ShimmerTile();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.grey[800]! : AppColors.grey[300]!;
    final highlightColor = isDark ? AppColors.grey[700]! : AppColors.grey[100]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Container(
                    width: 180,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String? lastTime;
  final String role;
  final String? avatarUrl;
  final bool isRead;
  final bool isMeSender;
  final int unreadCount;
  final bool isOnline;
  final VoidCallback onTap;

  const _ConversationTile({
    super.key,
    required this.name,
    required this.lastMessage,
    this.lastTime,
    required this.role,
    this.avatarUrl,
    required this.isRead,
    required this.isMeSender,
    this.unreadCount = 0,
    this.isOnline = false,
    required this.onTap,
  });

  String _formatTime(String? iso, BuildContext context) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDate = DateTime(dt.year, dt.month, dt.day);
      if (msgDate == today) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (msgDate == yesterday) return AppLocalizations.of(context)!.yesterday;
      if (now.difference(msgDate).inDays < 7) {
        final locale = Localizations.localeOf(context).languageCode;
        return intl.DateFormat.EEEE(locale).format(msgDate);
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e, st) {
      AppLogger.debug(
          '⚠️ ConversationsScreen: invalid last message time "$iso": $e\n$st');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = isMeSender
        ? '${AppLocalizations.of(context)!.youPrefix}$lastMessage'
        : lastMessage;
    final hasUnread = !isRead || unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: context.divColor.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildAvatar(context),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (lastTime != null)
                            Text(
                              _formatTime(lastTime, context),
                              style: TextStyle(
                                color: hasUnread
                                    ? AppColors.primary
                                    : context.textSecondary,
                                fontSize: 12,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (isMeSender && isRead) ...[
                            const Icon(
                              Icons.done_all_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                          ] else if (isMeSender) ...[
                            Icon(
                              Icons.done_rounded,
                              size: 16,
                              color: context.textSecondary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: hasUnread
                                    ? context.textPrimary
                                    : context.textSecondary,
                                fontSize: 14,
                                height: 1.3,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            _buildUnreadBadge(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.2),
                AppColors.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            image: avatarUrl != null && avatarUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(avatarUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl == null || avatarUrl!.isEmpty
              ? Icon(
                  role == 'driver'
                      ? Icons.drive_eta_rounded
                      : Icons.person_rounded,
                  color: AppColors.primary,
                  size: 28,
                )
              : null,
        ),
        if (isOnline)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: context.bgColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUnreadBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        unreadCount > 99 ? '99+' : '$unreadCount',
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
