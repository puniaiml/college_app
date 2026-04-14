import 'package:shiksha_hub/chat_mate/screens/home_screen.dart';
import 'package:shiksha_hub/chat_mate/widgets/profile_check_dialog.dart';
import 'package:shiksha_hub/faculty/f_notes/fac_branch.dart';
import 'package:shiksha_hub/faculty/f_time_table/semester.dart';
import 'package:shiksha_hub/faculty/voicecollege.dart';
import 'package:shiksha_hub/chatBot/chat_bot_ai.dart';
import 'package:shiksha_hub/widgets/drawer_faculty.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FacultyHomePage extends StatefulWidget {
  const FacultyHomePage({super.key});

  @override
  State<FacultyHomePage> createState() => _FacultyHomePageState();
}

class _FacultyHomePageState extends State<FacultyHomePage> with WidgetsBindingObserver {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, dynamic>? facultyProfileData;
  bool isLoadingProfile = true;
  bool isLoadingData = false;
  bool _hasInternetConnection = true;
  String? _profileLoadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkConnectivityAndReload();
    }
  }

  Future<void> _initializeApp() async {
    await _checkInternetConnection();
    await _validateUserSession();
    await _loadFacultyProfile();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ProfileCheckDialog.checkAndShowDialog(context, userType: 'faculty');
      }
    });
  }

  Future<void> _checkInternetConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        _hasInternetConnection = !connectivityResult.contains(ConnectivityResult.none);
      });

      if (!_hasInternetConnection) {
        _showErrorSnackBar('No internet connection. Please check your network.');
      }

      Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
        if (mounted) {
          setState(() {
            _hasInternetConnection = !results.contains(ConnectivityResult.none) && results.isNotEmpty;
          });

          if (_hasInternetConnection && _profileLoadError != null) {
            _loadFacultyProfile();
          }
        }
      });
    } catch (e) {
      debugPrint('Connectivity check error: $e');
    }
  }

  Future<void> _checkConnectivityAndReload() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none && _profileLoadError != null) {
      _loadFacultyProfile();
    }
  }

  Future<bool> _validateUserSession() async {
    try {
      if (user == null) {
        _showErrorDialog(
          'Authentication Error',
          'You are not logged in. Please login again.',
          actionLabel: 'Login',
          onAction: () {
            Navigator.of(context).pop();
          },
        );
        return false;
      }

      await user!.reload();
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        _showErrorDialog(
          'Session Expired',
          'Your session has expired. Please login again.',
          actionLabel: 'Login',
          onAction: () {
            FirebaseAuth.instance.signOut();
            Navigator.of(context).pop();
          },
        );
        return false;
      }

      // Check email verification from Firestore instead of Firebase Auth
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .doc(currentUser.uid)
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final isEmailVerified = data['isEmailVerified'] as bool? ?? false;
        if (!isEmailVerified) {
          _showWarningSnackBar('Please verify your email address.');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Session validation error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFacultyProfile() async {
    if (!_hasInternetConnection) {
      setState(() {
        isLoadingProfile = false;
        _profileLoadError = 'No internet connection';
      });
      return;
    }

    try {
      if (user == null) {
        setState(() {
          isLoadingProfile = false;
          _profileLoadError = 'User not authenticated';
        });
        return;
      }

      setState(() {
        isLoadingProfile = true;
        _profileLoadError = null;
      });

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .doc(user!.uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        
        if (!_validateProfileData(data)) {
          setState(() {
            isLoadingProfile = false;
            _profileLoadError = 'Incomplete profile data';
          });
          _showIncompleteProfileDialog();
          return;
        }

        setState(() {
          facultyProfileData = data;
          isLoadingProfile = false;
          _profileLoadError = null;
        });
      } else {
        setState(() {
          isLoadingProfile = false;
          _profileLoadError = 'Profile not found';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          isLoadingProfile = false;
          _profileLoadError = e.toString().contains('timeout') 
              ? 'Connection timeout. Please try again.' 
              : 'Failed to load profile';
        });
      }
    }
  }

  bool _validateProfileData(Map<String, dynamic> data) {
    final requiredFields = ['email', 'name', 'collegeName', 'branchId', 'branchName'];
    for (var field in requiredFields) {
      if (data[field] == null || data[field].toString().trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _showIncompleteProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            const Text('Incomplete Profile'),
          ],
        ),
        content: const Text(
          'Your profile is incomplete. Please update your profile to access all features.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
            ),
            child: const Text('Update Profile', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getFacultyData() async {
    if (!_hasInternetConnection) {
      _showErrorSnackBar('No internet connection');
      return null;
    }

    try {
      if (user == null) {
        if (mounted) _showErrorSnackBar('User not authenticated');
        return null;
      }

      if (isLoadingData) return null;

      if (mounted) {
        setState(() {
          isLoadingData = true;
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.indigo),
          ),
        );
      }

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .doc(user!.uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      if (mounted) {
        setState(() {
          isLoadingData = false;
        });

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }

      if (!doc.exists) {
        if (mounted) {
          _showErrorSnackBar('Profile not found. Please contact administration.');
        }
        return null;
      }

      final facultyData = doc.data() as Map<String, dynamic>;
      final college = facultyData['collegeName'];
      final branchId = facultyData['branchId'];
      final branchName = facultyData['branchName'];

      if (college == null || college.toString().trim().isEmpty) {
        if (mounted) {
          _showErrorDialog(
            'Incomplete Profile',
            'College information is missing from your profile. Please update your profile.',
            actionLabel: 'Update Profile',
            onAction: () {
              Navigator.of(context).pop();
            },
          );
        }
        return null;
      }

      if (branchId == null || branchId.toString().trim().isEmpty) {
        if (mounted) {
          _showErrorDialog(
            'Branch Not Assigned',
            'Branch information is missing from your profile. Please contact your administrator.',
            actionLabel: 'Contact Support',
            onAction: () {
              Navigator.of(context).pop();
            },
          );
        }
        return null;
      }

      return {
        'college': college,
        'branchId': branchId,
        'branchName': branchName,
      };
    } catch (e) {
      debugPrint('Error getting faculty data: $e');
      if (mounted) {
        setState(() {
          isLoadingData = false;
        });

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (e.toString().contains('timeout')) {
          _showErrorSnackBar('Connection timeout. Please check your internet connection.');
        } else {
          _showErrorSnackBar('Error loading profile: ${e.toString()}');
        }
      }
      return null;
    }
  }

  Future<void> _navigateToNotes() async {
    if (!_hasInternetConnection) {
      _showErrorSnackBar('No internet connection');
      return;
    }

    if (isLoadingData) return;

    final sessionValid = await _validateUserSession();
    if (!sessionValid) return;

    final facultyData = await _getFacultyData();
    if (facultyData == null || !mounted) return;

    if (facultyData['college'] == null || facultyData['college'].toString().trim().isEmpty) {
      _showErrorSnackBar('College information is required to access notes');
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BranchFaculty(
            selectedCollege: facultyData['college'] ?? '',
          ),
        ),
      );
    }
  }

  Future<void> _navigateToTimeTable() async {
    if (!_hasInternetConnection) {
      _showErrorSnackBar('No internet connection');
      return;
    }

    if (isLoadingData) return;

    final sessionValid = await _validateUserSession();
    if (!sessionValid) return;

    try {
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      if (mounted) {
        setState(() {
          isLoadingData = true;
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.indigo),
          ),
        );
      }

      DocumentSnapshot facultyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .doc(user!.uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      if (mounted) {
        setState(() {
          isLoadingData = false;
        });

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }

      if (!facultyDoc.exists) {
        if (mounted) {
          _showErrorDialog(
            'Profile Not Found',
            'Faculty profile not found. Please contact support.',
          );
        }
        return;
      }

      final facultyData = facultyDoc.data() as Map<String, dynamic>;
      
      final branchId = facultyData['branchId'] as String?;
      final branchName = facultyData['branchName'] as String?;
      final college = facultyData['collegeName'];

      if (branchId == null || branchId.trim().isEmpty) {
        if (mounted) {
          _showErrorDialog(
            'Branch Not Assigned',
            'Branch information is missing from your profile. Please contact your administrator to assign a branch.',
            actionLabel: 'Contact Support',
            onAction: () {
              Navigator.of(context).pop();
            },
          );
        }
        return;
      }

      if (branchName == null || branchName.trim().isEmpty) {
        if (mounted) {
          _showErrorDialog(
            'Branch Information Missing',
            'Branch name is missing. Please update your profile.',
          );
        }
        return;
      }

      final branchDoc = await FirebaseFirestore.instance
          .collection('branches')
          .doc(branchId)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      if (!branchDoc.exists) {
        if (mounted) {
          _showErrorDialog(
            'Branch Not Found',
            'Your assigned branch no longer exists in the system. Please contact your administrator.',
            actionLabel: 'Contact Support',
            onAction: () {
              Navigator.of(context).pop();
            },
          );
        }
        return;
      }

      if (college == null || college.toString().trim().isEmpty) {
        if (mounted) {
          _showErrorDialog(
            'College Information Missing',
            'College information is required. Please update your profile.',
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                FacultySemesterPage(
              selectedCollege: college ?? '',
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
    } catch (e) {
      debugPrint('Error navigating to timetable: $e');
      if (mounted) {
        setState(() {
          isLoadingData = false;
        });

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (e.toString().contains('timeout')) {
          _showErrorSnackBar('Connection timeout. Please check your internet connection and try again.');
        } else {
          _showErrorSnackBar('Failed to load timetable: ${e.toString()}');
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorDialog(
    String title,
    String message, {
    String actionLabel = 'OK',
    VoidCallback? onAction,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            onPressed: onAction ?? () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
            ),
            child: Text(actionLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  final List<Map<String, dynamic>> menuItems = [
    {
      "icon": "assets/images/edit.png",
      "title": "Notes",
      "description": "Manage study materials",
    },
    {
      "icon": "assets/images/study-time.png",
      "title": "Time Table",
      "description": "Manage schedules",
    },
  ];

  Widget _buildShimmerTitle() {
    final width = MediaQuery.of(context).size.width;
    return Shimmer.fromColors(
      baseColor: Colors.white,
      highlightColor: const Color.fromARGB(255, 63, 58, 58),
      period: const Duration(seconds: 4),
      child: Text(
        "Shiksha Hub!",
        style: GoogleFonts.poppins(
          fontSize: width * 0.07,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          height: 1.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildWelcomeSection() {
  if (isLoadingProfile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigo.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(
              color: Colors.indigo, strokeWidth: 2.5),
        ),
      ),
    );
  }

  if (_profileLoadError != null) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_profileLoadError!,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.redAccent)),
          ),
          GestureDetector(
            onTap: _loadFacultyProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Retry',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                )),
            ),
          ),
        ],
      ),
    );
  }

  if (facultyProfileData == null) return const SizedBox.shrink();

  final fullName  = facultyProfileData!['name'] as String? ?? 'User';
  final firstName = fullName.split(' ').first;
  final branch    = facultyProfileData!['branchName'] as String? ?? '';
  final college   = facultyProfileData!['collegeName'] as String? ?? '';
  final role      = facultyProfileData!['role'] as String? ?? 'Faculty';
  final imgUrl    = facultyProfileData!['profileImageUrl'] as String? ?? '';
  final initials  = fullName.trim().isEmpty
      ? 'U'
      : fullName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.indigo.withOpacity(0.12)),
      boxShadow: [
        BoxShadow(
          color: Colors.indigo.withOpacity(0.07),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: imgUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(imgUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        )),
                    ),
                  ),
                )
              : Center(
                  child: Text(initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    )),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Welcome, $firstName!',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A237E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(role,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF303F9F),
                      )),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (branch.isNotEmpty)
                _buildInfoChip(branch, Icons.account_tree_outlined,
                    MediaQuery.of(context).size.width),
              const SizedBox(height: 4),
              if (college.isNotEmpty)
                _buildInfoChip(college, Icons.school_outlined,
                    MediaQuery.of(context).size.width),
            ],
          ),
        ),
      ],
    ),
  ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0);
}

  Widget _buildInfoChip(String text, IconData icon, double screenWidth) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: Colors.indigo.withOpacity(0.6)),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Actions",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionItem(
                  Icons.mic,
                  "Voice\nAssistant",
                  () {
                    if (!_hasInternetConnection) {
                      _showErrorSnackBar('No internet connection');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const VoicePage()),
                    );
                  },
                ),
                _buildQuickActionItem(
                  Icons.chat_bubble,
                  "Chat\nBot",
                  () {
                    if (!_hasInternetConnection) {
                      _showErrorSnackBar('No internet connection');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChatBot()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(
      IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.indigo),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(int index, double width) {
    final item = menuItems[index];
    final isDisabled = !_hasInternetConnection || isLoadingData;
    
    return InkWell(
      onTap: isDisabled
          ? () {
              if (!_hasInternetConnection) {
                _showErrorSnackBar('No internet connection');
              }
            }
          : () async {
              if (index == 0) {
                _navigateToNotes();
              } else if (index == 1) {
                _navigateToTimeTable();
              }
            },
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: width * 0.05,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDisabled ? Colors.grey[300] : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(isDisabled ? 0.05 : 0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isLoadingData && (index == 0 || index == 1)
                ? SizedBox(
                    width: width * 0.15,
                    height: width * 0.15,
                    child: const CircularProgressIndicator(
                      color: Colors.indigo,
                      strokeWidth: 2,
                    ),
                  )
                : Opacity(
                    opacity: isDisabled ? 0.5 : 1.0,
                    child: Image.asset(
                      item["icon"],
                      width: width * 0.2,
                      height: width * 0.2,
                    ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
                  ),
            SizedBox(height: width * 0.03),
            Text(
              item["title"],
              style: GoogleFonts.poppins(
                fontSize: width * 0.05,
                fontWeight: FontWeight.bold,
                color: isDisabled ? Colors.grey[600] : Colors.indigo,
              ),
            ).animate().fadeIn(delay: 300.ms),
            SizedBox(height: width * 0.015),
            Text(
              item["description"],
              style: GoogleFonts.poppins(
                fontSize: width * 0.035,
                color: isDisabled ? Colors.grey[500] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    final paddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.indigo,
      drawer: const FacultyDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkInternetConnection();
          await _validateUserSession();
          await _loadFacultyProfile();
        },
        color: Colors.indigo,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: height * 0.22,
              floating: false,
              pinned: true,
              backgroundColor: Colors.indigo,
              elevation: 0,
              leadingWidth: 70,
              leading: Builder(
                builder: (context) => Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: IconButton(
                    icon: const Icon(
                      Icons.sort,
                      color: Colors.white,
                      size: 45,
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ),
              title: Container(
                height: 40,
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school, color: Colors.indigo, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Manage classes & schedules',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.notifications,
                                color: Colors.indigo, size: 16),
                          ),
                          if (!_hasInternetConnection)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: EdgeInsets.fromLTRB(
                    width * 0.08,
                    paddingTop + kToolbarHeight + 10,
                    width * 0.08,
                    height * 0.02,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: _buildShimmerTitle()
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .slide(begin: const Offset(-0.2, 0)),
                      ),
                      SizedBox(height: height * 0.005),
                      Flexible(
                        child: Text(
                          "Manage, Monitor, Enhance ..",
                          style: GoogleFonts.poppins(
                            fontSize: width * 0.035,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 3,
                            fontWeight: FontWeight.w300,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .slide(begin: const Offset(-0.2, 0)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(height: height * 0.01),
                    if (!_hasInternetConnection)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.wifi_off, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No internet connection',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.red, size: 20),
                              onPressed: () async {
                                await _checkInternetConnection();
                                if (_hasInternetConnection) {
                                  _loadFacultyProfile();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    _buildWelcomeSection(),
                    GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.95,
                        mainAxisSpacing: height * 0.02,
                        crossAxisSpacing: width * 0.02,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: menuItems.length,
                      itemBuilder: (context, index) {
                        return _buildCard(index, width);
                      },
                    ),
                    SizedBox(height: height * 0.03),
                    _buildQuickActions(),
                    SizedBox(height: height * 0.03),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final unreadStream = uid.isEmpty
              ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
              : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('unread_chats')
                  .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: unreadStream,
            builder: (context, snapshot) {
              int totalUnread = 0;
              if (snapshot.hasData) {
                for (final d in snapshot.data!.docs) {
                  final c = d.data()['count'];
                  if (c is int) {
                    totalUnread += c;
                  } else if (c is double) {
                    totalUnread += c.toInt();
                  }
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      FloatingActionButton(
                        onPressed: () {
                          if (!_hasInternetConnection) {
                            _showErrorSnackBar('No internet connection');
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatMateHomeScreen(),
                            ),
                          );
                        },
                        backgroundColor: _hasInternetConnection 
                            ? Colors.indigo 
                            : Colors.grey,
                        child: const Icon(Icons.chat, color: Colors.white),
                      ),
                      if (totalUnread > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              totalUnread > 99 ? '99+' : totalUnread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _hasInternetConnection 
                          ? Colors.indigo 
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Chat Mate',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}