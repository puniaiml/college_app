import 'package:shiksha_hub/auth/email_service.dart';
import 'package:shiksha_hub/auth/email_verification_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:shiksha_hub/auth/login.dart';
import 'dart:math' as math;
import 'package:shiksha_hub/services/notification_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  late AnimationController _lottieController;
  late AnimationController _formController;
  late AnimationController _rotationController;
  late Animation<double> _lottieScaleAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _buttonScaleAnimation;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usnController = TextEditingController();

  final TextEditingController _universitySearchController = TextEditingController();
  final TextEditingController _collegeSearchController = TextEditingController();
  final TextEditingController _courseSearchController = TextEditingController();
  final TextEditingController _branchSearchController = TextEditingController();

  String? _selectedUniversityId;
  String? _selectedCollegeId;
  String? _selectedCourseId;
  String? _selectedBranchId;
  String? _selectedYearOfPassing;
  List<Map<String, dynamic>> _universities = [];
  List<Map<String, dynamic>> _colleges = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _branches = [];
  
  List<Map<String, dynamic>> _filteredUniversities = [];
  List<Map<String, dynamic>> _filteredColleges = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  List<Map<String, dynamic>> _filteredBranches = [];

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isLoadingUniversities = false;
  bool _isLoadingColleges = false;
  bool _isLoadingCourses = false;
  bool _isLoadingBranches = false;

  String _passwordStrength = '';

  bool _firstNameTouched = false;
  bool _lastNameTouched = false;
  bool _emailTouched = false;
  bool _phoneTouched = false;
  bool _usnTouched = false;
  bool _passwordTouched = false;

  String? _universityError;
  String? _collegeError;
  String? _courseError;
  String? _branchError;
  String? _yearOfPassingError;

  static const primaryBlue = Color(0xFF1A237E);
  static const accentYellow = Color(0xFFFFD700);
  static const deepBlack = Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUniversities();
    _setupSearchListeners();
  }

  void _setupSearchListeners() {
    _universitySearchController.addListener(() {
      _filterUniversities(_universitySearchController.text);
    });
    _collegeSearchController.addListener(() {
      _filterColleges(_collegeSearchController.text);
    });
    _courseSearchController.addListener(() {
      _filterCourses(_courseSearchController.text);
    });
    _branchSearchController.addListener(() {
      _filterBranches(_branchSearchController.text);
    });
    _passwordController.addListener(() {
      setState(() {
        _passwordStrength = _getPasswordStrength(_passwordController.text);
      });
    });
  }

  void _filterUniversities(String query) {
    setState(() {
      _filteredUniversities = _universities.where((university) =>
          university['name'].toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _filterColleges(String query) {
    setState(() {
      _filteredColleges = _colleges.where((college) =>
          college['name'].toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _filterCourses(String query) {
    setState(() {
      _filteredCourses = _courses.where((course) =>
          course['name'].toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _filterBranches(String query) {
    setState(() {
      _filteredBranches = _branches.where((branch) =>
          branch['name'].toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _setupAnimations() {
    _lottieController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _formController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _lottieScaleAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _lottieController,
        curve: Curves.elasticOut,
      ),
    );

    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    ));

    _rotationAnimation = Tween<double>(
      begin: -0.1,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutBack,
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
    ));

    _lottieController.forward().then((_) {
      _formController.forward();
      _rotationController.forward();
    });
  }

  Future<void> _loadUniversities() async {
    setState(() => _isLoadingUniversities = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('universities').get();
      setState(() {
        _universities = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc['name'],
          };
        }).toList();
        _filteredUniversities = _universities;
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to load universities: $e');
    } finally {
      setState(() => _isLoadingUniversities = false);
    }
  }

  Future<void> _loadColleges(String universityId) async {
    setState(() {
      _selectedUniversityId = universityId;
      _selectedCollegeId = null;
      _selectedCourseId = null;
      _selectedBranchId = null;
      _colleges = [];
      _courses = [];
      _branches = [];
      _filteredColleges = [];
      _filteredCourses = [];
      _filteredBranches = [];
      _isLoadingColleges = true;
      _collegeSearchController.clear();
      _courseSearchController.clear();
      _branchSearchController.clear();
      _universityError = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('colleges')
          .where('universityId', isEqualTo: universityId)
          .get();

      setState(() {
        _colleges = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc['name'],
          };
        }).toList();
        _filteredColleges = _colleges;
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to load colleges: $e');
    } finally {
      setState(() => _isLoadingColleges = false);
    }
  }

  Future<void> _loadCourses(String collegeId) async {
    setState(() {
      _selectedCollegeId = collegeId;
      _selectedCourseId = null;
      _selectedBranchId = null;
      _courses = [];
      _branches = [];
      _filteredCourses = [];
      _filteredBranches = [];
      _isLoadingCourses = true;
      _courseSearchController.clear();
      _branchSearchController.clear();
      _collegeError = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('collegeId', isEqualTo: collegeId)
          .get();

      setState(() {
        _courses = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc['name'],
          };
        }).toList();
        _filteredCourses = _courses;
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to load courses: $e');
    } finally {
      setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _loadBranches(String courseId) async {
    setState(() {
      _selectedCourseId = courseId;
      _selectedBranchId = null;
      _branches = [];
      _filteredBranches = [];
      _isLoadingBranches = true;
      _branchSearchController.clear();
      _courseError = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('branches')
          .where('courseId', isEqualTo: courseId)
          .get();

      setState(() {
        _branches = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc['name'],
          };
        }).toList();
        _filteredBranches = _branches;
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to load branches: $e');
    } finally {
      setState(() => _isLoadingBranches = false);
    }
  }

  String? _validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return '$fieldName can only contain letters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(value.trim())) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  String? _validateUSN(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'USN is required';
    }
    if (value.trim().length != 10) {
      return 'USN must be exactly 10 characters';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String _getPasswordStrength(String password) {
    if (password.isEmpty) return '';
    
    int strength = 0;
    
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
    
    if (strength <= 2) return 'Weak';
    if (strength <= 4) return 'Medium';
    return 'Strong';
  }

  Color _getPasswordStrengthColor(String strength) {
    switch (strength) {
      case 'Weak':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Strong':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  bool _validateDropdowns() {
    bool isValid = true;

    if (_selectedUniversityId == null) {
      setState(() => _universityError = 'Please select a university');
      isValid = false;
    } else {
      setState(() => _universityError = null);
    }

    if (_selectedCollegeId == null) {
      setState(() => _collegeError = 'Please select a college');
      isValid = false;
    } else {
      setState(() => _collegeError = null);
    }

    if (_selectedCourseId == null) {
      setState(() => _courseError = 'Please select a course');
      isValid = false;
    } else {
      setState(() => _courseError = null);
    }

    if (_selectedBranchId == null) {
      setState(() => _branchError = 'Please select a branch');
      isValid = false;
    } else {
      setState(() => _branchError = null);
    }

    if (_selectedYearOfPassing == null) {
      setState(() => _yearOfPassingError = 'Please select year of passing');
      isValid = false;
    } else {
      setState(() => _yearOfPassingError = null);
    }

    return isValid;
  }

  Future<void> _registerStudent() async {
    if (!_formKey.currentState!.validate()) {
      Get.snackbar(
        'Validation Error',
        'Please fill all required fields correctly',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    if (!_validateDropdowns()) {
      Get.snackbar(
        'Validation Error',
        'Please complete all academic information',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emailCheck = await FirebaseFirestore.instance
          .collection('user_metadata')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (emailCheck.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'email-already-exists',
          message: 'This email is already registered',
        );
      }

      final otp = (math.Random().nextInt(900000) + 100000).toString();
      final email = _emailController.text.trim();

      final otpSent = await EmailService.sendOtpEmail(email, otp);
      if (!otpSent) {
        throw FirebaseAuthException(
          code: 'otp-send-failed',
          message: 'Failed to send OTP. Please try again.',
        );
      }

      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: _passwordController.text,
          );

      final User? user = userCredential.user;
      if (user == null) throw Exception('User creation failed');

      final universityName = _universities
          .firstWhere((uni) => uni['id'] == _selectedUniversityId)['name'];
      final collegeName = _colleges
          .firstWhere((col) => col['id'] == _selectedCollegeId)['name'];
      final courseName = _courses
          .firstWhere((course) => course['id'] == _selectedCourseId)['name'];
      final branchName = _branches
          .firstWhere((branch) => branch['id'] == _selectedBranchId)['name'];

      final studentData = {
        'uid': user.uid,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'fullName': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'email': email,
        'phone': _phoneController.text.trim(),
        'usn': _usnController.text.trim().toUpperCase(),
        'accountStatus': 'pending_verification',
        'userType': 'student',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEmailVerified': false,
        'isActive': false,
        'verificationOtp': otp,
        'otpCreatedAt': FieldValue.serverTimestamp(),
        'universityId': _selectedUniversityId,
        'universityName': universityName,
        'collegeId': _selectedCollegeId,
        'collegeName': collegeName,
        'courseId': _selectedCourseId,
        'courseName': courseName,
        'branchId': _selectedBranchId,
        'branchName': branchName,
        'yearOfPassing': _selectedYearOfPassing,
      };

      final metadata = {
        'uid': user.uid,
        'email': email,
        'userType': 'student',
        'accountStatus': 'pending_verification',
        'dataLocation': 'users/pending_students/data/${user.uid}',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();
      
      final studentRef = FirebaseFirestore.instance
          .collection('users')
          .doc('pending_students')
          .collection('data')
          .doc(user.uid);
      
      final metadataRef = FirebaseFirestore.instance
          .collection('user_metadata')
          .doc(user.uid);
      
      batch.set(studentRef, studentData);
      batch.set(metadataRef, metadata);

      await batch.commit();

      try {
        await NotificationService.notifyPendingStudentSubmitted(
          college: collegeName,
          branch: branchName,
          studentName: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        );
      } catch (_) {}

      Get.off(() => OtpVerificationPage(
        userId: user.uid,
        email: email, 
        userType: 'student',
      ));

    } on FirebaseAuthException catch (e) {
      Get.dialog(
        AlertDialog(
          title: const Text('Registration Error'),
          content: Text(e.message ?? 'An error occurred during registration'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.dialog(
        AlertDialog(
          title: const Text('Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _getResponsiveFontSize(double size, double maxSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    return math.min(screenWidth * size, maxSize);
  }

  double _getResponsiveSize(double percentage) {
    final screenSize = MediaQuery.of(context).size;
    return math.min(screenSize.width, screenSize.height) * percentage;
  }

  EdgeInsets _getResponsivePadding() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return EdgeInsets.symmetric(horizontal: screenWidth * 0.05);
    } else if (screenWidth < 900) {
      return EdgeInsets.symmetric(horizontal: screenWidth * 0.08);
    } else {
      return EdgeInsets.symmetric(horizontal: screenWidth * 0.15);
    }
  }

  Widget _buildSearchableDropdown({
    required String hintText,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> filteredItems,
    required String? selectedValue,
    required Function(String?) onChanged,
    required TextEditingController searchController,
    bool isLoading = false,
    bool enabled = true,
    String? errorText,
    String? disabledMessage,
  }) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 900;
    
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(_rotationAnimation.value),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.symmetric(
              vertical: isDesktop ? 12 : isTablet ? 10 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue.withOpacity(0.08),
                  deepBlack.withOpacity(0.03),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.08),
                  blurRadius: isDesktop ? 25 : 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: accentYellow.withOpacity(0.08),
                  blurRadius: isDesktop ? 25 : 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: enabled && !isLoading 
                  ? () => _showSearchDialog(
                        hintText: hintText,
                        items: items,
                        filteredItems: filteredItems,
                        selectedValue: selectedValue,
                        onChanged: onChanged,
                        searchController: searchController,
                      ) 
                  : () {
                      if (!enabled && disabledMessage != null) {
                        Get.snackbar(
                          'Selection Required',
                          disabledMessage,
                          backgroundColor: Colors.orange.shade100,
                          colorText: Colors.orange.shade900,
                          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                          snackPosition: SnackPosition.TOP,
                          duration: const Duration(seconds: 3),
                          margin: const EdgeInsets.all(16),
                          borderRadius: 12,
                        );
                      }
                    },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: isDesktop ? 20 : isTablet ? 18 : 16,
                  horizontal: isDesktop ? 24 : isTablet ? 20 : 16,
                ),
                decoration: BoxDecoration(
                  color: enabled 
                      ? Colors.white.withOpacity(0.95)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                  border: Border.all(
                    color: !enabled
                        ? Colors.grey.withOpacity(0.3)
                        : errorText != null 
                            ? Colors.red.withOpacity(0.5)
                            : primaryBlue.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: enabled ? primaryBlue : Colors.grey.shade400,
                      size: _getResponsiveSize(0.055),
                    ),
                    SizedBox(width: isDesktop ? 16 : 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: selectedValue != null
                                  ? items.firstWhere((item) => item['id'] == selectedValue)['name']
                                  : 'Select $hintText',
                              style: TextStyle(
                                color: enabled
                                    ? (selectedValue != null 
                                        ? deepBlack 
                                        : deepBlack.withOpacity(0.5))
                                    : Colors.grey.shade400,
                                fontSize: _getResponsiveFontSize(0.04, 16),
                                fontWeight: selectedValue != null 
                                    ? FontWeight.w500 
                                    : FontWeight.normal,
                              ),
                            ),
                            TextSpan(
                              text: ' *',
                              style: TextStyle(
                                color: enabled ? Colors.red : Colors.grey.shade400,
                                fontSize: _getResponsiveFontSize(0.04, 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isLoading)
                      Container(
                        width: isDesktop ? 24 : 20,
                        height: isDesktop ? 24 : 20,
                        margin: EdgeInsets.only(left: isDesktop ? 12 : 8),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                        ),
                      )
                    else if (!enabled)
                      Icon(
                        Icons.lock_outline,
                        color: Colors.grey.shade400,
                        size: _getResponsiveSize(0.055),
                      )
                    else
                      Icon(
                        Icons.arrow_drop_down,
                        color: primaryBlue,
                        size: _getResponsiveSize(0.06),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: EdgeInsets.only(
                left: isDesktop ? 24 : isTablet ? 20 : 16,
                top: 4,
              ),
              child: Text(
                errorText,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: _getResponsiveFontSize(0.03, 12),
                ),
              ),
            ),
          if (!enabled && disabledMessage != null)
            Padding(
              padding: EdgeInsets.only(
                left: isDesktop ? 24 : isTablet ? 20 : 16,
                top: 4,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: _getResponsiveFontSize(0.035, 14),
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      disabledMessage,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: _getResponsiveFontSize(0.03, 12),
                        fontStyle: FontStyle.italic,
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

  void _showSearchDialog({
    required String hintText,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> filteredItems,
    required String? selectedValue,
    required Function(String?) onChanged,
    required TextEditingController searchController,
  }) {
    List<Map<String, dynamic>> localFilteredItems = List.from(items);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select $hintText',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: primaryBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 16),
                      onChanged: (query) {
                        setDialogState(() {
                          localFilteredItems = items.where((item) =>
                              item['name'].toLowerCase().contains(query.toLowerCase())
                          ).toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search $hintText...',
                        prefixIcon: const Icon(Icons.search, color: primaryBlue),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  setDialogState(() {
                                    localFilteredItems = List.from(items);
                                  });
                                },
                                icon: const Icon(Icons.clear, color: primaryBlue),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryBlue),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryBlue, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Expanded(
                      child: localFilteredItems.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No results found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: localFilteredItems.length,
                              itemBuilder: (context, index) {
                                final item = localFilteredItems[index];
                                final isSelected = selectedValue == item['id'];
                                
                                return ListTile(
                                  title: Text(
                                    item['name'],
                                    style: TextStyle(
                                      color: isSelected ? primaryBlue : Colors.black,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  leading: isSelected
                                      ? const Icon(Icons.check_circle, color: primaryBlue)
                                      : const Icon(Icons.circle_outlined, color: Colors.grey),
                                  onTap: () {
                                    onChanged(item['id']);
                                    searchController.clear();
                                    Navigator.pop(context);
                                  },
                                  tileColor: isSelected 
                                      ? primaryBlue.withOpacity(0.1) 
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildYearOfPassingDropdown() {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 900;
    
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(_rotationAnimation.value),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.symmetric(
              vertical: isDesktop ? 12 : isTablet ? 10 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue.withOpacity(0.08),
                  deepBlack.withOpacity(0.03),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.08),
                  blurRadius: isDesktop ? 25 : 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: accentYellow.withOpacity(0.08),
                  blurRadius: isDesktop ? 25 : 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () => _showYearPicker(context),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: isDesktop ? 20 : isTablet ? 18 : 16,
                  horizontal: isDesktop ? 24 : isTablet ? 20 : 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                  border: Border.all(
                    color: _yearOfPassingError != null
                        ? Colors.red.withOpacity(0.5)
                        : primaryBlue.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: primaryBlue,
                      size: _getResponsiveSize(0.055),
                    ),
                    SizedBox(width: isDesktop ? 16 : 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _selectedYearOfPassing ?? 'Select Year of Passing',
                              style: TextStyle(
                                color: _selectedYearOfPassing != null 
                                    ? deepBlack 
                                    : deepBlack.withOpacity(0.5),
                                fontSize: _getResponsiveFontSize(0.04, 16),
                                fontWeight: _selectedYearOfPassing != null 
                                    ? FontWeight.w500 
                                    : FontWeight.normal,
                              ),
                            ),
                            TextSpan(
                              text: ' *',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: _getResponsiveFontSize(0.04, 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: primaryBlue,
                      size: _getResponsiveSize(0.06),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_yearOfPassingError != null)
            Padding(
              padding: EdgeInsets.only(
                left: isDesktop ? 24 : isTablet ? 20 : 16,
                top: 4,
              ),
              child: Text(
                _yearOfPassingError!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: _getResponsiveFontSize(0.03, 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showYearPicker(BuildContext context) async {
    final currentYear = DateTime.now().year;
    final initialDate = _selectedYearOfPassing != null 
        ? DateTime(int.parse(_selectedYearOfPassing!), 6, 15)
        : DateTime(currentYear, 6, 15);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(currentYear - 15),
      lastDate: DateTime(currentYear + 15),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: deepBlack,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedYearOfPassing = pickedDate.year.toString();
        _yearOfPassingError = null;
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
    bool isTouched = false,
    Function(bool)? onTouchedChanged,
  }) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 900;
    
    String? currentError;
    if (isTouched && validator != null) {
      currentError = validator(controller.text);
    }
    
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(_rotationAnimation.value),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.symmetric(
              vertical: isDesktop ? 12 : isTablet ? 10 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue.withOpacity(0.08),
                  deepBlack.withOpacity(0.03),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.08),
                  blurRadius: isDesktop ? 25 : 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: accentYellow.withOpacity(0.08),
                  blurRadius: isDesktop ? 25 : 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              obscureText: isPassword && !_isPasswordVisible,
              validator: validator,
              onChanged: (value) {
                if (onTouchedChanged != null && !isTouched) {
                  onTouchedChanged(true);
                }
                if (isTouched) {
                  setState(() {});
                }
              },
              onTap: () {
                if (onTouchedChanged != null && !isTouched) {
                  onTouchedChanged(true);
                }
              },
              style: TextStyle(
                fontSize: _getResponsiveFontSize(0.04, 16),
                color: deepBlack,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: deepBlack.withOpacity(0.5),
                  fontSize: _getResponsiveFontSize(0.04, 16),
                  fontWeight: FontWeight.normal,
                ),
                label: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: hint,
                        style: TextStyle(
                          color: deepBlack.withOpacity(0.5),
                          fontSize: _getResponsiveFontSize(0.04, 16),
                        ),
                      ),
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: _getResponsiveFontSize(0.04, 16),
                        ),
                      ),
                    ],
                  ),
                ),
                prefixIcon: Icon(
                  icon,
                  color: currentError != null ? Colors.red : primaryBlue,
                  size: _getResponsiveSize(0.055),
                ),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: primaryBlue,
                          size: _getResponsiveSize(0.055),
                        ),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      )
                    : (currentError != null 
                        ? Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: _getResponsiveSize(0.055),
                          )
                        : (isTouched && controller.text.isNotEmpty
                            ? Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: _getResponsiveSize(0.055),
                              )
                            : null)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.95),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                  borderSide: BorderSide(
                    color: currentError != null
                        ? Colors.red.withOpacity(0.5)
                        : primaryBlue.withOpacity(0.1),
                    width: currentError != null ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                  borderSide: BorderSide(
                    color: currentError != null ? Colors.red : primaryBlue,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                  borderSide: BorderSide(
                    color: Colors.red.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                  borderSide: const BorderSide(
                    color: Colors.red,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: isDesktop ? 20 : isTablet ? 18 : 16,
                  horizontal: isDesktop ? 24 : isTablet ? 20 : 16,
                ),
              ),
            ),
          ),
          if (currentError != null)
            Padding(
              padding: EdgeInsets.only(
                left: isDesktop ? 24 : isTablet ? 20 : 16,
                top: 4,
              ),
              child: Text(
                currentError,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: _getResponsiveFontSize(0.03, 12),
                ),
              ),
            ),
          if (isPassword && _passwordStrength.isNotEmpty && currentError == null)
            Padding(
              padding: EdgeInsets.only(
                left: isDesktop ? 24 : isTablet ? 20 : 16,
                top: 4,
              ),
              child: Row(
                children: [
                  Text(
                    'Password Strength: ',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(0.03, 12),
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    _passwordStrength,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(0.03, 12),
                      color: _getPasswordStrengthColor(_passwordStrength),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 900;
    
    return ScaleTransition(
      scale: _buttonScaleAnimation,
      child: Container(
        width: double.infinity,
        height: isDesktop ? size.height * 0.08 : isTablet ? size.height * 0.075 : size.height * 0.07,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryBlue, Color(0xFF0D47A1)],
            stops: [0.0, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withOpacity(0.4),
              blurRadius: isDesktop ? 20 : 15,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: accentYellow.withOpacity(0.2),
              blurRadius: isDesktop ? 20 : 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _registerStudent,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? SizedBox(
                  width: isDesktop ? 28 : 24,
                  height: isDesktop ? 28 : 24,
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                )
              : Text(
                  'Register',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _getResponsiveFontSize(0.055, 20),
                    fontWeight: FontWeight.bold,
                    letterSpacing: isDesktop ? 3 : 2,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: _getResponsivePadding(),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    SizedBox(height: isDesktop ? size.height * 0.04 : size.height * 0.03),
                    
                    ScaleTransition(
                      scale: _lottieScaleAnimation,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(math.pi * _lottieScaleAnimation.value * 0.0),
                        alignment: Alignment.center,
                        child: SizedBox(
                          height: isDesktop 
                              ? size.height * 0.3 
                              : isTablet 
                                  ? size.height * 0.28 
                                  : size.height * 0.25,
                          child: Lottie.asset(
                            'assets/lottie/register.json',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    
                    SlideTransition(
                      position: _formSlideAnimation,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(_rotationAnimation.value),
                        alignment: Alignment.center,
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 800 : double.infinity,
                          ),
                          padding: EdgeInsets.all(
                            isDesktop ? size.width * 0.04 : size.width * 0.06,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(isDesktop ? 40 : 30),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.1),
                                blurRadius: isDesktop ? 40 : 30,
                                spreadRadius: isDesktop ? 8 : 5,
                                offset: const Offset(0, -5),
                              ),
                              BoxShadow(
                                color: accentYellow.withOpacity(0.1),
                                blurRadius: isDesktop ? 40 : 30,
                                spreadRadius: isDesktop ? 8 : 5,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [primaryBlue, Color(0xFFE91E63)],
                                ).createShader(bounds),
                                child: Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: _getResponsiveFontSize(0.08, 32),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(height: size.height * 0.01),
                              Text(
                                'Sign up to get started',
                                style: TextStyle(
                                  fontSize: _getResponsiveFontSize(0.04, 18),
                                  color: deepBlack.withOpacity(0.6),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: isDesktop ? size.height * 0.03 : size.height * 0.02),
                              
                              isDesktop 
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _firstNameController,
                                            hint: 'First Name',
                                            icon: Icons.person,
                                            validator: (value) => _validateName(value, 'First name'),
                                            isTouched: _firstNameTouched,
                                            onTouchedChanged: (touched) => setState(() => _firstNameTouched = touched),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _lastNameController,
                                            hint: 'Last Name',
                                            icon: Icons.person_outline,
                                            validator: (value) => _validateName(value, 'Last name'),
                                            isTouched: _lastNameTouched,
                                            onTouchedChanged: (touched) => setState(() => _lastNameTouched = touched),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _buildTextField(
                                          controller: _firstNameController,
                                          hint: 'First Name',
                                          icon: Icons.person,
                                          validator: (value) => _validateName(value, 'First name'),
                                          isTouched: _firstNameTouched,
                                          onTouchedChanged: (touched) => setState(() => _firstNameTouched = touched),
                                        ),
                                        _buildTextField(
                                          controller: _lastNameController,
                                          hint: 'Last Name',
                                          icon: Icons.person_outline,
                                          validator: (value) => _validateName(value, 'Last name'),
                                          isTouched: _lastNameTouched,
                                          onTouchedChanged: (touched) => setState(() => _lastNameTouched = touched),
                                        ),
                                      ],
                                    ),
                              
                              if (isDesktop) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _emailController,
                                        hint: 'Email',
                                        icon: Icons.email_rounded,
                                        validator: _validateEmail,
                                        isTouched: _emailTouched,
                                        onTouchedChanged: (touched) => setState(() => _emailTouched = touched),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _phoneController,
                                        hint: 'Phone Number',
                                        icon: Icons.phone,
                                        validator: _validatePhone,
                                        isTouched: _phoneTouched,
                                        onTouchedChanged: (touched) => setState(() => _phoneTouched = touched),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _usnController,
                                        hint: 'USN',
                                        icon: Icons.badge_outlined,
                                        validator: _validateUSN,
                                        isTouched: _usnTouched,
                                        onTouchedChanged: (touched) => setState(() => _usnTouched = touched),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _passwordController,
                                        hint: 'Password',
                                        icon: Icons.lock_rounded,
                                        isPassword: true,
                                        validator: _validatePassword,
                                        isTouched: _passwordTouched,
                                        onTouchedChanged: (touched) => setState(() => _passwordTouched = touched),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                _buildTextField(
                                  controller: _emailController,
                                  hint: 'Email',
                                  icon: Icons.email_rounded,
                                  validator: _validateEmail,
                                  isTouched: _emailTouched,
                                  onTouchedChanged: (touched) => setState(() => _emailTouched = touched),
                                ),
                                _buildTextField(
                                  controller: _phoneController,
                                  hint: 'Phone Number',
                                  icon: Icons.phone,
                                  validator: _validatePhone,
                                  isTouched: _phoneTouched,
                                  onTouchedChanged: (touched) => setState(() => _phoneTouched = touched),
                                ),
                                _buildTextField(
                                  controller: _usnController,
                                  hint: 'USN',
                                  icon: Icons.badge_outlined,
                                  validator: _validateUSN,
                                  isTouched: _usnTouched,
                                  onTouchedChanged: (touched) => setState(() => _usnTouched = touched),
                                ),
                                _buildTextField(
                                  controller: _passwordController,
                                  hint: 'Password',
                                  icon: Icons.lock_rounded,
                                  isPassword: true,
                                  validator: _validatePassword,
                                  isTouched: _passwordTouched,
                                  onTouchedChanged: (touched) => setState(() => _passwordTouched = touched),
                                ),
                              ],
                              
                              Container(
                                width: double.infinity,
                                margin: EdgeInsets.symmetric(
                                  vertical: isDesktop ? 20 : 16,
                                ),
                                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(isDesktop ? 25 : 20),
                                  border: Border.all(
                                    color: primaryBlue.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Academic Information',
                                      style: TextStyle(
                                        fontSize: _getResponsiveFontSize(0.05, 20),
                                        fontWeight: FontWeight.bold,
                                        color: primaryBlue,
                                      ),
                                    ),
                                    SizedBox(height: isDesktop ? 16 : 12),
                                    
                                    if (isDesktop) ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildSearchableDropdown(
                                              hintText: 'University',
                                              icon: Icons.school,
                                              items: _universities,
                                              filteredItems: _filteredUniversities,
                                              selectedValue: _selectedUniversityId,
                                              onChanged: (value) => _loadColleges(value!),
                                              searchController: _universitySearchController,
                                              isLoading: _isLoadingUniversities,
                                              errorText: _universityError,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildSearchableDropdown(
                                              hintText: 'College',
                                              icon: Icons.business,
                                              items: _colleges,
                                              filteredItems: _filteredColleges,
                                              selectedValue: _selectedCollegeId,
                                              onChanged: (value) => _loadCourses(value!),
                                              searchController: _collegeSearchController,
                                              isLoading: _isLoadingColleges,
                                              enabled: _selectedUniversityId != null,
                                              errorText: _collegeError,
                                              disabledMessage: _selectedUniversityId == null 
                                                  ? 'Please select a university first'
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildSearchableDropdown(
                                              hintText: 'Course',
                                              icon: Icons.menu_book,
                                              items: _courses,
                                              filteredItems: _filteredCourses,
                                              selectedValue: _selectedCourseId,
                                              onChanged: (value) => _loadBranches(value!),
                                              searchController: _courseSearchController,
                                              isLoading: _isLoadingCourses,
                                              enabled: _selectedCollegeId != null,
                                              errorText: _courseError,
                                              disabledMessage: _selectedCollegeId == null 
                                                  ? 'Please select a college first'
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildSearchableDropdown(
                                              hintText: 'Branch',
                                              icon: Icons.account_tree,
                                              items: _branches,
                                              filteredItems: _filteredBranches,
                                              selectedValue: _selectedBranchId,
                                              onChanged: (value) => setState(() {
                                                _selectedBranchId = value;
                                                _branchError = null;
                                              }),
                                              searchController: _branchSearchController,
                                              isLoading: _isLoadingBranches,
                                              enabled: _selectedCourseId != null,
                                              errorText: _branchError,
                                              disabledMessage: _selectedCourseId == null 
                                                  ? 'Please select a course first'
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      _buildSearchableDropdown(
                                        hintText: 'University',
                                        icon: Icons.school,
                                        items: _universities,
                                        filteredItems: _filteredUniversities,
                                        selectedValue: _selectedUniversityId,
                                        onChanged: (value) => _loadColleges(value!),
                                        searchController: _universitySearchController,
                                        isLoading: _isLoadingUniversities,
                                        errorText: _universityError,
                                      ),
                                      _buildSearchableDropdown(
                                        hintText: 'College',
                                        icon: Icons.business,
                                        items: _colleges,
                                        filteredItems: _filteredColleges,
                                        selectedValue: _selectedCollegeId,
                                        onChanged: (value) => _loadCourses(value!),
                                        searchController: _collegeSearchController,
                                        isLoading: _isLoadingColleges,
                                        enabled: _selectedUniversityId != null,
                                        errorText: _collegeError,
                                        disabledMessage: _selectedUniversityId == null 
                                            ? 'Please select a university first'
                                            : null,
                                      ),
                                      _buildSearchableDropdown(
                                        hintText: 'Course',
                                        icon: Icons.menu_book,
                                        items: _courses,
                                        filteredItems: _filteredCourses,
                                        selectedValue: _selectedCourseId,
                                        onChanged: (value) => _loadBranches(value!),
                                        searchController: _courseSearchController,
                                        isLoading: _isLoadingCourses,
                                        enabled: _selectedCollegeId != null,
                                        errorText: _courseError,
                                        disabledMessage: _selectedCollegeId == null 
                                            ? 'Please select a college first'
                                            : null,
                                      ),
                                      _buildSearchableDropdown(
                                        hintText: 'Branch',
                                        icon: Icons.account_tree,
                                        items: _branches,
                                        filteredItems: _filteredBranches,
                                        selectedValue: _selectedBranchId,
                                        onChanged: (value) => setState(() {
                                          _selectedBranchId = value;
                                          _branchError = null;
                                        }),
                                        searchController: _branchSearchController,
                                        isLoading: _isLoadingBranches,
                                        enabled: _selectedCourseId != null,
                                        errorText: _branchError,
                                        disabledMessage: _selectedCourseId == null 
                                            ? 'Please select a course first'
                                            : null,
                                      ),
                                    ],
                                    
                                    _buildYearOfPassingDropdown(),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: isDesktop ? size.height * 0.03 : size.height * 0.02),
                              _buildRegisterButton(),
                              SizedBox(height: isDesktop ? size.height * 0.04 : size.height * 0.03),
                              
                              Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      color: deepBlack.withOpacity(0.6),
                                      fontSize: _getResponsiveFontSize(0.035, 16),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Get.to(() => const LoginPage()),
                                    child: Text(
                                      'Login Now',
                                      style: TextStyle(
                                        color: primaryBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: _getResponsiveFontSize(0.035, 16),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isDesktop ? size.height * 0.08 : size.height * 0.05),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _formController.dispose();
    _rotationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _usnController.dispose();
    _universitySearchController.dispose();
    _collegeSearchController.dispose();
    _courseSearchController.dispose();
    _branchSearchController.dispose();
    super.dispose();
  }
}