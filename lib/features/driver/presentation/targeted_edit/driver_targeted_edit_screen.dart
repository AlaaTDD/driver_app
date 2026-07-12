import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/models/field_status_model.dart';
import '../../../../core/models/revision_request_labels.dart';
import '../../../../core/models/revision_request_model.dart';
import '../../../../core/services/r2_storage_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/errors/exceptions.dart';

class DriverTargetedEditScreen extends StatefulWidget {
  final RevisionRequestModel? revision;
  const DriverTargetedEditScreen({super.key, required this.revision});

  @override
  State<DriverTargetedEditScreen> createState() =>
      _DriverTargetedEditScreenState();
}

class _DriverTargetedEditScreenState
    extends State<DriverTargetedEditScreen> {
  final _nationalIdController    = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _vehiclePlateController  = TextEditingController();
  final _vehicleBrandController  = TextEditingController();
  final _vehicleModelController  = TextEditingController();
  final _vehicleYearController   = TextEditingController();
  final _vehicleColorController  = TextEditingController();

  final Map<String, String?> _uploadedUrls = {};
  final Map<String, bool>    _uploading    = {};
  bool _submitting = false;

  @override
  void dispose() {
    _nationalIdController.dispose();
    _licenseNumberController.dispose();
    _vehiclePlateController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  RevisionRequestModel? get _revision => widget.revision;

  String? _reasonFor(String key) => _revision?.fieldStatuses[key]?.reason;

  // ────────────────────────────── Submit ───────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;
    final l   = AppLocalizations.of(context)!;
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      final updates = <String, dynamic>{};

      void addText(String key, TextEditingController ctrl) {
        if (ctrl.text.trim().isNotEmpty) updates[key] = ctrl.text.trim();
      }

      addText('national_id',    _nationalIdController);
      addText('license_number', _licenseNumberController);
      addText('vehicle_plate',  _vehiclePlateController);
      addText('vehicle_brand',  _vehicleBrandController);
      addText('vehicle_model',  _vehicleModelController);
      addText('vehicle_color',  _vehicleColorController);
      if (_vehicleYearController.text.trim().isNotEmpty) {
        final y = int.tryParse(_vehicleYearController.text.trim());
        if (y != null) updates['vehicle_year'] = y;
      }

      _uploadedUrls.forEach((key, url) {
        if (url != null) updates[key] = url;
      });

      if (updates.isEmpty) {
        AppToast.error(l.submitChanges);
        return;
      }

      // [دورة المراجعة الثلاثية — Requires Action/Under Review/Approved]
      // لا يمكن لعميل السائق كتابة account_status مباشرة عبر .update() —
      // trg_protect_driver_account_status يفرض العمود على قيمته القديمة
      // بصمت لأي متصل غير service_role/admin. الاستدعاء الصحيح الوحيد هو
      // عبر RPC ذرية SECURITY DEFINER تتحقق من الملكية وتنقل الحالة إلى
      // under_review ضمن نفس التحديث. انظر MASTER_PLAN.md القسم 4.5 و4.6.
      await SupabaseService.client.rpc('driver_submit_revision_updates', params: {
        'p_driver_id': uid,
        'p_field_updates': updates,
      });

      if (mounted) {
        AppToast.success(l.changesSubmitted);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ────────────────────────────── Gallery Upload ────────────────────────────

  Future<void> _pickFromGallery(String fieldKey, String r2Segment) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return;

    setState(() => _uploading[fieldKey] = true);
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) throw AuthException('errorNotLoggedIn');
      final r2    = R2StorageService();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      // نستخدم مسار `drivers/$uid` لتطابق صلاحيات وإعدادات R2 في شاشة التسجيل
      final url   = await r2.uploadFile(
        file: File(image.path),
        path: 'drivers/$uid',
      );
      if (mounted) setState(() => _uploadedUrls[fieldKey] = url);
    } catch (e) {
      if (mounted) {
        AppToast.error(e is AppException ? e.message : 'errorUploadFailed');
      }
    } finally {
      if (mounted) setState(() => _uploading[fieldKey] = false);
    }
  }


  // ────────────────────────────── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l          = AppLocalizations.of(context)!;
    final revision   = _revision;

    final editableFields = revision?.fieldStatuses.values
            .where((f) => f.requiresAction || f.isPending)
            .toList() ??
        [];
    final approvedFields = revision?.approvedFields ?? [];
    final hasRequiresAction = editableFields.any((f) => f.requiresAction);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Column(
        children: [
          // ── Gradient Header ──────────────────────────────────────────────
          _buildHeader(context, l, hasRequiresAction),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: revision == null
                ? _buildEmptyState(context, l)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      // info banner
                      _buildInfoBanner(context, l, hasRequiresAction),
                      const SizedBox(height: 20),

                      // Editable fields
                      if (editableFields.isNotEmpty) ...[
                        _sectionLabel(
                          context,
                          hasRequiresAction
                              ? '⚠️  ${l.fieldStatusRequiresAction}'
                              : '✏️  ${l.fieldsRequested}',
                          hasRequiresAction ? AppColors.error : AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        ...editableFields.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildFieldCard(context, f, l),
                          ),
                        ),
                      ],

                      // Approved fields
                      if (approvedFields.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _sectionLabel(
                          context,
                          '✅  ${l.fieldStatusApproved}',
                          AppColors.success,
                        ),
                        const SizedBox(height: 10),
                        ...approvedFields.map((f) => _buildApprovedTile(context, f, l)),
                      ],

                      if (editableFields.isEmpty)
                        _buildEmptyState(context, l),
                    ],
                  ),
          ),

          // ── Submit Button ────────────────────────────────────────────────
          if (editableFields.isNotEmpty) _buildSubmitBar(context, l),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext ctx, AppLocalizations l, bool hasError) {
    final color1 = hasError ? const Color(0xFFD32F2F) : AppColors.primary;
    final color2 = hasError ? const Color(0xFFB71C1C) : const Color(0xFF1565C0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.targetedEditTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.editOnlyRequiredFields,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Info Banner ─────────────────────────────────────────────────────────────

  Widget _buildInfoBanner(
      BuildContext ctx, AppLocalizations l, bool hasError) {
    final color = hasError ? AppColors.error : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.editOnlyRequiredFields,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Label ───────────────────────────────────────────────────────────

  Widget _sectionLabel(BuildContext ctx, String text, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // ── Field Card ──────────────────────────────────────────────────────────────

  Widget _buildFieldCard(
      BuildContext ctx, FieldStatusModel field, AppLocalizations l) {
    final label = RevisionRequestModel(
      id: '',
      fieldStatuses: {field.fieldKey: field},
    ).fieldLabel(ctx, field.fieldKey);

    final reason       = _reasonFor(field.fieldKey);
    final isImageField = field.fieldKey.contains('image_url') ||
        field.fieldKey == 'criminal_record_url';
    final accent       = field.requiresAction ? AppColors.error : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: ctx.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Card Header ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isImageField
                        ? Icons.image_outlined
                        : Icons.edit_note_rounded,
                    color: accent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: ctx.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    field.requiresAction
                        ? l.fieldStatusRequiresAction
                        : l.fieldStatusPending,
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Reason ──────────────────────────────────────────
          if (reason != null && reason.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded,
                      size: 14, color: AppColors.error.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        color: ctx.textSecondary,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Input ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: isImageField
                ? _buildImageZone(ctx, field.fieldKey, l)
                : _buildTextField(ctx, field.fieldKey, label, accent),
          ),
        ],
      ),
    );
  }

  // ── Text Field ──────────────────────────────────────────────────────────────

  Widget _buildTextField(
      BuildContext ctx, String key, String hint, Color accent) {
    final ctrl = switch (key) {
      'national_id'    => _nationalIdController,
      'license_number' => _licenseNumberController,
      'vehicle_plate'  => _vehiclePlateController,
      'vehicle_brand'  => _vehicleBrandController,
      'vehicle_model'  => _vehicleModelController,
      'vehicle_year'   => _vehicleYearController,
      'vehicle_color'  => _vehicleColorController,
      _                => null,
    };
    if (ctrl == null) return const SizedBox.shrink();

    return TextField(
      controller: ctrl,
      keyboardType:
          key == 'vehicle_year' ? TextInputType.number : TextInputType.text,
      style: TextStyle(
          color: ctx.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: ctx.textSecondary.withValues(alpha: 0.5), fontSize: 14),
        filled: true,
        fillColor: ctx.elevatedColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ctx.divColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ctx.divColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(_fieldIcon(key), color: accent, size: 18),
      ),
    );
  }

  IconData _fieldIcon(String key) => switch (key) {
        'national_id'    => Icons.badge_outlined,
        'license_number' => Icons.credit_card_outlined,
        'vehicle_plate'  => Icons.pin_outlined,
        'vehicle_brand'  => Icons.directions_car_outlined,
        'vehicle_model'  => Icons.car_repair_outlined,
        'vehicle_year'   => Icons.calendar_today_outlined,
        'vehicle_color'  => Icons.palette_outlined,
        _                => Icons.edit_outlined,
      };

  // ── Image Upload Zone ────────────────────────────────────────────────────────

  Widget _buildImageZone(BuildContext ctx, String key, AppLocalizations l) {
    final isUploading = _uploading[key] ?? false;
    final uploaded    = _uploadedUrls[key];
    final r2Segment   = switch (key) {
      'national_id_image_url' => 'national_id',
      'license_image_url'     => 'license',
      'criminal_record_url'   => 'criminal_record',
      'vehicle_image_url'     => 'vehicle',
      _                       => key,
    };

    return GestureDetector(
      onTap: isUploading ? null : () => _pickFromGallery(key, r2Segment),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: uploaded != null
              ? AppColors.success.withValues(alpha: 0.04)
              : AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: uploaded != null
                ? AppColors.success.withValues(alpha: 0.5)
                : AppColors.primary.withValues(alpha: 0.25),
            width: uploaded != null ? 1.5 : 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: isUploading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.uploading,
                      style: TextStyle(
                          color: ctx.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            : uploaded != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(
                          uploaded,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Overlay badge
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                l.uploaded,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Tap to change
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library_outlined,
                                    color: Colors.white, size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  l.changePhoto,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_library_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l.uploadDocument,
                        style: TextStyle(
                          color: ctx.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.tapToSelectFromGallery,
                        style: TextStyle(
                          color: ctx.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // ── Approved Tile ───────────────────────────────────────────────────────────

  Widget _buildApprovedTile(
      BuildContext ctx, FieldStatusModel field, AppLocalizations l) {
    final label = RevisionRequestModel(
      id: '',
      fieldStatuses: {field.fieldKey: field},
    ).fieldLabel(ctx, field.fieldKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: ctx.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            l.fieldStatusApproved,
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit Bar ──────────────────────────────────────────────────────────────

  Widget _buildSubmitBar(BuildContext ctx, AppLocalizations l) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(ctx).padding.bottom + 12),
      decoration: BoxDecoration(
        color: ctx.cardColor,
        border: Border(top: BorderSide(color: ctx.divColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      l.submitChanges,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext ctx, AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              l.noFieldsToEdit,
              style: TextStyle(
                color: ctx.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
