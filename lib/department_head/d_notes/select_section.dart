import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:shiksha_hub/department_head/d_notes/select_subject.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (mirrors select_scheme.dart / select_semester.dart)
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
    Color(0xFF1E88E5),
  ];

  static Color accentFor(int i) => _palette[i % _palette.length];
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class SectionSelectionPage extends StatefulWidget {
  final String selectedCollege;
  final String branch;
  final String scheme;
  final String? schemeId;
  final String semester;
  final String universityName;
  final String courseName;
  final String? semesterId;

  const SectionSelectionPage({
    super.key,
    required this.selectedCollege,
    required this.branch,
    required this.semester,
    required this.universityName,
    required this.courseName,
    required this.scheme,
    this.schemeId,
    this.semesterId,
  });

  @override
  State<SectionSelectionPage> createState() => _SectionSelectionPageState();
}

class _SectionSelectionPageState extends State<SectionSelectionPage>
    with SingleTickerProviderStateMixin {

  // PERFORMANCE: single controller, no BubblePainter / background animation
  late final AnimationController _listCtrl = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _sections = [];
  bool    _loading = true;
  String? _error;
  String? _semesterId;
  String? _branchId;

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
    await _loadSections();
  }

  Future<void> _resolveIds() async {
    try {
      if (widget.semesterId != null) {
        _semesterId = widget.semesterId;
        final doc = await FirebaseFirestore.instance
            .collection('semesters')
            .doc(_semesterId)
            .get();
        if (doc.exists) {
          _branchId = (doc.data() as Map<String, dynamic>)['branchId'];
        }
      } else {
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
      }
    } catch (e) {
      debugPrint('Error resolving IDs: $e');
    }
  }

  Future<void> _loadSections() async {
    try {
      setState(() { _loading = true; _error = null; });

      if (_semesterId == null) throw Exception('Semester ID not found');

      final snap = await FirebaseFirestore.instance
          .collection('sections')
          .where('semesterId', isEqualTo: _semesterId)
          .orderBy('name')
          .get();

      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d    = doc.data();
        final name = (d['name'] as String?) ?? 'Unknown Section';
        list.add({
          'id':            doc.id,
          'name':          name,
          'title':         name,
          'accent':        _C.accentFor(list.length),
          'createdByType': d['createdByType'] as String?,
          'data':          d,
        });
      }

      if (mounted) {
        setState(() { _sections = list; _loading = false; });
        if (list.isNotEmpty) _listCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Filtering ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _sections;
    return _sections
        .where((s) => (s['name'] as String).toLowerCase().contains(q))
        .toList();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _go(String sectionName, String sectionId) => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => SelectSubjectPage(
        selectedCollege: widget.selectedCollege,
        branch:          widget.branch,
        semester:        widget.semester,
        universityName:  widget.universityName,
        courseName:      widget.courseName,
        scheme:          widget.scheme,
        schemeId:        widget.schemeId,
        sectionName:     sectionName,
        sectionId:       sectionId,
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
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search sections…',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
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
    if (_error != null && _sections.isEmpty) {
      return _ErrorView(error: _error!, onRetry: _initializeData);
    }
    if (_sections.isEmpty) {
      return _EmptyView(
          branch: widget.branch,
          semester: widget.semester,
          onRetry: _initializeData);
    }

    final filtered = _filtered;

    return RefreshIndicator(
      color: _C.indigo500,
      onRefresh: _loadSections,
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
              child: _SectionCard(
                title:  s['title']  as String,
                accent: s['accent'] as Color,
                index:  i,
                onTap:  () => _go(s['name'] as String, s['id'] as String),
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
  final double topPad;

  const _Header({
    required this.branch,
    required this.semester,
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
                  'Select Section',
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
                      Text(
                        '$branch  •  $semester  •  $scheme',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
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
//  SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Color  accent;
  final int    index;
  final VoidCallback onTap;

  const _SectionCard({
    required this.title,
    required this.accent,
    required this.index,
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
                  // ── Letter avatar ──────────────────────────
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
                        title.isNotEmpty
                            ? title[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
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
        Text('Loading sections…',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: _C.indigo700.withOpacity(0.65),
            fontWeight: FontWeight.w500,
          )),
        const SizedBox(height: 6),
        Text('Fetching available sections',
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
          const Text('Could not load sections',
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
  final VoidCallback onRetry;
  const _EmptyView({
    required this.branch,
    required this.semester,
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
            child: const Icon(Icons.class_outlined,
                color: _C.indigo300, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('No Sections Available',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _C.indigo900,
            )),
          const SizedBox(height: 8),
          Text(
            'No sections found for $semester in $branch.\nContact your administrator to add sections.',
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