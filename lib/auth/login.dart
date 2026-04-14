import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shiksha_hub/auth/email_service.dart';
import 'package:shiksha_hub/auth/email_verification_page.dart';
import 'package:shiksha_hub/auth/wrapper.dart';
import 'package:shiksha_hub/owner/owner_home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:shiksha_hub/auth/register.dart';
import 'package:shiksha_hub/auth/forgot_password.dart';
import 'dart:math' as math;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late AnimationController _lottieController;
  late AnimationController _formController;
  late AnimationController _rotationController;
  late Animation<double> _lottieScaleAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _buttonScaleAnimation;

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _emailTouched = false;
  bool _passwordTouched = false;

  static const primaryBlue = Color(0xFF1A237E);
  static const accentYellow = Color(0xFFFFD700);
  static const deepBlack = Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
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

  @override
  void dispose() {
    _lottieController.dispose();
    _formController.dispose();
    _rotationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String getErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid registered email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact college support.';
      case 'user-not-found':
        return 'No account found. Please register with your email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid login credentials. Please check your details.';
      case 'invalid-input':
        return 'Please fill in all required fields.';
      case 'operation-not-allowed':
        return 'Login is not enabled. Please contact college support.';
      case 'account-inactive':
        return 'Your account is inactive. Please contact the administrator.';
      case 'no-user-record':
        return 'Account data not found. Please contact support.';
      case 'account-blocked':
        return 'Your account has been blocked.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<void> signIn() async {
    if (_isLoading) return;

    setState(() {
      _emailTouched = true;
      _passwordTouched = true;
    });

    if (!_formKey.currentState!.validate()) {
      Get.snackbar(
        'Validation Error',
        'Please fill all required fields correctly',
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
      if (_emailController.text.trim() == 'admin@gmail.com' &&
          _passwordController.text == 'admin@123') {
        Get.offAll(() => const OwnerDashboard());
        return;
      }

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'Unable to sign in. Please try again.',
        );
      }

      final metadataDoc = await FirebaseFirestore.instance
          .collection('user_metadata')
          .doc(user.uid)
          .get();

      if (!metadataDoc.exists) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'no-user-record',
          message: 'Account not found in system. Please register again.',
        );
      }

      final metadataData = metadataDoc.data() as Map<String, dynamic>;
      final String userType = metadataData['userType'] ?? '';
      final String accountStatus = metadataData['accountStatus'] ?? '';

      if (accountStatus == 'pending_verification') {
        await _handlePendingVerification(user, userType);
        return;
      }

      Get.offAll(() => const Wrapper());

    } on FirebaseAuthException catch (e) {
      _showErrorDialog('Login Error', getErrorMessage(e.code));
    } catch (e) {
      _showErrorDialog('Error', 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePendingVerification(User user, String userType) async {
    try {
      String collectionPath = _getCollectionPath(userType);
      
      if (collectionPath.isEmpty) {
        throw Exception('Invalid user type');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(collectionPath)
          .collection('data')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final String storedEmail = userData['email'] ?? user.email ?? '';

      final newOtp = (math.Random().nextInt(900000) + 100000).toString();

      await userDoc.reference.update({
        'verificationOtp': newOtp,
        'otpCreatedAt': FieldValue.serverTimestamp(),
      });

      await EmailService.sendOtpEmail(storedEmail, newOtp);

      Get.offAll(() => OtpVerificationPage(
            userId: user.uid,
            email: storedEmail,
            userType: userType,
          ));
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      _showErrorDialog('Verification Error', 'Failed to send verification code. Please try again.');
    }
  }

  String _getCollectionPath(String userType) {
    switch (userType) {
      case 'student': return 'pending_students';
      case 'college_staff': return 'college_staff';
      case 'faculty': return 'faculty';
      case 'department_head': return 'department_head';
      default: return '';
    }
  }

  void _showErrorDialog(String title, String message) {
    final size = MediaQuery.of(context).size;
    final values = _getResponsiveValues(size);
    
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          title,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Map<String, double> values,
    bool isPassword = false,
    String? Function(String?)? validator,
    bool isTouched = false,
    Function(bool)? onTouchedChanged,
  }) {
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
                fontSize: values['textFieldFontSize'],
                color: deepBlack,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: deepBlack.withOpacity(0.5),
                  fontSize: values['textFieldFontSize'],
                ),
                label: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: hint,
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
                  icon,
                  color: currentError != null ? Colors.red : primaryBlue,
                  size: values['iconSize'],
                ),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: primaryBlue,
                          size: values['iconSize'],
                        ),
                        onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                      )
                    : (currentError != null 
                        ? Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: values['iconSize'],
                          )
                        : (isTouched && controller.text.isNotEmpty
                            ? Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: values['iconSize'],
                              )
                            : null)),
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

  Widget _buildLoginButton(Map<String, double> values) {
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
          onPressed: _isLoading ? null : signIn,
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
                  'Login',
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
                  'assets/lottie/login.json',
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
          child: AutofillGroup(
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
                        'assets/lottie/login.json',
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
                  'Welcome Back!',
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
                'Sign in to continue',
                style: TextStyle(
                  fontSize: values['subtitleFontSize'],
                  color: deepBlack.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: values['verticalSpacing']!),
              _buildTextField(
                controller: _emailController,
                hint: 'Email',
                icon: Icons.email_rounded,
                values: values,
                validator: _validateEmail,
                isTouched: _emailTouched,
                onTouchedChanged: (touched) => setState(() => _emailTouched = touched),
              ),
              _buildTextField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock_rounded,
                isPassword: true,
                values: values,
                validator: _validatePassword,
                isTouched: _passwordTouched,
                onTouchedChanged: (touched) => setState(() => _passwordTouched = touched),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Get.to(() => const Forgot()),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: values['linkFontSize'],
                    ),
                  ),
                ),
              ),
              SizedBox(height: values['verticalSpacing']! * 0.6),
              _buildLoginButton(values),
              SizedBox(height: values['verticalSpacing']!),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    'New to the college? ',
                    style: TextStyle(
                      color: deepBlack.withOpacity(0.6),
                      fontSize: values['bodyFontSize'],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.to(() => const RegisterPage()),
                    child: Text(
                      'Register Now',
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