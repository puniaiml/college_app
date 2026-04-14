// ignore_for_file: unused_field

import 'package:shiksha_hub/department_head/hod_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shiksha_hub/department_head/d_time_table/branch.dart';

import 'dart:math' as math;

class CollegePage extends StatefulWidget {
  const CollegePage({super.key});

  @override
  State<CollegePage> createState() => _CollegePageState();
}

class _CollegePageState extends State<CollegePage> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  
  List<QueryDocumentSnapshot> _colleges = [];
  List<QueryDocumentSnapshot> _filteredColleges = [];
  String? _selectedCollege;
  String _searchQuery = '';
  bool _isLoading = true;
  
  late AnimationController _cardsController;
  late AnimationController _backgroundController;
  final List<Bubble> bubbles = List.generate(20, (index) => Bubble());
  
  static const primaryIndigo = Color(0xFF3F51B5);
  static const primaryBlue = Color(0xFF1A237E);
  static const accentColor = Color(0xFF536DFE);

  @override
  void initState() {
    super.initState();
    _fetchColleges();
    
    // Set status bar color to match app theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: primaryIndigo,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    
    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    
    _cardsController.forward();
  }

  @override
  void dispose() {
    _cardsController.dispose();
    _backgroundController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchColleges() async {
    try {
      final snapshot = await _firestore.collection('colleges').get();
      setState(() {
        _colleges = snapshot.docs;
        _filteredColleges = _colleges;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading colleges: ${e.toString()}')),
      );
    }
  }

  void _filterColleges(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredColleges = _colleges;
      } else {
        _filteredColleges = _colleges.where((college) {
          final collegeName = (college.data() as Map<String, dynamic>)['name'].toString().toLowerCase();
          return collegeName.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _navigateToBranchSelection() async {
    if (_selectedCollege != null) {
      Get.to(() => BranchAdmin(selectedCollege: _selectedCollege!),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 300));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a college'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: primaryBlue,
        ),
      );
    }
  }

  void _unfocus() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    // Responsive dimensions
    final double cardHeight = size.height * 0.09;
    final double iconSize = size.width * 0.075;
    final double titleFontSize = size.width * 0.042;
    final double headerHeight = size.height * 0.18;
    final double searchMargin = size.width * 0.04;
    
    return GestureDetector(
      onTap: _unfocus,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: primaryIndigo,
            statusBarIconBrightness: Brightness.light,
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Animated background
                AnimatedBackground(
                  controller: _backgroundController,
                  bubbles: bubbles,
                ),
                
                // Main content
                Column(
                  children: [
                    // Header
                    _buildHeader(size, headerHeight),
                    
                    // Content
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: primaryIndigo,
                              ),
                            )
                          : SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  // Search bar
                                  _buildSearchBar(size, searchMargin),
                                  
                                  // Colleges list
                                  _buildCollegesList(
                                    size, 
                                    cardHeight, 
                                    iconSize, 
                                    titleFontSize
                                  ),
                                  
                                  // Add some space at the bottom
                                  SizedBox(height: size.height * 0.08),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
                
                // Next button - fixed at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildNextButton(size),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size, double headerHeight) {
    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryBlue, primaryIndigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryIndigo.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App bar
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.02,
              vertical: size.height * 0.01,
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Get.to(() => const HodHome()),
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
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                  iconSize: size.width * 0.06,
                ),
              ],
            ),
          ),
          
          // Header title
          Padding(
            padding: EdgeInsets.only(
              bottom: size.height * 0.02,
              left: size.width * 0.05,
              right: size.width * 0.05,
            ),
            child: Column(
              children: [
                Text(
                  'Select College',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: size.width * 0.07,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: size.height * 0.005),
                Text(
                  'Choose your institution to continue',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: size.width * 0.035,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Size size, double margin) {
    return Container(
      margin: EdgeInsets.fromLTRB(margin, margin * 1.5, margin, margin * 0.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search colleges...',
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: size.width * 0.04,
            color: Colors.grey[400],
          ),
          prefixIcon: Icon(
            Icons.search,
            color: primaryIndigo,
            size: size.width * 0.06,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  color: Colors.grey[400],
                  onPressed: () {
                    _searchController.clear();
                    _filterColleges('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: size.height * 0.018,
            horizontal: size.width * 0.02,
          ),
        ),
        onChanged: _filterColleges,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: size.width * 0.04,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCollegesList(
    Size size,
    double cardHeight,
    double iconSize,
    double titleFontSize,
  ) {
    if (_filteredColleges.isEmpty) {
      return Container(
        height: size.height * 0.3,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: size.width * 0.15,
              color: Colors.grey[400],
            ),
            SizedBox(height: size.height * 0.02),
            Text(
              'No colleges found',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: size.width * 0.045,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: size.height * 0.01),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: size.width * 0.035,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        size.width * 0.04,
        size.width * 0.01,
        size.width * 0.04,
        size.width * 0.04,
      ),
      itemCount: _filteredColleges.length,
      itemBuilder: (context, index) {
        final college = _filteredColleges[index].data() as Map<String, dynamic>;
        final collegeName = college['name'] as String;
        final isEven = index % 2 == 0;

        return CustomCollege(
          title: collegeName,
          isSelected: _selectedCollege == collegeName,
          onTap: () {
            _unfocus();
            setState(() {
              _selectedCollege = collegeName;
            });
          },
          color: isEven ? primaryBlue : primaryIndigo,
          index: index,
          totalItems: _filteredColleges.length,
          animation: _cardsController,
          cardHeight: cardHeight,
          iconSize: iconSize,
          titleFontSize: titleFontSize,
        );
      },
    );
  }

  Widget _buildNextButton(Size size) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.all(size.width * 0.04),
      child: ElevatedButton(
        onPressed: _navigateToBranchSelection,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryIndigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
          minimumSize: Size(size.width * 0.9, 0),
          elevation: 5,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: size.width * 0.05,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(width: size.width * 0.02),
            Icon(
              Icons.arrow_forward_rounded,
              size: size.width * 0.06,
            ),
          ],
        ),
      ),
    );
  }
}

class Bubble {
  double x = math.Random().nextDouble() * 1.5 - 0.2;
  double y = math.Random().nextDouble() * 1.2 - 0.2;
  double size = math.Random().nextDouble() * 25 + 5;
  double speed = math.Random().nextDouble() * 0.4 + 0.1;
  double opacity = math.Random().nextDouble() * 0.4 + 0.1;
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
        ..color = const Color(0xFF3F51B5).withOpacity(bubble.opacity)
        ..style = PaintingStyle.fill;

      final position = Offset(
        (bubble.x * size.width + animation.value * bubble.speed * size.width) % size.width,
        (bubble.y * size.height + animation.value * bubble.speed * size.height) % size.height,
      );

      canvas.drawCircle(position, bubble.size, paint);
    }
  }

  @override
  bool shouldRepaint(BubblePainter oldDelegate) => true;
}

class CustomCollege extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final int index;
  final int totalItems;
  final Animation<double> animation;
  final double cardHeight;
  final double iconSize;
  final double titleFontSize;

  const CustomCollege({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.color,
    required this.index,
    required this.totalItems,
    required this.animation,
    required this.cardHeight,
    required this.iconSize,
    required this.titleFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double intervalStart = (index / totalItems) * 0.7;
        final double intervalEnd = intervalStart + (0.3 / totalItems);

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

        final opacityAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Interval(
              intervalStart,
              intervalEnd,
              curve: Curves.easeIn,
            ),
          ),
        );

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: opacityAnimation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(15),
                  splashColor: Colors.white.withOpacity(0.2),
                  highlightColor: Colors.white.withOpacity(0.1),
                  child: Ink(
                    height: cardHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          isSelected ? color : color.withOpacity(0.95),
                          isSelected ? color.withOpacity(0.9) : color.withOpacity(0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(isSelected ? 0.4 : 0.25),
                          blurRadius: isSelected ? 10 : 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: cardHeight * 0.8,
                          height: cardHeight * 0.8,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            isSelected ? Icons.school : Icons.location_city,
                            size: iconSize,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 6,
                            ),
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12.0),
                          child: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: iconSize * 0.75,
                                )
                              : Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: iconSize * 0.5,
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