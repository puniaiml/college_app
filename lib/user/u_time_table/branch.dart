import 'package:shiksha_hub/user/u_time_table/semester.dart';
import 'package:shiksha_hub/user/user_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class StudentBranchAdmin extends StatefulWidget {
  final String selectedCollege;

  const StudentBranchAdmin({super.key, required this.selectedCollege});

  @override
  State<StudentBranchAdmin> createState() => _StudentBranchAdminState();
}

class _StudentBranchAdminState extends State<StudentBranchAdmin>
    with TickerProviderStateMixin {
  late AnimationController _cardsController;
  late AnimationController _backgroundController;
  final List<Bubble> bubbles = List.generate(15, (index) => Bubble());

  List<Map<String, dynamic>> _availableBranches = [];
  bool _isLoadingBranches = true;
  String? _errorMessage;

  static const primaryIndigo = Color(0xFF3F51B5);
  static const primaryBlue = Color(0xFF1A237E);

  final Map<String, IconData> _branchIcons = {
    'AIML': Icons.psychology,
    'CSE': Icons.computer,
    'ISE': Icons.security,
    'ECE': Icons.electrical_services,
    'EEE': Icons.electric_bolt,
    'MECH': Icons.precision_manufacturing,
    'CIVIL': Icons.architecture,
    'RAI': Icons.smart_toy,
    'Basic Science': Icons.science,
    'Artificial Intelligence': Icons.psychology,
    'Computer Science': Icons.computer,
    'Information Science': Icons.security,
    'Electronics': Icons.electrical_services,
    'Electrical': Icons.electric_bolt,
    'Mechanical': Icons.precision_manufacturing,
    'Civil': Icons.architecture,
    'Robotics': Icons.smart_toy,
    'Science': Icons.science,
  };

  @override
  void initState() {
    super.initState();
    // Set status bar color immediately
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: primaryIndigo, // Match your app bar color
        statusBarIconBrightness: Brightness.light, // White icons
        statusBarBrightness: Brightness.dark, // For iOS
      ),
    );

    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _loadAvailableBranches();
  }

  @override
  void dispose() {
    _cardsController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableBranches() async {
    try {
      setState(() {
        _isLoadingBranches = true;
        _errorMessage = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(user.uid)
          .get();

      if (!studentDoc.exists) {
        throw Exception('Student data not found');
      }

      final studentData = studentDoc.data() as Map<String, dynamic>;

      String? collegeId = studentData['collegeId'] as String?;
      String? collegeName = studentData['collegeName'] as String?;
      String? universityId = studentData['universityId'] as String?;
      String? universityName = studentData['universityName'] as String?;

      if (collegeId == null && collegeName == null) {
        throw Exception('College information not found in profile');
      }

      Query branchQuery = FirebaseFirestore.instance.collection('branches');

      if (collegeId != null) {
        branchQuery = branchQuery.where('collegeId', isEqualTo: collegeId);
      } else if (collegeName != null) {
        branchQuery = branchQuery.where('collegeName', isEqualTo: collegeName);
      }

      QuerySnapshot branchSnapshot = await branchQuery.get();

      List<Map<String, dynamic>> branches = [];

      for (var doc in branchSnapshot.docs) {
        final branchData = doc.data() as Map<String, dynamic>;
        final branchId = doc.id;
        final branchName = branchData['name'] as String? ?? branchId;
        final branchDescription = _getDefaultDescription(branchName);

        branches.add({
          'id': branchId,
          'title': branchName,
          'displayName': branchName,
          'subtitle': branchDescription,
          'icon': _getBranchIcon(branchName),
          'color': _getBranchColor(branches.length),
          'data': branchData,
        });
      }

      if (branches.isEmpty) {
        setState(() {
          _availableBranches = [];
          _isLoadingBranches = false;
          _errorMessage = 'No branches found for your college';
        });
        return;
      }

      setState(() {
        _availableBranches = branches;
        _isLoadingBranches = false;
      });

      _cardsController.forward();
    } catch (e) {
      print('Error loading branches: $e');
      setState(() {
        _isLoadingBranches = false;
        _errorMessage = 'Failed to load branches: ${e.toString()}';
      });

      Get.snackbar(
        'Error',
        'Failed to load branches: ${e.toString()}',
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        duration: const Duration(seconds: 5),
      );
    }
  }

  IconData _getBranchIcon(String branchName) {
    if (_branchIcons.containsKey(branchName)) {
      return _branchIcons[branchName]!;
    }

    for (String key in _branchIcons.keys) {
      if (branchName.toUpperCase().contains(key.toUpperCase()) ||
          key.toUpperCase().contains(branchName.toUpperCase())) {
        return _branchIcons[key]!;
      }
    }

    final name = branchName.toLowerCase();
    if (name.contains('computer') || name.contains('cse')) {
      return Icons.computer;
    } else if (name.contains('electrical') || name.contains('eee')) {
      return Icons.electric_bolt;
    } else if (name.contains('mechanical') || name.contains('mech')) {
      return Icons.precision_manufacturing;
    } else if (name.contains('civil')) {
      return Icons.architecture;
    } else if (name.contains('electronics') || name.contains('ece')) {
      return Icons.electrical_services;
    } else if (name.contains('information') || name.contains('ise')) {
      return Icons.security;
    } else if (name.contains('artificial') ||
        name.contains('ai') ||
        name.contains('ml')) {
      return Icons.psychology;
    } else if (name.contains('robot')) {
      return Icons.smart_toy;
    } else if (name.contains('science')) {
      return Icons.science;
    }

    return Icons.school;
  }

  Color _getBranchColor(int index) {
    return index % 2 == 0 ? primaryBlue : primaryIndigo;
  }

  String _getDefaultDescription(String branchName) {
    final descriptions = {
      'AIML': 'Artificial Intelligence & Machine Learning',
      'CSE': 'Computer Science Engineering',
      'ISE': 'Information Science Engineering',
      'ECE': 'Electronics & Communication Engineering',
      'EEE': 'Electrical & Electronics Engineering',
      'MECH': 'Mechanical Engineering',
      'CIVIL': 'Civil Engineering',
      'RAI': 'Robotics & Artificial Intelligence',
    };

    return descriptions[branchName] ?? '$branchName Department';
  }

  Widget _buildLoadingView() {
    final size = MediaQuery.of(context).size;

    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: size.width * 0.15,
              height: size.width * 0.15,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryIndigo),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: size.height * 0.03),
            Text(
              'Loading branches...',
              style: TextStyle(
                fontSize: size.width * 0.045,
                color: primaryIndigo,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    final size = MediaQuery.of(context).size;

    return Expanded(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(size.width * 0.06),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: size.width * 0.15,
                color: Colors.red.withOpacity(0.7),
              ),
              SizedBox(height: size.height * 0.02),
              Text(
                'Unable to Load Branches',
                style: TextStyle(
                  fontSize: size.width * 0.055,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.withOpacity(0.8),
                ),
              ),
              SizedBox(height: size.height * 0.015),
              Text(
                _errorMessage ?? 'An unexpected error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size.width * 0.04,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: size.height * 0.03),
              ElevatedButton.icon(
                onPressed: _loadAvailableBranches,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryIndigo,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.08,
                    vertical: size.height * 0.015,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final size = MediaQuery.of(context).size;

    return Expanded(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(size.width * 0.06),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: size.width * 0.2,
                color: Colors.grey.withOpacity(0.5),
              ),
              SizedBox(height: size.height * 0.02),
              Text(
                'No Branches Available',
                style: TextStyle(
                  fontSize: size.width * 0.055,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: size.height * 0.015),
              Text(
                'No active branches found for your college. Please contact the administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size.width * 0.04,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: size.height * 0.03),
              ElevatedButton.icon(
                onPressed: _loadAvailableBranches,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryIndigo,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.08,
                    vertical: size.height * 0.015,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double cardHeight = size.height * 0.11;
    final double iconSize = size.width * 0.08;
    final double titleFontSize = size.width * 0.055;
    final double subtitleFontSize = size.width * 0.036;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: primaryIndigo,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              AnimatedBackground(
                controller: _backgroundController,
                bubbles: bubbles,
              ),
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                    ),
                    height: kToolbarHeight +
                        60 +
                        MediaQuery.of(context).padding.top,
                    decoration: BoxDecoration(
                      color: primaryIndigo,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => Get.to(
                                () => const HomePage(),
                                transition: Transition.fadeIn,
                                duration: const Duration(milliseconds: 300),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(size.width * 0.025),
                                child: Image.asset(
                                  'assets/images/partners.png',
                                  height: size.width * 0.08,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Shiksha Hub',
                                style: TextStyle(
                                  fontFamily: 'Lobster',
                                  fontSize: 22,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              color: Colors.white,
                              onPressed: () => Navigator.of(context).pop(),
                              iconSize: size.width * 0.06,
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: size.height * 0.01),
                          child: Text(
                            'Select Branch',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: size.width * 0.07,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoadingBranches)
                    _buildLoadingView()
                  else if (_errorMessage != null && _availableBranches.isEmpty)
                    _buildErrorView()
                  else if (_availableBranches.isEmpty)
                    _buildEmptyView()
                  else
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.04,
                          vertical: size.width * 0.03,
                        ),
                        itemCount: _availableBranches.length,
                        itemBuilder: (context, index) {
                          final branch = _availableBranches[index];
                          return CustomBranch(
                            title: branch['displayName'] ?? branch['title'],
                            subtitle: branch['subtitle'],
                            icon: branch['icon'],
                            color: branch['color'],
                            onTap: () => _navigateToSemesterPage(
                                context, branch['id'], branch['title']),
                            index: index,
                            totalItems: _availableBranches.length,
                            animation: _cardsController,
                            cardHeight: cardHeight,
                            iconSize: iconSize,
                            titleFontSize: titleFontSize,
                            subtitleFontSize: subtitleFontSize,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSemesterPage(
      BuildContext context, String branchId, String branchName) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            StudentSemesterPage(
          selectedCollege: widget.selectedCollege,
          branchId: branchId,
          branchName: branchName,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}

class Bubble {
  double x = math.Random().nextDouble() * 1.5 - 0.2;
  double y = math.Random().nextDouble() * 1.2 - 0.2;
  double size = math.Random().nextDouble() * 20 + 5;
  double speed = math.Random().nextDouble() * 0.5 + 0.1;
}

class AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  final List<Bubble> bubbles;

  const AnimatedBackground({
    super.key,
    required this.controller,
    required this.bubbles,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: BubblePainter(
            bubbles: bubbles,
            animation: controller,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class BubblePainter extends CustomPainter {
  final List<Bubble> bubbles;
  final Animation<double> animation;

  BubblePainter({required this.bubbles, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    for (var bubble in bubbles) {
      final paint = Paint()
        ..color = const Color(0xFF3F51B5).withOpacity(0.1)
        ..style = PaintingStyle.fill;

      final position = Offset(
        (bubble.x * size.width + animation.value * bubble.speed * size.width) %
            size.width,
        (bubble.y * size.height +
                animation.value * bubble.speed * size.height) %
            size.height,
      );

      canvas.drawCircle(position, bubble.size, paint);
    }
  }

  @override
  bool shouldRepaint(BubblePainter oldDelegate) => true;
}

class CustomBranch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int index;
  final int totalItems;
  final Animation<double> animation;
  final double cardHeight;
  final double iconSize;
  final double titleFontSize;
  final double subtitleFontSize;

  const CustomBranch({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.index,
    required this.totalItems,
    required this.animation,
    required this.cardHeight,
    required this.iconSize,
    required this.titleFontSize,
    required this.subtitleFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double intervalStart = (index / totalItems) * 0.6;
        final double intervalEnd = intervalStart + (0.4 / totalItems);

        final slideAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Interval(
              intervalStart,
              intervalEnd,
              curve: Curves.easeOutCubic,
            ),
          ),
        );

        return SlideTransition(
          position: slideAnimation,
          child: Hero(
            tag: 'branch-$title',
            flightShuttleBuilder: (
              BuildContext flightContext,
              Animation<double> animation,
              HeroFlightDirection flightDirection,
              BuildContext fromHeroContext,
              BuildContext toHeroContext,
            ) {
              return Material(
                color: Colors.transparent,
                child: ScaleTransition(
                  scale: animation.drive(
                    Tween<double>(begin: 0.9, end: 1.0)
                        .chain(CurveTween(curve: Curves.easeInOut)),
                  ),
                  child: fromHeroContext.widget,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  splashColor: Colors.white.withOpacity(0.3),
                  highlightColor: Colors.white.withOpacity(0.1),
                  child: Container(
                    height: cardHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.9),
                          color.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: cardHeight * 0.75,
                          height: cardHeight * 0.75,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            icon,
                            size: iconSize,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: subtitleFontSize,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: iconSize * 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension CustomPageTransition on Widget {
  PageRouteBuilder getCustomPageRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => this,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }
}