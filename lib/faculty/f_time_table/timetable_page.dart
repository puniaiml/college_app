// ignore_for_file: unused_field

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiksha_hub/utils/theme_helper.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

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

  factory ClassDetails.fromJson(Map<String, dynamic> json) => ClassDetails(
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        facultyId: json['facultyId'] as String? ?? '',
        facultyName: json['facultyName'] as String? ?? '',
        type: json['type'] as String? ?? 'Class',
      );
}

enum TimetableLoadingState { initial, loading, loaded, error }

// ─── Design tokens ─────────────────────────────────────────────────────────────

class _T {
  static const Color surface  = Color(0xFFF7F6F2);
  static const Color card     = Color(0xFFFFFFFF);
  static const Color border   = Color(0xFFEBEBEB);
  static const Color text     = Color(0xFF1A1A1A);
  static const Color text2    = Color(0xFF666666);
  static const Color text3    = Color(0xFF999999);

  static const Color breakColor  = Color(0xFFEF6C00);
  static const Color breakLight  = Color(0xFFFFF3E0);
  static const Color liveColor   = Color(0xFF2E7D32);
  static const Color liveLight   = Color(0xFFE8F5E9);
  static const Color nextColor   = Color(0xFF1565C0);
  static const Color nextLight   = Color(0xFFE3F2FD);
  static const Color infoColor   = Color(0xFF0284C7);
  static const Color infoLight   = Color(0xFFE0F2FE);

  static const List<Color> palette = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
  ];

  static Color rowAccent(int index, {bool isBreak = false}) =>
      isBreak ? breakColor : palette[index % palette.length];
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class FacultyTimetableViewPage extends StatefulWidget {
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

  const FacultyTimetableViewPage({
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
  State<FacultyTimetableViewPage> createState() =>
      _FacultyTimetableViewPageState();
}

class _FacultyTimetableViewPageState extends State<FacultyTimetableViewPage>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  List<ClassDetails> classDetails = [];
  String selectedDay = '';
  TimetableLoadingState loadingState = TimetableLoadingState.initial;
  String? errorMessage;
  DateTime? lastUpdated;
  Timer? _liveTimer;

  late AnimationController _listAnimController;
  final ScrollController _scrollController = ScrollController();

  // ── Theme (cached in build) ────────────────────────────────────────────────
  late Color _primaryColor;

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

    // Refresh live indicators every minute
    _liveTimer = Timer.periodic(
        const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    _liveTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  String get _documentId => widget.sectionId;

  Future<void> _loadInitialData() async {
    setState(() {
      loadingState = TimetableLoadingState.loading;
      errorMessage = null;
    });
    try {
      await loadTimetable(selectedDay);
      if (mounted) {
        setState(() => loadingState = TimetableLoadingState.loaded);
        _listAnimController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loadingState = TimetableLoadingState.error;
          errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> loadTimetable(String day) async {
    if (!mounted) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('timetables')
          .doc(_documentId)
          .get();

      if (mounted) {
        setState(() {
          if (doc.exists) {
            final data = doc.data()?[day] as List<dynamic>?;
            classDetails = data
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
            final meta =
                doc.data()?['metadata'] as Map<String, dynamic>?;
            if (meta?['lastUpdated'] != null) {
              lastUpdated =
                  (meta!['lastUpdated'] as Timestamp).toDate();
            }
          } else {
            classDetails = [];
            lastUpdated = null;
          }
        });
      }
    } catch (e) {
      throw Exception('Error loading timetable: $e');
    }
  }

  // ── Time helpers ───────────────────────────────────────────────────────────

  DateTime? _parseTime(String t) {
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

  String _formatRange(String s, String e) =>
      (s.isEmpty || e.isEmpty) ? 'Time not set' : '$s – $e';

  String _duration(String s, String e) {
    final st = _parseTime(s), en = _parseTime(e);
    if (st == null || en == null) return '';
    final d = en.difference(st);
    final h = d.inHours, m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  bool _isCurrentClass(ClassDetails d) {
    final now = DateTime.now();
    if (DateFormat('EEEE').format(now) != selectedDay) return false;
    final s = _parseTime(d.startTime), e = _parseTime(d.endTime);
    if (s == null || e == null) return false;
    return now.isAfter(s) && now.isBefore(e);
  }

  bool _isUpcoming(ClassDetails d) {
    final now = DateTime.now();
    if (DateFormat('EEEE').format(now) != selectedDay) return false;
    final s = _parseTime(d.startTime);
    if (s == null) return false;
    final diff = s.difference(now).inMinutes;
    return diff > 0 && diff <= 30;
  }

  String _getTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0)
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours > 0)
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inMinutes > 0)
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    return 'Just now';
  }

  // Summary helpers
  int get _classCount =>
      classDetails.where((c) => c.type != 'Break').length;
  int get _breakCount =>
      classDetails.where((c) => c.type == 'Break').length;
  int get _liveCount => classDetails.where(_isCurrentClass).length;

  String _totalHours() {
    int mins = 0;
    for (final c in classDetails) {
      if (c.type == 'Break') continue;
      final s = _parseTime(c.startTime), e = _parseTime(c.endTime);
      if (s != null && e != null) mins += e.difference(s).inMinutes;
    }
    if (mins == 0) return '—';
    final h = mins ~/ 60, m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await _loadInitialData();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _primaryColor = ThemeHelper.primaryColor(context);

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
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: _primaryColor,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(children: [
                _buildDaySelector(),
                const SizedBox(height: 12),
                _buildSummaryBar(),
                if (lastUpdated != null) ...[
                  const SizedBox(height: 10),
                  _buildLastUpdated(),
                ],
                const SizedBox(height: 16),
                _buildContent(),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ]),
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
      child: Row(children: [
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
                'Class Schedule',
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
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _T.infoLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _T.infoColor.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_rounded,
                size: 12, color: _T.infoColor),
            const SizedBox(width: 5),
            Text(
              DateFormat('MMM dd').format(DateTime.now()),
              style: GoogleFonts.dmSans(
                  color: _T.infoColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _refresh,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.refresh_rounded, color: _T.text2, size: 18),
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          _statCell('$_classCount', 'Classes', color: _primaryColor),
          _vDivider(),
          _statCell('$_breakCount', 'Breaks', color: _T.breakColor),
          _vDivider(),
          _statCell('$_liveCount', 'Live', color: _T.liveColor),
          _vDivider(),
          _statCell(_totalHours(), 'Total', color: _T.text2),
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
      width: 1,
      color: _T.border,
      margin: const EdgeInsets.symmetric(vertical: 4));

  // ── Last updated ───────────────────────────────────────────────────────────

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _T.infoLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.infoColor.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.update_rounded, color: _T.infoColor, size: 14),
        const SizedBox(width: 6),
        Text(
          'Updated ${_getTimeAgo(lastUpdated!)}',
          style: GoogleFonts.dmSans(
              color: _T.infoColor,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }

  // ── Content ────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (loadingState == TimetableLoadingState.loading ||
        loadingState == TimetableLoadingState.initial) {
      return _stateCard(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                  color: _primaryColor, strokeWidth: 2.5),
              const SizedBox(height: 16),
              Text('Loading schedule…',
                  style: GoogleFonts.dmSans(
                      color: _T.text2, fontSize: 14)),
            ]),
      );
    }

    if (loadingState == TimetableLoadingState.error) {
      return _stateCard(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.error_outline_rounded,
                    size: 32, color: const Color(0xFFDC2626)),
              ),
              const SizedBox(height: 14),
              Text('Something went wrong',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _T.text)),
              const SizedBox(height: 6),
              Text(errorMessage ?? 'Unable to load schedule',
                  style: GoogleFonts.dmSans(
                      color: _T.text2, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Try Again',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
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
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.schedule_rounded,
                    size: 40,
                    color: _primaryColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 18),
              Text('No Classes Scheduled',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _T.text)),
              const SizedBox(height: 4),
              Text(selectedDay,
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: _primaryColor,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text('Your schedule for this day is currently empty.',
                  style: GoogleFonts.dmSans(
                      color: _T.text2, fontSize: 13),
                  textAlign: TextAlign.center),
            ]),
      );
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
      // Vertical line
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
              final t =
                  ((_listAnimController.value - delay) / (end - delay))
                      .clamp(0.0, 1.0);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - t)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTimelineSlot(e.value, e.key),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ]);
  }

  Widget _buildTimelineSlot(ClassDetails detail, int index) {
    final isBreak = detail.type == 'Break';
    final isLive = _isCurrentClass(detail);
    final isNext = _isUpcoming(detail);

    Color dotBorder = isLive
        ? _T.liveColor
        : isBreak
            ? _T.breakColor
            : _T.border;
    Color dotFill = isLive ? _T.liveColor : _T.card;

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
              color: isLive ? _T.liveColor : _T.text3,
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
      Expanded(child: _buildCard(detail, index, isLive, isNext, isBreak)),
    ]);
  }

  // ── Card ───────────────────────────────────────────────────────────────────

  Widget _buildCard(ClassDetails d, int index, bool isLive, bool isNext,
      bool isBreak) {
    if (isBreak) return _buildBreakCard(d);

    final accent = _T.rowAccent(index);
    Color borderColor = isLive
        ? const Color(0xFFA5D6A7)
        : isNext
            ? const Color(0xFF90CAF9)
            : _T.border;
    Color bgColor = isLive
        ? _T.liveLight
        : isNext
            ? _T.nextLight
            : _T.card;
    Color leftBar =
        isLive ? _T.liveColor : isNext ? _T.nextColor : accent;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: borderColor, width: isLive || isNext ? 1.5 : 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(children: [
          // Left accent bar
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: leftBar,
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
                    // Type badge + duration
                    Row(children: [
                      _typeBadge(d, isLive, isNext, accent),
                      const Spacer(),
                      _durationChip(d, isLive),
                    ]),
                    const SizedBox(height: 8),

                    // Subject
                    if (d.subject.isNotEmpty)
                      Text(
                        d.subject,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isLive ? _T.liveColor : _T.text,
                        ),
                      ),

                    const SizedBox(height: 6),

                    // Time range
                    Row(children: [
                      Icon(Icons.access_time_rounded,
                          size: 13, color: _T.text3),
                      const SizedBox(width: 4),
                      Text(
                        _formatRange(d.startTime, d.endTime),
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: _T.text2,
                            fontWeight: FontWeight.w500),
                      ),
                      if (isLive) ...[
                        const Spacer(),
                        _ongoingBadge(),
                      ],
                    ]),

                    // Faculty row
                    if (d.facultyName.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        height: 1,
                        color: isLive
                            ? const Color(0xFFC8E6C9)
                            : isNext
                                ? const Color(0xFFBBDEFB)
                                : _T.border,
                      ),
                      const SizedBox(height: 10),
                      _facultyRow(d, isLive, isNext, accent),
                    ],
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBreakCard(ClassDetails d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _T.breakLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(children: [
        const Text('☕', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Break Time',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _T.breakColor)),
                Text(
                  _formatRange(d.startTime, d.endTime),
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: _T.text3),
                ),
              ]),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE0B2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFFCC80)),
          ),
          child: Text(
            _duration(d.startTime, d.endTime),
            style: GoogleFonts.dmSans(
                fontSize: 11,
                color: _T.breakColor,
                fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }

  Widget _typeBadge(
      ClassDetails d, bool isLive, bool isNext, Color accent) {
    String label;
    Color bg, fg;
    if (isLive) {
      label = 'LIVE';
      bg = _T.liveLight;
      fg = _T.liveColor;
    } else if (isNext) {
      label = 'NEXT';
      bg = _T.nextLight;
      fg = _T.nextColor;
    } else {
      label = d.type.toUpperCase();
      bg = accent.withOpacity(0.1);
      fg = accent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.dmSans(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
    );
  }

  Widget _durationChip(ClassDetails d, bool isLive) {
    final dur = _duration(d.startTime, d.endTime);
    if (dur.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isLive
            ? const Color(0xFFC8E6C9)
            : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
            color: isLive ? const Color(0xFFA5D6A7) : _T.border),
      ),
      child: Text(dur,
          style: GoogleFonts.dmSans(
              fontSize: 11,
              color: isLive ? _T.liveColor : _T.text3,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _ongoingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _T.liveColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('ONGOING',
            style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
      ]),
    );
  }

  Widget _facultyRow(
      ClassDetails d, bool isLive, bool isNext, Color accent) {
    final fgColor =
        isLive ? _T.liveColor : isNext ? _T.nextColor : accent;
    final avatarBg =
        isLive ? _T.liveColor : isNext ? _T.nextColor : accent;

    return Row(children: [
      // Avatar
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: avatarBg,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          d.facultyName.trim().isNotEmpty
              ? d.facultyName.trim()[0].toUpperCase()
              : 'F',
          style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.facultyName,
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fgColor)),
              if (isNext)
                Text('Starting soon',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: _T.nextColor,
                        fontWeight: FontWeight.w500)),
            ]),
      ),
    ]);
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