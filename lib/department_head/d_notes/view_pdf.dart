// ignore_for_file: avoid_print

import 'package:shiksha_hub/department_head/hod_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../utils/auth_utils_user_specific_pdf_access.dart';
import '../../utils/pdf_viewer_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS
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
class ViewPdfPage extends StatefulWidget {
  final String  selectedCollege;
  final String  branch;
  final String  scheme;
  final String? schemeId;
  final String  semester;
  final String  subject;
  final String  module;
  final String  section;
  final String  sectionId;

  const ViewPdfPage({
    super.key,
    required this.selectedCollege,
    required this.branch,
    required this.semester,
    required this.subject,
    required this.module,
    required this.scheme,
    this.schemeId,
    required this.section,
    required this.sectionId,
  });

  @override
  State<ViewPdfPage> createState() => _ViewPdfPageState();
}

class _ViewPdfPageState extends State<ViewPdfPage>
    with SingleTickerProviderStateMixin {

  // PERFORMANCE: single controller, no BubblePainter / background animation
  late final AnimationController _listCtrl = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _pdfData   = [];
  bool _loading = true;
  bool _hasData = false;

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness:     Brightness.dark,
    ));
    _fetchPdfs();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  Future<void> _fetchPdfs() async {
    setState(() => _loading = true);

    try {
      Query query = _firestore
          .collection('notes')
          .where('college',  isEqualTo: widget.selectedCollege)
          .where('branch',   isEqualTo: widget.branch)
          .where('semester', isEqualTo: widget.semester)
          .where('section',  isEqualTo: widget.section)
          .where('subject',  isEqualTo: widget.subject)
          .where('module',   isEqualTo: widget.module);

      if (widget.scheme.isNotEmpty) {
        query = query.where('scheme', isEqualTo: widget.scheme);
      }

      query = query.orderBy('uploadedAt', descending: true).limit(50);

      final snap = await query.get();

      if (!mounted) return;

      final results = snap.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        d['docId']  = doc.id;
        d['name']  ??= d['title'] ?? 'Untitled Document';
        d['url']   ??= d['fileUrl'] ?? '';
        d['scheme'] ??= widget.scheme.isNotEmpty ? widget.scheme : 'Default';
        return d;
      }).toList();

      setState(() {
        _pdfData  = results;
        _hasData  = results.isNotEmpty;
        _loading  = false;
      });

      _listCtrl.reset();
      if (_hasData) _listCtrl.forward();
    } catch (e) {
      print('Error fetching PDFs: $e');
      if (!mounted) return;
      setState(() { _loading = false; _hasData = false; });
      _snack('Error loading notes: $e', Colors.redAccent);
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────
  Future<void> _deletePdf(String docId, String name, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 26),
            SizedBox(width: 10),
            Text('Delete Note',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$name"?\n\nThis action cannot be undone.',
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: _C.indigo500),
        ),
      );

      await _firestore.collection('notes').doc(docId).delete();

      setState(() {
        _pdfData.removeAt(index);
        _hasData = _pdfData.isNotEmpty;
      });

      if (mounted) Navigator.pop(context);
      _snack('Note deleted successfully', Colors.green);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _snack('Error deleting note: $e', Colors.redAccent);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

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
              module:   widget.module,
              topPad:   MediaQuery.of(context).padding.top,
              onRefresh: _fetchPdfs,
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(
                  color: _C.indigo500, strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text('Loading notes…',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                color: _C.indigo700,
                fontWeight: FontWeight.w500,
              )),
          ],
        ),
      );
    }

    if (!_hasData) {
      return RefreshIndicator(
        color: _C.indigo500,
        onRefresh: _fetchPdfs,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _C.indigo100.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.library_books_outlined,
                        color: _C.indigo300, size: 44),
                  ),
                  const SizedBox(height: 16),
                  const Text('No Notes Found',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _C.indigo900,
                    )),
                  const SizedBox(height: 8),
                  Text('Upload some notes to get started.',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _C.indigo500,
      onRefresh: _fetchPdfs,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _pdfData.length,
        itemBuilder: (_, i) {
          final pdf   = _pdfData[i];
          final title = pdf['name'] as String? ?? 'Untitled';
          final url   = pdf['url']  as String? ?? '';
          final docId = pdf['docId'] as String? ?? '';

          final interval = CurvedAnimation(
            parent: _listCtrl,
            curve: Interval(
              (i / _pdfData.length) * 0.5,
              (i / _pdfData.length) * 0.5 + 0.5,
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
              child: _PdfCard(
                title:    title,
                accent:   _C.accentFor(i),
                onTap:    url.isNotEmpty
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(
                            pdfUrl:  url,
                            pdfName: title,
                            userId:  AuthUtils.uid,
                          ),
                        ))
                    : () => _snack(
                        'PDF URL not available', Colors.redAccent),
                onDelete: () => _deletePdf(docId, title, i),
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
  final String   branch;
  final String   semester;
  final String   scheme;
  final String   section;
  final String   subject;
  final String   module;
  final double   topPad;
  final VoidCallback onRefresh;

  const _Header({
    required this.branch,
    required this.semester,
    required this.scheme,
    required this.section,
    required this.subject,
    required this.module,
    required this.topPad,
    required this.onRefresh,
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
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: _C.white, size: 20),
                  onPressed: onRefresh,
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => Get.to(
                    () => const HodHome(),
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
                        Icon(Icons.home_rounded,
                            color: _C.white, size: 16),
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
                  'Available Notes',
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
                        Icon(Icons.account_tree_outlined,
                            color: Colors.white.withOpacity(0.8),
                            size: 13),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '$branch  •  $semester  •  $scheme  •  $section  •  $subject  •  $module',
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
//  PDF CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PdfCard extends StatelessWidget {
  final String       title;
  final Color        accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PdfCard({
    required this.title,
    required this.accent,
    required this.onTap,
    required this.onDelete,
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
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  // ── PDF icon avatar ────────────────────────
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
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),

                  // ── Title ─────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _C.indigo900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text('Tap to view',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            color: _C.indigo700.withOpacity(0.60),
                            fontWeight: FontWeight.w400,
                          )),
                      ],
                    ),
                  ),

                  // ── Delete button ─────────────────────────
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 18),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // ── Arrow ─────────────────────────────────
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