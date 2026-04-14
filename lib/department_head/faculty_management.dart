import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FacultyManagementPage extends StatefulWidget {
  const FacultyManagementPage({super.key});

  @override
  _FacultyManagementPageState createState() => _FacultyManagementPageState();
}

class _FacultyManagementPageState extends State<FacultyManagementPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _selectedRole;
  bool _canHandleStudents = false;

  bool _isEditMode = false;
  String? _editingFacultyId;
  String? _editSelectedRole;
  bool _editCanHandleStudents = false;

  Map<String, dynamic>? _hodData;
  String? _universityId;
  String? _universityName;
  String? _collegeId;
  String? _collegeName;
  String? _courseId;
  String? _courseName;
  String? _branchId;
  String? _branchName;

  final Set<String> _expandedFaculty = <String>{};
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _editFormKey = GlobalKey<FormState>();

  final List<String> _facultyRoles = [
    'Assistant Professor',
    'Associate Professor',
    'Professor',
    'Teaching Staff',
    'Guest Faculty',
    'Lab Assistant',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _loadHODData();
    _animationController.forward();
  }

  Future<void> _loadHODData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot hodDoc = await _firestore
          .collection('users/department_head/data')
          .doc(user.uid)
          .get();

      if (hodDoc.exists) {
        _hodData = hodDoc.data() as Map<String, dynamic>;
        _universityId = _hodData!['universityId'];
        _universityName = _hodData!['universityName'];
        _collegeId = _hodData!['collegeId'];
        _collegeName = _hodData!['collegeName'];
        _courseId = _hodData!['courseId'];
        _courseName = _hodData!['courseName'];
        _branchId = _hodData!['branchId'];
        _branchName = _hodData!['branchName'];

        if (mounted) setState(() {});
      }
    } catch (e) {
      _showSnackBar('Error loading HOD data: $e', isError: true);
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
    final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
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

  Future<void> _createFaculty() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      _showSnackBar('Please select a faculty role', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emailCheckFutures = [
        _firestore
            .collection('users/faculty/data')
            .where('email', isEqualTo: _emailController.text.trim())
            .get(),
        _firestore
            .collection('users/college_staff/data')
            .where('email', isEqualTo: _emailController.text.trim())
            .get(),
        _firestore
            .collection('users/students/data')
            .where('email', isEqualTo: _emailController.text.trim())
            .get(),
        _firestore
            .collection('users/department_head/data')
            .where('email', isEqualTo: _emailController.text.trim())
            .get(),
        _firestore
            .collection('users/admin/data')
            .where('email', isEqualTo: _emailController.text.trim())
            .get(),
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
      } catch (e) {
        if (e is FirebaseAuthException) {
          if (e.code == 'weak-password') {
            _showSnackBar('Password is too weak', isError: true);
          } else if (e.code == 'email-already-in-use') {
            _showSnackBar('Email is already registered', isError: true);
          } else {
            _showSnackBar('Failed to create account: ${e.message}', isError: true);
          }
        } else {
          _showSnackBar('Failed to create user account', isError: true);
        }
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
        'courseId': _courseId,
        'branchId': _branchId,
        'universityName': _universityName,
        'collegeName': _collegeName,
        'courseName': _courseName,
        'branchName': _branchName,
        'role': _selectedRole,
        'canHandleStudents': _canHandleStudents,
        'userType': 'faculty',
        'isActive': true,
        'hasTemporaryPassword': false,
        'isEmailVerified': false,
        'accountStatus': 'pending_verification',
        'createdBy': _auth.currentUser?.uid,
        'createdByName': _hodData?['name'],
        'createdByRole': 'HOD',
        'departmentHeadId': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users/faculty/data')
          .doc(facultyUser.uid)
          .set(facultyData);

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

  Future<void> _updateFaculty() async {
    if (!_editFormKey.currentState!.validate()) return;
    if (_editSelectedRole == null) {
      _showSnackBar('Please select a faculty role', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('users/faculty/data')
          .doc(_editingFacultyId)
          .update({
        'name': _editNameController.text.trim(),
        'phone': _editPhoneController.text.trim(),
        'role': _editSelectedRole,
        'canHandleStudents': _editCanHandleStudents,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Faculty updated successfully');
      _cancelEdit();
    } catch (e) {
      _showSnackBar('Failed to update faculty: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEdit(Map<String, dynamic> facultyData, String facultyId) {
    setState(() {
      _isEditMode = true;
      _editingFacultyId = facultyId;
      _editNameController.text = facultyData['name']?.toString() ?? '';
      _editPhoneController.text = facultyData['phone']?.toString() ?? '';
      _editSelectedRole = facultyData['role']?.toString();
      _editCanHandleStudents = facultyData['canHandleStudents'] ?? false;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _editingFacultyId = null;
      _editSelectedRole = null;
      _editCanHandleStudents = false;
    });
    _editNameController.clear();
    _editPhoneController.clear();
  }

  void _toggleExpanded(String facultyId) {
    setState(() {
      if (_expandedFaculty.contains(facultyId)) {
        _expandedFaculty.remove(facultyId);
      } else {
        _expandedFaculty.add(facultyId);
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Faculty Created Successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Faculty account has been created for ${_nameController.text}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Faculty Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Email', _emailController.text),
                    _buildDetailRow('Role', _selectedRole ?? ''),
                    _buildDetailRow('Student Access Control', _canHandleStudents ? 'Yes' : 'No'),
                    _buildDetailRow('Department', _branchName ?? ''),
                    _buildDetailRow('Course', _courseName ?? ''),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mail_outline,
                            color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Next Steps',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The faculty member will receive an email verification link. They need to verify their email to activate the account.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      )
    );
  }

  Future<void> _deleteFaculty(
      String facultyId, String facultyName, String email) async {
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

  Future<void> _toggleFacultyStatus(
      String facultyId, bool currentStatus) async {
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
      _showSnackBar('Failed to update faculty status: ${e.toString()}',
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content,
      {bool isDangerous = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDangerous
                          ? Colors.red.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDangerous ? Icons.warning : Icons.help_outline,
                      color: isDangerous ? Colors.red : Colors.orange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
        ) ??
        false;
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    setState(() {
      _selectedRole = null;
      _canHandleStudents = false;
    });
    _formKey.currentState?.reset();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 3),
        margin: const EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }

  Widget _buildCreateFacultyForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isEditMode 
                            ? [Colors.orange.shade400, Colors.orange.shade600]
                            : [Colors.purple.shade400, Colors.purple.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_isEditMode ? Colors.orange : Colors.purple)
                              .withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isEditMode ? Icons.edit : Icons.person_add,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditMode ? 'Edit Faculty Member' : 'Add Faculty Member',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEditMode 
                              ? 'Update faculty member information'
                              : 'Add a new faculty member to your department',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isEditMode)
                    IconButton(
                      onPressed: _cancelEdit,
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),

              if (!_isEditMode) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade50,
                        Colors.blue.shade100.withOpacity(0.7),
                        Colors.white.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.shade200,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.08),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade600, Colors.blue.shade700],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Department Assignment',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue.shade800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.green.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 12,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Auto-assigned',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Faculty will be automatically assigned to your department with the following details:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoGrid(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_isEditMode) 
                _buildEditForm() 
              else 
                _buildCreateForm(),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading 
                      ? null 
                      : (_isEditMode ? _updateFaculty : _createFaculty),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditMode 
                        ? Colors.orange.shade600
                        : Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    shadowColor: (_isEditMode ? Colors.orange : Colors.purple)
                        .withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isEditMode 
                              ? 'Update Faculty Member'
                              : 'Create Faculty Account',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 400) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildInfoItem('University', _universityName ?? '', Icons.account_balance)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInfoItem('College', _collegeName ?? '', Icons.school)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildInfoItem('Course', _courseName ?? '', Icons.menu_book)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInfoItem('Department', _branchName ?? '', Icons.business)),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _buildInfoItem('University', _universityName ?? '', Icons.account_balance),
              const SizedBox(height: 12),
              _buildInfoItem('College', _collegeName ?? '', Icons.school),
              const SizedBox(height: 12),
              _buildInfoItem('Course', _courseName ?? '', Icons.menu_book),
              const SizedBox(height: 12),
              _buildInfoItem('Department', _branchName ?? '', Icons.business),
            ],
          );
        }
      },
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade300.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade500, Colors.blue.shade600],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
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
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not specified' : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: value.isEmpty ? Colors.grey.shade500 : Colors.black87,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 500;

          if (isWide) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildRoleDropdown()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStudentPermissionToggle()),
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
              ],
            );
          } else {
            return Column(
              children: [
                _buildRoleDropdown(),
                const SizedBox(height: 20),
                _buildStudentPermissionToggle(),
                const SizedBox(height: 20),
                _buildNameField(),
                const SizedBox(height: 20),
                _buildEmailField(),
                const SizedBox(height: 20),
                _buildPhoneField(),
                const SizedBox(height: 20),
                _buildPasswordField(),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _editFormKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 500;

          if (isWide) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildEditRoleDropdown()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildEditStudentPermissionToggle()),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(child: _buildEditNameField()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildEditPhoneField()),
                  ],
                ),
              ],
            );
          } else {
            return Column(
              children: [
                _buildEditRoleDropdown(),
                const SizedBox(height: 20),
                _buildEditStudentPermissionToggle(),
                const SizedBox(height: 20),
                _buildEditNameField(),
                const SizedBox(height: 20),
                _buildEditPhoneField(),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: _getInputDecoration(
        labelText: 'Select Faculty Role',
        prefixIcon: Icons.work,
        color: Colors.purple,
      ),
      validator: (value) => value == null ? 'Please select a role' : null,
      items: _facultyRoles.map((role) {
        return DropdownMenuItem<String>(
          value: role,
          child: Text(role),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedRole = value;
        });
      },
    );
  }

  Widget _buildEditRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _editSelectedRole,
      decoration: _getInputDecoration(
        labelText: 'Select Faculty Role',
        prefixIcon: Icons.work,
        color: Colors.orange,
      ),
      validator: (value) => value == null ? 'Please select a role' : null,
      items: _facultyRoles.map((role) {
        return DropdownMenuItem<String>(
          value: role,
          child: Text(role),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _editSelectedRole = value;
        });
      },
    );
  }

  Widget _buildStudentPermissionToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.purple.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.purple.shade50,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.school, color: Colors.purple.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Student Access Control',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: _canHandleStudents,
            onChanged: (value) {
              setState(() {
                _canHandleStudents = value;
              });
            },
            activeColor: Colors.purple.shade600,
            activeTrackColor: Colors.purple.shade200,
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade200,
          ),
        ],
      ),
    );
  }

  Widget _buildEditStudentPermissionToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.school, color: Colors.orange.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Student Access Control',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: _editCanHandleStudents,
            onChanged: (value) {
              setState(() {
                _editCanHandleStudents = value;
              });
            },
            activeColor: Colors.orange.shade600,
            activeTrackColor: Colors.orange.shade200,
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade200,
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      validator: _validateName,
      decoration: _getInputDecoration(
        labelText: 'Faculty Full Name',
        prefixIcon: Icons.person,
        color: Colors.purple,
      ),
    );
  }

  Widget _buildEditNameField() {
    return TextFormField(
      controller: _editNameController,
      validator: _validateName,
      decoration: _getInputDecoration(
        labelText: 'Faculty Full Name',
        prefixIcon: Icons.person,
        color: Colors.orange,
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      validator: _validateEmail,
      decoration: _getInputDecoration(
        labelText: 'Faculty Email',
        prefixIcon: Icons.email,
        color: Colors.purple,
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      validator: _validatePhone,
      decoration: _getInputDecoration(
        labelText: 'Faculty Phone Number',
        prefixIcon: Icons.phone,
        color: Colors.purple,
      ),
    );
  }

  Widget _buildEditPhoneField() {
    return TextFormField(
      controller: _editPhoneController,
      keyboardType: TextInputType.phone,
      validator: _validatePhone,
      decoration: _getInputDecoration(
        labelText: 'Faculty Phone Number',
        prefixIcon: Icons.phone,
        color: Colors.orange,
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      validator: _validatePassword,
      decoration: _getInputDecoration(
        labelText: 'Faculty Password',
        prefixIcon: Icons.lock,
        color: Colors.purple,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
    );
  }

  Color _getColorShade(Color color, int shade) {
    if (color == Colors.purple) {
      switch (shade) {
        case 100: return Colors.purple.shade100;
        case 200: return Colors.purple.shade200;
        case 300: return Colors.purple.shade300;
        case 400: return Colors.purple.shade400;
        case 500: return Colors.purple.shade500;
        case 600: return Colors.purple.shade600;
        case 700: return Colors.purple.shade700;
        case 800: return Colors.purple.shade800;
        case 900: return Colors.purple.shade900;
        default: return Colors.purple;
      }
    } else if (color == Colors.orange) {
      switch (shade) {
        case 100: return Colors.orange.shade100;
        case 200: return Colors.orange.shade200;
        case 300: return Colors.orange.shade300;
        case 400: return Colors.orange.shade400;
        case 500: return Colors.orange.shade500;
        case 600: return Colors.orange.shade600;
        case 700: return Colors.orange.shade700;
        case 800: return Colors.orange.shade800;
        case 900: return Colors.orange.shade900;
        default: return Colors.orange;
      }
    } else if (color == Colors.blue) {
      switch (shade) {
        case 100: return Colors.blue.shade100;
        case 200: return Colors.blue.shade200;
        case 300: return Colors.blue.shade300;
        case 400: return Colors.blue.shade400;
        case 500: return Colors.blue.shade500;
        case 600: return Colors.blue.shade600;
        case 700: return Colors.blue.shade700;
        case 800: return Colors.blue.shade800;
        case 900: return Colors.blue.shade900;
        default: return Colors.blue;
      }
    } else if (color == Colors.green) {
      switch (shade) {
        case 100: return Colors.green.shade100;
        case 200: return Colors.green.shade200;
        case 300: return Colors.green.shade300;
        case 400: return Colors.green.shade400;
        case 500: return Colors.green.shade500;
        case 600: return Colors.green.shade600;
        case 700: return Colors.green.shade700;
        case 800: return Colors.green.shade800;
        case 900: return Colors.green.shade900;
        default: return Colors.green;
      }
    } else if (color == Colors.red) {
      switch (shade) {
        case 100: return Colors.red.shade100;
        case 200: return Colors.red.shade200;
        case 300: return Colors.red.shade300;
        case 400: return Colors.red.shade400;
        case 500: return Colors.red.shade500;
        case 600: return Colors.red.shade600;
        case 700: return Colors.red.shade700;
        case 800: return Colors.red.shade800;
        case 900: return Colors.red.shade900;
        default: return Colors.red;
      }
    } else if (color == Colors.teal) {
      switch (shade) {
        case 100: return Colors.teal.shade100;
        case 200: return Colors.teal.shade200;
        case 300: return Colors.teal.shade300;
        case 400: return Colors.teal.shade400;
        case 500: return Colors.teal.shade500;
        case 600: return Colors.teal.shade600;
        case 700: return Colors.teal.shade700;
        case 800: return Colors.teal.shade800;
        case 900: return Colors.teal.shade900;
        default: return Colors.teal;
      }
    } else if (color == Colors.indigo) {
      switch (shade) {
        case 100: return Colors.indigo.shade100;
        case 200: return Colors.indigo.shade200;
        case 300: return Colors.indigo.shade300;
        case 400: return Colors.indigo.shade400;
        case 500: return Colors.indigo.shade500;
        case 600: return Colors.indigo.shade600;
        case 700: return Colors.indigo.shade700;
        case 800: return Colors.indigo.shade800;
        case 900: return Colors.indigo.shade900;
        default: return Colors.indigo;
      }
    } else {
      return Color.fromRGBO(
        (color.red * 0.7).round(),
        (color.green * 0.7).round(),
        (color.blue * 0.7).round(),
        1.0,
      );
    }
  }

  InputDecoration _getInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    required Color color,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.grey.shade700),
      prefixIcon: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(prefixIcon, color: _getColorShade(color, 700), size: 20),
      ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _getColorShade(color, 600), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _getColorShade(color, 600), width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorStyle: const TextStyle(fontSize: 12),
    );
  }

Widget _buildFacultyList() {
  return FadeTransition(
    opacity: _fadeAnimation,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.people, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Department Faculty',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage faculty members in your department',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Faculty Members',
                hintText: 'Enter name, email, or role...',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.search, color: Colors.purple.shade700, size: 20),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('users/faculty/data')
                    .where('branchId', isEqualTo: _branchId)
                    .where('collegeId', isEqualTo: _collegeId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading faculty members...',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
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
                            child: Icon(Icons.error_outline,
                                size: 64, color: Colors.red.shade400),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading faculty',
                            style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please try again later',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.grey.shade100, Colors.grey.shade200],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline,
                                    size: 80, color: Colors.grey.shade400),
                                const SizedBox(height: 20),
                                Text(
                                  'No Faculty Members Yet',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add your first faculty member using the form above',
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

                  final facultyList = snapshot.data!.docs;

                  final filteredFaculty = _searchController.text.isEmpty
                      ? facultyList
                      : facultyList.where((faculty) {
                          final data = faculty.data() as Map<String, dynamic>;
                          final name = data['name']?.toString().toLowerCase() ?? '';
                          final email = data['email']?.toString().toLowerCase() ?? '';
                          final role = data['role']?.toString().toLowerCase() ?? '';
                          final search = _searchController.text.toLowerCase();
                          return name.contains(search) ||
                              email.contains(search) ||
                              role.contains(search);
                        }).toList();

                  if (filteredFaculty.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.search_off,
                                size: 64, color: Colors.orange.shade400),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Results Found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search terms',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredFaculty.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemBuilder: (context, index) {
                      final faculty = filteredFaculty[index].data() as Map<String, dynamic>;
                      final facultyId = filteredFaculty[index].id;
                      final isActive = faculty['isActive'] ?? true;
                      final isEmailVerified = faculty['isEmailVerified'] ?? false;
                      final canHandleStudents = faculty['canHandleStudents'] ?? false;
                      final isExpanded = _expandedFaculty.contains(facultyId);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.grey.shade50],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isActive ? Colors.green : Colors.red)
                                  .withOpacity(0.08),
                              spreadRadius: 1,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => _toggleExpanded(facultyId),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: _buildFacultyHeader(
                                  faculty,
                                  isActive,
                                  isEmailVerified,
                                  canHandleStudents,
                                  isExpanded,
                                ),
                              ),
                            ),
                            if (isExpanded)
                              _buildExpandedDetails(faculty, facultyId, isActive),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildFacultyHeader(
  Map<String, dynamic> faculty,
  bool isActive,
  bool isEmailVerified,
  bool canHandleStudents,
  bool isExpanded,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 400;
      
      return Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [Colors.purple.shade400, Colors.purple.shade600]
                        : [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
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
                            faculty['name']?.toString() ?? 'Unknown Name',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isNarrow) ...[
                          const SizedBox(width: 8),
                          _buildRoleChip(faculty['role']),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    Text(
                      faculty['email']?.toString() ?? 'No email',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey.shade600,
                size: 24,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          Row(
            children: [
              if (isNarrow) ...[
                Expanded(child: _buildRoleChip(faculty['role'])),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: isNarrow ? 2 : 1,
                child: _buildStatusChips(isActive, isEmailVerified, canHandleStudents),
              ),
            ],
          ),
        ],
      );
    },
  );
}

Widget _buildRoleChip(String? role) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _getRoleColor(role).withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _getRoleColor(role),
        width: 1,
      ),
    ),
    child: Text(
      role?.toString() ?? 'N/A',
      style: TextStyle(
        color: _getRoleColor(role),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget _buildStatusChips(bool isActive, bool isEmailVerified, bool canHandleStudents) {
  return Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      _buildCompactStatusChip(
        isActive ? 'Active' : 'Inactive',
        isActive ? Colors.green : Colors.red,
        Icons.circle,
      ),
      _buildCompactStatusChip(
        isEmailVerified ? 'Verified' : 'Unverified',
        isEmailVerified ? Colors.blue : Colors.orange,
        isEmailVerified ? Icons.verified : Icons.mail_outline,
      ),
      if (canHandleStudents)
        _buildCompactStatusChip(
          'Students',
          Colors.teal,
          Icons.school,
        ),
    ],
  );
}

Widget _buildExpandedDetails(Map<String, dynamic> faculty, String facultyId, bool isActive) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      border: Border(
        top: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide)
              _buildWideDetailsGrid(faculty)
            else
              _buildNarrowDetailsGrid(faculty),
            
            const SizedBox(height: 20),

            if (isWide)
              _buildWideActionButtons(facultyId, faculty, isActive)
            else
              _buildNarrowActionButtons(facultyId, faculty, isActive),
          ],
        );
      },
    ),
  );
}

Widget _buildWideDetailsGrid(Map<String, dynamic> faculty) {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _buildDetailItem(
              Icons.phone,
              'Phone',
              faculty['phone']?.toString() ?? 'No phone',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDetailItem(
              Icons.business,
              'Department',
              faculty['branchName']?.toString() ?? _branchName ?? 'Unknown Department',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _buildDetailItem(
              Icons.calendar_today,
              'Created',
              faculty['createdAt'] != null ? _formatDate(faculty['createdAt']) : 'Unknown',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDetailItem(
              Icons.admin_panel_settings,
              'Created By',
              'You (HOD)',
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildNarrowDetailsGrid(Map<String, dynamic> faculty) {
  return Column(
    children: [
      _buildDetailItem(
        Icons.phone,
        'Phone',
        faculty['phone']?.toString() ?? 'No phone',
      ),
      const SizedBox(height: 12),
      _buildDetailItem(
        Icons.business,
        'Department',
        faculty['branchName']?.toString() ?? _branchName ?? 'Unknown Department',
      ),
      const SizedBox(height: 12),
      _buildDetailItem(
        Icons.calendar_today,
        'Created',
        faculty['createdAt'] != null ? _formatDate(faculty['createdAt']) : 'Unknown',
      ),
      const SizedBox(height: 12),
      _buildDetailItem(
        Icons.admin_panel_settings,
        'Created By',
        'You (HOD)',
      ),
    ],
  );
}

Widget _buildWideActionButtons(String facultyId, Map<String, dynamic> faculty, bool isActive) {
  return Row(
    children: [
      Expanded(
        child: _buildCompactActionButton(
          'Edit',
          Icons.edit,
          Colors.blue,
          () => _startEdit(faculty, facultyId),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _buildCompactActionButton(
          isActive ? 'Deactivate' : 'Activate',
          isActive ? Icons.pause : Icons.play_arrow,
          isActive ? Colors.orange : Colors.green,
          () => _toggleFacultyStatus(facultyId, isActive),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _buildCompactActionButton(
          'Delete',
          Icons.delete_outline,
          Colors.red,
          () => _deleteFaculty(
            facultyId,
            faculty['name']?.toString() ?? 'Unknown',
            faculty['email']?.toString() ?? '',
          ),
        ),
      ),
    ],
  );
}

Widget _buildNarrowActionButtons(String facultyId, Map<String, dynamic> faculty, bool isActive) {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _buildCompactActionButton(
              'Edit',
              Icons.edit,
              Colors.blue,
              () => _startEdit(faculty, facultyId),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactActionButton(
              isActive ? 'Deactivate' : 'Activate',
              isActive ? Icons.pause : Icons.play_arrow,
              isActive ? Colors.orange : Colors.green,
              () => _toggleFacultyStatus(facultyId, isActive),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: _buildCompactActionButton(
          'Delete',
          Icons.delete_outline,
          Colors.red,
          () => _deleteFaculty(
            facultyId,
            faculty['name']?.toString() ?? 'Unknown',
            faculty['email']?.toString() ?? '',
          ),
        ),
      ),
    ],
  );
}

  Widget _buildCompactStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _getColorShade(color, 700)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: _getColorShade(color, 700),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ));
  }

  Widget _buildCompactActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: _getColorShade(color, 700),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: _getColorShade(color, 300), width: 1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        final now = DateTime.now();
        final difference = now.difference(date).inDays;

        if (difference == 0) {
          return 'Today';
        } else if (difference == 1) {
          return 'Yesterday';
        } else if (difference < 7) {
          return '$difference days ago';
        } else {
          return '${date.day}/${date.month}/${date.year}';
        }
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'professor':
        return Colors.red;
      case 'associate professor':
        return Colors.purple;
      case 'assistant professor':
        return Colors.blue;
      case 'teaching staff':
        return Colors.green;
      case 'guest faculty':
        return Colors.orange;
      case 'lab assistant':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: Colors.purple.shade700),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Faculty Management',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade600, Colors.purple.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _hodData == null
          ? Center(
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
                      'Loading department information...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final isDesktop = screenWidth > 1200;
                final isTablet = screenWidth > 800 && screenWidth <= 1200;
                final isMobile = screenWidth <= 800;

                if (isDesktop) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: _buildCreateFacultyForm(),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 3,
                          child: _buildFacultyList(),
                        ),
                      ],
                    ),
                  );
                } else if (isTablet) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        _buildCreateFacultyForm(),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.65,
                          child: _buildFacultyList(),
                        ),
                      ],
                    ),
                  );
                } else {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
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
              },
            ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _editNameController.dispose();
    _editPhoneController.dispose();
    super.dispose();
  }
}