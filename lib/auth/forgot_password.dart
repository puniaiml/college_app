import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:shiksha_hub/auth/login.dart';
import 'package:get/get.dart';
import 'dart:math' as math;

class Forgot extends StatefulWidget {
  const Forgot({super.key});

  @override
  State<Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<Forgot> with TickerProviderStateMixin {
  late AnimationController _lottieController;
  late AnimationController _formController;
  late AnimationController _rotationController;
  late Animation<double> _lottieScaleAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _buttonScaleAnimation;
  
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailTouched = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const primaryBlue = Color(0xFF1A237E);
  static const accentYellow = Color(0xFFFFD700);
  static const deepBlack = Color(0xFF121212);

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _lottieController.dispose();
    _formController.dispose();
    _rotationController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Map<String, double> _getResponsiveValues(Size size) {
    double width = size.width;
    double height = size.height;
    
    bool isTablet = width > 600 && width <= 1024;
    bool isDesktop = width > 1024;
    bool isSmallPhone = width < 360;
    
    return {
      'horizontalPadding': isDesktop ? width * 0.25 : 
                          isTablet ? width * 0.15 : 
                          isSmallPhone ? width * 0.04 : width * 0.05,
      'formPadding': isDesktop ? width * 0.04 : 
                     isTablet ? width * 0.05 : 
                     isSmallPhone ? width * 0.04 : width * 0.06,
      'lottieHeight': isDesktop ? height * 0.25 : 
                      isTablet ? height * 0.28 : 
                      isSmallPhone ? height * 0.25 : height * 0.34,
      'titleFontSize': isDesktop ? 32 : 
                       isTablet ? width * 0.06 : 
                       isSmallPhone ? width * 0.07 : width * 0.08,
      'subtitleFontSize': isDesktop ? 18 : 
                          isTablet ? width * 0.035 : 
                          isSmallPhone ? width * 0.035 : width * 0.04,
      'textFieldFontSize': isDesktop ? 16 : 
                           isTablet ? width * 0.035 : 
                           isSmallPhone ? width * 0.035 : width * 0.04,
      'iconSize': isDesktop ? 24 : 
                  isTablet ? width * 0.05 : 
                  isSmallPhone ? width * 0.055 : width * 0.06,
      'buttonHeight': isDesktop ? 56 : 
                      isTablet ? height * 0.065 : 
                      isSmallPhone ? height * 0.06 : height * 0.07,
      'buttonFontSize': isDesktop ? 18 : 
                        isTablet ? width * 0.045 : 
                        isSmallPhone ? width * 0.05 : width * 0.06,
      'linkFontSize': isDesktop ? 16 : 
                      isTablet ? width * 0.04 : 
                      isSmallPhone ? width * 0.04 : width * 0.045,
      'bodyFontSize': isDesktop ? 16 : 
                      isTablet ? width * 0.035 : 
                      isSmallPhone ? width * 0.035 : width * 0.04,
      'maxFormWidth': isDesktop ? 500 : isTablet ? 400 : double.infinity,
      'verticalSpacing': isSmallPhone ? height * 0.015 : height * 0.025,
    };
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

  Future<void> reset() async {
    setState(() => _emailTouched = true);

    if (!_formKey.currentState!.validate()) {
      Get.snackbar(
        'Validation Error',
        'Please enter a valid email address',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        icon: const Icon(Icons.error_outline, color: Colors.red),
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      
      final userData = await _findUserData(email);
      
      if (userData == null) {
        _showErrorDialog('No account found with this email. Please check and try again.');
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      if (userData['hasTemporaryPassword'] == true) {
        final collectionPath = userData['collectionPath'];
        await _firestore
            .collection('users')
            .doc(collectionPath.split('/')[0])
            .collection(collectionPath.split('/')[1])
            .doc(userData['uid'])
            .update({
              'hasTemporaryPassword': false,
              'tempPassword': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      _showSuccessDialog(userData['hasTemporaryPassword'] == true);
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(_getErrorMessage(e.code));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _findUserData(String email) async {
    final collections = [
      'admin/data',
      'college_staff/data',
      'students/data',
      'faculty/data',
      'department_head/data',
      'pending_students/data',
      'blocked_students/data',
    ];

    for (final collection in collections) {
      final parts = collection.split('/');
      final snapshot = await _firestore
          .collection('users')
          .doc(parts[0])
          .collection(parts[1])
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return {
          ...snapshot.docs.first.data(),
          'uid': snapshot.docs.first.id,
          'collectionPath': collection,
        };
      }
    }
    return null;
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid college email address.';
      case 'user-not-found':
        return 'No account found with this email. Please check and try again.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  void _showErrorDialog(String message) {
    final size = MediaQuery.of(context).size;
    final values = _getResponsiveValues(size);
    
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          'Error',
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: values['subtitleFontSize'],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: primaryBlue,
              size: values['iconSize']! * 2,
            ),
            SizedBox(height: values['verticalSpacing']! * 0.5),
            Text(
              message,
              style: TextStyle(fontSize: values['textFieldFontSize']),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'OK',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: values['textFieldFontSize'],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(bool hadTemporaryPassword) {
    final size = MediaQuery.of(context).size;
    final values = _getResponsiveValues(size);
    
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          'Success',
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: values['subtitleFontSize'],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: values['iconSize']! * 2,
            ),
            SizedBox(height: values['verticalSpacing']! * 0.5),
            Text(
              hadTemporaryPassword
                  ? 'Password reset link sent. Your temporary password has been cleared.'
                  : 'Password reset link has been sent to your email.',
              style: TextStyle(fontSize: values['textFieldFontSize']),
              textAlign: TextAlign.center,
            ),
            if (hadTemporaryPassword)
              Padding(
                padding: EdgeInsets.only(top: values['verticalSpacing']! * 0.3),
                child: Text(
                  'You can now set a permanent password.',
                  style: TextStyle(
                    fontSize: values['textFieldFontSize']! * 0.9,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.offAll(() => const LoginPage());
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: values['textFieldFontSize'],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(Map<String, double> values) {
    String? currentError;
    if (_emailTouched) {
      currentError = _validateEmail(_emailController.text);
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
            margin: EdgeInsets.symmetric(vertical: values['verticalSpacing']! * 0.3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue.withOpacity(0.1),
                  deepBlack.withOpacity(0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: accentYellow.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              onChanged: (value) {
                if (!_emailTouched) {
                  setState(() => _emailTouched = true);
                }
                if (_emailTouched) {
                  setState(() {});
                }
              },
              onTap: () {
                if (!_emailTouched) {
                  setState(() => _emailTouched = true);
                }
              },
              style: TextStyle(
                fontSize: values['textFieldFontSize'],
                color: deepBlack,
              ),
              decoration: InputDecoration(
                hintText: 'Enter Registered Email',
                hintStyle: TextStyle(
                  color: deepBlack.withOpacity(0.5),
                  fontSize: values['textFieldFontSize'],
                ),
                label: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Registered Email',
                        style: TextStyle(
                          color: deepBlack.withOpacity(0.5),
                          fontSize: values['textFieldFontSize'],
                        ),
                      ),
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: values['textFieldFontSize'],
                        ),
                      ),
                    ],
                  ),
                ),
                prefixIcon: Icon(
                  Icons.email_rounded,
                  color: currentError != null ? Colors.red : primaryBlue,
                  size: values['iconSize'],
                ),
                suffixIcon: currentError != null 
                    ? Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: values['iconSize'],
                      )
                    : (_emailTouched && _emailController.text.isNotEmpty
                        ? Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: values['iconSize'],
                          )
                        : null),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                    color: currentError != null
                        ? Colors.red.withOpacity(0.5)
                        : primaryBlue.withOpacity(0.1),
                    width: currentError != null ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                    color: currentError != null ? Colors.red : primaryBlue,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                    color: Colors.red.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(
                    color: Colors.red,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: values['buttonHeight']! * 0.3,
                ),
              ),
            ),
          ),
          if (currentError != null)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: Text(
                currentError,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: values['textFieldFontSize']! * 0.85,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResetButton(Map<String, double> values) {
    return ScaleTransition(
      scale: _buttonScaleAnimation,
      child: Container(
        width: double.infinity,
        height: values['buttonHeight'],
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryBlue, Color(0xFF0D47A1)],
          ),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: accentYellow.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : reset,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: values['iconSize'],
                  height: values['iconSize'],
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Send Reset Link',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: values['buttonFontSize'],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final values = _getResponsiveValues(size);
    final isWideScreen = size.width > 1024;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isWideScreen ? 1200 : double.infinity,
                  ),
                  child: isWideScreen 
                      ? _buildWideScreenLayout(size, values)
                      : _buildMobileLayout(size, values),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWideScreenLayout(Size size, Map<String, double> values) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            padding: EdgeInsets.all(values['formPadding']!),
            child: ScaleTransition(
              scale: _lottieScaleAnimation,
              child: SizedBox(
                height: values['lottieHeight'],
                child: Lottie.asset(
                  'assets/lottie/forgot.json',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: values['horizontalPadding']!),
            child: _buildFormSection(size, values),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Size size, Map<String, double> values) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: values['horizontalPadding']!),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(height: size.height * 0.05),
              ScaleTransition(
                scale: _lottieScaleAnimation,
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(math.pi * _lottieScaleAnimation.value * 0.0),
                  alignment: Alignment.center,
                  child: SizedBox(
                    height: values['lottieHeight'],
                    child: Lottie.asset(
                      'assets/lottie/forgot.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              _buildFormSection(size, values),
              SizedBox(height: size.height * 0.05),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection(Size size, Map<String, double> values) {
    return SlideTransition(
      position: _formSlideAnimation,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(_rotationAnimation.value),
        alignment: Alignment.center,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: values['maxFormWidth']!,
          ),
          padding: EdgeInsets.all(values['formPadding']!),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, -5),
              ),
              BoxShadow(
                color: accentYellow.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [primaryBlue, Color.fromARGB(255, 234, 26, 168)],
                ).createShader(bounds),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: values['titleFontSize'],
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: values['verticalSpacing']! * 0.4),
              Text(
                'Enter your email to reset password',
                style: TextStyle(
                  fontSize: values['subtitleFontSize'],
                  color: deepBlack.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: values['verticalSpacing']!),
              _buildTextField(values),
              SizedBox(height: values['verticalSpacing']!),
              _buildResetButton(values),
              SizedBox(height: values['verticalSpacing']!),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    'Remember your password? ',
                    style: TextStyle(
                      color: deepBlack.withOpacity(0.6),
                      fontSize: values['bodyFontSize'],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.offAll(() => const LoginPage()),
                    child: Text(
                      'Login Now',
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: values['linkFontSize'],
                      ),
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
}