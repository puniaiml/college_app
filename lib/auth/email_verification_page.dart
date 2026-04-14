import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shiksha_hub/auth/email_service.dart';
import 'package:shiksha_hub/auth/wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class OtpVerificationPage extends StatefulWidget {
  final String userId;
  final String email;
  final String userType;

  const OtpVerificationPage({
    super.key,
    required this.userId,
    required this.email,
    required this.userType,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage>
    with TickerProviderStateMixin {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  bool _canResendOtp = false;
  int _remainingSeconds = 60;
  Timer? _resendTimer;
  String? _errorMessage;
  String? _successMessage;

  late AnimationController _bounceController;
  late AnimationController _shakeController;
  late AnimationController _formController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<Offset> _formSlideAnimation;

  static const primaryBlue = Color(0xFF1A237E);
  static const lightBlue = Color(0xFF3F51B5);
  static const backgroundColor = Color(0xFFF8F9FB);
  static const accentYellow = Color(0xFFFFD700);
  static const deepBlack = Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _setupAnimations();
    _setupFocusListeners();
  }

  void _setupAnimations() {
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _formController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    ));

    _formController.forward();
  }

  void _setupFocusListeners() {
    for (int i = 0; i < _otpFocusNodes.length; i++) {
      _otpFocusNodes[i].addListener(() {
        if (_otpFocusNodes[i].hasFocus) {
          _otpControllers[i].selection = TextSelection.fromPosition(
            TextPosition(offset: _otpControllers[i].text.length),
          );
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _resendTimer?.cancel();
    _bounceController.dispose();
    _shakeController.dispose();
    _formController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResendOtp = false;
      _remainingSeconds = 60;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _canResendOtp = true;
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _resendOtp() async {
    if (!_canResendOtp) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final newOtp = (Random().nextInt(900000) + 100000).toString();
      String collectionPath = '';

      switch (widget.userType) {
        case 'student':
          collectionPath = 'pending_students';
          break;
        case 'college_staff':
          collectionPath = 'college_staff';
          break;
        case 'faculty':
          collectionPath = 'faculty';
          break;
        case 'department_head':
          collectionPath = 'department_head';
          break;
        default:
          throw Exception('Invalid user type');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(collectionPath)
          .collection('data')
          .doc(widget.userId)
          .update({
        'verificationOtp': newOtp,
        'otpCreatedAt': FieldValue.serverTimestamp(),
      });

      final otpSent = await EmailService.sendOtpEmail(widget.email, newOtp);

      if (!otpSent) {
        throw Exception('Failed to send OTP email');
      }

      _startResendTimer();
      _clearOtpFields();

      setState(() {
        _successMessage = 'A new OTP has been sent to your email';
      });

      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend OTP. Please try again.';
      });
      _shakeController.forward().then((_) => _shakeController.reset());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearOtpFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final enteredOtp = _otpControllers.map((c) => c.text).join();

      if (enteredOtp.length != 6) {
        throw Exception('Please enter a valid 6-digit OTP');
      }

      String collectionPath = '';
      switch (widget.userType) {
        case 'student':
          collectionPath = 'pending_students';
          break;
        case 'college_staff':
          collectionPath = 'college_staff';
          break;
        case 'faculty':
          collectionPath = 'faculty';
          break;
        case 'department_head':
          collectionPath = 'department_head';
          break;
        default:
          throw Exception('Invalid user type');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(collectionPath)
          .collection('data')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data not found. Please contact support.');
      }

      final storedOtp = userDoc['verificationOtp'] as String?;
      final otpCreatedAt = userDoc['otpCreatedAt'] as Timestamp?;

      if (storedOtp == null || otpCreatedAt == null) {
        throw Exception('OTP not found. Please request a new OTP.');
      }

      final now = DateTime.now();
      final otpExpiryTime =
          otpCreatedAt.toDate().add(const Duration(minutes: 10));

      if (now.isAfter(otpExpiryTime)) {
        throw Exception('OTP has expired. Please request a new one.');
      }

      if (enteredOtp != storedOtp) {
        throw Exception('Invalid OTP. Please try again.');
      }

      _bounceController.forward().then((_) => _bounceController.reverse());
      await _completeVerification();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      _shakeController.forward().then((_) => _shakeController.reset());
      _clearOtpFields();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeVerification() async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      String collectionPath = '';
      String nextStatus = '';

      switch (widget.userType) {
        case 'student':
          collectionPath = 'pending_students';
          nextStatus = 'pending_approval';
          break;
        case 'college_staff':
          collectionPath = 'college_staff';
          nextStatus = 'active';
          break;
        case 'faculty':
          collectionPath = 'faculty';
          nextStatus = 'active';
          break;
        case 'department_head':
          collectionPath = 'department_head';
          nextStatus = 'active';
          break;
        default:
          throw Exception('Invalid user type');
      }

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(collectionPath)
          .collection('data')
          .doc(widget.userId);

      Map<String, dynamic> updateData = {
        'isEmailVerified': true,
        'accountStatus': nextStatus,
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.userType == 'department_head') {
        updateData['isFirstLogin'] = false;
        updateData['isActive'] = true;
      }

      batch.update(userRef, updateData);

      final metadataRef = FirebaseFirestore.instance
          .collection('user_metadata')
          .doc(widget.userId);

      batch.update(metadataRef, {
        'accountStatus': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      String successMessage = '';
      switch (widget.userType) {
        case 'student':
          successMessage =
              'Email verified! Your application is now pending college staff approval.';
          break;
        case 'college_staff':
        case 'faculty':
          successMessage =
              'Email verified successfully! Welcome to the platform.';
          break;
        case 'department_head':
          successMessage =
              'Email verified successfully! Welcome to the HOD portal.';
          break;
      }

      setState(() {
        _successMessage = successMessage;
      });

      await Future.delayed(
          Duration(seconds: widget.userType == 'student' ? 3 : 2));
      Get.offAll(() => const Wrapper());
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to complete verification. Please try again.';
      });
      print('Verification error: $e');
    }
  }

  void _handleOtpInput(String value, int index) {
    value = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (value.length > 1) {
      _handlePastedOtp(value, index);
      return;
    }

    _otpControllers[index].text = value;

    if (value.isNotEmpty && index < _otpControllers.length - 1) {
      FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
    }

    if (index == _otpControllers.length - 1 && value.isNotEmpty) {
      final isComplete =
          _otpControllers.every((controller) => controller.text.isNotEmpty);
      if (isComplete) {
        FocusScope.of(context).unfocus();
        _verifyOtp();
      }
    }
  }

  void _handlePastedOtp(String pastedText, int startIndex) {
    final digits = pastedText.replaceAll(RegExp(r'[^0-9]'), '');

    for (int i = 0;
        i < digits.length && (startIndex + i) < _otpControllers.length;
        i++) {
      _otpControllers[startIndex + i].text = digits[i];
    }

    final lastFilledIndex = startIndex + digits.length - 1;
    if (lastFilledIndex < _otpControllers.length - 1) {
      FocusScope.of(context).requestFocus(_otpFocusNodes[lastFilledIndex + 1]);
    } else {
      FocusScope.of(context).unfocus();
      if (_otpControllers.every((controller) => controller.text.isNotEmpty)) {
        _verifyOtp();
      }
    }
  }

  Future<void> _handleCancel() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Verification?'),
        content: const Text(
          'Are you sure you want to cancel the email verification?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      try {
        setState(() => _isLoading = true);

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          if (widget.userType == 'student') {
            final batch = FirebaseFirestore.instance.batch();

            final pendingRef = FirebaseFirestore.instance
                .collection('users')
                .doc('pending_students')
                .collection('data')
                .doc(user.uid);

            batch.delete(pendingRef);

            final metadataRef = FirebaseFirestore.instance
                .collection('user_metadata')
                .doc(user.uid);

            batch.delete(metadataRef);

            await batch.commit();
            await user.delete();
          } else if (widget.userType == 'department_head') {
            await FirebaseFirestore.instance
                .collection('users/department_head/data')
                .doc(user.uid)
                .update({
              'verificationOtp': null,
              'otpCreatedAt': null,
              'isFirstLogin': true,
            });
            await FirebaseAuth.instance.signOut();
          } else {
            await FirebaseAuth.instance.signOut();
          }
        }
      } catch (e) {
        print('Error during cleanup: $e');
        await FirebaseAuth.instance.signOut();
      } finally {
        Get.offAll(() => const Wrapper());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: primaryBlue, size: 18),
          ),
          onPressed: () => _handleCancel(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () => _handleCancel(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 60 : 24,
              vertical: 20,
            ),
            child: SlideTransition(
              position: _formSlideAnimation,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Email Icon Animation
                    AnimatedBuilder(
                      animation: _bounceAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _bounceAnimation.value,
                          child: Container(
                            height: 140,
                            width: 140,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(70),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withOpacity(0.15),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Lottie.asset(
                              'assets/lottie/email.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Title
                    const Text(
                      'Verify Your Email',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Subtitle
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(
                              text: 'We\'ve sent a 6-digit code to\n'),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Error/Success Message
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: (_errorMessage != null || _successMessage != null) 
                          ? null
                          : 0,
                      child: (_errorMessage != null || _successMessage != null)
                          ? AnimatedBuilder(
                              animation: _shakeAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(sin(_shakeAnimation.value * pi * 4) * 5, 0),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 24),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _errorMessage != null
                                          ? Colors.red.shade50
                                          : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _errorMessage != null
                                            ? Colors.red.shade300
                                            : Colors.green.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _errorMessage != null
                                              ? Icons.error_outline
                                              : Icons.check_circle_outline,
                                          color: _errorMessage != null
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _errorMessage ?? _successMessage ?? '',
                                            style: TextStyle(
                                              color: _errorMessage != null
                                                  ? Colors.red.shade800
                                                  : Colors.green.shade800,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    
                    // OTP Input Fields
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          final hasFocus = _otpFocusNodes[index].hasFocus;
                          final hasText = _otpControllers[index].text.isNotEmpty;
                          
                          return Flexible(
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: isTablet ? 6 : 3,
                              ),
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _errorMessage != null
                                      ? Colors.red.shade400
                                      : (hasFocus
                                          ? primaryBlue
                                          : (hasText
                                              ? primaryBlue.withOpacity(0.5)
                                              : Colors.grey.shade300)),
                                  width: hasFocus ? 2.5 : 1.5,
                                ),
                                color: _errorMessage != null
                                    ? Colors.red.withOpacity(0.05)
                                    : (hasFocus
                                        ? primaryBlue.withOpacity(0.05)
                                        : (hasText
                                            ? primaryBlue.withOpacity(0.03)
                                            : Colors.grey.shade50)),
                              ),
                              child: TextField(
                                controller: _otpControllers[index],
                                focusNode: _otpFocusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _errorMessage != null
                                      ? Colors.red.shade700
                                      : (hasText ? primaryBlue : Colors.grey.shade600),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (value) => _handleOtpInput(value, index),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Verify Button
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [primaryBlue, lightBlue],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isLoading ? null : _verifyOtp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Verify OTP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Resend Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          if (!_canResendOtp) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer_outlined,
                                    color: Colors.grey.shade600, 
                                    size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Resend code in $_remainingSeconds seconds',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            TextButton.icon(
                              onPressed: _resendOtp,
                              icon: const Icon(Icons.refresh, size: 20),
                              label: const Text(
                                'Resend OTP',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryBlue,
                                backgroundColor: primaryBlue.withOpacity(0.1),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.grey.shade500, 
                                  size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Code expires in 10 minutes',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
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
  }
}