import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'bloc/trips_bloc.dart';
import 'bloc/trips_state.dart';
import 'bloc/trips_event.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/app_toast.dart';
import 'package:shimmer/shimmer.dart';

// ── Shared widgets (Phase 3 refactor) ────────────────────────────────────────
import '../../../trips/presentation/widgets/trip_widgets.dart';

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
              AppToast.success(
                  ErrorMapper.getErrorMessage(context, state.message));
              context.read<TripsBloc>().add(const LoadUserTrips());
            } else if (state is TripsError) {
              AppToast.error(
                  ErrorMapper.getErrorMessage(context, state.message));
            }
          },
          builder: (context, state) {
            if (state is TripsLoading) {
              return _buildLoadingState();
            }

            if (state is TripsLoaded) {
              final allTrips = state.trips;
              final inProgress = allTrips
                  .where((t) => AppConstants.activeTripStatuses
                      .contains(t.status.toDbString()))
                  .toList();
              final completed = allTrips
                  .where((t) => t.status.toDbString() == 'completed')
                  .toList();
              final cancelled = allTrips
                  .where((t) => t.status.toDbString() == 'cancelled')
                  .toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SharedTripsHeader(
                      total: allTrips.length,
                      completed: completed.length,
                      cancelled: cancelled.length,
                      onBack: () => context.pop(),
                      onNewTrip: () => context.push(AppRoutes.userHome),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SharedSegmentedControl(
                      selectedIndex: _selectedIndex,
                      onIndexChanged: (index) {
                        _tabController.animateTo(index);
                      },
                      inProgressCount: inProgress.length,
                      completedCount: completed.length,
                      cancelledCount: cancelled.length,
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        SharedTripListView(
                          trips: inProgress,
                          isActive: true,
                          detailsRoute: AppRoutes.userTripDetails,
                        ),
                        SharedTripListView(
                          trips: completed,
                          detailsRoute: AppRoutes.userTripDetails,
                        ),
                        SharedTripListView(
                          trips: cancelled,
                          detailsRoute: AppRoutes.userTripDetails,
                        ),
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
          GestureDetector(
            onTap: () =>
                context.read<TripsBloc>().add(const LoadUserTrips()),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.refresh_rounded,
                    color: AppColors.white, size: 17),
                const SizedBox(width: 8),
                Text(l.retry,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
