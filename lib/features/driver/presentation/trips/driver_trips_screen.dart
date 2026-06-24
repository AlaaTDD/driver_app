import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'bloc/driver_trips_bloc.dart';
import 'bloc/driver_trips_state.dart';
import 'bloc/driver_trips_event.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/utils/trip_status.dart';
import '../../../../core/utils/app_toast.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

// ── Shared widgets (Phase 3 refactor) ────────────────────────────────────────
import '../../../trips/presentation/widgets/trip_widgets.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen>
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
    context.read<DriverTripsBloc>().add(const LoadDriverTrips());
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
        child: BlocConsumer<DriverTripsBloc, DriverTripsState>(
          listener: (context, state) {
            if (state is DriverTripsError) {
              AppToast.error(state.message);
            }
          },
          builder: (context, state) {
            if (state is DriverTripsLoading) {
              return _buildLoadingState();
            }

            if (state is DriverTripsLoaded) {
              final allTrips = state.trips;
              final inProgress = allTrips
                  .where((t) =>
                      t.status == TripStatus.scheduled ||
                      t.status == TripStatus.searching ||
                      t.status == TripStatus.accepted ||
                      t.status == TripStatus.driverArriving ||
                      t.status == TripStatus.inProgress)
                  .toList();
              final completed = allTrips
                  .where((t) => t.status == TripStatus.completed)
                  .toList();
              final cancelled = allTrips
                  .where((t) => t.status == TripStatus.cancelled)
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
                      // Driver doesn't create trips, so no onNewTrip
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
                          detailsRoute: AppRoutes.driverTripDetails,
                        ),
                        SharedTripListView(
                          trips: completed,
                          detailsRoute: AppRoutes.driverTripDetails,
                        ),
                        SharedTripListView(
                          trips: cancelled,
                          detailsRoute: AppRoutes.driverTripDetails,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            if (state is DriverTripsError) {
              return _buildErrorState(state.message, l);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final card = context.cardColor;
    final elevated = context.elevatedColor;
    return Shimmer.fromColors(
      baseColor: card,
      highlightColor: elevated,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 180,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
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
                  color: card,
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
    const rose = AppColors.error;
    const blue = AppColors.primary;
    final t2 = context.textSecondary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: rose.withValues(alpha: 0.3)),
              color: rose.withValues(alpha: 0.08),
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 40, color: rose),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(color: t2, fontSize: 14, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () =>
                context.read<DriverTripsBloc>().add(const LoadDriverTrips()),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [blue, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: blue.withValues(alpha: 0.3),
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
