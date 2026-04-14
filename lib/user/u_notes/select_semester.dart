import 'package:shiksha_hub/user/u_notes/selecct_sec_stu.dart';
import 'package:shiksha_hub/user/user_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (mirrors SelectSemesterPage / select_scheme.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const indigo900 = Color(0xFF1A237E);
  static const indigo700 = Color(0xFF303F9F);
  static const indigo500 = Color(0xFF3F51B5);
  static const indigo300 = Color(0xFF7986CB);
  static const indigo100 = Color(0xFFC5CAE9);
  static const white     = Colors.white;
  static const bg        = Color(0xFFF0F2FA);

  // Alternating card accents (odd / even semester)
  static const _evenAccent = Color(0xFF1A237E); // indigo900
  static const _oddAccent  = Color(0xFF3F51B5); // indigo500

  static Color accentFor(int semesterNumber) =>
      semesterNumber.isOdd ? _oddAccent : _evenAccent;


}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class StudentSelectSemesterPage extends StatefulWidget {
  final String selectedCollege;
  final String branch;
  final String branchId;
  final String scheme;
  final String? schemeId;

  const StudentSelectSemesterPage({
    super.key,
    required this.branch,
    required this.branchId,
    required this.selectedCollege,
    required this.scheme,
    required this.schemeId,
  });

  @override
  State<StudentSelectSemesterPage> createState() =>
      _StudentSelectSemesterPageState();
}

class _StudentSelectSemesterPageState extends State<StudentSelectSemesterPage>
    with SingleTickerProviderStateMixin {

  // PERFORMANCE: single lightweight controller — no BubblePainter / background animation
  late final AnimationController _listCtrl = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  List<Map<String, dynamic>> _semesters = [];
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
    _loadSemesters();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  static int _semesterNumber(String name) {
    final m = RegExp(r'\d+').firstMatch(name);
    return m != null ? int.parse(m.group(0)!) : 0;
  }

  static String _badgeLabel(String? type) {
    switch (type) {
      case 'admin':           return 'Admin';
      case 'hod':
      case 'department_head': return 'HOD';
      case 'college_staff':   return 'Staff';
      default:                return 'System';
    }
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  Future<void> _loadSemesters() async {
    try {
      setState(() { _loading = true; _error = null; });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');
      if (widget.branchId.isEmpty) throw Exception('Branch ID is required');

      final snap = await FirebaseFirestore.instance
          .collection('semesters')
          .where('branchId', isEqualTo: widget.branchId)
          .orderBy('name')
          .get();

      final list = snap.docs.map((doc) {
        final d    = doc.data();
        final name = (d['name'] as String?) ?? 'Unknown Semester';
        final num  = _semesterNumber(name);
        return {
          'id':          doc.id,
          'title':       name,
          'semesterNum': num,
          'accent':      _C.accentFor(num),
          'data':        d,
        };
      }).toList();

      // Sort by semester number ascending
      list.sort((a, b) =>
          (a['semesterNum'] as int).compareTo(b['semesterNum'] as int));

      if (mounted) {
        setState(() { _semesters = list; _loading = false; });
        if (list.isNotEmpty) _listCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _go(String semesterTitle) => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => StudentSectionSelectionPage(
        selectedCollege: widget.selectedCollege,
        branch:          widget.branch,
        scheme:          widget.scheme,
        schemeId:        widget.schemeId,
        semester:        semesterTitle,
        universityName:  '',
        courseName:      '',
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
              branch:  widget.branch,
              scheme:  widget.scheme,
              topPad:  MediaQuery.of(context).padding.top,
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const _LoadingView();
    if (_error != null && _semesters.isEmpty) {
      return _ErrorView(error: _error!, onRetry: _loadSemesters);
    }
    if (_semesters.isEmpty) {
      return _EmptyView(
          branch: widget.branch,
          scheme: widget.scheme,
          onRetry: _loadSemesters);
    }

    return RefreshIndicator(
      color: _C.indigo500,
      onRefresh: _loadSemesters,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        itemCount: _semesters.length,
        itemBuilder: (_, i) {
          final s = _semesters[i];

          final interval = CurvedAnimation(
            parent: _listCtrl,
            curve: Interval(
              (i / _semesters.length) * 0.5,
              (i / _semesters.length) * 0.5 + 0.5,
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
              child: _SemesterCard(
                title:       s['title']       as String,
                semesterNum: s['semesterNum'] as int,
                accent:      s['accent']      as Color,
                onTap:       () => _go(s['title'] as String),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String branch;
  final String scheme;
  final double topPad;
  const _Header({
    required this.branch,
    required this.scheme,
    required this.topPad,
  });

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
          // ── Top bar ────────────────────────────────────────────────────────
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

          // ── Title block ────────────────────────────────────────────────────
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
                  'Select Semester',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: _C.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                // Breadcrumb chip — branch • scheme
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
                        '$branch  •  $scheme',
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
//  SEMESTER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SemesterCard extends StatelessWidget {
  final String title;
  final int    semesterNum;
  final Color  accent;
  final VoidCallback onTap;

  const _SemesterCard({
    required this.title,
    required this.semesterNum,
    required this.accent,
    required this.onTap,
  });

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
                colors: [accent.withOpacity(0.11), Colors.white],
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
                  // ── Semester number avatar ─────────────────
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
                    child: Center(
                      child: Text(
                        semesterNum > 0 ? '$semesterNum' : '?',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // ── Text ──────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                        const SizedBox(height: 4),
                        Text(
                          'View subjects and materials',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            color: _C.indigo700.withOpacity(0.60),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Arrow ─────────────────────────────────
                  const SizedBox(width: 10),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _C.indigo500.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                        color: _C.indigo500, size: 14),
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
        Text('Loading semesters…',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: _C.indigo700.withOpacity(0.65),
            fontWeight: FontWeight.w500,
          )),
        const SizedBox(height: 6),
        Text('Fetching semester list',
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
          const Text('Could not load semesters',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _C.indigo900,
            )),
          const SizedBox(height: 8),
          Text(error,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13, color: Colors.grey[600])),
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
  final String branch;
  final String scheme;
  final VoidCallback onRetry;
  const _EmptyView({
    required this.branch,
    required this.scheme,
    required this.onRetry,
  });

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
            child: const Icon(Icons.calendar_today_outlined,
                color: _C.indigo300, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('No Semesters Available',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _C.indigo900,
            )),
          const SizedBox(height: 8),
          Text(
            'No semesters found for $branch under $scheme.\nPlease contact HOD or Admin to create them.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13, color: Colors.grey[600]),
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
  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(label,
      style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 13)),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 3,
      shadowColor: color.withOpacity(0.4),
    ),
  );
}