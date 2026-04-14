import 'package:shiksha_hub/faculty/faculty_home.dart';
import 'package:shiksha_hub/faculty/f_notes/upload_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (mirrors ChapterModulePage exactly)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const indigo900 = Color(0xFF1A237E);
  static const indigo700 = Color(0xFF303F9F);
  static const indigo500 = Color(0xFF3F51B5);
  static const indigo300 = Color(0xFF7986CB);
  static const indigo100 = Color(0xFFC5CAE9);
  static const white = Colors.white;
  static const bg = Color(0xFFF0F2FA);

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
//  MODULE DATA
// ─────────────────────────────────────────────────────────────────────────────
const _kModules = ['Module 1', 'Module 2', 'Module 3', 'Module 4', 'Module 5'];

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class FacultyChapterModulePage extends StatefulWidget {
  final String selectedCollege;
  final String branch;
  final String scheme;
  final String? schemeId;
  final String semester;
  final String subject;
  final String section;
  final String sectionId;

  const FacultyChapterModulePage({
    super.key,
    required this.selectedCollege,
    required this.branch,
    required this.semester,
    required this.subject,
    required this.scheme,
    this.schemeId,
    required this.section,
    required this.sectionId,
  });

  @override
  State<FacultyChapterModulePage> createState() => _FacultyChapterModulePageState();
}

class _FacultyChapterModulePageState extends State<FacultyChapterModulePage>
    with SingleTickerProviderStateMixin {

  // PERFORMANCE: single controller, no BubblePainter / background animation
  late final AnimationController _listCtrl = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..forward();

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness:     Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _go(String module) => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => FacultyUploadPdfPage(
        selectedCollege: widget.selectedCollege,
        branch:          widget.branch,
        semester:        widget.semester,
        subject:         widget.subject,
        module:          module,
        scheme:          widget.scheme,
        schemeId:        widget.schemeId,
        section:         widget.section,
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
              section:  widget.section,
              subject:  widget.subject,
              topPad:   MediaQuery.of(context).padding.top,
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: _kModules.length,
                itemBuilder: (_, i) {
                  final interval = CurvedAnimation(
                    parent: _listCtrl,
                    curve: Interval(
                      (i / _kModules.length) * 0.5,
                      (i / _kModules.length) * 0.5 + 0.5,
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
                      child: _ModuleCard(
                        title:  _kModules[i],
                        accent: _C.accentFor(i),
                        index:  i,
                        onTap:  () => _go(_kModules[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
  final String subject;
  final double topPad;

  const _Header({
    required this.branch,
    required this.semester,
    required this.scheme,
    required this.section,
    required this.subject,
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
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _C.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Get.to(
                    () => const FacultyHomePage(),
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
                        Text(
                          'Home',
                          style: TextStyle(
                            color: _C.white,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select Module',
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          color: Colors.white.withOpacity(0.8),
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '$branch  •  $semester  •  $scheme  •  $section  •  $subject',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
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
//  MODULE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ModuleCard extends StatelessWidget {
  final String title;
  final Color accent;
  final int index;
  final VoidCallback onTap;

  const _ModuleCard({
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
                  // ── Number avatar ──────────────────────────
                  Container(
                    width: 52,
                    height: 52,
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
                        '${index + 1}',
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
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage materials and resources',
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
                    width: 32,
                    height: 32,
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