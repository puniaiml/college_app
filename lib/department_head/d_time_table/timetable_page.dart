import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shiksha_hub/services/notification_service.dart';
import 'package:shiksha_hub/utils/theme_helper.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class ClassDetails {
  String startTime;
  String endTime;
  String subject;
  String facultyId;
  String facultyName;
  String type;

  ClassDetails({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.facultyId,
    required this.facultyName,
    required this.type,
  });

  ClassDetails copyWith({
    String? startTime,
    String? endTime,
    String? subject,
    String? facultyId,
    String? facultyName,
    String? type,
  }) =>
      ClassDetails(
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        subject: subject ?? this.subject,
        facultyId: facultyId ?? this.facultyId,
        facultyName: facultyName ?? this.facultyName,
        type: type ?? this.type,
      );

  Map<String, dynamic> toJson() => {
        'startTime': startTime,
        'endTime': endTime,
        'subject': subject,
        'facultyId': facultyId,
        'facultyName': facultyName,
        'type': type,
      };

  factory ClassDetails.fromJson(Map<String, dynamic> json) => ClassDetails(
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        facultyId: json['facultyId'] as String? ?? '',
        facultyName: json['facultyName'] as String? ?? '',
        type: json['type'] as String? ?? 'Class',
      );
}

class FacultyInfo {
  final String id;
  final String name;
  final String branchName;
  final String email;
  final String role;
  final bool isHOD;

  const FacultyInfo({
    required this.id,
    required this.name,
    required this.branchName,
    required this.email,
    required this.role,
    this.isHOD = false,
  });

  factory FacultyInfo.fromMap(String id, Map<String, dynamic> data) =>
      FacultyInfo(
        id: id,
        name: data['name'] as String? ?? 'Unknown Faculty',
        branchName: data['branchName'] as String? ?? 'Unknown Branch',
        email: data['email'] as String? ?? '',
        role: data['role'] as String? ?? 'Faculty',
        isHOD: false,
      );

  factory FacultyInfo.fromHODMap(String id, Map<String, dynamic> data) =>
      FacultyInfo(
        id: id,
        name: data['name'] as String? ?? 'Unknown HOD',
        branchName: data['branchName'] as String? ?? 'Unknown Branch',
        email: data['email'] as String? ?? '',
        role: 'Head of Department',
        isHOD: true,
      );
}

enum TimetableLoadingState { initial, loading, loaded, error }

// ─── Design tokens ────────────────────────────────────────────────────────────

class _T {
  // Surfaces
  static const Color surface = Color(0xFFF7F6F2);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEBEBEB);

  // Text
  static const Color text = Color(0xFF1A1A1A);
  static const Color text2 = Color(0xFF666666);
  static const Color text3 = Color(0xFF999999);

  // Accent palette for class rows
  static const List<Color> palette = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
  ];

  // Semantic
  static const Color breakColor = Color(0xFFEF6C00);
  static const Color breakLight = Color(0xFFFFF3E0);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color warnColor = Color(0xFFD97706);
  static const Color warnLight = Color(0xFFFFFBEB);

  static Color rowAccent(int index, {bool isBreak = false}) =>
      isBreak ? breakColor : palette[index % palette.length];

  static LinearGradient avatarGrad(String id, {bool isHod = false}) {
    if (isHod) {
      return const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    final idx = id.hashCode.abs() % palette.length;
    return LinearGradient(
      colors: [palette[idx], palette[(idx + 1) % palette.length]],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class TimetablePage extends StatefulWidget {
  final String selectedCollege;
  final String branchId;
  final String branchName;
  final String semesterId;
  final String semesterName;
  final String sectionId;
  final String sectionName;
  final String branch;
  final String semester;
  final String section;

  const TimetablePage({
    super.key,
    required this.selectedCollege,
    required this.branchId,
    required this.branchName,
    required this.semesterId,
    required this.semesterName,
    required this.sectionId,
    required this.sectionName,
    required this.branch,
    required this.semester,
    required this.section,
  });

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  List<ClassDetails> classDetails = [];
  List<FacultyInfo> availableFaculties = [];
  List<FacultyInfo> filteredFaculties = [];
  String selectedDay = '';
  TimetableLoadingState loadingState = TimetableLoadingState.initial;
  bool isSaving = false;
  bool isFacultyLoading = false;
  String? errorMessage;

  // ── Controllers ────────────────────────────────────────────────────────────
  late AnimationController _listAnimController;
  final TextEditingController _facultySearchController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  // ── Cache ──────────────────────────────────────────────────────────────────
  final Map<String, DateTime?> _timeCache = {};

  // ── Theme (cached in build) ────────────────────────────────────────────────
  late Color _primaryColor;
  late Color _successColor;
  late Color _warningColor;
  late Color _errorColor;
  late Color _cardColor;
  late Color _surfaceColor;
  late Color _textColor;

  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    selectedDay = DateFormat('EEEE').format(DateTime.now());
    _loadInitialData();
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    _facultySearchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  String get _documentId => widget.sectionId;

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      loadingState = TimetableLoadingState.loading;
      errorMessage = null;
    });
    try {
      await Future.wait([loadTimetable(selectedDay), _loadFaculties()]);
      if (mounted) {
        setState(() => loadingState = TimetableLoadingState.loaded);
        _listAnimController.forward(from: 0);
      }
    } catch (e, st) {
      _handleError(e, st, contextMsg: 'loading timetable and faculties');
    }
  }

  Future<void> _loadFaculties() async {
    if (!mounted) return;
    setState(() => isFacultyLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .where('isActive', isEqualTo: true)
          .where('accountStatus', isEqualTo: 'active')
          .get();

      final faculties = snapshot.docs
          .map((d) => FacultyInfo.fromMap(d.id, d.data()))
          .toList();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final hodDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc('department_head')
            .collection('data')
            .doc(currentUser.uid)
            .get();

        if (hodDoc.exists) {
          final d = hodDoc.data()!;
          if ((d['isActive'] ?? false) && d['accountStatus'] == 'active') {
            faculties.insert(0, FacultyInfo.fromHODMap(currentUser.uid, d));
          }
        }
      }

      faculties.sort((a, b) {
        if (a.isHOD != b.isHOD) return a.isHOD ? -1 : 1;
        if (a.branchName == widget.branchName &&
            b.branchName != widget.branchName) return -1;
        if (a.branchName != widget.branchName &&
            b.branchName == widget.branchName) return 1;
        return a.name.compareTo(b.name);
      });

      if (mounted) {
        setState(() {
          availableFaculties = faculties;
          filteredFaculties = faculties;
        });
      }
    } catch (e) {
      _handleError(e, null, contextMsg: 'loading faculties');
    } finally {
      if (mounted) setState(() => isFacultyLoading = false);
    }
  }

  void _onSearchChanged(String query, String branchFilter,
      void Function(void Function()) setDialogState) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setDialogState(() => _applyFilter(query, branchFilter));
    });
  }

  void _applyFilter(String query, String branchFilter) {
    var base = branchFilter == 'all'
        ? availableFaculties
        : availableFaculties
            .where((f) => f.branchName == branchFilter || f.isHOD)
            .toList();

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      base = base
          .where((f) =>
              f.name.toLowerCase().contains(q) ||
              f.branchName.toLowerCase().contains(q) ||
              f.email.toLowerCase().contains(q) ||
              f.role.toLowerCase().contains(q))
          .toList();
    }
    filteredFaculties = base;
  }

  Future<void> loadTimetable(String day) async {
    if (!mounted) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('timetables')
          .doc(_documentId)
          .get();

      if (!mounted) return;
      setState(() {
        _timeCache.clear();
        if (doc.exists) {
          final raw = doc.data()?[day] as List<dynamic>?;
          classDetails = raw
                  ?.map((j) =>
                      ClassDetails.fromJson(j as Map<String, dynamic>))
                  .toList() ??
              [];
          classDetails.sort((a, b) {
            final ta = _parseTime(a.startTime);
            final tb = _parseTime(b.startTime);
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return ta.compareTo(tb);
          });
        } else {
          classDetails = [];
        }
      });
    } catch (e) {
      _handleError(e, null, contextMsg: 'loading timetable');
    }
  }

  // ── Time helpers ───────────────────────────────────────────────────────────

  DateTime? _parseTime(String t) {
    if (t.isEmpty) return null;
    return _timeCache.putIfAbsent(t, () {
      try {
        final parts = t.split(' ');
        if (parts.length != 2) return null;
        final hm = parts[0].split(':');
        if (hm.length != 2) return null;
        int h = int.parse(hm[0]);
        final m = int.parse(hm[1]);
        final pm = parts[1].toLowerCase() == 'pm';
        final am = parts[1].toLowerCase() == 'am';
        if (pm && h != 12) h += 12;
        if (am && h == 12) h = 0;
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, h, m);
      } catch (_) {
        return null;
      }
    });
  }

  bool _hasTimeConflict(String start, String end, int currentIndex) {
    if (start.isEmpty || end.isEmpty) return false;
    final s = _parseTime(start);
    final e = _parseTime(end);
    if (s == null || e == null) return false;
    if (!s.isBefore(e)) return true;
    for (int i = 0; i < classDetails.length; i++) {
      if (i == currentIndex) continue;
      final d = classDetails[i];
      if (d.startTime.isEmpty || d.endTime.isEmpty) continue;
      final ds = _parseTime(d.startTime);
      final de = _parseTime(d.endTime);
      if (ds == null || de == null) continue;
      if (s.isBefore(de) && e.isAfter(ds)) return true;
    }
    return false;
  }

  String _shortTime(String t) {
    if (t.isEmpty) return '';
    final parts = t.split(' ');
    if (parts.length < 2) return t;
    final hm = parts[0].split(':');
    final h = int.tryParse(hm[0]) ?? 0;
    final m = int.tryParse(hm.length > 1 ? hm[1] : '0') ?? 0;
    final period = parts[1].toLowerCase();
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return m == 0
        ? '$h12 ${period.toUpperCase()}'
        : '$h12:${m.toString().padLeft(2, '0')}';
  }

  String _duration(String s, String e) {
    final st = _parseTime(s), en = _parseTime(e);
    if (st == null || en == null) return '';
    final d = en.difference(st);
    final h = d.inHours, m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> uploadTimetable() async {
    FocusScope.of(context).unfocus();
    if (classDetails.isEmpty) {
      _showSnack('No classes to save', isError: true);
      return;
    }
    final errors = _validateTimetable();
    if (errors.isNotEmpty) {
      _showValidationErrors(errors);
      return;
    }
    if (!mounted) return;
    setState(() => isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('timetables')
          .doc(_documentId)
          .set({
        selectedDay: classDetails.map((d) => d.toJson()).toList(),
        'metadata': {
          'sectionId': widget.sectionId,
          'sectionName': widget.sectionName,
          'branchId': widget.branchId,
          'branchName': widget.branchName,
          'semesterId': widget.semesterId,
          'semesterName': widget.semesterName,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': 'hod',
        },
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => isSaving = false);
        _showSnack('Timetable saved successfully!');
        HapticFeedback.lightImpact();
      }

      final user = FirebaseAuth.instance.currentUser;
      await NotificationService.notifyTimetableUpdate(
        sectionId: widget.sectionId,
        sectionName: widget.sectionName,
        college: widget.selectedCollege,
        branch: widget.branchName,
        semester: widget.semesterName,
        updatedByName: user?.displayName ?? 'HOD',
        day: selectedDay,
      );
    } catch (e) {
      if (mounted) setState(() => isSaving = false);
      _handleError(e, null, contextMsg: 'saving timetable');
      HapticFeedback.heavyImpact();
    }
  }

  List<String> _validateTimetable() {
    final errors = <String>[];
    for (int i = 0; i < classDetails.length; i++) {
      final d = classDetails[i];
      if (d.startTime.isEmpty || d.endTime.isEmpty) {
        errors.add(
            'Set time for ${d.type == "Break" ? "break" : "class"} ${i + 1}');
        continue;
      }
      if (d.type != 'Break') {
        if (d.subject.isEmpty) errors.add('Enter subject for class ${i + 1}');
        if (d.facultyId.isEmpty)
          errors.add('Select faculty for class ${i + 1}');
      }
      if (_hasTimeConflict(d.startTime, d.endTime, i)) {
        errors.add('Time conflict in ${d.type.toLowerCase()} ${i + 1}');
      }
    }
    return errors;
  }

  // ── Dialogs / snacks ───────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(
              isError ? Icons.error_outline : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(msg,
              style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ),
      ]),
      backgroundColor: isError ? _T.errorColor : _T.successColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      duration: Duration(seconds: isError ? 4 : 3),
    ));
  }

  void _handleError(Object e, StackTrace? st, {String? contextMsg}) {
    String msg;
    if (e is FirebaseException) {
      msg = e.message ?? 'Firebase error (${e.code})';
    } else if (e is PlatformException) {
      msg = e.message ?? 'Platform error';
    } else if (e is SocketException) {
      msg = 'No internet connection. Please try again.';
    } else {
      msg = e.toString();
    }

    if (!mounted) return;
    setState(() {
      loadingState = TimetableLoadingState.error;
      errorMessage = msg;
      isSaving = false;
      isFacultyLoading = false;
    });

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _T.errorLight,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.error_outline_rounded,
                color: _T.errorColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Something went wrong',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ]),
        content: Text(
          contextMsg != null ? '$contextMsg\n\n$msg' : msg,
          style: GoogleFonts.dmSans(fontSize: 14, color: _T.text2),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadInitialData();
            },
            child: Text('Retry',
                style: GoogleFonts.dmSans(
                    color: _primaryColor, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                  ClipboardData(text: 'Error: $e\n${st ?? ''}'));
              if (ctx.mounted) Navigator.pop(ctx);
              _showSnack('Copied to clipboard');
            },
            child: Text('Copy',
                style: GoogleFonts.dmSans(
                    color: _T.warnColor, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Dismiss',
                style: GoogleFonts.dmSans(color: _T.text3)),
          ),
        ],
      ),
    );
  }

  void _showValidationErrors(List<String> errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _T.errorLight,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.warning_amber_rounded,
                color: _T.errorColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Fix Issues',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Please fix the following:',
                  style: GoogleFonts.dmSans(color: _T.text2, fontSize: 13)),
              const SizedBox(height: 12),
              ...errors.map((err) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _T.errorLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _T.errorColor.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      Icon(Icons.circle, color: _T.errorColor, size: 8),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(err,
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, color: _T.text))),
                    ]),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it',
                style: GoogleFonts.dmSans(
                    color: _primaryColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Class management ──────────────────────────────────────────────────────

  void _addEntry(String type) {
    if (!mounted) return;
    setState(() {
      classDetails.add(ClassDetails(
        startTime: '',
        endTime: '',
        subject: type == 'Break' ? 'Break' : '',
        facultyId: '',
        facultyName: type == 'Break' ? 'Break' : '',
        type: type,
      ));
    });
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _selectTime(ClassDetails detail, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: _primaryColor, surface: _cardColor),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;
    final newTime = picked.format(context);
    final idx = classDetails.indexOf(detail);
    final testStart = isStart ? newTime : detail.startTime;
    final testEnd = isStart ? detail.endTime : newTime;

    if (_hasTimeConflict(testStart, testEnd, idx)) {
      _showSnack('Time conflict detected. Choose a different time.',
          isError: true);
      HapticFeedback.heavyImpact();
      return;
    }

    _timeCache.remove(isStart ? detail.startTime : detail.endTime);

    setState(() {
      if (isStart) {
        detail.startTime = newTime;
      } else {
        detail.endTime = newTime;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _showFacultyDialog(ClassDetails detail) {
    _facultySearchController.clear();
    filteredFaculties = availableFaculties;
    String branchFilter = 'all';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final branches = <String>{'all'};
          for (final f in availableFaculties) {
            branches.add(f.branchName);
          }
          final branchList = branches.toList()..sort();

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            elevation: 12,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.92,
              height: MediaQuery.of(ctx).size.height * 0.78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: _T.card,
              ),
              child: Column(children: [
                // ── Dialog header ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.person_search_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select Faculty',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            Text('Choose a faculty for this class',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color:
                                        Colors.white.withOpacity(0.85))),
                          ]),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ]),
                ),

                // ── Search + filter ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(children: [
                    _SearchField(
                      controller: _facultySearchController,
                      primaryColor: _primaryColor,
                      onChanged: (q) =>
                          _onSearchChanged(q, branchFilter, setDialogState),
                    ),
                    const SizedBox(height: 10),
                    _BranchDropdown(
                      value: branchFilter,
                      items: branchList,
                      primaryColor: _primaryColor,
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          branchFilter = v;
                          _applyFilter(
                              _facultySearchController.text, branchFilter);
                        });
                      },
                    ),
                  ]),
                ),

                // ── Faculty list ─────────────────────────────────────
                Expanded(
                  child: isFacultyLoading
                      ? Center(
                          child: CircularProgressIndicator(
                              color: _primaryColor, strokeWidth: 3))
                      : filteredFaculties.isEmpty
                          ? const _EmptyFacultyState()
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: filteredFaculties.length,
                              itemBuilder: (ctx, i) => RepaintBoundary(
                                child: _FacultyTile(
                                  faculty: filteredFaculties[i],
                                  gradient: _T.avatarGrad(
                                      filteredFaculties[i].id,
                                      isHod: filteredFaculties[i].isHOD),
                                  primaryColor: _primaryColor,
                                  onTap: () {
                                    setState(() {
                                      detail.facultyId =
                                          filteredFaculties[i].id;
                                      detail.facultyName =
                                          filteredFaculties[i].name;
                                    });
                                    Navigator.pop(dialogCtx);
                                    HapticFeedback.selectionClick();
                                  },
                                ),
                              ),
                            ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _primaryColor = ThemeHelper.primaryColor(context);
    _successColor = ThemeHelper.successColor(context);
    _warningColor = ThemeHelper.warningColor(context);
    _errorColor = ThemeHelper.errorColor(context);
    _cardColor = ThemeHelper.cardColor(context);
    _surfaceColor = ThemeHelper.surfaceColor(context);
    _textColor = ThemeHelper.textColor(context);

    final isDark = ThemeHelper.isDark(context);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: ThemeHelper.systemNavBarColor(context),
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _T.surface,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(children: [
              _buildDaySelector(),
              const SizedBox(height: 12),
              _buildSummaryBar(),
              const SizedBox(height: 12),
              _buildActionButtons(),
              const SizedBox(height: 16),
              _buildContent(),
            ]),
          ),
        ),
      ]),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _T.card,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back_ios_rounded,
                  color: _primaryColor, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timetable',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _T.text,
                  ),
                ),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(widget.sectionName,
                        style: GoogleFonts.dmSans(
                            color: _primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${widget.branchName} · ${widget.semesterName}',
                      style: GoogleFonts.dmSans(
                          color: _T.text2,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          // Date chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _T.successLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_calendar_rounded,
                  size: 12, color: _T.successColor),
              const SizedBox(width: 5),
              Text(
                DateFormat('MMM dd').format(DateTime.now()),
                style: GoogleFonts.dmSans(
                    color: _T.successColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ── Day selector ───────────────────────────────────────────────────────────

  Widget _buildDaySelector() {
    final today = DateFormat('EEEE').format(DateTime.now());
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = _days[i];
          final isSelected = day == selectedDay;
          final isToday = day == today;
          return GestureDetector(
            onTap: () {
              if (day == selectedDay) return;
              HapticFeedback.selectionClick();
              setState(() {
                selectedDay = day;
                loadingState = TimetableLoadingState.loading;
              });
              loadTimetable(day).then((_) {
                if (mounted) {
                  setState(() =>
                      loadingState = TimetableLoadingState.loaded);
                  _listAnimController.forward(from: 0);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? _primaryColor
                    : isToday
                        ? _primaryColor.withOpacity(0.08)
                        : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? _primaryColor
                      : isToday
                          ? _primaryColor.withOpacity(0.4)
                          : _T.border,
                  width: isToday && !isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: _primaryColor.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : null,
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day.substring(0, 3).toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isSelected
                            ? Colors.white70
                            : isToday
                                ? _primaryColor
                                : _T.text3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dayNumber(i),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : isToday
                                ? _primaryColor
                                : _T.text,
                      ),
                    ),
                    if (isToday)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white54
                              : _primaryColor.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ]),
            ),
          );
        },
      ),
    );
  }

  String _dayNumber(int i) {
    final now = DateTime.now();
    final diff = i + 1 - now.weekday;
    return '${now.add(Duration(days: diff)).day}';
  }

  // ── Summary bar ────────────────────────────────────────────────────────────

  Widget _buildSummaryBar() {
    final classCount =
        classDetails.where((c) => c.type != 'Break').length;
    final breakCount =
        classDetails.where((c) => c.type == 'Break').length;
    int totalMins = 0;
    for (final c in classDetails) {
      if (c.type == 'Break') continue;
      final s = _parseTime(c.startTime), e = _parseTime(c.endTime);
      if (s != null && e != null) totalMins += e.difference(s).inMinutes;
    }
    final h = totalMins ~/ 60, m = totalMins % 60;
    final total = totalMins == 0
        ? '—'
        : (h > 0 && m > 0)
            ? '${h}h ${m}m'
            : h > 0
                ? '${h}h'
                : '${m}m';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          _statCell('$classCount', 'Classes', color: _primaryColor),
          _vDivider(),
          _statCell('$breakCount', 'Breaks', color: _T.breakColor),
          _vDivider(),
          _statCell(total, 'Total', color: _T.text2),
        ]),
      ),
    );
  }

  Widget _statCell(String val, String label, {Color? color}) => Expanded(
        child: Column(children: [
          Text(val,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color ?? _primaryColor)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: _T.text3,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _vDivider() => Container(
      width: 1, color: _T.border, margin: const EdgeInsets.symmetric(vertical: 4));

  // ── Action buttons ─────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(
        child: _AddButton(
          label: 'Add Class',
          icon: Icons.add_circle_outline_rounded,
          bg: _primaryColor,
          fg: Colors.white,
          shadowColor: _primaryColor.withOpacity(0.35),
          onTap: () => _addEntry('Class'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _AddButton(
          label: 'Add Break',
          icon: Icons.coffee_rounded,
          bg: _T.breakLight,
          fg: _T.breakColor,
          border: _T.breakColor.withOpacity(0.4),
          onTap: () => _addEntry('Break'),
        ),
      ),
    ]);
  }

  // ── Content ────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (loadingState == TimetableLoadingState.loading ||
        loadingState == TimetableLoadingState.initial) {
      return _stateCard(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: _primaryColor, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text('Loading timetable…',
              style: GoogleFonts.dmSans(color: _T.text2, fontSize: 14)),
        ]),
      );
    }

    if (loadingState == TimetableLoadingState.error) {
      return _stateCard(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _T.errorLight, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.wifi_off_rounded,
                size: 32, color: _T.errorColor),
          ),
          const SizedBox(height: 14),
          Text('Could not load',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _T.text)),
          const SizedBox(height: 6),
          Text(errorMessage ?? 'Something went wrong',
              style: GoogleFonts.dmSans(color: _T.text2, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('Retry',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ]),
      );
    }

    if (classDetails.isEmpty) {
      return _stateCard(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.calendar_month_rounded,
                size: 40, color: _primaryColor.withOpacity(0.7)),
          ),
          const SizedBox(height: 18),
          Text('No Classes Yet',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _T.text)),
          const SizedBox(height: 4),
          Text(selectedDay,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: _primaryColor,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text('Use the buttons above to add classes or breaks.',
              style: GoogleFonts.dmSans(color: _T.text2, fontSize: 13),
              textAlign: TextAlign.center),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          '$selectedDay Schedule'.toUpperCase(),
          style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: _T.text3),
        ),
      ),
      _buildTimeline(),
    ]);
  }

  // ── Timeline ───────────────────────────────────────────────────────────────

  Widget _buildTimeline() {
    return Stack(children: [
      Positioned(
        left: 49,
        top: 0,
        bottom: 0,
        child: Container(width: 1, color: _T.border),
      ),
      AnimatedBuilder(
        animation: _listAnimController,
        builder: (context, _) {
          return Column(
            children: classDetails.asMap().entries.map((e) {
              final delay = (e.key * 0.1).clamp(0.0, 0.9);
              final end = (delay + 0.4).clamp(0.0, 1.0);
              final t = ((_listAnimController.value - delay) /
                      (end - delay))
                  .clamp(0.0, 1.0);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - t)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTimelineRow(e.value, e.key),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ]);
  }

  Widget _buildTimelineRow(ClassDetails detail, int index) {
    final isBreak = detail.type == 'Break';
    final conflict =
        _hasTimeConflict(detail.startTime, detail.endTime, index);
    final incomplete = detail.startTime.isEmpty ||
        detail.endTime.isEmpty ||
        (!isBreak &&
            (detail.subject.isEmpty || detail.facultyId.isEmpty));

    final accent = conflict
        ? _T.errorColor
        : _T.rowAccent(index, isBreak: isBreak);

    Color dotBorder =
        conflict ? _T.errorColor : isBreak ? _T.breakColor : _T.border;
    Color dotFill = conflict ? _T.errorColor : _T.card;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Time column
      SizedBox(
        width: 50,
        child: Padding(
          padding: const EdgeInsets.only(top: 14, right: 12),
          child: Text(
            _shortTime(detail.startTime),
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: conflict ? _T.errorColor : _T.text3,
            ),
          ),
        ),
      ),
      // Dot
      Container(
        width: 13,
        height: 13,
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: dotFill,
          shape: BoxShape.circle,
          border: Border.all(color: dotBorder, width: 2.5),
        ),
      ),
      const SizedBox(width: 12),
      // Card
      Expanded(child: _buildCard(detail, index, accent, conflict, incomplete)),
    ]);
  }

  Widget _buildCard(ClassDetails detail, int index, Color accent,
      bool conflict, bool incomplete) {
    final isBreak = detail.type == 'Break';

    if (isBreak) return _buildBreakCard(detail, index);

    Color bg = conflict
        ? _T.errorColor.withOpacity(0.04)
        : incomplete
            ? _T.warnColor.withOpacity(0.03)
            : _T.card;
    Color borderColor = conflict
        ? _T.errorColor.withOpacity(0.35)
        : incomplete
            ? _T.warnColor.withOpacity(0.3)
            : _T.border;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: borderColor,
            width: conflict || incomplete ? 1.5 : 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(children: [
          // Left accent bar
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge + menu
                    Row(children: [
                      _typeBadge('${index + 1}. ${detail.type}', accent),
                      const Spacer(),
                      _rowMenu(index),
                    ]),
                    const SizedBox(height: 10),

                    // Time row
                    Row(children: [
                      Expanded(
                        child: _TimeChip(
                          time: detail.startTime,
                          label: 'Start',
                          primaryColor: _primaryColor,
                          onTap: () => _selectTime(detail, true),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: _T.text3, size: 16),
                      ),
                      Expanded(
                        child: _TimeChip(
                          time: detail.endTime,
                          label: 'End',
                          primaryColor: _primaryColor,
                          onTap: () => _selectTime(detail, false),
                        ),
                      ),
                      if (detail.startTime.isNotEmpty &&
                          detail.endTime.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: _T.border),
                          ),
                          child: Text(
                            _duration(detail.startTime, detail.endTime),
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: _T.text3,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ]),

                    // Conflict warning
                    if (conflict) ...[
                      const SizedBox(height: 10),
                      _WarningBanner(
                          message: 'Time conflict with another class',
                          color: _T.errorColor),
                    ],

                    // Subject + faculty
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: detail.subject,
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            hintText: 'e.g. Mathematics',
                            labelStyle: GoogleFonts.dmSans(
                                color: _T.text3, fontSize: 13),
                            hintStyle: GoogleFonts.dmSans(
                                color: _T.text3, fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: _primaryColor.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: _primaryColor.withOpacity(0.2),
                                  width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: _primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: _surfaceColor,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _T.text),
                          onChanged: (v) => detail.subject = v,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: _FacultyPickerButton(
                          facultyName: detail.facultyName,
                          primaryColor: _primaryColor,
                          onTap: () => _showFacultyDialog(detail),
                        ),
                      ),
                    ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBreakCard(ClassDetails detail, int index) {
    return Container(
      decoration: BoxDecoration(
        color: _T.breakLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(children: [
          Container(
            width: 4,
            decoration: const BoxDecoration(
              color: _T.breakColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('☕', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('Break',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _T.breakColor)),
                      const Spacer(),
                      _rowMenu(index),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: _TimeChip(
                          time: detail.startTime,
                          label: 'Start',
                          primaryColor: _T.breakColor,
                          onTap: () => _selectTime(detail, true),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: _T.text3, size: 16),
                      ),
                      Expanded(
                        child: _TimeChip(
                          time: detail.endTime,
                          label: 'End',
                          primaryColor: _T.breakColor,
                          onTap: () => _selectTime(detail, false),
                        ),
                      ),
                      if (detail.startTime.isNotEmpty &&
                          detail.endTime.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE0B2),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: const Color(0xFFFFCC80)),
                          ),
                          child: Text(
                            _duration(detail.startTime, detail.endTime),
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: _T.breakColor,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _typeBadge(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
      );

  Widget _rowMenu(int index) => PopupMenuButton<String>(
        icon: Icon(Icons.more_vert_rounded, color: _T.text3, size: 20),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (v) {
          if (v == 'delete') {
            setState(() {
              classDetails.removeAt(index);
              _timeCache.clear();
            });
            HapticFeedback.heavyImpact();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded,
                  color: _T.errorColor, size: 18),
              const SizedBox(width: 10),
              Text('Delete',
                  style: GoogleFonts.dmSans(
                      color: _T.errorColor,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      );

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return AnimatedScale(
      scale: isSaving ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: FloatingActionButton.extended(
        onPressed: isSaving ? null : uploadTimetable,
        backgroundColor:
            isSaving ? const Color(0xFF9CA3AF) : _T.successColor,
        foregroundColor: Colors.white,
        elevation: isSaving ? 1 : 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation(Colors.white)),
              )
            : const Icon(Icons.save_rounded, size: 22),
        label: Text(
          isSaving ? 'Saving…' : 'Save Timetable',
          style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  Widget _stateCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.border),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [child]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared micro-widgets
// ══════════════════════════════════════════════════════════════════════════════

class _AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color? border;
  final Color? shadowColor;
  final VoidCallback onTap;

  const _AddButton({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.border,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: border != null ? Border.all(color: border!, width: 1.5) : null,
        boxShadow: shadowColor != null
            ? [
                BoxShadow(
                    color: shadowColor!,
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String time;
  final String label;
  final Color primaryColor;
  final VoidCallback onTap;

  const _TimeChip({
    required this.time,
    required this.label,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final empty = time.isEmpty;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: empty
              ? const Color(0xFFF5F5F5)
              : primaryColor.withOpacity(0.08),
          border: Border.all(
            color: empty
                ? const Color(0xFFE0E0E0)
                : primaryColor.withOpacity(0.35),
            width: empty ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color:
                      empty ? _T.text3 : primaryColor,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            empty ? 'Tap to set' : time,
            style: GoogleFonts.dmSans(
              fontSize: empty ? 11 : 12,
              color: empty ? _T.text2 : primaryColor,
              fontWeight:
                  empty ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
        ]),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  final Color color;
  const _WarningBanner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: GoogleFonts.dmSans(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _FacultyPickerButton extends StatelessWidget {
  final String facultyName;
  final Color primaryColor;
  final VoidCallback onTap;

  const _FacultyPickerButton({
    required this.facultyName,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final empty = facultyName.isEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border.all(
              color: primaryColor.withOpacity(0.2), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          if (!empty)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text(
                facultyName[0].toUpperCase(),
                style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.person_add_alt_1_rounded,
                  color: _T.text3, size: 18),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empty ? 'Select Faculty' : facultyName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: empty ? _T.text3 : _T.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!empty)
                  Text('Tap to change',
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: _T.text3)),
              ],
            ),
          ),
          Icon(Icons.expand_more_rounded, color: _T.text3, size: 18),
        ]),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final Color primaryColor;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search by name, branch or email…',
          hintStyle:
              GoogleFonts.dmSans(color: _T.text3, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: _T.text3, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: primaryColor.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: primaryColor.withOpacity(0.2), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: GoogleFonts.dmSans(fontSize: 14),
        onChanged: onChanged,
      );
}

class _BranchDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final Color primaryColor;
  final ValueChanged<String?> onChanged;

  const _BranchDropdown({
    required this.value,
    required this.items,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: 'Filter by Branch',
          labelStyle:
              GoogleFonts.dmSans(color: _T.text2, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: primaryColor.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: primaryColor.withOpacity(0.2), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: items
            .map((b) => DropdownMenuItem(
                  value: b,
                  child: Text(b == 'all' ? 'All Branches' : b,
                      style: GoogleFonts.dmSans(fontSize: 13)),
                ))
            .toList(),
        onChanged: onChanged,
      );
}

class _EmptyFacultyState extends StatelessWidget {
  const _EmptyFacultyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_search_rounded,
                size: 40, color: _T.text3),
          ),
          const SizedBox(height: 14),
          Text('No Faculty Found',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _T.text)),
          const SizedBox(height: 6),
          Text('Try a different search or filter',
              style: GoogleFonts.dmSans(fontSize: 13, color: _T.text3)),
        ]),
      );
}

class _FacultyTile extends StatelessWidget {
  final FacultyInfo faculty;
  final LinearGradient gradient;
  final Color primaryColor;
  final VoidCallback onTap;

  const _FacultyTile({
    required this.faculty,
    required this.gradient,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: primaryColor.withOpacity(0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: gradient.colors.first.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  faculty.name.isNotEmpty
                      ? faculty.name[0].toUpperCase()
                      : 'F',
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(faculty.name,
                              style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _T.text)),
                        ),
                        if (faculty.isHOD)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFEC4899),
                                Color(0xFFDB2777),
                              ]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('HOD',
                                style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ),
                      ]),
                      const SizedBox(height: 2),
                      Text(faculty.branchName,
                          style: GoogleFonts.dmSans(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      if (faculty.email.isNotEmpty)
                        Text(faculty.email,
                            style: GoogleFonts.dmSans(
                                color: _T.text3, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                    ]),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: _T.text3),
            ]),
          ),
        ),
      ),
    );
  }
}