import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../api/apis.dart';
import '../helper/dialogs.dart';
import '../../main.dart';
import '../models/chat_user.dart';
import '../widgets/profile_image.dart';

class ProfileScreen extends StatefulWidget {
  final ChatUser user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _image;
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  
  // Additional fields based on user type
  String? _userRole;
  Map<String, dynamic>? _extendedProfileData;

  @override
  void initState() {
    super.initState();
    _loadExtendedProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadExtendedProfile() async {
    setState(() => _isLoadingProfile = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Try to determine user role and fetch appropriate data
      DocumentSnapshot? doc;
      
      // Check student
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _userRole = 'student';
          _extendedProfileData = doc?.data() as Map<String, dynamic>;
          _populateFields();
        });
        return;
      }

      // Check pending students
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('pending_students')
          .collection('data')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _userRole = 'pending_student';
          _extendedProfileData = doc?.data() as Map<String, dynamic>;
          _populateFields();
        });
        return;
      }

      // Check faculty
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _userRole = 'faculty';
          _extendedProfileData = doc?.data() as Map<String, dynamic>;
          _populateFields();
        });
        return;
      }

      // Check HOD
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('department_head')
          .collection('data')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _userRole = 'hod';
          _extendedProfileData = doc?.data() as Map<String, dynamic>;
          _populateFields();
        });
        return;
      }

      // Check college staff
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('college_staff')
          .collection('data')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _userRole = 'college_staff';
          _extendedProfileData = doc?.data() as Map<String, dynamic>;
          _populateFields();
        });
        return;
      }

      // Default to basic profile
      _populateBasicFields();
      
    } catch (e) {
      log('Error loading extended profile: $e');
      _populateBasicFields();
    } finally {
      setState(() => _isLoadingProfile = false);
    }
  }

  void _populateBasicFields() {
    _nameController.text = widget.user.name;
    _emailController.text = widget.user.email;
    _phoneController.text = widget.user.phone;
    _aboutController.text = widget.user.about;
  }

  void _populateFields() {
    if (_extendedProfileData != null) {
      // Common fields
      _emailController.text = _extendedProfileData!['email'] ?? widget.user.email;
      _phoneController.text = _extendedProfileData!['phone'] ?? widget.user.phone ?? '';
      
      // Role-specific name handling
      if (_userRole == 'student' || _userRole == 'pending_student') {
        final firstName = _extendedProfileData!['firstName'] ?? '';
        final lastName = _extendedProfileData!['lastName'] ?? '';
        _nameController.text = '$firstName $lastName'.trim();
      } else {
        _nameController.text = _extendedProfileData!['name'] ?? widget.user.name;
      }
      
      _aboutController.text = widget.user.about;
    } else {
      _populateBasicFields();
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^\+?\d{10,15}$').hasMatch(cleaned)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validateAbout(String? value) {
    if (value != null && value.length > 150) {
      return 'About must be 150 characters or less';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: FocusScope.of(context).unfocus,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F3F8),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: _buildAppBar(),
        ),
        body: _isLoadingProfile
            ? _buildLoadingState()
            : Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth > 600;
                    final contentWidth = isTablet ? 600.0 : constraints.maxWidth;
                    
                    return Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 40 : 0,
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                _buildProfileSection(isTablet),
                                const SizedBox(height: 32),
                                _buildFormSection(isTablet),
                                const SizedBox(height: 40),
                                _buildUpdateButton(isTablet),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading profile...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF636E72),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'My Profile',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (_userRole != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getRoleDisplayName(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName() {
    switch (_userRole) {
      case 'student':
        return 'Student';
      case 'pending_student':
        return 'Pending Student';
      case 'faculty':
        return 'Faculty';
      case 'hod':
        return 'HOD';
      case 'college_staff':
        return 'Staff';
      default:
        return 'User';
    }
  }

  Widget _buildProfileSection(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 20),
      padding: EdgeInsets.all(isTablet ? 40 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.height * .1),
                        child: Image.file(
                          File(_image!),
                          width: isTablet ? 160 : MediaQuery.of(context).size.height * .18,
                          height: isTablet ? 160 : MediaQuery.of(context).size.height * .18,
                          fit: BoxFit.cover,
                        ),
                      )
                    : ProfileImage(
                        size: isTablet ? 160 : MediaQuery.of(context).size.height * .18,
                        url: _extendedProfileData?['profileImageUrl'] ?? widget.user.image,
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showBottomSheet,
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: EdgeInsets.all(isTablet ? 14 : 12),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: isTablet ? 26 : 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ).animate().scale(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
              ),
          SizedBox(height: isTablet ? 24 : 20),
          Text(
            _emailController.text,
            style: GoogleFonts.inter(
              color: const Color(0xFF636E72),
              fontSize: isTablet ? 16 : 15,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_extendedProfileData != null) ...[
            const SizedBox(height: 16),
            _buildProfileBadges(isTablet),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileBadges(bool isTablet) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_extendedProfileData!['accountStatus'] != null)
          _buildBadge(
            _extendedProfileData!['accountStatus'] == 'active' ? 'Active' : 'Pending',
            _extendedProfileData!['accountStatus'] == 'active' 
                ? Colors.green 
                : Colors.orange,
            isTablet,
          ),
        if (_extendedProfileData!['isEmailVerified'] == true)
          _buildBadge('Verified', Colors.blue, isTablet),
        if (_userRole == 'faculty' && _extendedProfileData!['canHandleStudents'] == true)
          _buildBadge('Student Manager', const Color(0xFFD4AF37), isTablet),
      ],
    );
  }

  Widget _buildBadge(String label, Color color, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 14 : 12,
        vertical: isTablet ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: isTablet ? 13 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFormSection(bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 20),
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            icon: CupertinoIcons.person_fill,
            label: 'Name',
            hint: 'eg. Happy Mate',
            validator: _validateName,
            isTablet: isTablet,
          ),
          SizedBox(height: isTablet ? 24 : 20),
          _buildTextField(
            controller: _emailController,
            icon: CupertinoIcons.mail_solid,
            label: 'Email',
            hint: 'your@email.com',
            validator: _validateEmail,
            readOnly: true,
            isTablet: isTablet,
          ),
          SizedBox(height: isTablet ? 24 : 20),
          _buildTextField(
            controller: _phoneController,
            icon: CupertinoIcons.phone_fill,
            label: 'Phone',
            hint: 'eg. +1234567890',
            validator: _validatePhone,
            keyboardType: TextInputType.phone,
            isTablet: isTablet,
          ),
          if (_extendedProfileData != null) ...[
            SizedBox(height: isTablet ? 24 : 20),
            _buildReadOnlyInfoCards(isTablet),
          ],
          SizedBox(height: isTablet ? 24 : 20),
          _buildTextField(
            controller: _aboutController,
            icon: CupertinoIcons.info_circle_fill,
            label: 'About',
            hint: 'eg. Feeling Happy',
            validator: _validateAbout,
            maxLines: 3,
            isTablet: isTablet,
          ),
          SizedBox(height: isTablet ? 24 : 20),
          _buildFocusModeToggle(isTablet),
        ],
      ),
    );
  }

  Widget _buildReadOnlyInfoCards(bool isTablet) {
    return Column(
      children: [
        if (_userRole == 'student' || _userRole == 'pending_student') ...[
          _buildInfoCard('USN', _extendedProfileData!['usn'] ?? 'N/A', isTablet),
          if (_extendedProfileData!['universityName'] != null) ...[
            SizedBox(height: isTablet ? 16 : 12),
            _buildInfoCard('University', _extendedProfileData!['universityName'], isTablet),
          ],
          if (_extendedProfileData!['collegeName'] != null) ...[
            SizedBox(height: isTablet ? 16 : 12),
            _buildInfoCard('College', _extendedProfileData!['collegeName'], isTablet),
          ],
          if (_extendedProfileData!['branchName'] != null) ...[
            SizedBox(height: isTablet ? 16 : 12),
            _buildInfoCard('Branch', _extendedProfileData!['branchName'], isTablet),
          ],
        ] else if (_userRole == 'faculty' || _userRole == 'hod' || _userRole == 'college_staff') ...[
          if (_extendedProfileData!['collegeName'] != null)
            _buildInfoCard('College', _extendedProfileData!['collegeName'], isTablet),
          if (_extendedProfileData!['courseName'] != null) ...[
            SizedBox(height: isTablet ? 16 : 12),
            _buildInfoCard('Course', _extendedProfileData!['courseName'], isTablet),
          ],
          if (_extendedProfileData!['branchName'] != null) ...[
            SizedBox(height: isTablet ? 16 : 12),
            _buildInfoCard('Department', _extendedProfileData!['branchName'], isTablet),
          ],
        ],
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 18 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE1E8ED),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 13 : 12,
                    color: const Color(0xFF667EEA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 15,
                    color: const Color(0xFF2D3436),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline,
            color: const Color(0xFF636E72),
            size: isTablet ? 22 : 20,
          ),
        ],
      ),
    );
  }

  Widget _buildFocusModeToggle(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 16 : 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.highlight,
                    color: const Color(0xFFFF6B6B),
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus Mode',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2D3436),
                        ),
                      ),
                      Text(
                        'Let others know you\'re concentrating',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 13 : 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF636E72),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Switch.adaptive(
            value: APIs.me.isFocusMode,
            onChanged: (val) async {
              setState(() => APIs.me.isFocusMode = val);
              await APIs.toggleFocusMode(val);
              Dialogs.showSnackbar(
                context,
                val ? 'Focus Mode ON - No distractions!' : 'Focus Mode OFF',
              );
            },
            activeColor: const Color(0xFFFF6B6B),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    bool readOnly = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    required bool isTablet,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.inter(
          fontSize: isTablet ? 16 : 15,
          color: const Color(0xFF2D3436),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          prefixIcon: Container(
            padding: EdgeInsets.all(isTablet ? 16 : 14),
            child: Icon(
              icon,
              color: readOnly ? const Color(0xFF636E72) : const Color(0xFF667EEA),
              size: isTablet ? 24 : 22,
            ),
          ),
          suffixIcon: readOnly
              ? Icon(
                  Icons.lock_outline,
                  color: const Color(0xFF636E72),
                  size: isTablet ? 22 : 20,
                )
              : null,
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFFB2BEC3),
            fontSize: isTablet ? 16 : 15,
            fontWeight: FontWeight.w400,
          ),
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: const Color(0xFF667EEA),
            fontSize: isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: readOnly 
              ? const Color(0xFFF8F9FD).withOpacity(0.5)
              : const Color(0xFFF8F9FD),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: Color(0xFFE1E8ED),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: Color(0xFF667EEA),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1.5,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 20,
            vertical: isTablet ? 20 : 18,
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton(bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 20),
      child: Container(
        width: double.infinity,
        height: isTablet ? 60 : 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _handleUpdate,
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: isTablet ? 28 : 24,
                        ),
                        SizedBox(width: isTablet ? 14 : 12),
                        Text(
                          'UPDATE PROFILE',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) {
      Dialogs.showSnackbar(context, 'Please fix all errors before updating');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update ChatUser model
      APIs.me.name = _nameController.text.trim();
      APIs.me.email = _emailController.text.trim();
      APIs.me.phone = _phoneController.text.trim();
      APIs.me.about = _aboutController.text.trim();

      // Update in Firebase
      await APIs.updateUserInfo();

      // Update profile image if changed
      if (_image != null) {
        await APIs.updateProfilePicture(File(_image!));
      }

      // Update extended profile if exists
      if (_extendedProfileData != null && _userRole != null) {
        await _updateExtendedProfile();
      }

      if (mounted) {
        Dialogs.showSnackbar(context, 'Profile Updated Successfully!');
      }
    } catch (e) {
      log('Error updating profile: $e');
      if (mounted) {
        Dialogs.showSnackbar(context, 'Failed to update profile. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateExtendedProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String collection;
    switch (_userRole) {
      case 'student':
        collection = 'students';
        break;
      case 'pending_student':
        collection = 'pending_students';
        break;
      case 'faculty':
        collection = 'faculty';
        break;
      case 'hod':
        collection = 'department_head';
        break;
      case 'college_staff':
        collection = 'college_staff';
        break;
      default:
        return;
    }

    Map<String, dynamic> updateData = {
      'phone': _phoneController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Add name field based on role
    if (_userRole == 'student' || _userRole == 'pending_student') {
      final nameParts = _nameController.text.trim().split(' ');
      updateData['firstName'] = nameParts.first;
      updateData['lastName'] = nameParts.length > 1 
          ? nameParts.sublist(1).join(' ') 
          : '';
      updateData['fullName'] = _nameController.text.trim();
    } else {
      updateData['name'] = _nameController.text.trim();
    }

    // Update profile image URL if changed
    if (_image != null && _extendedProfileData?['profileImageUrl'] != null) {
      // Image URL will be updated by APIs.updateProfilePicture
      // We can fetch the updated URL from storage if needed
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(collection)
        .collection('data')
        .doc(user.uid)
        .update(updateData);
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth > 600;
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: isTablet ? 20 : 16),
                  Container(
                    width: isTablet ? 50 : 40,
                    height: isTablet ? 5 : 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1E8ED),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: isTablet ? 28 : 24),
                  Text(
                    'Pick Profile Picture',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 22 : 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2D3436),
                    ),
                  ),
                  SizedBox(height: isTablet ? 36 : 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPickerOption(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        color: const Color(0xFF667EEA),
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          if (image != null) {
                            log('Image Path: ${image.path}');
                            setState(() {
                              _image = image.path;
                            });
                            if (mounted) Navigator.pop(context);
                          }
                        },
                        isTablet: isTablet,
                      ),
                      _buildPickerOption(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        color: const Color(0xFF764BA2),
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 80,
                          );
                          if (image != null) {
                            log('Image Path: ${image.path}');
                            setState(() {
                              _image = image.path;
                            });
                            if (mounted) Navigator.pop(context);
                          }
                        },
                        isTablet: isTablet,
                      ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 48 : 40),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    final size = isTablet ? 90.0 : 80.0;
    final iconSize = isTablet ? 36.0 : 32.0;
    
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(size / 2),
              child: Center(
                child: Icon(
                  icon,
                  color: color,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: isTablet ? 14 : 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF636E72),
          ),
        ),
      ],
    );
  }
}