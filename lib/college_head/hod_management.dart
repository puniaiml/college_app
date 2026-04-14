import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shiksha_hub/auth/email_service.dart';

class HODManagementPage extends StatefulWidget {
  const HODManagementPage({super.key});

  @override
  _HODManagementPageState createState() => _HODManagementPageState();
}

class _HODManagementPageState extends State<HODManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _selectedCourseId;
  String? _selectedBranchId;
  Map<String, dynamic>? _staffData;
  String? _universityId;
  String? _universityName;
  String? _collegeId;
  String? _collegeName;
  String _searchQuery = '';

  final Map<String, String> _courseNames = {};
  final Map<String, String> _branchNames = {};

  @override
  void initState() {
    super.initState();
    _loadStaffData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1200;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1200;

  Future<void> _loadStaffData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot staffDoc = await _firestore
          .collection('users/college_staff/data')
          .doc(user.uid)
          .get();

      if (staffDoc.exists) {
        _staffData = staffDoc.data() as Map<String, dynamic>;
        _universityId = _staffData!['universityId'];
        _universityName = _staffData!['universityName'];
        _collegeId = _staffData!['collegeId'];
        _collegeName = _staffData!['collegeName'];

        await _loadCoursesAndBranches();
        if (mounted) setState(() {});
      }
    } catch (e) {
      _showSnackBar('Error loading staff data: $e', isError: true);
    }
  }

  Future<void> _loadCoursesAndBranches() async {
    try {
      if (_collegeId != null) {
        final coursesSnapshot = await _firestore
            .collection('courses')
            .where('collegeId', isEqualTo: _collegeId)
            .get();

        for (var doc in coursesSnapshot.docs) {
          _courseNames[doc.id] = doc.data()['name']?.toString() ?? 'Unknown Course';
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      _showSnackBar('Error loading courses: $e', isError: true);
    }
  }

  Future<void> _loadBranches() async {
    if (_selectedCourseId == null) return;

    try {
      final branchesSnapshot = await _firestore
          .collection('branches')
          .where('courseId', isEqualTo: _selectedCourseId)
          .get();

      _branchNames.clear();
      for (var doc in branchesSnapshot.docs) {
        _branchNames[doc.id] = doc.data()['name']?.toString() ?? 'Unknown Branch';
      }

      if (mounted) {
        setState(() {
          _selectedBranchId = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error loading branches: $e', isError: true);
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter HOD name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter email address';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter phone number';
    }
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter password';
    }
    if (value.trim().length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateCourse(String? value) {
    if (value == null) {
      return 'Please select a course';
    }
    return null;
  }

  String? _validateBranch(String? value) {
    if (value == null) {
      return 'Please select a branch';
    }
    return null;
  }

  Future<void> _createHOD() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseId == null || _selectedBranchId == null) {
      _showSnackBar('Please select both course and branch', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emailCheckFutures = [
        _firestore.collection('users/department_head/data').where('email', isEqualTo: _emailController.text.trim()).get(),
        _firestore.collection('users/faculty/data').where('email', isEqualTo: _emailController.text.trim()).get(),
        _firestore.collection('users/college_staff/data').where('email', isEqualTo: _emailController.text.trim()).get(),
        _firestore.collection('users/students/data').where('email', isEqualTo: _emailController.text.trim()).get(),
        _firestore.collection('users/admin/data').where('email', isEqualTo: _emailController.text.trim()).get(),
      ];

      final emailResults = await Future.wait(emailCheckFutures);
      if (emailResults.any((result) => result.docs.isNotEmpty)) {
        _showSnackBar('A user with this email already exists', isError: true);
        return;
      }

      UserCredential hodCredential;
      try {
        hodCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          _showSnackBar('Password is too weak', isError: true);
        } else if (e.code == 'email-already-in-use') {
          _showSnackBar('Email is already registered', isError: true);
        } else {
          _showSnackBar('Failed to create account: ${e.message}', isError: true);
        }
        return;
      } catch (e) {
        _showSnackBar('Failed to create user account: ${e.toString()}', isError: true);
        return;
      }

      final hodUser = hodCredential.user;
      if (hodUser == null) {
        _showSnackBar('Failed to create user account', isError: true);
        return;
      }

      final otp = (Random().nextInt(900000) + 100000).toString();
      final email = _emailController.text.trim();

      final emailService = EmailService();
      final otpSent = await EmailService.sendOtpEmail(email, otp);
      if (!otpSent) {
        _showSnackBar('Failed to send OTP email. Please try again.', isError: true);
        return;
      }

      final hodData = {
        'uid': hodUser.uid,
        'name': _nameController.text.trim(),
        'email': email,
        'phone': _phoneController.text.trim(),
        'universityId': _universityId,
        'collegeId': _collegeId,
        'courseId': _selectedCourseId,
        'branchId': _selectedBranchId,
        'universityName': _universityName,
        'collegeName': _collegeName,
        'courseName': _courseNames[_selectedCourseId],
        'branchName': _branchNames[_selectedBranchId],
        'role': 'HOD',
        'userType': 'department_head',
        'isActive': false,
        'hasTemporaryPassword': false,
        'isEmailVerified': false,
        'accountStatus': 'pending_verification',
        'verificationOtp': otp,
        'otpCreatedAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
        'createdByName': _staffData?['name'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users/department_head/data').doc(hodUser.uid).set(hodData);
      await _firestore.collection('user_metadata').doc(hodUser.uid).set({
        'uid': hodUser.uid,
        'email': _emailController.text.trim(),
        'userType': 'department_head',
        'accountStatus': 'pending_verification',
        'dataLocation': 'users/department_head/data/${hodUser.uid}',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSuccessDialog();
      _clearForm();
    } catch (e) {
      _showSnackBar('Failed to create HOD: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: _isMobile ? double.infinity : 500,
          constraints: BoxConstraints(maxWidth: _isMobile ? 350 : 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(Icons.check_circle, color: Colors.green, size: 50),
              ),
              const SizedBox(height: 20),
              Text(
                'HOD Created Successfully!',
                style: TextStyle(
                  fontSize: _isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'HOD account has been created for ${_nameController.text}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Account Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Email: ${_emailController.text}\nRole: HOD\nCourse: ${_courseNames[_selectedCourseId]}\nBranch: ${_branchNames[_selectedBranchId]}',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mail_outline, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Next Steps',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The HOD will receive an email verification link. They need to verify their email to activate the account.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteHOD(String hodId, String hodName, String email) async {
    final confirm = await _showConfirmationDialog(
      'Delete HOD',
      'Are you sure you want to delete "$hodName"?\nThis will permanently remove their access.',
      isDangerous: true,
    );
    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('users/department_head/data').doc(hodId).delete();
      await _firestore.collection('user_metadata').doc(hodId).delete();
      _showSnackBar('HOD deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete HOD: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHODStatus(String hodId, bool currentStatus) async {
    setState(() => _isLoading = true);

    try {
      await _firestore.collection('users/department_head/data').doc(hodId).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('user_metadata').doc(hodId).update({
        'accountStatus': !currentStatus ? 'active' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('HOD status updated successfully');
    } catch (e) {
      _showSnackBar('Failed to update HOD status: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content, {bool isDangerous = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: _isMobile ? double.infinity : 400,
              constraints: BoxConstraints(maxWidth: _isMobile ? 350 : 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDangerous ? Colors.red.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      isDangerous ? Icons.warning : Icons.help_outline,
                      color: isDangerous ? Colors.red : Colors.orange,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: _isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDangerous ? Colors.red : Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(isDangerous ? 'Delete' : 'Confirm'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ?? false;
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    setState(() {
      _selectedCourseId = null;
      _selectedBranchId = null;
    });
    _formKey.currentState?.reset();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildCreateHODForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2)
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_isMobile ? 16 : 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                icon: Icons.person_add,
                title: 'Create New HOD',
                subtitle: 'Add a new Head of Department to your college',
                color: Colors.purple,
              ),
              const SizedBox(height: 24),
              
              _buildInfoCard(),
              const SizedBox(height: 24),

              _buildFormFields(),

              const SizedBox(height: 32),

              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: _isMobile ? 24 : 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: _isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: _isMobile ? 13 : 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Creating HOD For',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'University: $_universityName\nCollege: $_collegeName',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        if (_isDesktop) ...[
          Row(
            children: [
              Expanded(child: _buildCourseDropdown()),
              const SizedBox(width: 16),
              Expanded(child: _buildBranchDropdown()),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildNameField()),
              const SizedBox(width: 16),
              Expanded(child: _buildEmailField()),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildPhoneField()),
              const SizedBox(width: 16),
              Expanded(child: _buildPasswordField()),
            ],
          ),
        ] else if (_isTablet) ...[
          Row(
            children: [
              Expanded(child: _buildCourseDropdown()),
              const SizedBox(width: 16),
              Expanded(child: _buildBranchDropdown()),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildNameField()),
              const SizedBox(width: 16),
              Expanded(child: _buildEmailField()),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildPhoneField()),
              const SizedBox(width: 16),
              Expanded(child: _buildPasswordField()),
            ],
          ),
        ] else ...[
          _buildCourseDropdown(),
          const SizedBox(height: 20),
          _buildBranchDropdown(),
          const SizedBox(height: 20),
          _buildNameField(),
          const SizedBox(height: 20),
          _buildEmailField(),
          const SizedBox(height: 20),
          _buildPhoneField(),
          const SizedBox(height: 20),
          _buildPasswordField(),
        ],
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createHOD,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple.shade600,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: _isMobile ? 14 : 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                'Create HOD Account',
                style: TextStyle(
                  fontSize: _isMobile ? 15 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildCourseDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCourseId,
      decoration: _getDropdownDecoration('Select Course', Icons.menu_book, Colors.purple),
      validator: _validateCourse,
      items: _courseNames.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCourseId = value;
          _selectedBranchId = null;
        });
        if (value != null) _loadBranches();
      },
    );
  }

  Widget _buildBranchDropdown() {
    return IgnorePointer(
      ignoring: _selectedCourseId == null,
      child: DropdownButtonFormField<String>(
        value: _selectedBranchId,
        decoration: _getDropdownDecoration(
          _selectedCourseId == null ? 'Select Course First' : 'Select Branch',
          Icons.account_tree,
          Colors.purple,
        ),
        validator: _validateBranch,
        items: _selectedCourseId == null ? [] : _branchNames.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        onChanged: _selectedCourseId == null ? null : (value) => setState(() => _selectedBranchId = value),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      validator: _validateName,
      decoration: _getInputDecoration('HOD Full Name', Icons.person, Colors.purple),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      validator: _validateEmail,
      decoration: _getInputDecoration('HOD Email', Icons.email, Colors.purple),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      validator: _validatePhone,
      decoration: _getInputDecoration('HOD Phone Number', Icons.phone, Colors.purple),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      validator: _validatePassword,
      decoration: _getInputDecoration(
        'HOD Password',
        Icons.lock,
        Colors.purple,
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.grey.shade600),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  InputDecoration _getInputDecoration(String labelText, IconData prefixIcon, Color color, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.grey.shade600),
      prefixIcon: Icon(prefixIcon, color: color),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  InputDecoration _getDropdownDecoration(String labelText, IconData prefixIcon, Color color) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.grey.shade600),
      prefixIcon: Icon(prefixIcon, color: color),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildHODList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2)
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.people,
              title: 'HOD Directory',
              subtitle: 'Manage Heads of Department',
              color: Colors.indigo,
            ),
            const SizedBox(height: 24),
            
            _buildSearchField(),
            const SizedBox(height: 24),

            Expanded(
              child: _buildHODListContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search HODs',
        hintText: 'Search by name, email, or branch...',
        prefixIcon: Icon(Icons.search, color: Colors.purple.shade600),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildHODListContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users/department_head/data').where('collegeId', isEqualTo: _collegeId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final hodList = snapshot.data!.docs;
        final filteredHODs = _filterHODList(hodList);

        if (filteredHODs.isEmpty) {
          return _buildNoResultsState();
        }

        return _buildHODListView(filteredHODs);
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.purple.shade600,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading HODs...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading HODs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 20),
                Text(
                  'No HODs Yet',
                  style: TextStyle(
                    fontSize: _isMobile ? 18 : 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first HOD using the form above',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Results Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your search terms',
                  style: TextStyle(color: Colors.orange.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterHODList(List<QueryDocumentSnapshot> hodList) {
    return hodList.where((hod) {
      if (_searchQuery.isEmpty) return true;
      
      final data = hod.data() as Map<String, dynamic>;
      final search = _searchQuery.toLowerCase();
      final searchableFields = [
        data['name']?.toString().toLowerCase() ?? '',
        data['email']?.toString().toLowerCase() ?? '',
        data['branchName']?.toString().toLowerCase() ?? '',
        data['courseName']?.toString().toLowerCase() ?? '',
      ];
      
      return searchableFields.any((field) => field.contains(search));
    }).toList();
  }

  Widget _buildHODListView(List<QueryDocumentSnapshot> filteredHODs) {
    return ListView.separated(
      itemCount: filteredHODs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (context, index) {
        final hod = filteredHODs[index].data() as Map<String, dynamic>;
        final hodId = filteredHODs[index].id;
        final isActive = hod['isActive'] ?? true;
        final isEmailVerified = hod['isEmailVerified'] ?? false;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? Colors.green.shade200 : Colors.red.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2)
              )
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(_isMobile ? 12 : 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: _isMobile ? 48 : 56,
                      height: _isMobile ? 48 : 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isActive
                              ? [Colors.purple.shade400, Colors.purple.shade600]
                              : [Colors.red.shade400, Colors.red.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(_isMobile ? 24 : 28),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  hod['name']?.toString() ?? 'Unknown Name',
                                  style: TextStyle(
                                    fontSize: _isMobile ? 16 : 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildRoleBadge(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hod['email']?.toString() ?? 'No email',
                            style: TextStyle(
                              fontSize: _isMobile ? 13 : 14,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildStatusBadge(isActive ? 'Active' : 'Inactive', isActive),
                              const SizedBox(width: 8),
                              _buildVerificationBadge(isEmailVerified),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(
                          icon: isActive ? Icons.pause : Icons.play_arrow,
                          color: isActive ? Colors.orange : Colors.green,
                          tooltip: isActive ? 'Deactivate' : 'Activate',
                          onPressed: () => _toggleHODStatus(hodId, isActive),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.delete_outline,
                          color: Colors.red,
                          tooltip: 'Delete HOD',
                          onPressed: () => _deleteHOD(
                            hodId,
                            hod['name']?.toString() ?? 'Unknown',
                            hod['email']?.toString() ?? '',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildHODDetails(hod),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 1.5),
      ),
      child: const Text(
        'HOD',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? Colors.green : Colors.red),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isActive ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isVerified ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isVerified ? Colors.blue : Colors.orange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.mail_outline,
            size: 12,
            color: isVerified ? Colors.blue.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isVerified ? 'Verified' : 'Unverified',
            style: TextStyle(
              color: isVerified ? Colors.blue.shade700 : Colors.orange.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: _isMobile ? 18 : 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildHODDetails(Map<String, dynamic> hod) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 400;
          if (isWide) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildDetailItem(Icons.menu_book, 'Course', hod['courseName']?.toString() ?? 'Unknown Course'),
                      const SizedBox(height: 12),
                      _buildDetailItem(Icons.phone, 'Phone', hod['phone']?.toString() ?? 'No phone'),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _buildDetailItem(Icons.account_tree, 'Branch', hod['branchName']?.toString() ?? 'Unknown Branch'),
                      const SizedBox(height: 12),
                      _buildDetailItem(Icons.person, 'Created By', hod['createdByName']?.toString() ?? 'System'),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                _buildDetailItem(Icons.menu_book, 'Course', hod['courseName']?.toString() ?? 'Unknown Course'),
                const SizedBox(height: 12),
                _buildDetailItem(Icons.account_tree, 'Branch', hod['branchName']?.toString() ?? 'Unknown Branch'),
                const SizedBox(height: 12),
                _buildDetailItem(Icons.phone, 'Phone', hod['phone']?.toString() ?? 'No phone'),
                const SizedBox(height: 12),
                _buildDetailItem(Icons.person, 'Created By', hod['createdByName']?.toString() ?? 'System'),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: Colors.purple.shade700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_staffData == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text(
            'HOD Management',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.purple.shade600,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.purple.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'Loading college information...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'HOD Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade600, Colors.purple.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _buildResponsiveLayout(),
    );
  }

  Widget _buildResponsiveLayout() {
    if (_isDesktop) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildCreateHODForm()),
            const SizedBox(width: 24),
            Expanded(flex: 3, child: _buildHODList()),
          ],
        ),
      );
    } else if (_isTablet) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCreateHODForm(),
            const SizedBox(height: 20),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildHODList(),
            ),
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCreateHODForm(),
            const SizedBox(height: 20),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildHODList(),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}