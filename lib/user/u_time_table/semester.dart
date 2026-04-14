// ignore_for_file: unused_field

import 'package:shiksha_hub/user/u_time_table/select_section.dart';
import 'package:shiksha_hub/user/user_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (mirrored from SemesterPage)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const indigo900 = Color(0xFF1A237E);
  static const indigo700 = Color(0xFF303F9F);
  static const indigo500 = Color(0xFF3F51B5);
  static const indigo300 = Color(0xFF7986CB);
  static const indigo100 = Color(0xFFC5CAE9);
  static const white     = Colors.white;
  static const bg        = Color(0xFFF0F2FA);

  // Alternating card accents (odd / even semester number)
  static Color accentFor(int n) => n.isOdd ? indigo500 : indigo900;
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class StudentSemesterPage extends StatefulWidget {
  final String selectedCollege;
  final String branchId;
  final String branchName;

  const StudentSemesterPage({
    super.key,
    required this.branchId,
    required this.branchName,
    required this.selectedCollege,
  });

  @override
  State<StudentSemesterPage> createState() => _StudentSemesterPageState();
}

class _StudentSemesterPageState extends State<StudentSemesterPage>
    with SingleTickerProviderStateMixin {

  // PERFORMANCE: single lightweight AnimationController (no BubblePainter)
  late final AnimationController _listCtrl = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  List<Map<String, dynamic>> _semesters = [];
  bool    _loading = true;
  String? _error;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
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

  // ── Helpers ──────────────────────────────────────────────────────────────────
  static int _semNum(String name) {
    final m = RegExp(r'\d+').firstMatch(name);
    return m != null ? int.parse(m.group(0)!) : 0;
  }

  // ── Data ─────────────────────────────────────────────────────────────────────
  // PERFORMANCE: Future-based load instead of StreamBuilder
  // avoids continuous rebuilds on every Firestore snapshot.
  Future<void> _loadSemesters() async {
    try {
      setState(() { _loading = true; _error = null; });

      if (widget.branchId.isEmpty) throw Exception('Branch ID is required');

      final snap = await FirebaseFirestore.instance
          .collection('semesters')
          .where('branchId', isEqualTo: widget.branchId)
          .orderBy('name')
          .get();

      final list = snap.docs.map((doc) {
        final d             = doc.data();
        final name          = (d['name'] as String?) ?? 'Unknown Semester';
        final num           = _semNum(name);
        final createdByType = d['createdByType']?.toString();
        return {
          'id':            doc.id,
          'title':         name,
          'semesterNum':   num,
          'accent':        _C.accentFor(num),
          'createdByType': createdByType,
          'data':          d,
        };
      }).toList();

      list.sort((a, b) =>
          (a['semesterNum'] as int).compareTo(b['semesterNum'] as int));

      if (mounted) {
        setState(() { _semesters = list; _loading = false; });
        if (list.isNotEmpty) {
          _listCtrl
            ..reset()
            ..forward();
        }
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────────
  void _goToSection(String semesterId, String semesterName) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => StudentSelectSectionPage(
          selectedCollege: widget.selectedCollege,
          branchId:        widget.branchId,
          branchName:      widget.branchName,
          semesterId:      semesterId,
          semesterName:    semesterName,
          branch:          widget.branchName,
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
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────────
  void _showOptionsSheet(int index) {
    final sem   = _semesters[index];
    final title = sem['title'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: _C.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _OptionsSheet(
        title:           title,
        createdByType:   sem['createdByType'] as String?,
        branchName:      widget.branchName,
        semesterData:    sem['data'] as Map<String, dynamic>,
        onViewTimetable: () {
          Navigator.pop(context);
          _goToSection(sem['id'] as String, title);
        },
        onViewInfo: () {
          Navigator.pop(context);
          _showSemesterInfo(sem['data'] as Map<String, dynamic>);
        },
      ),
    );
  }

  // ── Semester info dialog ──────────────────────────────────────────────────────
  void _showSemesterInfo(Map<String, dynamic> data) {
    final createdByType = data['createdByType']?.toString();
    final createdAt     = data['createdAt'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          data['name'] ?? 'Semester Information',
          style: const TextStyle(
            fontFamily:  'Poppins',
            fontWeight:  FontWeight.w700,
            color:       _C.indigo900,
            fontSize:    16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Branch',     value: widget.branchName),
            if (createdByType != null)
              _InfoRow(label: 'Created by', value: createdByType.toUpperCase()),
            if (createdAt != null)
              _InfoRow(
                label: 'Created on',
                value: (createdAt as Timestamp)
                    .toDate()
                    .toString()
                    .split(' ')[0],
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.indigo500,
              foregroundColor: _C.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close',
                style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
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
              topPad:     MediaQuery.of(context).padding.top,
              branchName: widget.branchName,
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
      return _EmptyView(branchName: widget.branchName, onRetry: _loadSemesters);
    }

    return RefreshIndicator(
      color: _C.indigo500,
      onRefresh: _loadSemesters,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        itemCount: _semesters.length,
        // PERFORMANCE: RepaintBoundary isolates each card repaint
        itemBuilder: (_, i) {
          final s      = _semesters[i];
          final accent = s['accent'] as Color;

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
                title:          s['title']         as String,
                semesterNum:    s['semesterNum']   as int,
                accent:         accent,
                createdByType:  s['createdByType'] as String?,
                onTap:          () => _goToSection(s['id'] as String, s['title'] as String),
                onOptions:      () => _showOptionsSheet(i),
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
  final double topPad;
  final String branchName;
  const _Header({required this.topPad, required this.branchName});

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
            color:      Color(0x553F51B5),
            blurRadius: 20,
            offset:     Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // top bar
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
                              color:      _C.white,
                              fontSize:   13,
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

          // title block
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 28),
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
                  'Select Semester',
                  style: TextStyle(
                    fontFamily:  'Poppins',
                    fontSize:    26,
                    fontWeight:  FontWeight.w700,
                    color:       _C.white,
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
                        branchName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize:   12,
                          color:      Colors.white.withOpacity(0.9),
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
//  SEMESTER CARD  (student variant — adds createdByType badge)
// ─────────────────────────────────────────────────────────────────────────────
class _SemesterCard extends StatelessWidget {
  final String  title;
  final int     semesterNum;
  final Color   accent;
  final String? createdByType;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  const _SemesterCard({
    required this.title,
    required this.semesterNum,
    required this.accent,
    this.createdByType,
    required this.onTap,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap:       onTap,
          onLongPress: onOptions,
          borderRadius: BorderRadius.circular(20),
          splashColor: _C.indigo300.withOpacity(0.15),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.11), Colors.white],
                begin: Alignment.centerLeft,
                end:   Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.indigo100),
              boxShadow: [
                BoxShadow(
                  color:      accent.withOpacity(0.10),
                  blurRadius: 10,
                  offset:     const Offset(0, 4),
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
                        end:   Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:      accent.withOpacity(0.30),
                          blurRadius: 8,
                          offset:     const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        semesterNum > 0 ? '$semesterNum' : '?',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize:   20,
                          fontWeight: FontWeight.w800,
                          color:      Colors.white,
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
                            fontSize:   15,
                            fontWeight: FontWeight.w700,
                            color:      _C.indigo900,
                          ),
                          maxLines:  1,
                          overflow:  TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View timetables and schedules',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize:   11.5,
                            color:      _C.indigo700.withOpacity(0.60),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Actions ───────────────────────────────
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onOptions,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color:        _C.indigo500.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.more_vert,
                          color: _C.indigo500, size: 16),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color:        _C.indigo500.withOpacity(0.10),
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
//  OPTIONS BOTTOM SHEET  (student variant — view timetable + semester info)
// ─────────────────────────────────────────────────────────────────────────────
class _OptionsSheet extends StatelessWidget {
  final String                title;
  final String?               createdByType;
  final String                branchName;
  final Map<String, dynamic>  semesterData;
  final VoidCallback          onViewTimetable;
  final VoidCallback          onViewInfo;

  const _OptionsSheet({
    required this.title,
    required this.createdByType,
    required this.branchName,
    required this.semesterData,
    required this.onViewTimetable,
    required this.onViewInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize:   16,
                fontWeight: FontWeight.w700,
                color:      _C.indigo900,
              )),
          const SizedBox(height: 12),
          _SheetTile(
            icon:  Icons.calendar_month_outlined,
            color: _C.indigo900,
            label: 'View Timetable',
            onTap: onViewTimetable,
          ),
          _SheetTile(
            icon:  Icons.info_outline_rounded,
            color: _C.indigo500,
            label: 'Semester Information',
            onTap: onViewInfo,
          ),
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       label;
  final VoidCallback onTap;
  const _SheetTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color:        color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
    title: Text(label,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize:   14,
          fontWeight: FontWeight.w500,
        )),
    trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
    onTap:  onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPER WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            )),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontFamily: 'Poppins')),
        ),
      ],
    ),
  );
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
              fontSize:   15,
              color:      _C.indigo700.withOpacity(0.65),
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 6),
        Text('Fetching semester list',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize:   12,
              color:      Colors.grey[500],
            )),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String       error;
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
              color:  Colors.red.withOpacity(0.08),
              shape:  BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Could not load semesters',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize:   17,
                fontWeight: FontWeight.w700,
                color:      _C.indigo900,
              )),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize:   13,
                  color:      Colors.grey[600])),
          const SizedBox(height: 24),
          _PillButton(
              label: 'Try Again',
              icon:  Icons.refresh,
              color: _C.indigo500,
              onTap: onRetry),
        ],
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  final String       branchName;
  final VoidCallback onRetry;
  const _EmptyView({required this.branchName, required this.onRetry});

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
            child: const Icon(Icons.calendar_month_outlined,
                color: _C.indigo300, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('No Semesters Available',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize:   17,
                fontWeight: FontWeight.w700,
                color:      _C.indigo900,
              )),
          const SizedBox(height: 8),
          Text(
            'No semesters found for $branchName.\nPlease contact your faculty.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize:   13,
                color:      Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          _PillButton(
              label: 'Refresh',
              icon:  Icons.refresh,
              color: _C.indigo500,
              onTap: onRetry),
        ],
      ),
    ),
  );
}

class _PillButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
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
    icon:  Icon(icon, size: 17),
    label: Text(label,
        style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize:   13)),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30)),
      elevation:   3,
      shadowColor: color.withOpacity(0.4),
    ),
  );
}