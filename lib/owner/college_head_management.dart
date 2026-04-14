import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollegeHeadManagementPage extends StatefulWidget {
  const CollegeHeadManagementPage({super.key});

  @override
  _CollegeHeadManagementPageState createState() =>
      _CollegeHeadManagementPageState();
}

class _CollegeHeadManagementPageState
    extends State<CollegeHeadManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String? _selectedUniversityId;
  String? _selectedCollegeId;
  String? _selectedCourseId;
  final Map<String, String> _universityNames = {};
  final Map<String, String> _collegeNames = {};
  final Map<String, String> _courseNames = {};

  @override
  void initState() {
    super.initState();
    _loadUniversitiesAndColleges();
  }

  Future<void> _loadUniversitiesAndColleges() async {
    try {
      // Load universities
      final universitiesSnapshot =
          await _firestore.collection('universities').get();
      for (var doc in universitiesSnapshot.docs) {
        _universityNames[doc.id] =
            doc.data()['name']?.toString() ?? 'Unknown University';
      }

      // Load colleges
      final collegesSnapshot = await _firestore.collection('colleges').get();
      for (var doc in collegesSnapshot.docs) {
        _collegeNames[doc.id] =
            doc.data()['name']?.toString() ?? 'Unknown College';
      }

      // Load courses
      final coursesSnapshot = await _firestore.collection('courses').get();
      for (var doc in coursesSnapshot.docs) {
        _courseNames[doc.id] =
            doc.data()['name']?.toString() ?? 'Unknown Course';
      }

      setState(() {});
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  String _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String password = '';
    for (int i = 0; i < 8; i++) {
      password += chars[(random + i) % chars.length];
    }
    return password;
  }

  Future<void> _createCollegeStaff() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _selectedUniversityId == null ||
        _selectedCollegeId == null ||
        _selectedCourseId == null) {
      _showSnackBar(
          'Please fill in all fields and select university/college/course',
          isError: true);
      return;
    }

    if (!_emailController.text.contains('@')) {
      _showSnackBar('Please enter a valid email address', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if email already exists in any user type
      final emailCheckFutures = [
        _firestore
            .collection('users/college_staff/data')
            .where('email', isEqualTo: _emailController.text.trim())
            .get(),
        _firestore
            .collection('users/students/data')
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

      // Generate a temporary password
      final tempPassword = _generatePassword();

      // Create user in Firebase Auth
      UserCredential staffCredential;

      try {
        staffCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: tempPassword,
        );
      } catch (e) {
        _showSnackBar('Failed to create user account: ${e.toString()}',
            isError: true);
        return;
      }

      final staffUser = staffCredential.user;
      if (staffUser == null) {
        _showSnackBar('Failed to create user account', isError: true);
        return;
      }

      // Send email verification
      await staffUser.sendEmailVerification();

      // Create college staff data in the new structure
      final staffData = {
        'uid': staffUser.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'universityId': _selectedUniversityId,
        'collegeId': _selectedCollegeId,
        'courseId': _selectedCourseId,
        'universityName': _universityNames[_selectedUniversityId],
        'collegeName': _collegeNames[_selectedCollegeId],
        'courseName': _courseNames[_selectedCourseId],
        'role': 'college_staff',
        'isActive': true,
        'hasTemporaryPassword': true,
        'tempPassword': tempPassword,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Create document in college_staff collection
      await _firestore
          .collection('users/college_staff/data')
          .doc(staffUser.uid)
          .set(staffData);

      // Create user metadata
      await _firestore.collection('user_metadata').doc(staffUser.uid).set({
        'uid': staffUser.uid,
        'email': _emailController.text.trim(),
        'userType': 'college_staff',
        'accountStatus': 'pending_verification',
        'dataLocation': 'users/college_staff/data/${staffUser.uid}',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSuccessDialog(tempPassword);
      _clearForm();
    } catch (e) {
      _showSnackBar('Failed to create college staff: ${e.toString()}',
          isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String tempPassword) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Staff Created Successfully!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'College staff account has been created for ${_nameController.text}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Temporary Password:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: SelectableText(
                      tempPassword,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
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
                      Icon(Icons.info_outline,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Instructions',
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
                    'Please share these credentials with the staff member. They will need to:\n\n'
                    '• Verify their email address\n'
                    '• Change the temporary password after first login\n'
                    '• Use "Forgot Password" option if they forget credentials',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Got it!',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCollegeStaff(
      String staffId, String staffName, String email) async {
    final confirm = await _showConfirmationDialog(
      'Delete College Staff',
      'Are you sure you want to delete "$staffName"?\nThis will permanently remove their access.',
      isDangerous: true,
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      // Delete from college_staff collection
      await _firestore
          .collection('users/college_staff/data')
          .doc(staffId)
          .delete();

      // Delete user metadata
      await _firestore.collection('user_metadata').doc(staffId).delete();

      // Delete the auth user (this requires admin privileges in production)
      try {
        await _auth.currentUser?.delete();
      } catch (e) {
        print('Error deleting auth user: $e');
      }

      _showSnackBar('College staff deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete college staff: ${e.toString()}',
          isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStaffStatus(String staffId, bool currentStatus) async {
    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('users/college_staff/data')
          .doc(staffId)
          .update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update user metadata
      await _firestore.collection('user_metadata').doc(staffId).update({
        'accountStatus': !currentStatus ? 'active' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Staff status updated successfully');
    } catch (e) {
      _showSnackBar('Failed to update staff status: ${e.toString()}',
          isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content,
      {bool isDangerous = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDangerous
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDangerous ? Icons.warning : Icons.help_outline,
                    color: isDangerous ? Colors.red : Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600))),
              ],
            ),
            content: Text(content,
                style: const TextStyle(fontSize: 16, height: 1.4)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDangerous ? Colors.red : Colors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isDangerous ? 'Delete' : 'Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    setState(() {
      _selectedUniversityId = null;
      _selectedCollegeId = null;
      _selectedCourseId = null;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
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
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
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

  Widget _buildCreateStaffForm() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add,
                      color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New College Staff',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Add a new staff member to your college',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Responsive grid layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;

                if (isWide) {
                  return Column(
                    children: [
                      // Row 1: University and College
                      Row(
                        children: [
                          Expanded(child: _buildUniversityDropdown()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildCollegeDropdown()),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Row 2: Course
                      _buildCourseDropdown(),
                      const SizedBox(height: 20),

                      // Row 3: Name and Email
                      Row(
                        children: [
                          Expanded(child: _buildNameField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildEmailField()),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Row 4: Phone
                      _buildPhoneField(),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildUniversityDropdown(),
                      const SizedBox(height: 20),
                      _buildCollegeDropdown(),
                      const SizedBox(height: 20),
                      _buildCourseDropdown(),
                      const SizedBox(height: 20),
                      _buildNameField(),
                      const SizedBox(height: 20),
                      _buildEmailField(),
                      const SizedBox(height: 20),
                      _buildPhoneField(),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 32),

            // Create Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createCollegeStaff,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Create College Staff Account',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniversityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedUniversityId,
      decoration: InputDecoration(
        labelText: 'Select University',
        prefixIcon: const Icon(Icons.school, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: _universityNames.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedUniversityId = value;
          _selectedCollegeId = null;
          _selectedCourseId = null;
        });
      },
    );
  }

  Widget _buildCollegeDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _selectedUniversityId != null
          ? _firestore
              .collection('colleges')
              .where('universityId', isEqualTo: _selectedUniversityId)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        final isLoading = _selectedUniversityId != null && !snapshot.hasData;
        final colleges =
            snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];

        return DropdownButtonFormField<String>(
          value: _selectedCollegeId,
          decoration: InputDecoration(
            labelText: _selectedUniversityId == null
                ? 'Select University First'
                : isLoading
                    ? 'Loading Colleges...'
                    : 'Select College',
            prefixIcon: const Icon(Icons.business, color: Colors.blue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: colleges.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(data['name']?.toString() ?? 'Unknown College'),
            );
          }).toList(),
          onChanged: _selectedUniversityId == null
              ? null
              : (value) {
                  setState(() {
                    _selectedCollegeId = value;
                    _selectedCourseId = null;
                  });
                },
        );
      },
    );
  }

  Widget _buildCourseDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _selectedCollegeId != null
          ? _firestore
              .collection('courses')
              .where('collegeId', isEqualTo: _selectedCollegeId)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        final isLoading = _selectedCollegeId != null && !snapshot.hasData;
        final courses =
            snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];

        return DropdownButtonFormField<String>(
          value: _selectedCourseId,
          decoration: InputDecoration(
            labelText: _selectedCollegeId == null
                ? 'Select College First'
                : isLoading
                    ? 'Loading Courses...'
                    : 'Select Course',
            prefixIcon: const Icon(Icons.menu_book, color: Colors.blue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: courses.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(data['name']?.toString() ?? 'Unknown Course'),
            );
          }).toList(),
          onChanged: _selectedCollegeId == null
              ? null
              : (value) {
                  setState(() {
                    _selectedCourseId = value;
                  });
                },
        );
      },
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Staff Full Name',
        prefixIcon: const Icon(Icons.person, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Staff Email',
        prefixIcon: const Icon(Icons.email, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Staff Phone Number',
        prefixIcon: const Icon(Icons.phone, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildStaffList() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.people, color: Colors.green, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'College Staff Directory',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Manage existing staff members',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Staff Members',
                hintText: 'Enter name, email, college, or course...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
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
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('users/college_staff/data')
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
                            'Loading staff members...',
                            style: TextStyle(color: Colors.grey),
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
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading staff',
                            style: TextStyle(
                                fontSize: 18, color: Colors.red.shade700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: const TextStyle(color: Colors.grey),
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
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No Staff Members Yet',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first staff member using the form above',
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

                  final staffList = snapshot.data!.docs;

                  // Filter based on search
                  final filteredStaff = _searchController.text.isEmpty
                      ? staffList
                      : staffList.where((staff) {
                          final data = staff.data() as Map<String, dynamic>;
                          final name =
                              data['name']?.toString().toLowerCase() ?? '';
                          final email =
                              data['email']?.toString().toLowerCase() ?? '';
                          final college =
                              data['collegeName']?.toString().toLowerCase() ??
                                  '';
                          final course =
                              data['courseName']?.toString().toLowerCase() ??
                                  '';
                          final search = _searchController.text.toLowerCase();
                          return name.contains(search) ||
                              email.contains(search) ||
                              college.contains(search) ||
                              course.contains(search);
                        }).toList();

                  if (filteredStaff.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64, color: Colors.grey.shade400),
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
                    itemCount: filteredStaff.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemBuilder: (context, index) {
                      final staff =
                          filteredStaff[index].data() as Map<String, dynamic>;
                      final staffId = filteredStaff[index].id;
                      final isActive = staff['isActive'] ?? true;
                      final hasTempPassword =
                          staff['hasTemporaryPassword'] ?? false;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.08),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isActive
                                            ? [
                                                Colors.green.shade400,
                                                Colors.green.shade600
                                              ]
                                            : [
                                                Colors.red.shade400,
                                                Colors.red.shade600
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isActive
                                                  ? Colors.green
                                                  : Colors.red)
                                              .withOpacity(0.3),
                                          spreadRadius: 2,
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Staff Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                staff['name']?.toString() ??
                                                    'Unknown Name',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? Colors.green
                                                        .withOpacity(0.1)
                                                    : Colors.red
                                                        .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isActive
                                                      ? Colors.green
                                                      : Colors.red,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Text(
                                                isActive
                                                    ? 'Active'
                                                    : 'Inactive',
                                                style: TextStyle(
                                                  color: isActive
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade700,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          staff['email']?.toString() ??
                                              'No email',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (hasTempPassword) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color:
                                                      Colors.orange.shade300),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.key,
                                                    size: 12,
                                                    color:
                                                        Colors.orange.shade700),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    'Temp Password',
                                                    style: TextStyle(
                                                      color: Colors
                                                          .orange.shade700,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 11,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Action Buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.orange.withOpacity(0.1)
                                              : Colors.green.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            isActive
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: isActive
                                                ? Colors.orange.shade700
                                                : Colors.green.shade700,
                                          ),
                                          tooltip: isActive
                                              ? 'Deactivate'
                                              : 'Activate',
                                          onPressed: () => _toggleStaffStatus(
                                              staffId, isActive),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: IconButton(
                                          icon: Icon(Icons.delete_outline,
                                              color: Colors.red.shade700),
                                          tooltip: 'Delete Staff',
                                          onPressed: () => _deleteCollegeStaff(
                                            staffId,
                                            staff['name']?.toString() ??
                                                'Unknown',
                                            staff['email']?.toString() ?? '',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Staff Details Grid
                              Container(
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
                                                _buildDetailItem(
                                                  Icons.business,
                                                  'College',
                                                  staff['collegeName']
                                                          ?.toString() ??
                                                      'Unknown College',
                                                ),
                                                const SizedBox(height: 12),
                                                _buildDetailItem(
                                                  Icons.phone,
                                                  'Phone',
                                                  staff['phone']?.toString() ??
                                                      'No phone',
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          Expanded(
                                            child: Column(
                                              children: [
                                                _buildDetailItem(
                                                  Icons.menu_book,
                                                  'Course',
                                                  staff['courseName']
                                                          ?.toString() ??
                                                      'Unknown Course',
                                                ),
                                                const SizedBox(height: 12),
                                                _buildDetailItem(
                                                  Icons.school,
                                                  'University',
                                                  staff['universityName']
                                                          ?.toString() ??
                                                      'Unknown University',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      return Column(
                                        children: [
                                          _buildDetailItem(
                                            Icons.business,
                                            'College',
                                            staff['collegeName']?.toString() ??
                                                'Unknown College',
                                          ),
                                          const SizedBox(height: 12),
                                          _buildDetailItem(
                                            Icons.menu_book,
                                            'Course',
                                            staff['courseName']?.toString() ??
                                                'Unknown Course',
                                          ),
                                          const SizedBox(height: 12),
                                          _buildDetailItem(
                                            Icons.school,
                                            'University',
                                            staff['universityName']
                                                    ?.toString() ??
                                                'Unknown University',
                                          ),
                                          const SizedBox(height: 12),
                                          _buildDetailItem(
                                            Icons.phone,
                                            'Phone',
                                            staff['phone']?.toString() ??
                                                'No phone',
                                          ),
                                        ],
                                      );
                                    }
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: Colors.blue.shade700),
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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
          'College Staff Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 1200;

          if (isWide) {
            // Desktop layout: Side by side
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildCreateStaffForm(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: _buildStaffList(),
                  ),
                ],
              ),
            );
          } else {
            // Mobile/Tablet layout: Scrollable
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildCreateStaffForm(),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: _buildStaffList(),
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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}