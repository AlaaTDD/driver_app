// lib/features/user/presentation/trips/trips_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'bloc/trips_bloc.dart';
import 'bloc/trips_state.dart';
import 'bloc/trips_event.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/error/error_mapper.dart';
import 'package:shimmer/shimmer.dart';
import 'widgets/trips_header.dart';
import 'widgets/segmented_control.dart';
import 'widgets/trip_list_view.dart';

class UserTripsScreen extends StatefulWidget {
  const UserTripsScreen({super.key});

  @override
  State<UserTripsScreen> createState() => _UserTripsScreenState();
}

class _UserTripsScreenState extends State<UserTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedIndex) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });
    context.read<TripsBloc>().add(const LoadUserTrips());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        top: true,
        child: BlocConsumer<TripsBloc, TripsState>(
        listener: (context, state) {
          if (state is TripActionSuccess) {
            _showToast(ErrorMapper.getErrorMessage(context, state.message), AppColors.success);
            context.read<TripsBloc>().add(const LoadUserTrips());
          } else if (state is TripsError) {
            _showToast(ErrorMapper.getErrorMessage(context, state.message), AppColors.error);
          }
        },
        builder: (context, state) {
          if (state is TripsLoading) {
            return _buildLoadingState();
          }

          if (state is TripsLoaded) {
            final allTrips = state.trips;
            final inProgress = allTrips
                .where((t) =>
                    t['status'] == 'searching' ||
                    t['status'] == 'accepted' ||
                    t['status'] == 'in_progress')
                .toList();
            final completed =
                allTrips.where((t) => t['status'] == 'completed').toList();
            final cancelled =
                allTrips.where((t) => t['status'] == 'cancelled').toList();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Modern Header with Stats
                SliverToBoxAdapter(
                  child: TripsHeader(
                    total: allTrips.length,
                    completed: completed.length,
                    cancelled: cancelled.length,
                    onBack: () => context.pop(),
                    onNewTrip: () => context.push(AppRoutes.userHome),
                  ),
                ),
                // Custom Segmented Control
                SliverToBoxAdapter(
                  child: SegmentedControl(
                    selectedIndex: _selectedIndex,
                    onIndexChanged: (index) {
                      _tabController.animateTo(index);
                    },
                    inProgressCount: inProgress.length,
                    completedCount: completed.length,
                    cancelledCount: cancelled.length,
                  ),
                ),
                // Tab Content
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      TripListView(trips: inProgress, isActive: true),
                      TripListView(trips: completed),
                      TripListView(trips: cancelled),
                    ],
                  ),
                ),
              ],
            );
          }

          if (state is TripsError) {
            return _buildErrorState(state.message, l);
          }

          return const SizedBox.shrink();
        },
      ),
      ),
    );
  }

  void _showToast(String message, Color color) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(message: message, color: color),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: context.cardColor,
      highlightColor: context.elevatedColor,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 180,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Container(
                height: 140,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              childCount: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, AppLocalizations l) {
    return Center(
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
                size: 64, color: AppColors.error),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(color: context.textPrimary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _GradientButton(
            onPressed: () =>
                context.read<TripsBloc>().add(const LoadUserTrips()),
            icon: Icons.refresh,
            label: l.retry,
          ),
        ],
      ),
    );
  }
}

// ========== Modern UI Components ==========

class _ToastWidget extends StatelessWidget {
  final String message;
  final Color color;

  const _ToastWidget({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, -20 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _GradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
