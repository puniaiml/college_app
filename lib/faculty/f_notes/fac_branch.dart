import 'package:shiksha_hub/faculty/f_notes/select_scheme.dart';
import 'package:shiksha_hub/faculty/faculty_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (identical to SelectBranchAdmin)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const indigo900 = Color(0xFF1A237E);
  static const indigo700 = Color(0xFF303F9F);
  static const indigo500 = Color(0xFF3F51B5);
  static const indigo300 = Color(0xFF7986CB);
  static const indigo100 = Color(0xFFC5CAE9);
  static const white     = Colors.white;
  static const bg        = Color(0xFFF0F2FA);

  static const _accents = <String, Color>{
    'AIML':             Color(0xFF0277BD),
    'ARTIFICIAL':       Color(0xFF0277BD),
    'MACHINE LEARNING': Color(0xFF0277BD),
    'DATA SCIENCE':     Color(0xFF00838F),
    'COMPUTER':         Color(0xFF1565C0),
    'CSE':              Color(0xFF1565C0),
    'INFORMATION':      Color(0xFF283593),
    'ISE':              Color(0xFF283593),
    'SOFTWARE':         Color(0xFF1B5E20),
    'CYBER':            Color(0xFF4A148C),
    'NETWORK':          Color(0xFF006064),
    'CLOUD':            Color(0xFF01579B),
    'ECE':              Color(0xFF6A1B9A),
    'VLSI':             Color(0xFF4A148C),
    'EMBEDDED':         Color(0xFF37474F),
    'ELECTRON':         Color(0xFF6A1B9A),
    'EEE':              Color(0xFF4527A0),
    'POWER':            Color(0xFF827717),
    'ELECTRICAL':       Color(0xFF4527A0),
    'MECHATRON':        Color(0xFF004D40),
    'MECHANICAL':       Color(0xFF00695C),
    'MECH':             Color(0xFF00695C),
    'AUTOMOBILE':       Color(0xFF33691E),
    'AEROSPACE':        Color(0xFF0D47A1),
    'AERONAUT':         Color(0xFF0D47A1),
    'CIVIL':            Color(0xFF4E342E),
    'STRUCT':           Color(0xFF5D4037),
    'ENVIRONMENT':      Color(0xFF2E7D32),
    'URBAN':            Color(0xFF37474F),
    'ROBOTICS':         Color(0xFF00838F),
    'RAI':              Color(0xFF00838F),
    'IOT':              Color(0xFF00695C),
    'BIOMEDICAL':       Color(0xFFC62828),
    'BIOTECHNOLOGY':    Color(0xFF558B2F),
    'CHEMICAL':         Color(0xFFE65100),
    'PHYSICS':          Color(0xFF283593),
    'MATHEMATICS':      Color(0xFF4E342E),
    'BASIC SCIENCE':    Color(0xFF1565C0),
    'SCIENCE':          Color(0xFF1565C0),
    'BUSINESS':         Color(0xFF1A237E),
    'MANAGEMENT':       Color(0xFF1A237E),
    'FINANCE':          Color(0xFF1B5E20),
    'ARCHITECTURE':     Color(0xFF4E342E),
    'DESIGN':           Color(0xFF880E4F),
    'ART':              Color(0xFF880E4F),
    'MEDICAL':          Color(0xFFC62828),
    'HEALTH':           Color(0xFFC62828),
    'NURSING':          Color(0xFFAD1457),
    'AGRICULTURE':      Color(0xFF33691E),
    'FOOD':             Color(0xFFBF360C),
  };

  static Color accentFor(String name) {
    final up = name.toUpperCase();
    for (final k in _accents.keys) {
      if (up.contains(k)) return _accents[k]!;
    }
    return indigo700;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ICON + DESCRIPTION HELPERS
// ─────────────────────────────────────────────────────────────────────────────
const List<(String, IconData, String)> _kwMap = [
  ('ARTIFICIAL INTELLIGENCE', Icons.auto_awesome,           'Artificial Intelligence'),
  ('MACHINE LEARNING',        Icons.auto_awesome,           'Machine Learning'),
  ('AIML',                    Icons.auto_awesome,           'AI & Machine Learning'),
  ('DATA SCIENCE',            Icons.bar_chart,              'Data Science'),
  ('DATA ENGINEER',           Icons.storage,                'Data Engineering'),
  ('COMPUTER SCIENCE',        Icons.terminal,               'Computer Science Engg.'),
  ('CSE',                     Icons.terminal,               'Computer Science Engg.'),
  ('INFORMATION SCIENCE',     Icons.shield_outlined,        'Information Science Engg.'),
  ('INFORMATION TECH',        Icons.dns_outlined,           'Information Technology'),
  ('ISE',                     Icons.shield_outlined,        'Information Science Engg.'),
  ('SOFTWARE',                Icons.code,                   'Software Engineering'),
  ('CYBER',                   Icons.security,               'Cyber Security'),
  ('NETWORK',                 Icons.hub_outlined,           'Network Engineering'),
  ('CLOUD',                   Icons.cloud_outlined,         'Cloud Computing'),
  ('WEB',                     Icons.language,               'Web Technologies'),
  ('ELECTRONICS & COMMUNICATION', Icons.waves,              'Electronics & Communication'),
  ('ECE',                     Icons.waves,                  'Electronics & Communication'),
  ('VLSI',                    Icons.memory,                 'VLSI Design'),
  ('EMBEDDED',                Icons.developer_board,        'Embedded Systems'),
  ('SIGNAL',                  Icons.graphic_eq,             'Signal Processing'),
  ('TELECOMMUN',              Icons.cell_tower,             'Telecommunication'),
  ('ELECTRON',                Icons.electrical_services,    'Electronics Engg.'),
  ('ELECTRICAL & ELECTRONICS', Icons.flash_on,              'Electrical & Electronics'),
  ('EEE',                     Icons.flash_on,               'Electrical & Electronics'),
  ('POWER',                   Icons.bolt,                   'Power Systems'),
  ('ELECTRICAL',              Icons.electric_bolt,          'Electrical Engineering'),
  ('MECHATRON',               Icons.precision_manufacturing,'Mechatronics'),
  ('MECHANICAL',              Icons.settings,               'Mechanical Engineering'),
  ('MECH',                    Icons.settings,               'Mechanical Engineering'),
  ('THERMAL',                 Icons.thermostat,             'Thermal Engineering'),
  ('MANUFACT',                Icons.factory,                'Manufacturing Engg.'),
  ('AUTOMOBILE',              Icons.directions_car,         'Automobile Engineering'),
  ('AEROSPACE',               Icons.flight,                 'Aerospace Engineering'),
  ('AERONAUT',                Icons.flight,                 'Aeronautical Engineering'),
  ('CIVIL',                   Icons.domain,                 'Civil Engineering'),
  ('STRUCT',                  Icons.apartment,              'Structural Engineering'),
  ('ENVIRONMENT',             Icons.eco,                    'Environmental Engg.'),
  ('TRANSPORT',               Icons.commute,                'Transportation Engg.'),
  ('URBAN',                   Icons.location_city,          'Urban Planning'),
  ('CONSTRUCTION',            Icons.construction,           'Construction Engg.'),
  ('ROBOTICS',                Icons.smart_toy_outlined,     'Robotics Engineering'),
  ('RAI',                     Icons.smart_toy_outlined,     'Robotics & AI'),
  ('AUTOMATION',              Icons.smart_toy_outlined,     'Automation Engg.'),
  ('DRONE',                   Icons.airplanemode_active,    'Drone Technology'),
  ('IOT',                     Icons.sensors,                'Internet of Things'),
  ('BIOTECHNOLOGY',           Icons.biotech,                'Biotechnology'),
  ('BIOCHEM',                 Icons.biotech,                'Biochemical Engg.'),
  ('CHEMICAL',                Icons.science_outlined,       'Chemical Engineering'),
  ('PHARMA',                  Icons.medication,             'Pharmaceutical Engg.'),
  ('NANOTECHNOLOGY',          Icons.grain,                  'Nanotechnology'),
  ('MATERIAL',                Icons.layers_outlined,        'Materials Science'),
  ('PHYSICS',                 Icons.blur_on,                'Physics'),
  ('MATHEMATICS',             Icons.functions,              'Mathematics'),
  ('MATH',                    Icons.functions,              'Mathematics'),
  ('STATISTIC',               Icons.bar_chart,              'Statistics'),
  ('BASIC SCIENCE',           Icons.science_outlined,       'Basic Sciences'),
  ('SCIENCE',                 Icons.science_outlined,       'Science'),
  ('BUSINESS',                Icons.business_center,        'Business Studies'),
  ('MANAGEMENT',              Icons.manage_accounts,        'Management Studies'),
  ('MBA',                     Icons.business_center,        'Business Administration'),
  ('COMMERCE',                Icons.store,                  'Commerce'),
  ('ECONOMICS',               Icons.trending_up,            'Economics'),
  ('FINANCE',                 Icons.account_balance,        'Finance'),
  ('ACCOUNTING',              Icons.receipt_long,           'Accounting'),
  ('MARKETING',               Icons.campaign,               'Marketing'),
  ('HUMAN RESOURCE',          Icons.people,                 'Human Resources'),
  ('ARCHITECTURE',            Icons.architecture,           'Architecture'),
  ('DESIGN',                  Icons.design_services,        'Design'),
  ('INTERIOR',                Icons.chair,                  'Interior Design'),
  ('FASHION',                 Icons.checkroom,              'Fashion Design'),
  ('FINE ART',                Icons.palette,                'Fine Arts'),
  ('ART',                     Icons.palette,                'Arts'),
  ('MEDIA',                   Icons.movie,                  'Media Studies'),
  ('JOURNALISM',              Icons.article,                'Journalism'),
  ('FILM',                    Icons.videocam,               'Film Studies'),
  ('ANIMATION',               Icons.animation,              'Animation'),
  ('GAME',                    Icons.sports_esports,         'Game Design'),
  ('BIOMEDICAL',              Icons.monitor_heart,          'Biomedical Engg.'),
  ('MEDICAL',                 Icons.local_hospital,         'Medical Sciences'),
  ('NURSING',                 Icons.medical_services,       'Nursing'),
  ('DENTIST',                 Icons.medical_services,       'Dentistry'),
  ('HEALTH',                  Icons.health_and_safety,      'Health Sciences'),
  ('PSYCHOLOGY',              Icons.psychology,             'Psychology'),
  ('LAW',                     Icons.gavel,                  'Law'),
  ('LEGAL',                   Icons.gavel,                  'Legal Studies'),
  ('SOCIAL',                  Icons.groups,                 'Social Sciences'),
  ('POLITICAL',               Icons.account_balance,        'Political Science'),
  ('HISTORY',                 Icons.history_edu,            'History'),
  ('GEOGRAPHY',               Icons.public,                 'Geography'),
  ('LANGUAGE',                Icons.translate,              'Languages'),
  ('ENGLISH',                 Icons.menu_book,              'English'),
  ('LITERATURE',              Icons.menu_book,              'Literature'),
  ('AGRICULTURE',             Icons.grass,                  'Agriculture'),
  ('HORTICULTURE',            Icons.local_florist,          'Horticulture'),
  ('FORESTRY',                Icons.park,                   'Forestry'),
  ('FOOD',                    Icons.restaurant,             'Food Technology'),
  ('PHYSICAL',                Icons.fitness_center,         'Physical Education'),
  ('SPORT',                   Icons.sports,                 'Sports Science'),
];

IconData _iconFor(String name) {
  final up = name.toUpperCase();
  for (final (kw, icon, _) in _kwMap) {
    if (up.contains(kw)) return icon;
  }
  return Icons.school_outlined;
}

String _descFor(String name) {
  final up = name.toUpperCase();
  for (final (kw, _, desc) in _kwMap) {
    if (up.contains(kw)) return desc;
  }
  final trimmed = name.trim();
  return trimmed.length > 6 ? trimmed : '$trimmed Department';
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class BranchFaculty extends StatefulWidget {
  final String selectedCollege;
  const BranchFaculty({super.key, required this.selectedCollege});

  @override
  State<BranchFaculty> createState() => _BranchFacultyState();
}

class _BranchFacultyState extends State<BranchFaculty>
    with SingleTickerProviderStateMixin {

  // PERFORMANCE: single lightweight AnimationController (no BubblePainter)
  late final AnimationController _listCtrl = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  List<Map<String, dynamic>> _branches = [];
  bool    _loading = true;
  String? _error;
  String? _facultyBranchId;

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness:     Brightness.dark,
    ));
    _loadBranches();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  Future<void> _loadBranches() async {
    try {
      setState(() { _loading = true; _error = null; });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // PERFORMANCE: 2 Firestore reads total
      final facultySnap = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .doc(user.uid)
          .get();

      if (!facultySnap.exists) throw Exception('Faculty profile not found');
      final faculty = facultySnap.data()!;

      _facultyBranchId = faculty['branchId'] as String?;
      final collegeId   = faculty['collegeId']   as String?;
      final collegeName = faculty['collegeName'] as String?;

      if (collegeId == null && collegeName == null) {
        throw Exception('College info missing in profile');
      }

      Query q = FirebaseFirestore.instance.collection('branches');
      q = collegeId != null
          ? q.where('collegeId', isEqualTo: collegeId)
          : q.where('collegeName', isEqualTo: collegeName);

      final snap = await q.get();

      if (snap.docs.isEmpty) {
        if (mounted) setState(() { _loading = false; _branches = []; });
        return;
      }

      final list = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] as String?) ?? doc.id;
        return <String, dynamic>{
          'id':     doc.id,
          'name':   name,
          'desc':   _descFor(name),
          'icon':   _iconFor(name),
          'accent': _C.accentFor(name),
        };
      }).toList();

      // Faculty's own branch first → then A–Z
      list.sort((a, b) {
        final aOwn = a['id'] == _facultyBranchId;
        final bOwn = b['id'] == _facultyBranchId;
        if (aOwn && !bOwn) return -1;
        if (!aOwn && bOwn) return 1;
        return (a['name'] as String)
            .toLowerCase()
            .compareTo((b['name'] as String).toLowerCase());
      });

      if (mounted) {
        setState(() { _branches = list; _loading = false; });
        _listCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _go(String id, String name) => Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => FacultySelectSchemePage(
        branch: name,
        branchId: id,
        selectedCollege: widget.selectedCollege,
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
            _Header(topPad: MediaQuery.of(context).padding.top),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const _LoadingView();
    if (_error != null && _branches.isEmpty) {
      return _ErrorView(error: _error!, onRetry: _loadBranches);
    }
    if (_branches.isEmpty) return _EmptyView(onRetry: _loadBranches);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: _branches.length,
      // PERFORMANCE: RepaintBoundary isolates each card repaint
      itemBuilder: (ctx, i) {
        final b      = _branches[i];
        final isOwn  = b['id'] == _facultyBranchId;

        final interval = CurvedAnimation(
          parent: _listCtrl,
          curve: Interval(
            (i / _branches.length) * 0.5,
            (i / _branches.length) * 0.5 + 0.5,
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
            child: _BranchCard(
              name:   b['name']   as String,
              desc:   b['desc']   as String,
              icon:   b['icon']   as IconData,
              accent: b['accent'] as Color,
              isOwn:  isOwn,
              onTap:  () => _go(b['id'] as String, b['name'] as String),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final double topPad;
  const _Header({required this.topPad});

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
                  'Select Branch',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: _C.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a department to explore',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.65),
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
//  BRANCH CARD
// ─────────────────────────────────────────────────────────────────────────────
class _BranchCard extends StatelessWidget {
  final String   name;
  final String   desc;
  final IconData icon;
  final Color    accent;
  final bool     isOwn;
  final VoidCallback onTap;

  const _BranchCard({
    required this.name,
    required this.desc,
    required this.icon,
    required this.accent,
    required this.isOwn,
    required this.onTap,
  });

  // Amber tint for the faculty's own branch (mirrors HOD amber in SelectBranchAdmin)
  static const _amber = Color(0xFFFFB300);

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
                colors: [
                  isOwn
                      ? accent.withOpacity(0.14)
                      : _C.indigo500.withOpacity(0.06),
                  Colors.white,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOwn ? _amber.withOpacity(0.85) : _C.indigo100,
                width: isOwn ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isOwn ? _amber : _C.indigo500)
                      .withOpacity(isOwn ? 0.18 : 0.10),
                  blurRadius: isOwn ? 18 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  // ── Icon ──────────────────────────────────
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
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),

                  // ── Text ─────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: _C.indigo900,
                                ),
                              ),
                            ),
                            if (isOwn) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _amber,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'My Branch',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          desc,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            color: _C.indigo700.withOpacity(0.60),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // ── Arrow ────────────────────────────────
                  Container(
                    width: 32, height: 32,
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
        Text('Loading branches…',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: _C.indigo700.withOpacity(0.65),
            fontWeight: FontWeight.w500,
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
          const Text('Could not load branches',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _C.indigo900,
            )),
          const SizedBox(height: 8),
          Text(error,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins',
                fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 24),
          _PillButton(label: 'Try Again', icon: Icons.refresh, onTap: onRetry),
        ],
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

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
            child: const Icon(Icons.school_outlined,
                color: _C.indigo300, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('No Branches Found',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _C.indigo900,
            )),
          const SizedBox(height: 8),
          Text(
            'No branches are assigned to your college yet.\nPlease contact the administrator.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins',
                fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          _PillButton(label: 'Refresh', icon: Icons.refresh, onTap: onRetry),
        ],
      ),
    ),
  );
}

class _PillButton extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final VoidCallback onTap;
  const _PillButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label,
      style: const TextStyle(
          fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
    style: ElevatedButton.styleFrom(
      backgroundColor: _C.indigo500,
      foregroundColor: _C.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 4,
      shadowColor: _C.indigo500.withOpacity(0.4),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAGE TRANSITION EXTENSION
// ─────────────────────────────────────────────────────────────────────────────
extension CustomPageTransition on Widget {
  PageRouteBuilder getCustomPageRoute() => PageRouteBuilder(
    pageBuilder: (_, __, ___) => this,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOutCubic))
          .animate(anim),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
}