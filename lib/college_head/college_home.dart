import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shiksha_hub/chat_mate/widgets/profile_check_dialog.dart';
import 'package:shiksha_hub/chat_mate/screens/home_screen.dart';
import 'package:shiksha_hub/widgets/drawer_college_head.dart';

// ─── Theme ───────────────────────────────────────────────────────────────────

class _T {
  static const Color bgDark    = Color(0xFF0B0F1A);
  static const Color bgCard    = Color(0xFF131929);
  static const Color bgCardAlt = Color(0xFF1A2235);
  static const Color border    = Color(0xFF243050);
  static const Color textPri   = Color(0xFFEFF3FF);
  static const Color textSec   = Color(0xFF7A8BAD);
  static const Color textMuted = Color(0xFF3D4F72);
  static const Color blue      = Color(0xFF3B82F6);
  static const Color cyan      = Color(0xFF06B6D4);
  static const Color green     = Color(0xFF10B981);
  static const Color amber     = Color(0xFFF59E0B);
  static const Color rose      = Color(0xFFF43F5E);
  static const Color purple    = Color(0xFF8B5CF6);
  static const Color indigo    = Color(0xFF6366F1);
  static const Color teal      = Color(0xFF14B8A6);
  static final List<Color> palette =
      [blue, cyan, green, amber, purple, rose, indigo, teal];
}

// ─── Model ───────────────────────────────────────────────────────────────────

class ChartData {
  final String x;
  final double y;
  final Color color;
  const ChartData(this.x, this.y, this.color);
}

// ─── Dashboard ───────────────────────────────────────────────────────────────

class CollegeStaffDashboard extends StatefulWidget {
  const CollegeStaffDashboard({super.key});
  @override
  State<CollegeStaffDashboard> createState() => _DashState();
}

class _DashState extends State<CollegeStaffDashboard>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  String? _collegeId, _collegeName, _universityName;

  int _total = 0, _active = 0, _pending = 0,
      _faculty = 0, _courses = 0, _branches = 0;

  List<ChartData> _byCourse  = [];
  List<ChartData> _byBranch  = [];
  List<ChartData> _growth    = [];
  List<ChartData> _status    = [];
  List<ChartData> _byRole    = [];
  List<ChartData> _facByCourse = [];

  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _load();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ProfileCheckDialog.checkAndShowDialog(context, userType: 'college_staff');
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _refreshing = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final doc = await _db
          .collection('users').doc('college_staff')
          .collection('data').doc(user.uid).get();
      if (!doc.exists) throw Exception('Staff data not found');

      final d = doc.data()!;
      _collegeId    = d['collegeId'];
      _collegeName  = d['collegeName'];
      _universityName = d['universityName'];
      if (_collegeId == null) throw Exception('College ID not found');

      final res = await Future.wait([
        _db.collection('users/students/data')
            .where('collegeId', isEqualTo: _collegeId).get(),
        _db.collection('users/pending_students/data')
            .where('collegeId', isEqualTo: _collegeId).get(),
        _db.collection('users/faculty/data')
            .where('collegeId', isEqualTo: _collegeId).get(),
        _db.collection('courses')
            .where('collegeId', isEqualTo: _collegeId).get(),
        _db.collection('branches')
            .where('collegeId', isEqualTo: _collegeId).get(),
      ]);

      _active   = res[0].size;
      _pending  = res[1].size;
      _total    = _active + _pending;
      _faculty  = res[2].size;
      _courses  = res[3].size;
      _branches = res[4].size;

      // Aggregation
      final byCourse    = <String, int>{};
      final byBranch    = <String, int>{};
      final byRole      = <String, int>{};
      final facByCourse = <String, int>{};

      for (final s in res[0].docs) {
        final sd = s.data() as Map<String, dynamic>;
        final c = sd['courseName'] ?? 'Unknown';
        final b = sd['branchName'] ?? 'Unknown';
        byCourse[c] = (byCourse[c] ?? 0) + 1;
        byBranch[b] = (byBranch[b] ?? 0) + 1;
      }
      for (final f in res[2].docs) {
        final fd = f.data() as Map<String, dynamic>;
        final r = fd['role'] ?? 'Unknown';
        final c = fd['courseName'] ?? 'Unknown';
        byRole[r]      = (byRole[r] ?? 0) + 1;
        facByCourse[c] = (facByCourse[c] ?? 0) + 1;
      }

      // Growth last 7 days
      final now = DateTime.now();
      final growthRaw = await Future.wait(List.generate(7, (i) async {
        final date  = now.subtract(Duration(days: 6 - i));
        final start = DateTime(date.year, date.month, date.day);
        final end   = DateTime(date.year, date.month, date.day, 23, 59, 59);
        final a = await _db.collection('users/students/data')
            .where('collegeId', isEqualTo: _collegeId)
            .where('createdAt', isGreaterThanOrEqualTo: start)
            .where('createdAt', isLessThanOrEqualTo: end).get();
        final p = await _db.collection('users/pending_students/data')
            .where('collegeId', isEqualTo: _collegeId)
            .where('createdAt', isGreaterThanOrEqualTo: start)
            .where('createdAt', isLessThanOrEqualTo: end).get();
        return MapEntry('${date.day}/${date.month}',
            (a.size + p.size).toDouble());
      }));

      if (!mounted) return;
      setState(() {
        ChartData mk(String k, int v, int i) =>
            ChartData(k, v.toDouble(), _T.palette[i % _T.palette.length]);

        final cList  = byCourse.entries.toList();
        final bList  = byBranch.entries.toList();
        final rList  = byRole.entries.toList();
        final fcList = facByCourse.entries.toList();

        _byCourse    = List.generate(cList.length,  (i) => mk(cList[i].key,  cList[i].value,  i));
        _byBranch    = List.generate(bList.length,  (i) => mk(bList[i].key,  bList[i].value,  i));
        _byRole      = List.generate(rList.length,  (i) => mk(rList[i].key,  rList[i].value,  i));
        _facByCourse = List.generate(fcList.length, (i) => mk(fcList[i].key, fcList[i].value, i));

        _growth = growthRaw.map((e) =>
            ChartData(e.key, e.value, _T.cyan)).toList();
        _status = [
          ChartData('Active',  _active.toDouble(),  _T.green),
          ChartData('Pending', _pending.toDouble(), _T.amber),
        ];

        _loading    = false;
        _refreshing = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error      = e.toString();
        _loading    = false;
        _refreshing = false;
      });
    }
  }

  // ── Scaffold ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq     = MediaQuery.of(context);
    final sw     = mq.size.width;
    final narrow = sw < 600;

    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: _T.bgDark),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _T.bgDark,
        drawer: const CollegeStaffDrawer(),
        // FAB opens quick-action sheet
        floatingActionButton: FloatingActionButton(
          backgroundColor: _T.blue,
          onPressed: () => _showActions(context),
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
        body: RefreshIndicator(
          color: _T.cyan,
          backgroundColor: _T.bgCard,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              _buildHeader(mq, narrow),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    narrow ? 16 : 24, 16,
                    narrow ? 16 : 24, 80),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_error != null)
                      _errorWidget()
                    else if (_loading)
                      ..._skeletonItems()
                    else
                      ..._contentItems(narrow, sw),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _T.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: _T.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          _sheetTile(Icons.refresh_rounded, 'Refresh Data', _T.cyan, () {
            Navigator.pop(ctx); _load();
          }),
          _sheetTile(Icons.chat_bubble_outline_rounded,
              'ChatMate — Academic Collaboration', _T.blue, () {
            Navigator.pop(ctx);
            Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => const ChatMateHomeScreen()));
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sheetTile(IconData icon, String title, Color accent, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: accent, size: 18),
      ),
      title: Text(title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w600, color: _T.textPri)),
      onTap: onTap,
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  SliverAppBar _buildHeader(MediaQueryData mq, bool narrow) {
    return SliverAppBar(
      expandedHeight: narrow ? 220 : 260,
      pinned: true,
      stretch: true,
      backgroundColor: _T.bgDark,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: _GlassBtn(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: const Icon(Icons.menu_rounded, color: _T.textPri, size: 18),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: _GlassBtn(
            onTap: _refreshing ? null : _load,
            child: _refreshing
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: _T.cyan, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded,
                    color: _T.textPri, size: 18),
          ),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.blurBackground],
        background: _headerBg(mq.padding.top, narrow),
      ),
    );
  }

  Widget _headerBg(double topPad, bool narrow) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0D1B3E), Color(0xFF0B0F1A)],
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter()),
        Positioned(top: -40, right: -40,
            child: _Orb(color: _T.blue.withOpacity(0.20), size: 220)),
        Positioned(bottom: 10, left: 20,
            child: _Orb(color: _T.indigo.withOpacity(0.10), size: 160)),
        // Bottom fade
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(height: 60,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, _T.bgDark],
              ),
            ),
          ),
        ),
        // Text content
        Positioned(
          left: 20, right: 20, bottom: 36,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _liveBadge(),
              const SizedBox(height: 12),
              Text(_collegeName ?? 'College Analytics',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: narrow ? 24 : 30,
                  fontWeight: FontWeight.w800,
                  color: _T.textPri,
                  letterSpacing: -0.5, height: 1.1)),
              const SizedBox(height: 4),
              Text('College Dashboard Overview',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: narrow ? 13 : 15,
                  color: _T.textSec, fontWeight: FontWeight.w500)),
              if (_universityName != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.account_balance_rounded,
                      size: 12, color: _T.textMuted),
                  const SizedBox(width: 4),
                  Flexible(child: Text(_universityName!,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: _T.textMuted))),
                ]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _liveBadge() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _T.indigo.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _T.indigo.withOpacity(0.40)),
        ),
        child: Text('COLLEGE ADMIN',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9, color: _T.indigo,
            fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _T.blue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _T.blue.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: _T.cyan.withOpacity(0.5 + 0.5 * _pulse.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('LIVE',
            style: GoogleFonts.spaceMono(
              fontSize: 9, color: _T.cyan,
              letterSpacing: 1.4, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }

  // ── Content items ──────────────────────────────────────────────────────────

  List<Widget> _contentItems(bool narrow, double sw) {
    final cols = sw > 1100 ? 3 : sw > 600 ? 2 : 1;
    return [
      _sectionLabel('Overview', Icons.insights_rounded),
      const SizedBox(height: 14),
      _statsSection(narrow, cols, sw),
      const SizedBox(height: 28),
      _sectionLabel('Student Trends', Icons.show_chart_rounded),
      const SizedBox(height: 14),
      _chartCard(
        title: 'Daily Registrations',
        sub: 'Last 7 days · entire college',
        icon: Icons.trending_up_rounded,
        accent: _T.cyan,
        chartH: narrow ? 200.0 : 260.0,
        child: _areaChart(),
      ),
      const SizedBox(height: 28),
      _sectionLabel('Distribution Analytics', Icons.donut_large_rounded),
      const SizedBox(height: 14),
      if (narrow) ..._pieColumn(narrow) else _pieRows(narrow),
      const SizedBox(height: 8),
    ];
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  Widget _statsSection(bool narrow, int cols, double sw) {
    final cards = [
      _statTile('Total Students', '$_total',   'Entire college',        Icons.groups_2_rounded,        _T.blue,   0),
      _statTile('Active',         '$_active',  'Verified students',     Icons.verified_rounded,        _T.green,  55),
      _statTile('Pending',        '$_pending', 'Awaiting verification', Icons.hourglass_top_rounded,   _T.amber,  110),
      _statTile('Faculty',        '$_faculty', 'Teaching staff',        Icons.school_rounded,          _T.purple, 165),
      _statTile('Courses',        '$_courses', 'Available courses',     Icons.menu_book_rounded,       _T.teal,   220),
      _statTile('Branches',       '$_branches','Academic branches',     Icons.account_tree_rounded,    _T.indigo, 275),
    ];

    if (narrow) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: cards.map((c) =>
            Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
            .toList(),
      );
    }

    final tileW = cols == 3
        ? (sw - 48 - 24) / 3
        : (sw - 48 - 12) / 2;

    return Wrap(spacing: 12, runSpacing: 12,
      children: cards.map((c) => SizedBox(width: tileW, child: c)).toList(),
    );
  }

  Widget _statTile(String label, String value, String sub,
      IconData icon, Color accent, int delayMs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
        boxShadow: [BoxShadow(
            color: accent.withOpacity(0.07),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                      color: accent, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: 14),
          Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28, fontWeight: FontWeight.w800,
              color: _T.textPri, letterSpacing: -1)),
          const SizedBox(height: 2),
          Text(label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w600, color: _T.textSec)),
          Text(sub,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11, color: _T.textMuted)),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delayMs), duration: 450.ms);
  }

  // ── Chart card ─────────────────────────────────────────────────────────────

  Widget _chartCard({
    required String title,
    required String sub,
    required IconData icon,
    required Color accent,
    required double chartH,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _T.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Icon(icon, color: accent, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: _T.textPri, letterSpacing: -0.2)),
                  Text(sub,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _T.textMuted)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 8),
          Divider(color: _T.border, thickness: 1, height: 1),
          SizedBox(
            height: chartH,
            child: Padding(padding: const EdgeInsets.all(10), child: child),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  // ── Area chart ─────────────────────────────────────────────────────────────

  Widget _areaChart() {
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      backgroundColor: Colors.transparent,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: GoogleFonts.spaceMono(fontSize: 9, color: _T.textMuted),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        majorGridLines: MajorGridLines(
            width: 1, color: _T.border.withOpacity(0.6)),
        axisLine: const AxisLine(width: 0),
        labelStyle: GoogleFonts.spaceMono(fontSize: 9, color: _T.textMuted),
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true, color: _T.bgCardAlt,
        textStyle: GoogleFonts.spaceMono(color: _T.textPri, fontSize: 11),
      ),
      series: <CartesianSeries>[
        AreaSeries<ChartData, String>(
          dataSource: _growth,
          xValueMapper: (d, _) => d.x,
          yValueMapper: (d, _) => d.y,
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_T.cyan.withOpacity(0.30), Colors.transparent],
          ),
          borderColor: _T.cyan,
          borderWidth: 2.5,
          markerSettings: const MarkerSettings(
            isVisible: true, height: 6, width: 6,
            color: _T.cyan, borderColor: _T.bgCard, borderWidth: 2,
          ),
          animationDuration: 1000,
        ),
      ],
    );
  }

  // ── Donut chart ────────────────────────────────────────────────────────────

  Widget _donut(List<ChartData> data, String empty) {
    if (data.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 36, color: _T.textMuted),
          const SizedBox(height: 8),
          Text(empty, style: GoogleFonts.plusJakartaSans(
              fontSize: 12, color: _T.textMuted)),
        ],
      ));
    }
    return SfCircularChart(
      backgroundColor: Colors.transparent,
      legend: Legend(
        isVisible: true,
        overflowMode: LegendItemOverflowMode.wrap,
        position: LegendPosition.bottom,
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 10, color: _T.textSec),
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true, color: _T.bgCardAlt,
        textStyle: GoogleFonts.spaceMono(color: _T.textPri, fontSize: 10),
      ),
      series: <CircularSeries>[
        DoughnutSeries<ChartData, String>(
          dataSource: data,
          xValueMapper: (d, _) => d.x,
          yValueMapper: (d, _) => d.y,
          pointColorMapper: (d, _) => d.color,
          innerRadius: '52%',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: _T.textPri),
          ),
          enableTooltip: true,
          explode: true, explodeIndex: 0, explodeOffset: '8%',
          animationDuration: 900,
        ),
      ],
    );
  }

  // ── Pie layouts (6 charts) ─────────────────────────────────────────────────

  List<Widget> _pieColumn(bool narrow) {
    const h = 230.0;
    return [
      _chartCard(title: 'Student Status',    sub: 'Active vs Pending',              icon: Icons.donut_large_rounded,    accent: _T.green,  chartH: h, child: _donut(_status,    'No data')),
      const SizedBox(height: 14),
      _chartCard(title: 'Students by Course', sub: 'Distribution across courses',   icon: Icons.school_rounded,         accent: _T.blue,   chartH: h, child: _donut(_byCourse,  'No data')),
      const SizedBox(height: 14),
      _chartCard(title: 'Students by Branch', sub: 'Distribution across branches',  icon: Icons.account_tree_rounded,   accent: _T.indigo, chartH: h, child: _donut(_byBranch,  'No data')),
      const SizedBox(height: 14),
      _chartCard(title: 'Faculty by Role',   sub: 'Position distribution',          icon: Icons.work_outline_rounded,   accent: _T.purple, chartH: h, child: _donut(_byRole,    'No data')),
      const SizedBox(height: 14),
      _chartCard(title: 'Faculty by Course', sub: 'Faculty across courses',         icon: Icons.menu_book_rounded,      accent: _T.amber,  chartH: h, child: _donut(_facByCourse,'No data')),
    ];
  }

  Widget _pieRows(bool narrow) {
    const h = 230.0;
    Widget pair(Widget a, Widget b) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ]),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pair(
          _chartCard(title: 'Student Status',     sub: 'Active vs Pending',             icon: Icons.donut_large_rounded,  accent: _T.green,  chartH: h, child: _donut(_status,     'No data')),
          _chartCard(title: 'Students by Course', sub: 'Distribution across courses',   icon: Icons.school_rounded,        accent: _T.blue,   chartH: h, child: _donut(_byCourse,  'No data')),
        ),
        pair(
          _chartCard(title: 'Students by Branch', sub: 'Distribution across branches', icon: Icons.account_tree_rounded,  accent: _T.indigo, chartH: h, child: _donut(_byBranch,  'No data')),
          _chartCard(title: 'Faculty by Role',    sub: 'Position distribution',         icon: Icons.work_outline_rounded,  accent: _T.purple, chartH: h, child: _donut(_byRole,    'No data')),
        ),
        // Last chart centred on its own row (odd count)
        _chartCard(title: 'Faculty by Course', sub: 'Faculty distribution across courses',
          icon: Icons.menu_book_rounded, accent: _T.amber, chartH: h,
          child: _donut(_facByCourse, 'No data')),
      ],
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────

  List<Widget> _skeletonItems() {
    Widget box(double h) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Shimmer.fromColors(
        baseColor: _T.bgCard, highlightColor: _T.bgCardAlt,
        child: Container(height: h,
            decoration: BoxDecoration(color: _T.bgCard,
                borderRadius: BorderRadius.circular(16))),
      ),
    );
    return [box(80), box(80), box(80), box(80), box(80),
            const SizedBox(height: 8), box(260), box(260)];
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _errorWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _T.rose.withOpacity(0.1), shape: BoxShape.circle,
              border: Border.all(color: _T.rose.withOpacity(0.3)),
            ),
            child: const Icon(Icons.error_outline_rounded,
                size: 44, color: _T.rose),
          ),
          const SizedBox(height: 18),
          Text('Something went wrong',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w700, color: _T.textPri)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: _T.textSec)),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: _T.blue),
            label: Text('Retry', style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w600, color: _T.blue)),
            style: TextButton.styleFrom(
              backgroundColor: _T.blue.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _T.blue.withOpacity(0.3)),
              ),
            ),
          ),
        ],
      )),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 15, color: _T.cyan),
      const SizedBox(width: 8),
      Text(text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: _T.textSec, letterSpacing: 1.2)),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: _T.border, thickness: 1)),
    ]);
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _GlassBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _GlassBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Center(child: child),
    ),
  );
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(
          color: color, blurRadius: size * 0.8, spreadRadius: size * 0.15)],
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF243050).withOpacity(0.3)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width;  x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}