import 'package:shiksha_hub/faculty/department_analysis.dart';
import 'package:shiksha_hub/faculty/student_management_page.dart';
import 'package:shiksha_hub/faculty/subject_management.dart';
import 'package:shiksha_hub/hod&faculty/mentor.dart';
import 'package:shiksha_hub/widgets/profile_page_faculty.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shiksha_hub/auth/login.dart';

import '../hod&faculty/branch_student_export.dart';

class FacultyDrawer extends StatefulWidget {
  const FacultyDrawer({super.key});

  @override
  State<FacultyDrawer> createState() => _FacultyDrawerState();
}

class _FacultyDrawerState extends State<FacultyDrawer>
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
        // Get from faculty collection (changed from college_staff)
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc('faculty')
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
              'name': user.displayName ?? 'Faculty Member',
              'email': user.email ?? 'No email',
              'collegeName': 'Faculty',
              'role': 'faculty',
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
          'name': 'Faculty Member',
          'email': 'No email',
          'collegeName': 'Faculty',
          'role': 'faculty',
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
              userData?['name'] ?? 'Faculty Member',
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
            const SizedBox(height: 8),
            

            // Role badge
            if (userData?['role'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getRoleColor(userData!['role']).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getRoleColor(userData!['role']).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  userData!['role'].toString().toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
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

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'hod':
        return Colors.red;
      case 'assistant professor':
        return Colors.blue;
      case 'associate professor':
        return Colors.purple;
      case 'professor':
        return Colors.indigo;
      case 'teaching staff':
        return Colors.green;
      case 'lab assistant':
        return Colors.teal;
      case 'faculty':
      default:
        return Colors.blue;
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
                          icon: Icons.analytics,
                          title: "Dashboard",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const FacultyBranchDashboard());
                          },
                          iconColor: const Color.fromARGB(255, 238, 136, 42),
                          index: 0,
                        ),
                        _buildDrawerItem(
                          icon: Icons.person_rounded,
                          title: "My Profile",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const FacultyProfilePage());
                          },
                          iconColor: Colors.blue[300],
                          index: 1,
                        ),
                        _buildDrawerItem(
                          icon: Icons.school_rounded,
                          title: "Student Management",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const FacultyStudentManagementPage());
                          },
                          iconColor: Colors.green[300],
                          index: 2,
                        ),
                        _buildDrawerItem(
                          icon: Icons.subject,
                          title: "Subject Management",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const FacultySchemeManagementPage());
                          },
                          iconColor: const Color.fromARGB(255, 159, 101, 235),
                          index: 2,
                        ),
                        _buildDrawerItem(
                          icon: Icons.school_rounded,
                          title: "Branch Student Details",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const StudentDetailsExportPage());
                          },
                          iconColor: Colors.green[300],
                          index: 2,
                        ),
                        _buildDrawerItem(
                          icon: Icons.assignment_rounded,
                          title: "Mentor Management",
                          onTap: () {
                            Navigator.pop(context);
                            Get.to(() => const MentorMenteeManagementPage());
                          },
                          iconColor: Colors.purple[300],
                          index: 3,
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
                          icon: Icons.fact_check_rounded,
                          title: "Exams",
                          onTap: () {
                            Navigator.pop(context);
                            // Get.to(() => FacultyCreateExamPage(...));
                          },
                          iconColor: Colors.deepPurple[300],
                          index: 6,
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