import 'package:shiksha_hub/user/u_notes/select_semester.dart';
import 'package:shiksha_hub/user/user_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (mirrors SelectSchemePage / ad_branch.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const indigo900 = Color(0xFF1A237E);
  static const indigo700 = Color(0xFF303F9F);
  static const indigo500 = Color(0xFF3F51B5);
  static const indigo300 = Color(0xFF7986CB);
  static const indigo100 = Color(0xFFC5CAE9);
  static const white     = Colors.white;
  static const bg        = Color(0xFFF0F2FA);

  static const schemeAccents = <String, Color>{
    'admin':           Color(0xFFC62828),
    'department_head': Color(0xFF4527A0),
    'college_staff':   Color(0xFF1B5E20),
  };

  static Color accentFor(String? type) =>
      schemeAccents[type] ?? indigo700;

  static const _palette = <Color>[
    Color(0xFF1565C0),
    Color(0xFF283593),
    Color(0xFF6A1B9A),
    Color(0xFF00695C),
    Color(0xFF4E342E),
    Color(0xFF0277BD),
  ];

  static Color paletteAt(int i) => _palette[i % _palette.length];
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class StudentSelectSchemePage extends StatefulWidget {
  final String selectedCollege;
  final String branch;
  final String branchId;

  const StudentSelectSchemePage({
    super.key,
    required this.selectedCollege,
    required this.branch,
    required this.branchId,
  });

  @override
  State<StudentSelectSchemePage> createState() =>
      _StudentSelectSchemePageState();
}

class _StudentSelectSchemePageState extends State<StudentSelectSchemePage>
    with SingleTickerProviderStateMixin {

  // Single controller — no AnimatedBackground, no TickerProviderStateMixin overhead
  late final AnimationController _listCtrl = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  List<Map<String, dynamic>> _schemes = [];
  bool    _loading = true;
  String? _error;

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness:     Brightness.dark,
    ));
    _loadSchemes();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Extracts the start year from "2024-25" → 2024
  static int _parseStartYear(String academicYear) {
    if (academicYear.isEmpty) return 0;
    final parts = academicYear.split('-');
    return int.tryParse(parts.first.trim()) ?? 0;
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  Future<void> _loadSchemes() async {
    try {
      setState(() { _loading = true; _error = null; });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final studentSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(user.uid)
          .get();

      if (!studentSnap.exists) throw Exception('Student profile not found');
      final courseId = studentSnap.data()!['courseId'] as String?;
      if (courseId == null) throw Exception('Course info missing in profile');

      // No orderBy — sort client-side by academic year (oldest → newest)
      final snap = await FirebaseFirestore.instance
          .collection('schemes')
          .where('courseId', isEqualTo: courseId)
          .where('status', isEqualTo: 'active')
          .get();

      final list = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final d        = doc.data();
        final branches = d['branches'] as List<dynamic>?;

        if (branches != null &&
            branches.isNotEmpty &&
            !branches.contains(widget.branchId)) continue;

        final type         = d['createdByType'] as String?;
        final name         = (d['name'] as String?) ?? 'Unknown Scheme';
        final academicYear = (d['academicYear'] as String?) ?? '';
        final description  = (d['description'] as String?) ?? '';

        final subtitle = _buildSubtitle(academicYear, description);

        list.add({
          'id':           doc.id,
          'title':        name,
          'subtitle':     subtitle,
          'academicYear': academicYear,
          'description':  description,
          'type':         type,
          'accent':       _C.accentFor(type),
          'paletteColor': _C.paletteAt(list.length),
          'icon':         _iconFor(type),
        });
      }

      // Oldest → newest
      list.sort((a, b) {
        final yearA = _parseStartYear(a['academicYear'] as String);
        final yearB = _parseStartYear(b['academicYear'] as String);
        return yearA.compareTo(yearB);
      });

      if (mounted) {
        setState(() { _schemes = list; _loading = false; });
        if (list.isNotEmpty) _listCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  static String _buildSubtitle(String year, String desc) {
    if (year.isNotEmpty && desc.isNotEmpty) return '$year  •  $desc';
    if (year.isNotEmpty) return 'Academic Year: $year';
    if (desc.isNotEmpty) return desc;
    return 'Academic scheme';
  }

  static IconData _iconFor(String? type) {
    switch (type) {
      case 'admin':           return Icons.admin_panel_settings_outlined;
      case 'department_head': return Icons.school_outlined;
      case 'college_staff':   return Icons.person_outline;
      default:                return Icons.schema_outlined;
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _go(Map<String, dynamic> scheme) => Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => StudentSelectSemesterPage(
        branch:          widget.branch,
        branchId:        widget.branchId,
        selectedCollege: widget.selectedCollege,
        scheme:          scheme['title'] as String,
        schemeId:        scheme['id']    as String,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOutCubic))
            .animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
    ),
  );

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Column(
          children: [
            _Header(
              branch: widget.branch,
              topPad: MediaQuery.of(context).padding.top,
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const _LoadingView();
    if (_error != null && _schemes.isEmpty) {
      return _ErrorView(error: _error!, onRetry: _loadSchemes);
    }
    if (_schemes.isEmpty) return _EmptyView(onRetry: _loadSchemes);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: _schemes.length,
      itemBuilder: (ctx, i) {
        final s = _schemes[i];

        final interval = CurvedAnimation(
          parent: _listCtrl,
          curve: Interval(
            (i / _schemes.length) * 0.5,
            (i / _schemes.length) * 0.5 + 0.5,
            curve: Curves.easeOutCubic,
          ),
        );

        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: interval,
            builder: (_, child) => Opacity(
              opacity: interval.value,
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - interval.value)),
                child: child,
              ),
            ),
            child: _SchemeCard(
              title:        s['title']        as String,
              subtitle:     s['subtitle']     as String,
              academicYear: s['academicYear'] as String,
              type:         s['type']         as String?,
              icon:         s['icon']         as IconData,
              accent:       s['accent']       as Color,
              paletteColor: s['paletteColor'] as Color,
              onTap:        () => _go(s),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String branch;
  final double topPad;
  const _Header({required this.branch, required this.topPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: topPad),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.indigo900, _C.indigo500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x553F51B5),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _C.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Get.to(
                    () => const HomePage(),
                    transition: Transition.fadeIn,
                    duration: const Duration(milliseconds: 300),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home_rounded, color: _C.white, size: 16),
                        SizedBox(width: 6),
                        Text('Home',
                            style: TextStyle(
                              color: _C.white,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Title block
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 28),
            child: Column(
              children: [
                // Decorative pill
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select Scheme',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: _C.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                // Branch breadcrumb chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined,
                          color: Colors.white.withOpacity(0.8), size: 13),
                      const SizedBox(width: 5),
                      Text(
                        branch,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
//  SCHEME CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SchemeCard extends StatelessWidget {
  final String   title;
  final String   subtitle;
  final String   academicYear;
  final String?  type;
  final IconData icon;
  final Color    accent;
  final Color    paletteColor;
  final VoidCallback onTap;

  const _SchemeCard({
    required this.title,
    required this.subtitle,
    required this.academicYear,
    required this.type,
    required this.icon,
    required this.accent,
    required this.paletteColor,
    required this.onTap,
  });

  String get _badge {
    switch (type) {
      case 'admin':           return 'Admin';
      case 'department_head': return 'HOD';
      case 'college_staff':   return 'Staff';
      default:                return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: _C.indigo300.withOpacity(0.15),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withOpacity(0.11),
                  Colors.white,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.indigo100, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  // ── Icon container ─────────────────────────
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withOpacity(0.72)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),

                  // ── Text block ─────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row with badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _C.indigo900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: accent.withOpacity(0.30),
                                    width: 1),
                              ),
                              child: Text(
                                _badge,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Academic year pill
                        if (academicYear.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _C.indigo500.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _C.indigo100, width: 1),
                            ),
                            child: Text(
                              academicYear,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _C.indigo700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],

                        // Subtitle / description
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            color: _C.indigo700.withOpacity(0.60),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // ── Arrow ──────────────────────────────────
                  const SizedBox(width: 10),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _C.indigo500.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _C.indigo500,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATE VIEWS
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 40, height: 40,
          child: CircularProgressIndicator(
              color: _C.indigo500, strokeWidth: 3),
        ),
        const SizedBox(height: 16),
        Text('Loading schemes…',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: _C.indigo700.withOpacity(0.65),
            fontWeight: FontWeight.w500,
          )),
        const SizedBox(height: 6),
        Text('Fetching available academic schemes',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.grey[500],
          )),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Could not load schemes',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _C.indigo900,
            )),
          const SizedBox(height: 8),
          Text(error,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins',
                fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 24),
          _PillButton(
              label: 'Try Again',
              icon: Icons.refresh,
              color: _C.indigo500,
              onTap: onRetry),
        ],
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.indigo100.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.schema_outlined,
                color: _C.indigo300, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('No Schemes Available',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _C.indigo900,
            )),
          const SizedBox(height: 8),
          Text(
            'No active academic schemes found for your course.\nContact the administrator.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins',
                fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          _PillButton(
              label: 'Refresh',
              icon: Icons.refresh,
              color: _C.indigo500,
              onTap: onRetry),
        ],
      ),
    ),
  );
}

class _PillButton extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final Color      color;
  final VoidCallback onTap;
  const _PillButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(label,
      style: const TextStyle(
          fontFamily: 'Poppins', fontWeight: FontWeight.w600,
          fontSize: 13)),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30)),
      elevation: 3,
      shadowColor: color.withOpacity(0.4),
    ),
  );
}