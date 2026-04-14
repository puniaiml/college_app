import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FacultyManagementPage extends StatefulWidget {
  const FacultyManagementPage({super.key});

  @override
  _FacultyManagementPageState createState() => _FacultyManagementPageState();
}

class _FacultyManagementPageState extends State<FacultyManagementPage> {
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
  String? _selectedRole;
  String? _selectedFilterBranchId;
  String _searchQuery = '';
  
  final Set<String> _expandedCards = <String>{};
  
  Map<String, dynamic>? _staffData;
  String? _universityId;
  String? _universityName;
  String? _collegeId;
  String? _collegeName;

  final Map<String, String> _courseNames = {};
  final Map<String, String> _branchNames = {};

  final List<String> _facultyRoles = [
    'Assistant Professor',
    'Associate Professor',
    'Teaching Staff',
  ];

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
      return 'Please enter faculty name';
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

  String? _validateRole(String? value) {
    if (value == null) {
      return 'Please select a role';
    }
    return null;
  }

  Future<void> _createFaculty() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseId == null || _selectedBranchId == null || _selectedRole == null) {
      _showSnackBar('Please fill in all fields and make all selections', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emailCheckFutures = [
        _firestore.collection('users/faculty/data').where('email', isEqualTo: _emailController.text.trim()).get(),
        _firestore.collection('users/college_staff/data').where('email', isEqualTo: _emailController.text.trim()).get(),
        _firestore.collection('users/students/data').where('email', isEqualTo: _emailController.text.trim()).get(),
        _firestore.collection('users/admin/data').where('email', isEqualTo: _emailController.text.trim()).get(),
      ];

      final emailResults = await Future.wait(emailCheckFutures);
      final emailExists = emailResults.any((result) => result.docs.isNotEmpty);

      if (emailExists) {
        _showSnackBar('A user with this email already exists', isError: true);
        return;
      }

      UserCredential facultyCredential;

      try {
        facultyCredential = await _auth.createUserWithEmailAndPassword(
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

      final facultyUser = facultyCredential.user;
      if (facultyUser == null) {
        _showSnackBar('Failed to create user account', isError: true);
        return;
      }

      await facultyUser.sendEmailVerification();

      final facultyData = {
        'uid': facultyUser.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'universityId': _universityId,
        'collegeId': _collegeId,
        'courseId': _selectedCourseId,
        'branchId': _selectedBranchId,
        'universityName': _universityName,
        'collegeName': _collegeName,
        'courseName': _courseNames[_selectedCourseId],
        'branchName': _branchNames[_selectedBranchId],
        'role': _selectedRole,
        'userType': 'faculty',
        'isActive': true,
        'hasTemporaryPassword': false,
        'isEmailVerified': false,
        'accountStatus': 'pending_verification',
        'createdBy': _auth.currentUser?.uid,
        'createdByName': _staffData?['name'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users/faculty/data').doc(facultyUser.uid).set(facultyData);

      await _firestore.collection('user_metadata').doc(facultyUser.uid).set({
        'uid': facultyUser.uid,
        'email': _emailController.text.trim(),
        'userType': 'faculty',
        'accountStatus': 'pending_verification',
        'dataLocation': 'users/faculty/data/${facultyUser.uid}',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSuccessDialog();
      _clearForm();
    } catch (e) {
      _showSnackBar('Failed to create faculty: ${e.toString()}', isError: true);
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
                'Faculty Created Successfully!',
                style: TextStyle(
                  fontSize: _isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Faculty account has been created for ${_nameController.text}',
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
                      'Email: ${_emailController.text}\n'
                      'Role: $_selectedRole\n'
                      'Course: ${_courseNames[_selectedCourseId]}\n'
                      'Branch: ${_branchNames[_selectedBranchId]}',
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
                      'The faculty member will receive an email verification link. They need to verify their email to activate the account.',
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

  Future<void> _deleteFaculty(String facultyId, String facultyName, String email) async {
    final confirm = await _showConfirmationDialog(
      'Delete Faculty Member',
      'Are you sure you want to delete "$facultyName"?\nThis will permanently remove their access.',
      isDangerous: true,
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('users/faculty/data').doc(facultyId).delete();
      await _firestore.collection('user_metadata').doc(facultyId).delete();
      _showSnackBar('Faculty deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete faculty: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFacultyStatus(String facultyId, bool currentStatus) async {
    setState(() => _isLoading = true);

    try {
      await _firestore.collection('users/faculty/data').doc(facultyId).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('user_metadata').doc(facultyId).update({
        'accountStatus': !currentStatus ? 'active' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Faculty status updated successfully');
    } catch (e) {
      _showSnackBar('Failed to update faculty status: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      _selectedRole = null;
    });
    _formKey.currentState?.reset();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 3),
        margin: EdgeInsets.all(_isMobile ? 12 : 16),
      ),
    );
  }

  Widget _buildCreateFacultyForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(_isMobile ? 16 : 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                icon: Icons.person_add,
                title: 'Create New Faculty Member',
                subtitle: 'Add a new faculty member to your college',
                color: Colors.indigo,
              ),
              const SizedBox(height: 20),
              
              _buildInfoCard(),
              const SizedBox(height: 20),

              _buildFormFields(),

              const SizedBox(height: 24),

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
        borderRadius: BorderRadius.circular(16),
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
                'Creating Faculty For',
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
          const SizedBox(height: 16),
          _buildRoleDropdown(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildNameField()),
              const SizedBox(width: 16),
              Expanded(child: _buildEmailField()),
            ],
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          _buildRoleDropdown(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildNameField()),
              const SizedBox(width: 16),
              Expanded(child: _buildEmailField()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildPhoneField()),
              const SizedBox(width: 16),
              Expanded(child: _buildPasswordField()),
            ],
          ),
        ] else ...[
          _buildCourseDropdown(),
          const SizedBox(height: 16),
          _buildBranchDropdown(),
          const SizedBox(height: 16),
          _buildRoleDropdown(),
          const SizedBox(height: 16),
          _buildNameField(),
          const SizedBox(height: 16),
          _buildEmailField(),
          const SizedBox(height: 16),
          _buildPhoneField(),
          const SizedBox(height: 16),
          _buildPasswordField(),
        ],
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createFaculty,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo.shade600,
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
                'Create Faculty Account',
                style: TextStyle(
                  fontSize: _isMobile ? 15 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(prefixIcon, color: Colors.indigo.shade600),
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
          borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
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
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required String labelText,
    required IconData prefixIcon,
    required String? Function(T?)? validator,
    required void Function(T?) onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(prefixIcon, color: Colors.indigo.shade600),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
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
          borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
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
      ),
    );
  }

  Widget _buildCourseDropdown() {
    return _buildDropdownField<String>(
      value: _selectedCourseId,
      items: _courseNames.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      labelText: 'Select Course',
      prefixIcon: Icons.menu_book,
      validator: _validateCourse,
      onChanged: (value) {
        setState(() {
          _selectedCourseId = value;
          _selectedBranchId = null;
        });
        if (value != null) {
          _loadBranches();
        }
      },
    );
  }

  Widget _buildBranchDropdown() {
    return _buildDropdownField<String>(
      value: _selectedBranchId,
      items: _branchNames.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      labelText: _selectedCourseId == null ? 'Select Course First' : 'Select Branch',
      prefixIcon: Icons.account_tree,
      validator: _validateBranch,
      enabled: _selectedCourseId != null,
      onChanged: (value) {
        setState(() {
          _selectedBranchId = value;
        });
      },
    );
  }

  Widget _buildRoleDropdown() {
    return _buildDropdownField<String>(
      value: _selectedRole,
      items: _facultyRoles.map((role) {
        return DropdownMenuItem<String>(
          value: role,
          child: Text(role),
        );
      }).toList(),
      labelText: 'Select Role',
      prefixIcon: Icons.work,
      validator: _validateRole,
      onChanged: (value) {
        setState(() {
          _selectedRole = value;
        });
      },
    );
  }

  Widget _buildNameField() {
    return _buildInputField(
      controller: _nameController,
      labelText: 'Faculty Full Name',
      prefixIcon: Icons.person,
      validator: _validateName,
    );
  }

  Widget _buildEmailField() {
    return _buildInputField(
      controller: _emailController,
      labelText: 'Faculty Email',
      prefixIcon: Icons.email,
      keyboardType: TextInputType.emailAddress,
      validator: _validateEmail,
    );
  }

  Widget _buildPhoneField() {
    return _buildInputField(
      controller: _phoneController,
      labelText: 'Faculty Phone Number',
      prefixIcon: Icons.phone,
      keyboardType: TextInputType.phone,
      validator: _validatePhone,
    );
  }

  Widget _buildPasswordField() {
    return _buildInputField(
      controller: _passwordController,
      labelText: 'Faculty Password',
      prefixIcon: Icons.lock,
      obscureText: _obscurePassword,
      validator: _validatePassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey.shade600,
        ),
        onPressed: () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        },
      ),
    );
  }

  Widget _buildFacultyList() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(_isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.people,
              title: 'Faculty Directory',
              subtitle: 'Manage faculty members',
              color: Colors.teal,
            ),
            const SizedBox(height: 20),

            _buildSearchAndFilter(),
            const SizedBox(height: 20),

            Expanded(
              child: _buildFacultyListContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        _buildSearchField(),
        if (!_isMobile) const SizedBox(height: 16),
        if (!_isMobile)
          Row(
            children: [
              Expanded(child: _buildBranchFilterDropdown()),
            ],
          )
        else ...[
          const SizedBox(height: 16),
          _buildBranchFilterDropdown(),
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search Faculty Members',
        hintText: 'Search by name, email, or role...',
        prefixIcon: Icon(Icons.search, color: Colors.indigo.shade600),
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
          borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
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

  Widget _buildBranchFilterDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFilterBranchId,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All Branches', style: TextStyle(color: Colors.grey)),
        ),
        ..._branchNames.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedFilterBranchId = value;
        });
      },
      isExpanded: true,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: 'Filter by Branch',
        prefixIcon: Icon(Icons.filter_alt, color: Colors.indigo.shade600),
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
          borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildFacultyListContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users/faculty/data')
          .where('collegeId', isEqualTo: _collegeId)
          .snapshots(),
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

        final facultyList = snapshot.data!.docs;
        final filteredFaculty = _filterFacultyList(facultyList);

        if (filteredFaculty.isEmpty) {
          return _buildNoResultsState();
        }

        return _buildFacultyListView(filteredFaculty);
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.teal.shade600,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading faculty members...',
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
            'Error loading faculty',
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
                  'No Faculty Members Yet',
                  style: TextStyle(
                    fontSize: _isMobile ? 18 : 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first faculty member using the form above',
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
                  'Try adjusting your filters or search terms',
                  style: TextStyle(color: Colors.orange.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterFacultyList(List<QueryDocumentSnapshot> facultyList) {
    return facultyList.where((faculty) {
      final data = faculty.data() as Map<String, dynamic>;
      
      if (_selectedFilterBranchId != null && 
          data['branchId'] != _selectedFilterBranchId) {
        return false;
      }
      
      if (_searchQuery.isNotEmpty) {
        final search = _searchQuery.toLowerCase();
        final searchableFields = [
          data['name']?.toString().toLowerCase() ?? '',
          data['email']?.toString().toLowerCase() ?? '',
          data['role']?.toString().toLowerCase() ?? '',
          data['branchName']?.toString().toLowerCase() ?? '',
          data['courseName']?.toString().toLowerCase() ?? '',
        ];
        
        return searchableFields.any((field) => field.contains(search));
      }
      
      return true;
    }).toList();
  }

  Widget _buildFacultyListView(List<QueryDocumentSnapshot> filteredFaculty) {
    return ListView.separated(
      itemCount: filteredFaculty.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (context, index) {
        final faculty = filteredFaculty[index].data() as Map<String, dynamic>;
        final facultyId = filteredFaculty[index].id;
        return _buildCompactFacultyCard(faculty, facultyId);
      },
    );
  }

  Widget _buildCompactFacultyCard(Map<String, dynamic> faculty, String facultyId) {
    final isActive = faculty['isActive'] ?? true;
    final isEmailVerified = faculty['isEmailVerified'] ?? false;
    final isExpanded = _expandedCards.contains(facultyId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.green.shade200 : Colors.red.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCards.remove(facultyId);
                } else {
                  _expandedCards.add(facultyId);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(_isMobile ? 12 : 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isActive
                            ? [Colors.teal.shade400, Colors.teal.shade600]
                            : [Colors.red.shade400, Colors.red.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                faculty['name']?.toString() ?? 'Unknown Name',
                                style: TextStyle(
                                  fontSize: _isMobile ? 15 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildCompactRoleBadge(faculty['role']?.toString()),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          faculty['email']?.toString() ?? 'No email',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildCompactStatusBadge(isActive ? 'Active' : 'Inactive', isActive),
                            const SizedBox(width: 6),
                            _buildCompactVerificationBadge(isEmailVerified),
                            const Spacer(),
                            Text(
                              faculty['branchName']?.toString() ?? 'Unknown Branch',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.expand_more,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedDetails(faculty, facultyId, isActive),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(Map<String, dynamic> faculty, String facultyId, bool isActive) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(_isMobile ? 12 : 16),
        child: Column(
          children: [
            if (_isMobile) ...[
              _buildCompactDetailItem(Icons.menu_book, 'Course', faculty['courseName']?.toString() ?? 'Unknown Course'),
              const SizedBox(height: 8),
              _buildCompactDetailItem(Icons.phone, 'Phone', faculty['phone']?.toString() ?? 'No phone'),
              const SizedBox(height: 8),
              _buildCompactDetailItem(Icons.person, 'Created By', faculty['createdByName']?.toString() ?? 'System'),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildCompactDetailItem(Icons.menu_book, 'Course', faculty['courseName']?.toString() ?? 'Unknown Course'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCompactDetailItem(Icons.phone, 'Phone', faculty['phone']?.toString() ?? 'No phone'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCompactDetailItem(Icons.person, 'Created By', faculty['createdByName']?.toString() ?? 'System'),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildCompactActionButton(
                    icon: isActive ? Icons.pause : Icons.play_arrow,
                    label: isActive ? 'Deactivate' : 'Activate',
                    color: isActive ? Colors.orange : Colors.green,
                    onPressed: () => _toggleFacultyStatus(facultyId, isActive),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactActionButton(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    color: Colors.red,
                    onPressed: () => _deleteFaculty(
                      facultyId,
                      faculty['name']?.toString() ?? 'Unknown',
                      faculty['email']?.toString() ?? '',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactRoleBadge(String? role) {
    final roleColor = _getRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: roleColor, width: 1),
      ),
      child: Text(
        role ?? 'N/A',
        style: TextStyle(
          color: roleColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildCompactStatusBadge(String status, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isActive ? Colors.green : Colors.red, width: 0.8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isActive ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildCompactVerificationBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isVerified ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isVerified ? Colors.blue : Colors.orange, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.mail_outline,
            size: 10,
            color: isVerified ? Colors.blue.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 3),
          Text(
            isVerified ? 'Verified' : 'Unverified',
            style: TextStyle(
              color: isVerified ? Colors.blue.shade700 : Colors.orange.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: Colors.teal.shade700),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
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

  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    if (_staffData == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(
            'Faculty Management',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: _isMobile ? 18 : 20,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade600, Colors.teal.shade600],
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Faculty Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: _isMobile ? 18 : 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade600, Colors.teal.shade600],
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
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildCreateFacultyForm(),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 3,
              child: _buildFacultyList(),
            ),
          ],
        ),
      );
    } else if (_isTablet) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCreateFacultyForm(),
            const SizedBox(height: 24),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildFacultyList(),
            ),
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCreateFacultyForm(),
            const SizedBox(height: 20),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: _buildFacultyList(),
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