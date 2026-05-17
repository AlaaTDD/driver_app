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
import '../../../trips/data/models/trip_model.dart';
import 'package:snapix/core/theme/app_colors.dart';

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
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: true,
        child: BlocConsumer<DriverTripsBloc, DriverTripsState>(
          listener: (context, state) {
            if (state is DriverTripsError) {
              _showToast(state.message, AppColors.error);
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
                      t.status == TripStatus.searching ||
                      t.status == TripStatus.accepted ||
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
                    child: _TripsHeader(
                      total: allTrips.length,
                      completed: completed.length,
                      cancelled: cancelled.length,
                      onBack: () => context.pop(),
                      onNewTrip: () => context.push(AppRoutes.driverHome),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _SegmentedControl(
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
                        _TripListView(trips: inProgress, isActive: true),
                        _TripListView(trips: completed),
                        _TripListView(trips: cancelled),
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

  void _showToast(String message, Color color) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(message: message, color: color),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }

  Widget _buildLoadingState() {
    const card = AppColors.surface;
    const elevated = AppColors.surfaceElevated;
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
    const t1 = AppColors.textPrimary;
    const t2 = AppColors.textSecondary;
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
            style: const TextStyle(color: t2, fontSize: 14, height: 1.6),
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
        color: AppColors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, -20 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    const Icon(Icons.check_circle,
                        color: AppColors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: AppColors.white,
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

class _TripsHeader extends StatelessWidget {
  final int total;
  final int completed;
  final int cancelled;
  final VoidCallback onBack;
  final VoidCallback onNewTrip;

  const _TripsHeader({
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.onBack,
    required this.onNewTrip,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const card = AppColors.surface;
    const elevated = AppColors.surfaceElevated;
    const border = AppColors.divider;
    const blue = AppColors.primary;
    const emerald = AppColors.secondary;
    const rose = AppColors.error;
    const t1 = AppColors.textPrimary;
    const t2 = AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: blue.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
              color: blue.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: AppColors.black.withValues(alpha: 0.38), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: elevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 1),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: t1, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(l.myTrips,
                      style: const TextStyle(
                          color: t1,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2)),
                  const SizedBox(height: 2),
                  Text(l.totalTripsLabel(total),
                      style: const TextStyle(
                          color: t2, fontSize: 12, height: 1.2)),
                ])),
            GestureDetector(
              onTap: onNewTrip,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [blue, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: blue.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_taxi_rounded,
                      color: AppColors.white, size: 15),
                  const SizedBox(width: 5),
                  Text(l.startWorking,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Container(height: 1, color: border),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _CompactStat(
              icon: Icons.check_circle_rounded,
              value: completed.toString(),
              label: l.completed,
              color: emerald,
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _CompactStat(
              icon: Icons.cancel_rounded,
              value: cancelled.toString(),
              label: l.cancelled,
              color: rose,
            )),
          ]),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _CompactStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const elevated = AppColors.surfaceElevated;
    const t1 = AppColors.textPrimary;
    const t2 = AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  color: t1,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.2)),
          Text(label,
              style: const TextStyle(color: t2, fontSize: 11, height: 1.2)),
        ])),
      ]),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final int inProgressCount;
  final int completedCount;
  final int cancelledCount;

  const _SegmentedControl({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.inProgressCount,
    required this.completedCount,
    required this.cancelledCount,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const elevated = AppColors.surfaceElevated;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: elevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _SegmentButton(
              icon: Icons.pending_actions_rounded,
              label: l.inProgress,
              count: inProgressCount,
              isSelected: selectedIndex == 0,
              onTap: () => onIndexChanged(0),
            ),
            _SegmentButton(
              icon: Icons.check_circle_rounded,
              label: l.completed,
              count: completedCount,
              isSelected: selectedIndex == 1,
              onTap: () => onIndexChanged(1),
            ),
            _SegmentButton(
              icon: Icons.cancel_rounded,
              label: l.cancelled,
              count: cancelledCount,
              isSelected: selectedIndex == 2,
              onTap: () => onIndexChanged(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const blue = AppColors.primary;
    const card = AppColors.surface;
    const t2 = AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [blue, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : AppColors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: blue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.white : t2),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.white : t2,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.white.withValues(alpha: 0.2)
                        : card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? AppColors.white : t2,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TripListView extends StatelessWidget {
  final List<TripModel> trips;
  final bool isActive;

  const _TripListView({required this.trips, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return _EmptyState(isActive: isActive);
    }

    final grouped = _groupTripsByDate(context, trips);

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DriverTripsBloc>().add(const LoadDriverTrips());
      },
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped.entries.elementAt(index);
          return _TripDateSection(
            dateLabel: entry.key,
            trips: entry.value,
            isActive: isActive,
          );
        },
      ),
    );
  }

  Map<String, List<TripModel>> _groupTripsByDate(
      BuildContext context, List<TripModel> trips) {
    final grouped = <String, List<TripModel>>{};
    final now = DateTime.now();

    for (final trip in trips) {
      final createdAt = trip.createdAt;

      final date = createdAt;
      String label;

      if (_isSameDay(date, now)) {
        label = AppLocalizations.of(context)!.today;
      } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
        label = AppLocalizations.of(context)!.yesterday;
      } else if (now.difference(date).inDays < 7) {
        label = AppLocalizations.of(context)!.thisWeek;
      } else {
        label = '${date.day}/${date.month}/${date.year}';
      }

      grouped.putIfAbsent(label, () => []).add(trip);
    }

    return grouped;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _EmptyState extends StatelessWidget {
  final bool isActive;
  const _EmptyState({this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const blue = AppColors.primary;
    const t1 = AppColors.textPrimary;
    const t2 = AppColors.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: blue.withValues(alpha: 0.2)),
            ),
            child: Icon(
              isActive ? Icons.local_taxi_rounded : Icons.route_rounded,
              size: 56,
              color: blue.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.noTrips,
            style: const TextStyle(
                color: t1, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            isActive
                ? AppLocalizations.of(context)!.noActiveTrips
                : AppLocalizations.of(context)!.tripsWillAppearHere,
            style: const TextStyle(color: t2, fontSize: 14),
          ),
          if (isActive) ...[
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_back_rounded,
                      color: AppColors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.backToHome,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripDateSection extends StatelessWidget {
  final String dateLabel;
  final List<TripModel> trips;
  final bool isActive;

  const _TripDateSection({
    required this.dateLabel,
    required this.trips,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    const t2 = AppColors.textSecondary;
    const blue = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(children: [
            Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                    color: blue, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t2,
                letterSpacing: 0.5,
              ),
            ),
          ]),
        ),
        ...trips.asMap().entries.map((entry) {
          return _AnimatedTripCard(
            trip: entry.value,
            isActive: isActive,
            delay: entry.key * 50,
          );
        }),
      ],
    );
  }
}

class _AnimatedTripCard extends StatefulWidget {
  final TripModel trip;
  final bool isActive;
  final int delay;

  const _AnimatedTripCard({
    required this.trip,
    this.isActive = false,
    this.delay = 0,
  });

  @override
  State<_AnimatedTripCard> createState() => _AnimatedTripCardState();
}

class _AnimatedTripCardState extends State<_AnimatedTripCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _TripCard(trip: widget.trip, isActive: widget.isActive),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;
  final bool isActive;

  const _TripCard({required this.trip, this.isActive = false});

  String _formatTime(DateTime createdAt) {
    final local = createdAt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = trip.status;
    final distance = trip.distanceKm.toStringAsFixed(1);
    final price = trip.price.toStringAsFixed(0);
    final time = _formatTime(trip.createdAt);

    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusText(status, l);

    const card = AppColors.surface;
    const elevated = AppColors.surfaceElevated;
    const border = AppColors.divider;
    const blue = AppColors.primary;
    const emerald = AppColors.secondary;
    const t1 = AppColors.textPrimary;
    const t2 = AppColors.textSecondary;
    const t3 = AppColors.textDisabled;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? Border.all(color: blue.withValues(alpha: 0.4), width: 1.5)
            : Border.all(color: border, width: 1),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: blue.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ]
            : [
                BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.26),
                    blurRadius: 8,
                    offset: Offset(0, 2))
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: () => context
                .push('${AppRoutes.driverTripDetails}?tripId=${trip.id}'),
            splashColor: blue.withValues(alpha: 0.08),
            highlightColor: elevated.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ──────────────────────────────────────────────
                  Row(children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                            width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(statusLabel,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const Spacer(),
                    if (time.isNotEmpty) ...[
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: t3),
                      const SizedBox(width: 4),
                      Text(time,
                          style: const TextStyle(color: t2, fontSize: 12)),
                    ],
                  ]),

                  const SizedBox(height: 14),

                  // ── Route ──────────────────────────────────────────────────
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Dots + line
                    Column(children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: emerald,
                          boxShadow: [
                            BoxShadow(
                                color: emerald.withValues(alpha: 0.4),
                                blurRadius: 5)
                          ],
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 28,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              emerald.withValues(alpha: 0.4),
                              blue.withValues(alpha: 0.4)
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: blue,
                          boxShadow: [
                            BoxShadow(
                                color: blue.withValues(alpha: 0.4),
                                blurRadius: 5)
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(width: 10),
                    // Addresses
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                            trip.pickupAddress.isEmpty
                                ? '---'
                                : trip.pickupAddress,
                            style: const TextStyle(
                                color: t1,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            trip.destinationAddress.isEmpty
                                ? '---'
                                : trip.destinationAddress,
                            style: const TextStyle(
                                color: t1,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ])),
                  ]),

                  const SizedBox(height: 14),
                  Container(height: 1, color: border),
                  const SizedBox(height: 12),

                  // ── Footer: distance + price ────────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: elevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.straighten_rounded,
                            size: 12, color: t2),
                        const SizedBox(width: 4),
                        Text('$distance ${l.km}',
                            style: const TextStyle(
                                color: t2,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [blue, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: blue.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Text('$price ${l.currencySar}',
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TripStatus? status) {
    const blue = AppColors.primary;
    const emerald = AppColors.secondary;
    const rose = AppColors.error;
    const amber = AppColors.warning;
    const t2 = AppColors.textSecondary;

    return switch (status) {
      TripStatus.completed => emerald,
      TripStatus.cancelled => rose,
      TripStatus.inProgress || TripStatus.accepted => blue,
      TripStatus.searching => amber,
      _ => t2,
    };
  }

  String _getStatusText(TripStatus? status, AppLocalizations l) {
    return switch (status) {
      TripStatus.completed => l.completed,
      TripStatus.cancelled => l.cancelled,
      TripStatus.inProgress => l.inProgress,
      TripStatus.accepted => l.tripAccepted,
      TripStatus.searching => l.searchingForDriver,
      _ => status?.name ?? '',
    };
  }
}
