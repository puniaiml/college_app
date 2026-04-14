// ignore_for_file: avoid_print

import 'dart:io';
import 'package:shiksha_hub/department_head/d_notes/view_pdf.dart';
import 'package:shiksha_hub/department_head/hod_home.dart';
import 'package:shiksha_hub/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

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
  ];

  static Color accentFor(int i) => _palette[i % _palette.length];
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class UploadPdfPage extends StatefulWidget {
  final String  selectedCollege;
  final String  branch;
  final String  scheme;
  final String? schemeId;
  final String  semester;
  final String  subject;
  final String  module;
  final String  section;
  final String  sectionId;

  const UploadPdfPage({
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
  State<UploadPdfPage> createState() => _UploadPdfPageState();
}

class _UploadPdfPageState extends State<UploadPdfPage>
    with SingleTickerProviderStateMixin {

  // PERFORMANCE: single controller, no BubblePainter / background animation
  late final AnimationController _listCtrl = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..forward();

  PlatformFile? _pickedFile;
  UploadTask?   _uploadTask;
  int           _refreshKey = 0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness:     Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  // ── File picking ────────────────────────────────────────────────────────────
  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return;
    setState(() => _pickedFile = result.files.first);
  }

  // ── Upload ──────────────────────────────────────────────────────────────────
  Future<void> _uploadFile() async {
    if (_pickedFile == null) {
      _snack('Please select a PDF file first', Colors.redAccent);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final path =
        'Notes/${widget.selectedCollege}/${widget.branch}/${widget.scheme}'
        '/${widget.semester}/${widget.section}/${widget.subject}'
        '/${widget.module}/${_pickedFile!.name}';

    final filePath = _pickedFile!.path;
    if (filePath == null) return;

    final ref = FirebaseStorage.instance.ref().child(path);
    setState(() => _uploadTask = ref.putFile(File(filePath)));

    try {
      final snapshot    = await _uploadTask!.whenComplete(() {});
      final urlDownload = await snapshot.ref.getDownloadURL();
      final fileSize    = await snapshot.ref
          .getMetadata()
          .then((m) => m.size);

      await _firestore.collection('notes').add({
        'name':           _pickedFile!.name,
        'url':            urlDownload,
        'fileName':       _pickedFile!.name,
        'fileSize':       fileSize,
        'college':        widget.selectedCollege,
        'branch':         widget.branch,
        'scheme':         widget.scheme,
        'schemeId':       widget.schemeId,
        'semester':       widget.semester,
        'section':        widget.section,
        'sectionId':      widget.sectionId,
        'subject':        widget.subject,
        'module':         widget.module,
        'uploadedBy':     user!.uid,
        'uploadedByName': user.displayName ?? 'HOD',
        'uploadedAt':     FieldValue.serverTimestamp(),
        'downloadCount':  0,
        'status':         'active',
      });

      setState(() {
        _uploadTask  = null;
        _pickedFile  = null;
        _refreshKey++;
      });

      _snack('File uploaded successfully!', _C.indigo500);

      await NotificationService.notifyNotesUpload(
        college:        widget.selectedCollege,
        branch:         widget.branch,
        semester:       widget.semester,
        subject:        widget.subject,
        module:         widget.module,
        fileName:       _pickedFile?.name ?? '',
        uploadedByName: user.displayName ?? 'HOD',
        scheme:         widget.scheme,
      );

      print('Download-Link: $urlDownload');
    } catch (e) {
      print('Upload error: $e');
      _snack('Upload failed: $e', Colors.redAccent);
      setState(() => _uploadTask = null);
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

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _goViewPdf() => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => ViewPdfPage(
        key:            ValueKey(_refreshKey),
        selectedCollege: widget.selectedCollege,
        branch:          widget.branch,
        semester:        widget.semester,
        subject:         widget.subject,
        module:          widget.module,
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

  // ── Action definitions ──────────────────────────────────────────────────────
  List<_ActionItem> get _actions => [
    _ActionItem(
      title:    'Select PDF',
      subtitle: 'Choose a PDF file from your device',
      icon:     Icons.file_open_rounded,
      accent:   _C.accentFor(0),
      onTap:    _selectFile,
    ),
    _ActionItem(
      title:    'Upload PDF',
      subtitle: 'Upload the selected file to the cloud',
      icon:     Icons.cloud_upload_rounded,
      accent:   _C.accentFor(1),
      onTap:    _uploadFile,
    ),
    _ActionItem(
      title:    'View Uploaded PDFs',
      subtitle: 'Browse all notes for this module',
      icon:     Icons.menu_book_rounded,
      accent:   _C.accentFor(2),
      onTap:    _goViewPdf,
    ),
  ];

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
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // ── Selected file banner ─────────────────────────────────
                  if (_pickedFile != null) ...[
                    _FileBanner(
                      fileName:   _pickedFile!.name,
                      uploadTask: _uploadTask,
                      onClear:    () => setState(() => _pickedFile = null),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // ── Action cards ─────────────────────────────────────────
                  ..._actions.asMap().entries.map((e) {
                    final i    = e.key;
                    final item = e.value;

                    final interval = CurvedAnimation(
                      parent: _listCtrl,
                      curve: Interval(
                        (i / _actions.length) * 0.5,
                        (i / _actions.length) * 0.5 + 0.5,
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
                        child: _ActionCard(
                          item:  item,
                          index: i,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACTION ITEM MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _ActionItem {
  final String       title;
  final String       subtitle;
  final IconData     icon;
  final Color        accent;
  final VoidCallback onTap;
  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
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
  final String module;
  final double topPad;

  const _Header({
    required this.branch,
    required this.semester,
    required this.scheme,
    required this.section,
    required this.subject,
    required this.module,
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
                  'Upload PDF',
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
//  FILE BANNER  (shown when a file is picked)
// ─────────────────────────────────────────────────────────────────────────────
class _FileBanner extends StatelessWidget {
  final String      fileName;
  final UploadTask? uploadTask;
  final VoidCallback onClear;

  const _FileBanner({
    required this.fileName,
    required this.uploadTask,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.indigo100),
        boxShadow: [
          BoxShadow(
            color: _C.indigo500.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selected File',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      )),
                    Text(fileName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _C.indigo900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.grey, size: 18),
                onPressed: onClear,
              ),
            ],
          ),
          if (uploadTask != null) ...[
            const SizedBox(height: 10),
            StreamBuilder<TaskSnapshot>(
              stream: uploadTask!.snapshotEvents,
              builder: (_, snap) {
                final progress = snap.hasData
                    ? snap.data!.bytesTransferred / snap.data!.totalBytes
                    : 0.0;
                final pct =
                    (progress * 100).toStringAsFixed(0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Uploading…',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: _C.indigo700.withOpacity(0.7),
                          )),
                        Text('$pct%',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _C.indigo500,
                          )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: _C.indigo100,
                        valueColor: const AlwaysStoppedAnimation(_C.indigo500),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final _ActionItem item;
  final int         index;

  const _ActionCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: _C.indigo300.withOpacity(0.15),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [item.accent.withOpacity(0.11), Colors.white],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.indigo100, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: item.accent.withOpacity(0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  // ── Icon avatar ──────────────────────────
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          item.accent,
                          item.accent.withOpacity(0.72)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: item.accent.withOpacity(0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(item.icon,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),

                  // ── Text ──────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _C.indigo900,
                          )),
                        const SizedBox(height: 4),
                        Text(item.subtitle,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            color: _C.indigo700.withOpacity(0.60),
                            fontWeight: FontWeight.w400,
                          )),
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