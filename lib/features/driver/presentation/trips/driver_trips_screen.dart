
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'bloc/driver_trips_bloc.dart';
import 'bloc/driver_trips_state.dart';
import 'bloc/driver_trips_event.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/utils/trip_status.dart';
import '../../../trips/data/models/trip_model.dart';

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
              final completed =
                  allTrips.where((t) => t.status == TripStatus.completed).toList();
              final cancelled =
                  allTrips.where((t) => t.status == TripStatus.cancelled).toList();

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
                context.read<DriverTripsBloc>().add(const LoadDriverTrips()),
            icon: Icons.refresh,
            label: l.retry,
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Row(
            children: [
              _HeaderActionButton(
                icon: Icons.arrow_back_ios_new,
                onTap: onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.myTrips,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.totalTripsLabel(total),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onNewTrip,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_taxi, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.startWorking,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          Row(
            children: [
              Expanded(
                child: _CompactStat(
                  icon: Icons.check_circle,
                  value: completed.toString(),
                  label: l.completed,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactStat(
                  icon: Icons.cancel,
                  value: cancelled.toString(),
                  label: l.cancelled,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.2,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.elevatedColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _SegmentButton(
              icon: Icons.pending_actions,
              label: l.inProgress,
              count: inProgressCount,
              isSelected: selectedIndex == 0,
              onTap: () => onIndexChanged(0),
            ),
            _SegmentButton(
              icon: Icons.check_circle,
              label: l.completed,
              count: completedCount,
              isSelected: selectedIndex == 1,
              onTap: () => onIndexChanged(1),
            ),
            _SegmentButton(
              icon: Icons.cancel,
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : context.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : context.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : context.cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : context.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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
      backgroundColor: context.cardColor,
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

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.local_taxi_outlined : Icons.route_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.noTrips,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isActive
                ? AppLocalizations.of(context)!.noActiveTrips
                : AppLocalizations.of(context)!.tripsWillAppearHere,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 24),
            _GradientButton(
              onPressed: () => context.pop(),
              icon: Icons.local_taxi,
              label: AppLocalizations.of(context)!.backToHome,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                dateLabel,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.elevatedColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trips.length.toString(),
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final userData = trip.userData;
    final userName = userData?['name'] as String? ?? '';
    final l = AppLocalizations.of(context)!;
    final status = trip.status;
    final canNavigate = status == TripStatus.accepted || status == TripStatus.inProgress;
    final price = trip.price.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('${AppRoutes.driverTripDetails}?tripId=${trip.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  Row(
                    children: [
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _getStatusIcon(status),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusText(status, l),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: context.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(trip.createdAt),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _RouteVisualizer(
                    pickup: trip.pickupAddress,
                    destination: trip.destinationAddress,
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      
                      if (userName.isNotEmpty) ...[
                        Hero(
                          tag: 'user_${trip.id}',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: userData?['avatar_url'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: userData!['avatar_url'],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 40,
                                        height: 40,
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        child: const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 40,
                                        height: 40,
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        child: const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      child: const Icon(
                                        Icons.person,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (userData?['phone'] != null)
                                Text(
                                  userData!['phone'],
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          AppLocalizations.of(context)!.newCustomer,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                      ],
                      
                      if (canNavigate)
                        _ActionButton(
                          icon: Icons.navigation,
                          color: AppColors.primary,
                          onTap: () => context.push('${AppRoutes.driverTripDetails}?tripId=${trip.id}'),
                        ),
                      const SizedBox(width: 12),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.9),
                              AppColors.primaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$price ${l.currencySar}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getStatusIcon(TripStatus? status) {
    final iconData = switch (status) {
      TripStatus.completed => Icons.check_circle,
      TripStatus.cancelled => Icons.cancel,
      TripStatus.inProgress => Icons.local_taxi,
      TripStatus.accepted => Icons.thumb_up,
      TripStatus.searching => Icons.search,
      _ => Icons.trip_origin,
    };
    return Icon(iconData, size: 14, color: _getStatusColor(status));
  }

  Color _getStatusColor(TripStatus? status) {
    return switch (status) {
      TripStatus.completed => AppColors.success,
      TripStatus.cancelled => const Color(0xFF6B7280),
      TripStatus.inProgress => AppColors.primary,
      TripStatus.accepted => const Color(0xFF8B5CF6),
      TripStatus.searching => const Color(0xFFF59E0B),
      _ => AppColors.textDisabled,
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

class _RouteVisualizer extends StatelessWidget {
  final String pickup;
  final String destination;

  const _RouteVisualizer({required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: context.cardColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            Container(
              width: 2,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.success.withValues(alpha: 0.5),
                    AppColors.primary.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: context.cardColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LocationPoint(
                label: AppLocalizations.of(context)!.startingPoint,
                address: pickup,
                isDestination: false,
              ),
              const SizedBox(height: 20),
              _LocationPoint(
                label: AppLocalizations.of(context)!.destination,
                address: destination,
                isDestination: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationPoint extends StatelessWidget {
  final String label;
  final String address;
  final bool isDestination;

  const _LocationPoint({
    required this.label,
    required this.address,
    required this.isDestination,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDestination ? AppColors.primary : AppColors.success,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          address.isEmpty ? '---' : address,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 13,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
