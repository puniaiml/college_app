import 'package:shiksha_hub/college_head/faculty_management.dart';
import 'package:shiksha_hub/college_head/hod_management.dart';
import 'package:shiksha_hub/college_head/course_branch_management.dart';
import 'package:shiksha_hub/college_head/shceem.dart';
import 'package:shiksha_hub/college_head/student_management_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shiksha_hub/widgets/profile_college_head.dart';
import 'package:shiksha_hub/auth/login.dart';

class CollegeStaffDrawer extends StatefulWidget {
  const CollegeStaffDrawer({super.key});

  @override
  State<CollegeStaffDrawer> createState() => _CollegeStaffDrawerState();
}

class _CollegeStaffDrawerState extends State<CollegeStaffDrawer>
    with TickerProviderStateMixin {
  
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _profileController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _profileScaleAnimation;

  // User data
  Map<String, dynamic>? userData;
  bool isLoading = true;

  // Colors
  static const primaryBlue = Color(0xFF1A237E);
  static const accentYellow = Color(0xFFFFD700);
  static const deepBlack = Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _fetchUserData();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _profileController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _profileScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _profileController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    _slideController.forward();
    _fadeController.forward();
    _profileController.forward();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get from college_staff collection
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc('college_staff')
            .collection('data')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          setState(() {
            userData = doc.data() as Map<String, dynamic>;
            isLoading = false;
          });
        } else {
          // Fallback to basic user info
          setState(() {
            userData = {
              'name': user.displayName ?? 'Staff Member',
              'email': user.email ?? 'No email',
              'collegeName': 'College Staff',
              'role': 'college_staff',
              'accountStatus': 'active',
              'isActive': true,
            };
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        userData = {
          'name': 'Staff Member',
          'email': 'No email',
          'collegeName': 'College Staff',
          'role': 'college_staff',
          'accountStatus': 'unknown',
          'isActive': false,
        };
        isLoading = false;
      });
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          backgroundColor: Colors.white,
          elevation: 20,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Confirm Logout",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Are you sure you want to logout?",
                        style: TextStyle(
                          color: deepBlack,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Color(0xFFD32F2F)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                    Get.offAll(() => const LoginPage());
                  } catch (e) {
                    Get.snackbar('Error', 'Failed to logout: $e');
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    bool showBadge = false,
    String? badgeText,
    int index = 0,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset((1 - value) * 100, 0),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (iconColor ?? Colors.white).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: iconColor ?? Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (showBadge && badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white54,
                          size: 16,
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

  Widget _buildProfileHeader() {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _profileScaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Profile Image with Status Indicator
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    child: userData?['profileImageUrl'] != null && 
                           userData!['profileImageUrl'].toString().isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              userData!['profileImageUrl'],
                              width: 85,
                              height: 85,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar();
                              },
                            ),
                          )
                        : _buildDefaultAvatar(),
                  ),
                ),
                // Status indicator
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Name
            Text(
              userData?['name'] ?? 'Staff Member',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            
            // Email
            Text(
              userData?['email'] ?? 'No email',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),
            
            // College
            if (userData?['collegeName'] != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentYellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  userData!['collegeName'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            
            // Course if available
            if (userData?['courseName'] != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  userData!['courseName'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (userData == null) return Colors.grey;
    
    final isActive = userData!['isActive'] ?? false;
    final isEmailVerified = userData!['isEmailVerified'] ?? false;
    final accountStatus = userData!['accountStatus'] ?? 'inactive';
    
    if (isActive && isEmailVerified && accountStatus == 'active') {
      return Colors.green;
    } else if (!isEmailVerified) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 85,
      height: 85,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            primaryBlue.withOpacity(0.7),
            primaryBlue.withOpacity(0.9),
          ],
        ),
      ),
      child: const Icon(
        Icons.person,
        size: 45,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: screenWidth * 0.85,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryBlue,
              primaryBlue.withOpacity(0.9),
              const Color(0xFF0D47A1),
            ],
          ),
        ),
        child: Drawer(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildDrawerItem(
                          icon: Icons.person_rounded,
                          title: "My Profile",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const CollegeStaffProfilePage());
                          },
                          iconColor: Colors.blue[300],
                          index: 1,
                        ),
                        _buildDrawerItem(
                          icon: Icons.school_rounded,
                          title: "Course/Branch Management",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const StaffCourseBranchSemesterManagementPage());
                          },
                          iconColor: Colors.green[300],
                          index: 2,
                        ),
                        _buildDrawerItem(
                          icon: Icons.article_rounded,
                          title: "Scheme Management",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const StaffSchemeManagementPage());
                          },
                          iconColor: const Color.fromARGB(255, 246, 255, 120),
                          index: 2,
                        ),
                        _buildDrawerItem(
                          icon: Icons.assignment_ind,
                          title: "Department Head Management",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const HODManagementPage());
                          },
                          iconColor: const Color.fromARGB(255, 3, 255, 234),
                          index: 2,
                        ),
                        _buildDrawerItem(
                          icon: Icons.engineering,
                          title: "Faculty Management",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const FacultyManagementPage());
                          },
                          iconColor: const Color.fromARGB(255, 217, 255, 3),
                          index: 2,
                        ),
                        _buildDrawerItem(
                          icon: Icons.groups,
                          title: "Student Management",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const CollegeStudentManagementPage());
                          },
                          iconColor: const Color.fromARGB(255, 255, 27, 27),
                          index: 2,
                        ),
                        _buildDrawerItem(
                          icon: Icons.event_rounded,
                          title: "Events & Notices",
                          onTap: () {
                            Navigator.pop(context);
                            // Add events page navigation
                          },
                          iconColor: Colors.teal[300],
                          index: 5,
                        ),
                      
                        _buildDrawerItem(
                          icon: Icons.notifications_rounded,
                          title: "Notifications",
                          onTap: () {
                            Navigator.pop(context);
                            // Add notifications page navigation
                          },
                          iconColor: Colors.red[300],
                          showBadge: true,
                          badgeText: "5",
                          index: 7,
                        ),
                        
                        _buildDrawerItem(
                          icon: Icons.help_rounded,
                          title: "Help & Support",
                          onTap: () {
                            Navigator.pop(context);
                            // Add help page navigation
                          },
                          iconColor: Colors.cyan[300],
                          index: 9,
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  _buildDrawerItem(
                    icon: Icons.logout_rounded,
                    title: "Logout",
                    onTap: () {
                      Navigator.pop(context);
                      _confirmLogout(context);
                    },
                    iconColor: Colors.red[400],
                    index: 10,
                  ),
                  const SizedBox(height: 20),
                  
                  // App version
                  Text(
                    "Staff Portal v1.0.0",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _profileController.dispose();
    super.dispose();
  }
}

