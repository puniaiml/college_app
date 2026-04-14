import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
// ignore: unused_import
import 'dart:math' as math;

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage>
    with TickerProviderStateMixin {
  
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Student data
  Map<String, dynamic>? studentData;
  bool isLoading = true;
  bool isEditing = false;
  bool isUpdating = false;

  // Edit controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  String? _profileImageUrl;

  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  // Colors
  static const primaryBlue = Color(0xFF1A237E);
  static const accentYellow = Color(0xFFFFD700);
  static const deepBlack = Color(0xFF121212);
  static const lightGray = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadStudentData();
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

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  Future<void> _loadStudentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Try to get from active students first
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // Try pending students
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc('pending_students')
            .collection('data')
            .doc(user.uid)
            .get();
      }

      if (doc.exists) {
        setState(() {
          studentData = doc.data() as Map<String, dynamic>;
          _populateControllers();
          isLoading = false;
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load profile data: $e');
      setState(() => isLoading = false);
    }
  }

  void _populateControllers() {
    if (studentData != null) {
      _firstNameController.text = studentData!['firstName'] ?? '';
      _lastNameController.text = studentData!['lastName'] ?? '';
      _phoneController.text = studentData!['phone'] ?? '';
      _emailController.text = studentData!['email'] ?? '';
      _selectedGender = studentData!['gender'];
      _profileImageUrl = studentData!['profileImageUrl'];
      
      if (studentData!['dateOfBirth'] != null) {
        _selectedDateOfBirth = (studentData!['dateOfBirth'] as Timestamp).toDate();
      }
    }
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
          .child('${user.uid}.jpg');

      final uploadTask = await ref.putFile(_selectedImage!);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      Get.snackbar('Error', 'Failed to upload image: $e');
      return null;
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: deepBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => isUpdating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Upload image if selected
      final imageUrl = await _uploadImage();

      final updatedData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'fullName': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        'dateOfBirth': _selectedDateOfBirth != null 
            ? Timestamp.fromDate(_selectedDateOfBirth!) 
            : null,
        'profileImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update in the appropriate collection
      final isActive = studentData!['accountStatus'] == 'active';
      final collection = isActive ? 'students' : 'pending_students';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .update(updatedData);

      // Reload data
      await _loadStudentData();

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

  Widget _buildProfileHeader() {
    final size = MediaQuery.of(context).size;
    
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
                padding: EdgeInsets.all(size.width * 0.05),
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
                        fontSize: size.width * 0.06,
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
              
              // Profile Image
              GestureDetector(
                onTap: isEditing ? _pickImage : null,
                child: Stack(
                  children: [
                    Container(
                      width: size.width * 0.35,
                      height: size.width * 0.35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
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
                    if (isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: accentYellow,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.camera_alt,
                            color: deepBlack,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              SizedBox(height: size.height * 0.02),
              
              // Name and USN
              if (!isEditing) ...[
                Text(
                  studentData?['fullName'] ?? 'N/A',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size.width * 0.07,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: size.height * 0.005),
                Text(
                  studentData?['usn'] ?? 'N/A',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: size.width * 0.045,
                    letterSpacing: 1,
                  ),
                ),
              ],
              
              SizedBox(height: size.height * 0.02),
              
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: studentData?['accountStatus'] == 'active'
                      ? Colors.green
                      : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  studentData?['accountStatus'] == 'active' ? 'Active' : 'Pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              SizedBox(height: size.height * 0.03),
            ],
          ),
        ),
      ),
    );
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
    final size = MediaQuery.of(context).size;
    
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
          fontSize: size.width * 0.04,
          color: deepBlack,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: primaryBlue.withOpacity(0.7),
            fontSize: size.width * 0.035,
          ),
          prefixIcon: Icon(
            icon,
            color: primaryBlue,
            size: size.width * 0.06,
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
  }

  Widget _buildGenderDropdown() {
    final size = MediaQuery.of(context).size;
    
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
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        items: ['Male', 'Female', 'Other'].map((gender) {
          return DropdownMenuItem(
            value: gender,
            child: Text(gender),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedGender = value),
        decoration: InputDecoration(
          labelText: 'Gender',
          labelStyle: TextStyle(
            color: primaryBlue.withOpacity(0.7),
            fontSize: size.width * 0.035,
          ),
          prefixIcon: Icon(
            Icons.person_outline,
            color: primaryBlue,
            size: size.width * 0.06,
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
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    final size = MediaQuery.of(context).size;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: primaryBlue,
            size: size.width * 0.06,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: size.width * 0.035,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: size.width * 0.04,
            color: valueColor ?? deepBlack,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    final size = MediaQuery.of(context).size;
    
    return Container(
      width: double.infinity,
      height: size.height * 0.07,
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
                  fontSize: size.width * 0.05,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (isLoading) {
      return Scaffold(
        backgroundColor: lightGray,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/loading.json',
                width: size.width * 0.3,
                height: size.width * 0.3,
              ),
              SizedBox(height: size.height * 0.02),
              Text(
                'Loading Profile...',
                style: TextStyle(
                  fontSize: size.width * 0.045,
                  color: deepBlack.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (studentData == null) {
      return Scaffold(
        backgroundColor: lightGray,
        body: Center(
          child: Text(
            'No profile data found',
            style: TextStyle(
              fontSize: size.width * 0.05,
              color: deepBlack.withOpacity(0.7),
            ),
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(size.width * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isEditing) ...[
                        Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: size.width * 0.06,
                            fontWeight: FontWeight.bold,
                            color: deepBlack,
                          ),
                        ),
                        SizedBox(height: size.height * 0.02),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildEditableField(
                                label: 'First Name',
                                controller: _firstNameController,
                                icon: Icons.person,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildEditableField(
                                label: 'Last Name',
                                controller: _lastNameController,
                                icon: Icons.person_outline,
                              ),
                            ),
                          ],
                        ),
                        
                        _buildEditableField(
                          label: 'Phone',
                          controller: _phoneController,
                          icon: Icons.phone,
                        ),
                        
                        _buildGenderDropdown(),
                        
                        _buildEditableField(
                          label: 'Date of Birth',
                          controller: TextEditingController(
                            text: _selectedDateOfBirth != null
                                ? DateFormat('dd/MM/yyyy').format(_selectedDateOfBirth!)
                                : 'Select Date',
                          ),
                          icon: Icons.calendar_today,
                          readOnly: true,
                          onTap: _selectDateOfBirth,
                        ),
                        
                        _buildUpdateButton(),
                      ] else ...[
                        Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: size.width * 0.06,
                            fontWeight: FontWeight.bold,
                            color: deepBlack,
                          ),
                        ),
                        SizedBox(height: size.height * 0.02),
                        
                        _buildInfoCard(
                          title: 'Email',
                          value: studentData!['email'] ?? 'N/A',
                          icon: Icons.email,
                        ),
                        
                        _buildInfoCard(
                          title: 'Phone',
                          value: studentData!['phone'] ?? 'N/A',
                          icon: Icons.phone,
                        ),
                        
                        _buildInfoCard(
                          title: 'Gender',
                          value: studentData!['gender'] ?? 'Not specified',
                          icon: Icons.person_outline,
                        ),
                        
                        if (studentData!['dateOfBirth'] != null)
                          _buildInfoCard(
                            title: 'Date of Birth',
                            value: DateFormat('dd MMMM yyyy')
                                .format((studentData!['dateOfBirth'] as Timestamp).toDate()),
                            icon: Icons.calendar_today,
                          ),
                        
                        SizedBox(height: size.height * 0.03),
                        
                        Text(
                          'Academic Information',
                          style: TextStyle(
                            fontSize: size.width * 0.06,
                            fontWeight: FontWeight.bold,
                            color: deepBlack,
                          ),
                        ),
                        SizedBox(height: size.height * 0.02),
                        
                        _buildInfoCard(
                          title: 'University',
                          value: studentData!['universityName'] ?? 'N/A',
                          icon: Icons.school,
                        ),
                        
                        _buildInfoCard(
                          title: 'College',
                          value: studentData!['collegeName'] ?? 'N/A',
                          icon: Icons.business,
                        ),
                        
                        _buildInfoCard(
                          title: 'Course',
                          value: studentData!['courseName'] ?? 'N/A',
                          icon: Icons.menu_book,
                        ),
                        
                        _buildInfoCard(
                          title: 'Branch',
                          value: studentData!['branchName'] ?? 'N/A',
                          icon: Icons.account_tree,
                        ),
                        
                        _buildInfoCard(
                          title: 'Year of Passing',
                          value: studentData!['yearOfPassing'] ?? 'N/A',
                          icon: Icons.calendar_today,
                        ),
                        
                        if (studentData!['createdAt'] != null) ...[
                          SizedBox(height: size.height * 0.03),
                          Text(
                            'Account Information',
                            style: TextStyle(
                              fontSize: size.width * 0.06,
                              fontWeight: FontWeight.bold,
                              color: deepBlack,
                            ),
                          ),
                          SizedBox(height: size.height * 0.02),
                          
                          _buildInfoCard(
                            title: 'Member Since',
                            value: DateFormat('dd MMMM yyyy')
                                .format((studentData!['createdAt'] as Timestamp).toDate()),
                            icon: Icons.date_range,
                          ),
                        ],
                      ],
                      
                      SizedBox(height: size.height * 0.05),
                    ],
                  ),
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}