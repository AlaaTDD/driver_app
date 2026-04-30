// lib/features/shared/presentation/rating/rating_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'bloc/rating_bloc.dart';
import 'bloc/rating_event.dart';
import 'bloc/rating_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../core/error/error_mapper.dart';

class RatingScreen extends StatefulWidget {
  final String tripId;

  const RatingScreen({super.key, required this.tripId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        title: Text(AppLocalizations.of(context)!.rateTrip),
      ),
      body: BlocConsumer<RatingBloc, RatingState>(
        listener: (context, state) {
          if (state is RatingSuccess) {
            Future.delayed(const Duration(seconds: 2), () {
              if (!context.mounted) return;
              final authState = context.read<AuthBloc>().state;
              final isDriver = authState is AuthAuthenticated && authState.user.role == 'driver';
              context.go(isDriver ? AppRoutes.driverHome : AppRoutes.userHome);
            });
          }
        },
        builder: (context, state) {
          if (state is RatingLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          } else if (state is RatingSuccess) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 80),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.thanksForRating,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.returningHome,
                    style: TextStyle(
                        color: context.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            );
          } else if (state is RatingError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(ErrorMapper.getErrorMessage(context, state.message),
                      style:
                          TextStyle(color: context.textPrimary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _rating = 0),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: Text(AppLocalizations.of(context)!.retry),
                  ),
                ],
              ),
            );
          }
          return _buildRatingForm();
        },
      ),
    );
  }

  Widget _buildRatingForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.star,
            color: AppColors.warning,
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.howWasTrip,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: AppColors.warning,
                  size: 40,
                ),
                onPressed: () {
                  setState(() => _rating = index + 1.0);
                },
              );
            }),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.addCommentOptional,
              hintText: AppLocalizations.of(context)!.shareExperience,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _rating > 0
                ? () {
                    context.read<RatingBloc>().add(SubmitRating(
                      tripId: widget.tripId,
                      rating: _rating,
                      comment: _commentController.text.isNotEmpty ? _commentController.text : null,
                    ));
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(AppLocalizations.of(context)!.submitRating),
          ),
        ],
      ),
    );
  }
}
