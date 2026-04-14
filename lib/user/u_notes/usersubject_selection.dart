import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shiksha_hub/user/u_notes/select_module.dart';
import 'package:shiksha_hub/user/user_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (mirrors SelectSubjectPage / select_section.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const indigo900 = Color(0xFF1A237E);
  static const indigo700 = Color(0xFF303F9F);
  static const indigo500 = Color(0xFF3F51B5);
  static const indigo300 = Color(0xFF7986CB);
  static const indigo100 = Color(0xFFC5CAE9);
  static const white     = Colors.white;
  static const bg        = Color(0xFFF0F2FA);

  static const _palette = <Color>[
    Color(0xFF1A237E),
    Color(0xFF3F51B5),
    Color(0xFF283593),
    Color(0xFF3949AB),
    Color(0xFF303F9F),
    Color(0xFF1565C0),
  ];

  static Color accentFor(int i) => _palette[i % _palette.length];
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class StudentSelectSubjectPage extends StatefulWidget {
  final String selectedCollege;
  final String branch;
  final String scheme;
  final String? schemeId;
  final String semester;
  final String sectionName;
  final String sectionId;

  const StudentSelectSubjectPage({
    super.key,
    required this.selectedCollege,
    required this.branch,
    required this.semester,
    required String universityName,
    required String courseName,
    required this.scheme,
    this.schemeId,
    required this.sectionName,
    required this.sectionId,
  });

  @override
  State<StudentSelectSubjectPage> createState() =>
      _StudentSelectSubjectPageState();
}

class _StudentSelectSubjectPageState extends State<StudentSelectSubjectPage>
    with SingleTickerProviderStateMixin {

  // PERFORMANCE: single controller — no BubblePainter / background animation
  late final AnimationController _listCtrl = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _subjects = [];
  bool    _loading = true;
  String? _error;
  String? _branchId;
  String? _semesterId;

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness:     Brightness.dark,
    ));
    _searchCtrl.addListener(() => setState(() {}));
    _initializeData();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  Future<void> _initializeData() async {
    await _resolveIds();
    await _loadSubjects();
  }

  Future<void> _resolveIds() async {
    try {
      final branchSnap = await FirebaseFirestore.instance
          .collection('branches')
          .where('name', isEqualTo: widget.branch)
          .limit(1)
          .get();
      if (branchSnap.docs.isNotEmpty) {
        _branchId = branchSnap.docs.first.id;
      }

      final semSnap = await FirebaseFirestore.instance
          .collection('semesters')
          .where('name', isEqualTo: widget.semester)
          .where('branchId', isEqualTo: _branchId)
          .limit(1)
          .get();
      if (semSnap.docs.isNotEmpty) {
        _semesterId = semSnap.docs.first.id;
      }
    } catch (e) {
      debugPrint('Error resolving IDs: $e');
    }
  }

  Future<void> _loadSubjects() async {
    try {
      setState(() { _loading = true; _error = null; });

      if (_branchId == null || _semesterId == null || widget.schemeId == null) {
        throw Exception('Missing required IDs: branchId, semesterId, or schemeId');
      }

      final snap = await FirebaseFirestore.instance
          .collection('subjects')
          .where('schemeId',   isEqualTo: widget.schemeId)
          .where('branchId',   isEqualTo: _branchId)
          .where('semesterId', isEqualTo: _semesterId)
          .where('status',     isEqualTo: 'active')
          .orderBy('name')
          .get();

      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d    = doc.data();
        final name = (d['name'] as String?) ?? 'Unknown Subject';
        final code = (d['code'] as String?) ?? '';
        list.add({
          'id':     doc.id,
          'name':   name,
          'code':   code,
          'accent': _C.accentFor(list.length),
          'data':   d,
        });
      }

      if (mounted) {
        setState(() { _subjects = list; _loading = false; });
        if (list.isNotEmpty) _listCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Filtering ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _subjects;
    return _subjects.where((s) {
      return (s['name'] as String).toLowerCase().contains(q) ||
             (s['code'] as String).toLowerCase().contains(q);
    }).toList();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _goToModules(String subjectName) => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => StudentChapterModulePage(
        selectedCollege: widget.selectedCollege,
        branch:          widget.branch,
        semester:        widget.semester,
        subject:         subjectName,
        scheme:          widget.scheme,
        schemeId:        widget.schemeId,
        section:         widget.sectionName,
        sectionId:       widget.sectionId,
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
              branch:   widget.branch,
              semester: widget.semester,
              scheme:   widget.scheme,
              section:  widget.sectionName,
              topPad:   MediaQuery.of(context).padding.top,
            ),
            // ── Search bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _C.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.indigo100),
                  boxShadow: [
                    BoxShadow(
                      color: _C.indigo500.withOpacity(0.07),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search subjects…',
                    hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _C.indigo500, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.grey, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const _LoadingView();
    if (_error != null && _subjects.isEmpty) {
      return _ErrorView(error: _error!, onRetry: _initializeData);
    }
    if (_subjects.isEmpty) {
      return _EmptyView(
          branch:   widget.branch,
          semester: widget.semester,
          scheme:   widget.scheme,
          onRetry:  _initializeData);
    }

    final filtered = _filtered;

    return RefreshIndicator(
      color: _C.indigo500,
      onRefresh: _loadSubjects,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: filtered.length,
        itemBuilder: (_, i) {
          final s = filtered[i];

          final interval = CurvedAnimation(
            parent: _listCtrl,
            curve: Interval(
              (i / filtered.length) * 0.5,
              (i / filtered.length) * 0.5 + 0.5,
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
              child: _SubjectCard(
                name:   s['name']   as String,
                code:   s['code']   as String,
                accent: s['accent'] as Color,
                onTap:  () => _goToModules(s['name'] as String),
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
  final String semester;
  final String scheme;
  final String section;
  final double topPad;

  const _Header({
    required this.branch,
    required this.semester,
    required this.scheme,
    required this.section,
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
            padding: const EdgeInsets.only(top: 4, bottom: 28),
            child: Column(
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select Subject',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: _C.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                // Breadcrumb chip
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
                      Flexible(
                        child: Text(
                          '$branch  •  $semester  •  $scheme  •  $section',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
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
//  SUBJECT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SubjectCard extends StatelessWidget {
  final String name;
  final String code;
  final Color  accent;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.name,
    required this.code,
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
                  // ── Icon avatar ────────────────────────────
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
                    child: const Icon(Icons.menu_book_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),

                  // ── Text ──────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
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
                        if (code.isNotEmpty) ...[
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
                              code,
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
                        Text(
                          'Tap to view modules',
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
                  const SizedBox(width: 8),
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
        Text('Loading subjects…',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: _C.indigo700.withOpacity(0.65),
            fontWeight: FontWeight.w500,
          )),
        const SizedBox(height: 6),
        Text('Fetching available subjects',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.grey[500])),
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
          const Text('Could not load subjects',
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
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.grey[600])),
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
  final String semester;
  final String scheme;
  final VoidCallback onRetry;
  const _EmptyView({
    required this.branch,
    required this.semester,
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
            child: const Icon(Icons.menu_book_rounded,
                color: _C.indigo300, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('No Subjects Available',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _C.indigo900,
            )),
          const SizedBox(height: 8),
          Text(
            'No subjects found for $semester in $branch under $scheme.\nPlease contact your faculty.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.grey[600]),
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