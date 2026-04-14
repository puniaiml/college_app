// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'dart:math' as math;

class FacultyProfilePage extends StatefulWidget {
  const FacultyProfilePage({super.key});

  @override
  State<FacultyProfilePage> createState() => _FacultyProfilePageState();
}

class _FacultyProfilePageState extends State<FacultyProfilePage>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _badgeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _badgeAnimation;

  Map<String, dynamic>? facultyData;
  bool isLoading = true;
  bool isEditing = false;
  bool isUpdating = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _profileImageUrl;

  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  static const primaryBlue = Color(0xFF1A237E);
  static const accentYellow = Color(0xFFFFD700);
  static const deepBlack = Color(0xFF121212);
  static const lightGray = Color(0xFFF5F5F5);
  static const premiumGold = Color(0xFFD4AF37);
  // ignore: unused_field
  static const premiumBlue = Color(0xFF4285F4);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadFacultyData();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _badgeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
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

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _badgeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _badgeController,
      curve: Curves.elasticOut,
    ));

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  Future<void> _loadFacultyData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          facultyData = doc.data() as Map<String, dynamic>;
          _populateControllers();
          isLoading = false;
        });
        
        if (_hasStudentAccess()) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _badgeController.forward();
          });
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load profile data: $e');
      setState(() => isLoading = false);
    }
  }

  void _populateControllers() {
    if (facultyData != null) {
      _nameController.text = facultyData!['name'] ?? '';
      _phoneController.text = facultyData!['phone'] ?? '';
      _emailController.text = facultyData!['email'] ?? '';
      _profileImageUrl = facultyData!['profileImageUrl'];
    }
  }

  bool _hasStudentAccess() {
    return facultyData?['canHandleStudents'] == true;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _profileImageUrl;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('faculty_${user.uid}.jpg');

      final uploadTask = await ref.putFile(_selectedImage!);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      Get.snackbar('Error', 'Failed to upload image: $e');
      return null;
    }
  }

  Future<void> _updateProfile() async {
    setState(() => isUpdating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final imageUrl = await _uploadImage();

      final updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'profileImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .doc(user.uid)
          .update(updatedData);

      await _loadFacultyData();

      setState(() {
        isEditing = false;
        _selectedImage = null;
      });

      Get.snackbar(
        'Success',
        'Profile updated successfully',
        backgroundColor: Colors.green.withOpacity(0.1),
        colorText: Colors.green,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to update profile: $e');
    } finally {
      setState(() => isUpdating = false);
    }
  }

  Widget _buildPremiumIndicator() {
    if (!_hasStudentAccess()) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _badgeController,
      builder: (context, child) {
        return ScaleTransition(
          scale: _badgeAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [premiumGold, Color(0xFFB8860B)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: premiumGold.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Student Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final avatarSize = isTablet ? 140.0 : constraints.maxWidth * 0.32;
        final titleSize = isTablet ? 28.0 : constraints.maxWidth * 0.06;
        final nameSize = isTablet ? 32.0 : constraints.maxWidth * 0.07;
        final roleSize = isTablet ? 18.0 : constraints.maxWidth * 0.045;
        
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue,
                  primaryBlue.withOpacity(0.8),
                  const Color(0xFF0D47A1),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth * 0.05,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'My Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => isEditing = !isEditing),
                          icon: Icon(
                            isEditing ? Icons.close : Icons.edit,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  GestureDetector(
                    onTap: isEditing ? _pickImage : null,
                    child: Stack(
                      children: [
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _hasStudentAccess() ? premiumGold : Colors.white,
                              width: _hasStudentAccess() ? 4 : 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _hasStudentAccess() 
                                    ? premiumGold.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _selectedImage != null
                                ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  )
                                : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                    ? Image.network(
                                        _profileImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return _buildDefaultAvatar();
                                        },
                                      )
                                    : _buildDefaultAvatar(),
                          ),
                        ),
                        if (_hasStudentAccess())
                          Positioned(
                            top: 0,
                            right: 0,
                            child: ScaleTransition(
                              scale: _badgeAnimation,
                              child: Container(
                                width: isTablet ? 48 : 36,
                                height: isTablet ? 48 : 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [premiumGold, Color(0xFFB8860B)],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  Icons.verified,
                                  color: Colors.white,
                                  size: isTablet ? 24 : 18,
                                ),
                              ),
                            ),
                          ),
                        if (isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: accentYellow,
                                shape: BoxShape.circle,
                              ),
                              padding: EdgeInsets.all(isTablet ? 12 : 8),
                              child: Icon(
                                Icons.camera_alt,
                                color: deepBlack,
                                size: isTablet ? 24 : 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (!isEditing) ...[
                    Text(
                      facultyData?['name'] ?? 'N/A',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: nameSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      facultyData?['role'] ?? 'Faculty Member',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: roleSize,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildPremiumIndicator(),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor() {
    if (facultyData == null) return Colors.grey;
    
    final isActive = facultyData!['isActive'] ?? false;
    final isEmailVerified = facultyData!['isEmailVerified'] ?? false;
    final accountStatus = facultyData!['accountStatus'] ?? 'inactive';
    
    if (isActive && isEmailVerified && accountStatus == 'active') {
      return Colors.green;
    } else if (!isEmailVerified) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getStatusText() {
    if (facultyData == null) return 'Unknown';
    
    final isActive = facultyData!['isActive'] ?? false;
    final isEmailVerified = facultyData!['isEmailVerified'] ?? false;
    final accountStatus = facultyData!['accountStatus'] ?? 'inactive';
    
    if (isActive && isEmailVerified && accountStatus == 'active') {
      return 'Active';
    } else if (!isEmailVerified) {
      return 'Email Unverified';
    } else if (!isActive) {
      return 'Inactive';
    } else {
      return 'Pending';
    }
  }

  // ignore: unused_element
  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'hod':
        return Colors.red;
      case 'assistant professor':
        return Colors.blue;
      case 'associate professor':
        return Colors.purple;
      case 'teaching staff':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        Icons.person,
        size: 60,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final fontSize = isTablet ? 16.0 : 14.0;
        final labelSize = isTablet ? 14.0 : 12.0;
        final iconSize = isTablet ? 24.0 : 20.0;
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            style: TextStyle(
              fontSize: fontSize,
              color: deepBlack,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: primaryBlue.withOpacity(0.7),
                fontSize: labelSize,
              ),
              prefixIcon: Icon(
                icon,
                color: primaryBlue,
                size: iconSize,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
    bool isPremiumFeature = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final titleSize = isTablet ? 14.0 : 12.0;
        final valueSize = isTablet ? 16.0 : 14.0;
        final iconSize = isTablet ? 24.0 : 20.0;
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: isPremiumFeature ? Border.all(
              color: premiumGold.withOpacity(0.5),
              width: 2,
            ) : null,
            boxShadow: [
              BoxShadow(
                color: isPremiumFeature 
                    ? premiumGold.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 20, 
              vertical: isTablet ? 12 : 8,
            ),
            leading: Container(
              padding: EdgeInsets.all(isTablet ? 12 : 10),
              decoration: BoxDecoration(
                color: isPremiumFeature 
                    ? premiumGold.withOpacity(0.1)
                    : primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isPremiumFeature ? premiumGold : primaryBlue,
                size: iconSize,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isPremiumFeature) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [premiumGold, Color(0xFFB8860B)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PREMIUM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  color: valueColor ?? deepBlack,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing: isPremiumFeature ? const Icon(
              Icons.star,
              color: premiumGold,
              size: 20,
            ) : null,
          ),
        );
      },
    );
  }

  Widget _buildUpdateButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final buttonHeight = isTablet ? 56.0 : 50.0;
        final fontSize = isTablet ? 18.0 : 16.0;
        
        return Container(
          width: double.infinity,
          height: buttonHeight,
          margin: const EdgeInsets.symmetric(vertical: 20),
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
            ],
          ),
          child: ElevatedButton(
            onPressed: isUpdating ? null : _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: isUpdating
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Text(
                    'Update Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final fontSize = isTablet ? 24.0 : 20.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: deepBlack,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: lightGray,
        body: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth > 600;
              final lottieSize = isTablet ? 200.0 : constraints.maxWidth * 0.3;
              final textSize = isTablet ? 18.0 : constraints.maxWidth * 0.045;
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/lottie/loading.json',
                    width: lottieSize,
                    height: lottieSize,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Profile...',
                    style: TextStyle(
                      fontSize: textSize,
                      color: deepBlack.withOpacity(0.7),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    if (facultyData == null) {
      return Scaffold(
        backgroundColor: lightGray,
        body: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth > 600;
              final textSize = isTablet ? 20.0 : constraints.maxWidth * 0.05;
              
              return Text(
                'No profile data found',
                style: TextStyle(
                  fontSize: textSize,
                  color: deepBlack.withOpacity(0.7),
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightGray,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildProfileHeader(),
            
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth > 600;
                    final horizontalPadding = isTablet ? 40.0 : 20.0;
                    
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet ? 800 : double.infinity,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isEditing) ...[
                              _buildSectionTitle('Edit Profile'),
                              
                              _buildEditableField(
                                label: 'Full Name',
                                controller: _nameController,
                                icon: Icons.person,
                              ),
                              
                              _buildEditableField(
                                label: 'Phone',
                                controller: _phoneController,
                                icon: Icons.phone,
                              ),
                              
                              _buildEditableField(
                                label: 'Email (Read Only)',
                                controller: _emailController,
                                icon: Icons.email,
                                readOnly: true,
                              ),
                              
                              _buildUpdateButton(),
                            ] else ...[
                              _buildSectionTitle('Personal Information'),
                              
                              _buildInfoCard(
                                title: 'College',
                                value: facultyData!['collegeName'] ?? 'N/A',
                                icon: Icons.business,
                              ),
                              
                              _buildInfoCard(
                                title: 'Course',
                                value: facultyData!['courseName'] ?? 'N/A',
                                icon: Icons.menu_book,
                              ),
                              
                              _buildInfoCard(
                                title: 'Branch',
                                value: facultyData!['branchName'] ?? 'N/A',
                                icon: Icons.account_tree,
                              ),
                              
                              const SizedBox(height: 24),
                              
                              _buildSectionTitle('Account Information'),
                              
                              _buildInfoCard(
                                title: 'Account Status',
                                value: facultyData!['accountStatus'] ?? 'Unknown',
                                icon: Icons.account_circle,
                                valueColor: _getStatusColor(),
                              ),
                              
                              _buildInfoCard(
                                title: 'Active Status',
                                value: (facultyData!['isActive'] ?? false) ? 'Active' : 'Inactive',
                                icon: Icons.power_settings_new,
                                valueColor: (facultyData!['isActive'] ?? false) ? Colors.green : Colors.red,
                              ),
                              
                              if (facultyData!['hasTemporaryPassword'] != null)
                                _buildInfoCard(
                                  title: 'Password Status',
                                  value: facultyData!['hasTemporaryPassword'] ? 'Temporary Password' : 'Custom Password',
                                  icon: Icons.key,
                                  valueColor: facultyData!['hasTemporaryPassword'] ? Colors.orange : Colors.green,
                                ),
                              
                              if (facultyData!['createdAt'] != null)
                                _buildInfoCard(
                                  title: 'Member Since',
                                  value: DateFormat('dd MMMM yyyy')
                                      .format((facultyData!['createdAt'] as Timestamp).toDate()),
                                  icon: Icons.date_range,
                                ),
                              
                              if (facultyData!['verifiedAt'] != null)
                                _buildInfoCard(
                                  title: 'Email Verified On',
                                  value: DateFormat('dd MMMM yyyy, hh:mm a')
                                      .format((facultyData!['verifiedAt'] as Timestamp).toDate()),
                                  icon: Icons.verified,
                                  valueColor: Colors.green,
                                ),
                              
                              if (facultyData!['createdByName'] != null)
                                _buildInfoCard(
                                  title: 'Account Created By',
                                  value: facultyData!['createdByName'] ?? 'System',
                                  icon: Icons.person_add,
                                  valueColor: Colors.blue,
                                ),
                            ],
                            
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _badgeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
    }