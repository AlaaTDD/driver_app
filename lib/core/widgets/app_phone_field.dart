import 'package:flutter/material.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/design_system.dart';

// ─────────────────────────────────────────────
// Country data model
// ─────────────────────────────────────────────
class _Country {
  final String code;
  final String name;
  final String dialCode;
  const _Country({
    required this.code,
    required this.name,
    required this.dialCode,
  });
}

// ─────────────────────────────────────────────
// Countries list — MENA first, then worldwide
// ─────────────────────────────────────────────
const List<_Country> _kCountries = [
  // ── MENA ──────────────────────────────────────────────────
  _Country(code: 'EG', name: 'Egypt',        dialCode: '+20' ),
  _Country(code: 'SA', name: 'Saudi Arabia', dialCode: '+966'),
  _Country(code: 'AE', name: 'UAE',          dialCode: '+971'),
  _Country(code: 'KW', name: 'Kuwait',       dialCode: '+965'),
  _Country(code: 'QA', name: 'Qatar',        dialCode: '+974'),
  _Country(code: 'BH', name: 'Bahrain',      dialCode: '+973'),
  _Country(code: 'OM', name: 'Oman',         dialCode: '+968'),
  _Country(code: 'JO', name: 'Jordan',       dialCode: '+962'),
  _Country(code: 'LB', name: 'Lebanon',      dialCode: '+961'),
  _Country(code: 'SY', name: 'Syria',        dialCode: '+963'),
  _Country(code: 'IQ', name: 'Iraq',         dialCode: '+964'),
  _Country(code: 'PS', name: 'Palestine',    dialCode: '+970'),
  _Country(code: 'LY', name: 'Libya',        dialCode: '+218'),
  _Country(code: 'TN', name: 'Tunisia',      dialCode: '+216'),
  _Country(code: 'DZ', name: 'Algeria',      dialCode: '+213'),
  _Country(code: 'MA', name: 'Morocco',      dialCode: '+212'),
  _Country(code: 'SD', name: 'Sudan',        dialCode: '+249'),
  _Country(code: 'YE', name: 'Yemen',        dialCode: '+967'),
  // ── Europe ────────────────────────────────────────────────
  _Country(code: 'GB', name: 'United Kingdom', dialCode: '+44' ),
  _Country(code: 'FR', name: 'France',          dialCode: '+33' ),
  _Country(code: 'DE', name: 'Germany',         dialCode: '+49' ),
  _Country(code: 'IT', name: 'Italy',           dialCode: '+39' ),
  _Country(code: 'ES', name: 'Spain',           dialCode: '+34' ),
  _Country(code: 'RU', name: 'Russia',          dialCode: '+7'  ),
  _Country(code: 'TR', name: 'Turkey',          dialCode: '+90' ),
  _Country(code: 'NL', name: 'Netherlands',     dialCode: '+31' ),
  _Country(code: 'SE', name: 'Sweden',          dialCode: '+46' ),
  _Country(code: 'PL', name: 'Poland',          dialCode: '+48' ),
  // ── Americas ──────────────────────────────────────────────
  _Country(code: 'US', name: 'United States', dialCode: '+1'  ),
  _Country(code: 'CA', name: 'Canada',         dialCode: '+1'  ),
  _Country(code: 'BR', name: 'Brazil',         dialCode: '+55' ),
  _Country(code: 'MX', name: 'Mexico',         dialCode: '+52' ),
  _Country(code: 'AR', name: 'Argentina',      dialCode: '+54' ),
  // ── Asia & Oceania ────────────────────────────────────────
  _Country(code: 'IN', name: 'India',       dialCode: '+91' ),
  _Country(code: 'PK', name: 'Pakistan',    dialCode: '+92' ),
  _Country(code: 'BD', name: 'Bangladesh',  dialCode: '+880'),
  _Country(code: 'CN', name: 'China',       dialCode: '+86' ),
  _Country(code: 'JP', name: 'Japan',       dialCode: '+81' ),
  _Country(code: 'KR', name: 'South Korea', dialCode: '+82' ),
  _Country(code: 'ID', name: 'Indonesia',   dialCode: '+62' ),
  _Country(code: 'MY', name: 'Malaysia',    dialCode: '+60' ),
  _Country(code: 'PH', name: 'Philippines', dialCode: '+63' ),
  _Country(code: 'AU', name: 'Australia',   dialCode: '+61' ),
  // ── Africa ────────────────────────────────────────────────
  _Country(code: 'NG', name: 'Nigeria',      dialCode: '+234'),
  _Country(code: 'KE', name: 'Kenya',        dialCode: '+254'),
  _Country(code: 'ZA', name: 'South Africa', dialCode: '+27' ),
  _Country(code: 'ET', name: 'Ethiopia',     dialCode: '+251'),
  _Country(code: 'GH', name: 'Ghana',        dialCode: '+233'),
];

// ─────────────────────────────────────────────
// AppPhoneField — completely custom, RTL-safe
// ─────────────────────────────────────────────

/// Phone number input with country code selector.
///
/// Built entirely with standard Flutter widgets — no third-party phone
/// packages. Layout is always LTR (phone numbers are globally LTR), so
/// it renders correctly in Arabic/RTL apps without any special handling.
///
/// [onChanged] receives the complete number, e.g. "+201001234567".
/// [initialCountryCode] is the 2-letter ISO code, default "EG" (Egypt).
class AppPhoneField extends StatefulWidget {
  final void Function(String completeNumber) onChanged;
  final String initialCountryCode;
  final TextInputAction textInputAction;

  const AppPhoneField({
    super.key,
    required this.onChanged,
    this.initialCountryCode = 'EG',
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<AppPhoneField> createState() => _AppPhoneFieldState();
}

class _AppPhoneFieldState extends State<AppPhoneField> {
  late _Country _selected;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = _kCountries.firstWhere(
      (c) => c.code == widget.initialCountryCode,
      orElse: () => _kCountries.first,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fireChange() {
    final number = _controller.text.trim();
    widget.onChanged('${_selected.dialCode}$number');
  }

  void _openPicker() async {
    final result = await showModalBottomSheet<_Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CountryPickerSheet(selected: _selected),
    );
    if (result != null && mounted) {
      setState(() => _selected = result);
      _fireChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      // Phone numbers are globally LTR — force LTR regardless of app locale
      textDirection: TextDirection.ltr,
      style: TextStyle(color: context.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: l.phone,
        hintText: '10XXXXXXXX',
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        // Custom prefix: [code][+20][▼][divider]
        // No flag emoji — emoji flags are two Unicode Regional Indicator
        // chars that render as ? boxes on many devices/emulators.
        // ISO code text (EG, SA…) is always safe and readable.
        prefix: GestureDetector(
          onTap: _openPicker,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.ltr,
            children: [
              Text(
                _selected.code,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(width: 4),
              Text(
                _selected.dialCode,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: context.textSecondary,
              ),
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 18,
                color: context.divColor,
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
      onChanged: (_) => _fireChange(),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return l.enterPhone;
        return null;
      },
    );
  }
}

// ─────────────────────────────────────────────
// Country Picker Bottom Sheet
// ─────────────────────────────────────────────
class _CountryPickerSheet extends StatefulWidget {
  final _Country selected;
  const _CountryPickerSheet({required this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<_Country> _filtered = _kCountries;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        _filtered = q.isEmpty
            ? _kCountries
            : _kCountries.where((c) {
                return c.name.toLowerCase().contains(q) ||
                    c.dialCode.contains(q) ||
                    c.code.toLowerCase().contains(q);
              }).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.divColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                labelText: l.searchCountry,
                prefixIcon: const Icon(Icons.search_rounded),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final isSelected = c.code == widget.selected.code;
                return ListTile(
                  title: Text(
                    c.name,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  leading: Text(
                    c.code,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  trailing: Text(
                    c.dialCode,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  selected: isSelected,
                  selectedTileColor: AppColors.primarySurface20,
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
