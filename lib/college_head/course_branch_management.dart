import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class StaffCourseBranchSemesterManagementPage extends StatefulWidget {
  const StaffCourseBranchSemesterManagementPage({super.key});

  @override
  _StaffCourseBranchSemesterManagementPageState createState() => _StaffCourseBranchSemesterManagementPageState();
}

class _StaffCourseBranchSemesterManagementPageState extends State<StaffCourseBranchSemesterManagementPage> 
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isLoading = false;
  bool _isLoadingStaffData = true;
  String? _selectedCourseId;
  String? _selectedBranchId;
  String _currentView = 'course';
  Map<String, String> _breadcrumb = {};
  String? _selectedSemester;
  
  Map<String, dynamic>? _staffData;
  String? _staffUniversityId;
  String? _staffCollegeId;
  String? _staffUniversityName;
  String? _staffCollegeName;

  final List<String> _semesterOptions = [
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8',
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadStaffData();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadStaffData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('User not logged in', isError: true);
        setState(() => _isLoadingStaffData = false);
        return;
      }

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc('college_staff')
          .collection('data')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        _showSnackBar('Staff profile not found', isError: true);
        setState(() => _isLoadingStaffData = false);
        return;
      }

      _staffData = doc.data() as Map<String, dynamic>;
      _staffUniversityId = _staffData!['universityId'];
      _staffCollegeId = _staffData!['collegeId'];
      _staffUniversityName = _staffData!['universityName'];
      _staffCollegeName = _staffData!['collegeName'];
      
      if (_staffUniversityId == null || _staffCollegeId == null) {
        _showSnackBar('Staff data incomplete', isError: true);
      }
      
      _updateBreadcrumb();
      
      setState(() {
        _isLoadingStaffData = false;
      });
    } catch (e) {
      _showSnackBar('Failed to load staff data: $e', isError: true);
      setState(() => _isLoadingStaffData = false);
    }
  }

  void _updateBreadcrumb() {
    _breadcrumb = {
      'universityName': _staffUniversityName ?? 'University',
      'collegeName': _staffCollegeName ?? 'College',
      'courseName': '',
      'branchName': '',
    };
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Future<void> _addCourse() async {
    final courseName = _courseController.text.trim();
    
    if (courseName.isEmpty) {
      _showSnackBar('Course name cannot be empty', isError: true);
      return;
    }
    
    if (courseName.length < 2) {
      _showSnackBar('Course name must be at least 2 characters', isError: true);
      return;
    }
    
    if (_staffCollegeId == null) {
      _showSnackBar('Staff college information not found', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      QuerySnapshot existingCourse = await _firestore
          .collection('courses')
          .where('collegeId', isEqualTo: _staffCollegeId)
          .where('name', isEqualTo: courseName)
          .limit(1)
          .get();

      if (existingCourse.docs.isNotEmpty) {
        _showSnackBar('Course already exists in this college', isError: true);
        _safeSetState(() => _isLoading = false);
        return;
      }

      await _firestore.collection('courses').add({
        'name': courseName,
        'collegeId': _staffCollegeId,
        'universityId': _staffUniversityId,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByType': 'college_staff',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        _showSnackBar('Course added successfully!');
        _courseController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to add course: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _addBranch() async {
    final branchName = _branchController.text.trim();
    
    if (branchName.isEmpty) {
      _showSnackBar('Branch name cannot be empty', isError: true);
      return;
    }
    
    if (branchName.length < 2) {
      _showSnackBar('Branch name must be at least 2 characters', isError: true);
      return;
    }

    if (_selectedCourseId == null) {
      _showSnackBar('Please select a course first', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      QuerySnapshot existingBranch = await _firestore
          .collection('branches')
          .where('courseId', isEqualTo: _selectedCourseId)
          .where('name', isEqualTo: branchName)
          .limit(1)
          .get();

      if (existingBranch.docs.isNotEmpty) {
        _showSnackBar('Branch already exists in this course', isError: true);
        _safeSetState(() => _isLoading = false);
        return;
      }

      await _firestore.collection('branches').add({
        'name': branchName,
        'courseId': _selectedCourseId,
        'collegeId': _staffCollegeId,
        'universityId': _staffUniversityId,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByType': 'college_staff',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        _showSnackBar('Branch added successfully!');
        _branchController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to add branch: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _addSemester() async {
    if (_selectedSemester == null) {
      _showSnackBar('Please select a semester', isError: true);
      return;
    }

    if (_selectedBranchId == null) {
      _showSnackBar('Please select a branch first', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      QuerySnapshot existingSemester = await _firestore
          .collection('semesters')
          .where('branchId', isEqualTo: _selectedBranchId)
          .where('name', isEqualTo: _selectedSemester!.trim())
          .limit(1)
          .get();

      if (existingSemester.docs.isNotEmpty) {
        _showSnackBar('Semester already exists in this branch', isError: true);
        _safeSetState(() => _isLoading = false);
        return;
      }

      await _firestore.collection('semesters').add({
        'name': _selectedSemester!.trim(),
        'branchId': _selectedBranchId,
        'courseId': _selectedCourseId,
        'collegeId': _staffCollegeId,
        'universityId': _staffUniversityId,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByType': 'college_staff',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'semesterNumber': _semesterOptions.indexOf(_selectedSemester!) + 1,
      });
      
      if (mounted) {
        _showSnackBar('Semester added successfully!');
        _selectedSemester = null;
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to add semester: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCourse(String courseId, String courseName) async {
    final confirm = await _showConfirmationDialog(
      'Delete Course',
      'Are you sure you want to delete "$courseName"?\nThis will also delete all associated branches and semesters.',
      isDangerous: true,
    );
    
    if (!confirm) return;

    _safeSetState(() => _isLoading = true);

    try {
      await _deleteCourseData(courseId);
      if (mounted) {
        _showSnackBar('Course deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete course: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCourseData(String courseId) async {
    final WriteBatch batch = _firestore.batch();
    
    final branches = await _firestore
        .collection('branches')
        .where('courseId', isEqualTo: courseId)
        .get();

    for (var branch in branches.docs) {
      final semesters = await _firestore
          .collection('semesters')
          .where('branchId', isEqualTo: branch.id)
          .get();

      for (var semester in semesters.docs) {
        batch.delete(semester.reference);
      }

      batch.delete(branch.reference);
    }

    final courseRef = _firestore.collection('courses').doc(courseId);
    batch.delete(courseRef);
    
    await batch.commit();
  }

  Future<void> _deleteBranch(String branchId, String branchName) async {
    final confirm = await _showConfirmationDialog(
      'Delete Branch',
      'Are you sure you want to delete "$branchName"?\nThis will also delete all associated semesters.',
      isDangerous: true,
    );
    
    if (!confirm) return;

    _safeSetState(() => _isLoading = true);

    try {
      await _deleteBranchData(branchId);
      if (mounted) {
        _showSnackBar('Branch deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete branch: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBranchData(String branchId) async {
    final WriteBatch batch = _firestore.batch();
    
    final semesters = await _firestore
        .collection('semesters')
        .where('branchId', isEqualTo: branchId)
        .get();

    for (var semester in semesters.docs) {
      batch.delete(semester.reference);
    }

    final branchRef = _firestore.collection('branches').doc(branchId);
    batch.delete(branchRef);
    
    await batch.commit();
  }

  Future<void> _deleteSemester(String semesterId, String semesterName) async {
    final confirm = await _showConfirmationDialog(
      'Delete Semester',
      'Are you sure you want to delete "$semesterName"?',
      isDangerous: true,
    );
    
    if (!confirm) return;

    _safeSetState(() => _isLoading = true);

    try {
      await _firestore.collection('semesters').doc(semesterId).delete();
      if (mounted) {
        _showSnackBar('Semester deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete semester: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content, {bool isDangerous = false}) async {
    if (!mounted) return false;
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDangerous ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
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
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isDangerous ? 'Delete' : 'Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _navigateToBranches(String courseId, String courseName) {
    _safeSetState(() {
      _selectedCourseId = courseId;
      _currentView = 'branch';
      _breadcrumb['courseName'] = courseName;
      _searchController.clear();
      _selectedSemester = null;
    });
  }

  void _navigateToSemesters(String branchId, String branchName) {
    _safeSetState(() {
      _selectedBranchId = branchId;
      _currentView = 'semester';
      _breadcrumb['branchName'] = branchName;
      _searchController.clear();
    });
  }

  void _navigateBack() {
    _safeSetState(() {
      if (_currentView == 'semester') {
        _currentView = 'branch';
        _selectedBranchId = null;
        _breadcrumb['branchName'] = '';
        _selectedSemester = null;
      } else if (_currentView == 'branch') {
        _currentView = 'course';
        _selectedCourseId = null;
        _breadcrumb['courseName'] = '';
      }
      _searchController.clear();
    });
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
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getTitle() {
    switch (_currentView) {
      case 'course':
        return 'Courses';
      case 'branch':
        return 'Branches';
      case 'semester':
        return 'Semesters';
      default:
        return 'Course Management';
    }
  }

  Color _getViewColor() {
    switch (_currentView) {
      case 'course':
        return Colors.purple;
      case 'branch':
        return Colors.orange;
      case 'semester':
        return Colors.teal;
      default:
        return Colors.purple;
    }
  }

  IconData _getViewIcon() {
    switch (_currentView) {
      case 'course':
        return Icons.menu_book;
      case 'branch':
        return Icons.account_tree;
      case 'semester':
        return Icons.schedule;
      default:
        return Icons.menu_book;
    }
  }

  Widget _buildBreadcrumb() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Row(
          children: [
            Icon(Icons.navigation, color: Colors.grey.shade600, size: isMobile ? 16 : 20),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Wrap(
                spacing: isMobile ? 4 : 8,
                runSpacing: isMobile ? 4 : 8,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _breadcrumb['universityName']!,
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 11 : 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(' / ', style: TextStyle(color: Colors.grey, fontSize: isMobile ? 11 : 13)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _breadcrumb['collegeName']!,
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 11 : 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_currentView != 'course') ...[
                    Text(' / ', style: TextStyle(color: Colors.grey, fontSize: isMobile ? 11 : 13)),
                    if (_currentView == 'branch')
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _breadcrumb['courseName']!,
                          style: TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 11 : 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _currentView == 'semester' ? () {
                          _safeSetState(() {
                            _currentView = 'branch';
                            _selectedBranchId = null;
                            _breadcrumb['branchName'] = '';
                            _selectedSemester = null;
                          });
                        } : null,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _breadcrumb['courseName']!,
                            style: TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.w600,
                              fontSize: isMobile ? 11 : 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                  if (_currentView == 'semester') ...[
                    Text(' / ', style: TextStyle(color: Colors.grey, fontSize: isMobile ? 11 : 13)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _breadcrumb['branchName']!,
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 11 : 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book, color: Colors.purple, size: isMobile ? 24 : 28),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Course to ${_breadcrumb['collegeName']}',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Create a new course',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),
            TextField(
              controller: _courseController,
              decoration: InputDecoration(
                labelText: 'Course Name (e.g., B.Tech, B.Sc, MBA)',
                prefixIcon: Icon(Icons.menu_book, color: Colors.purple),
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
                  borderSide: const BorderSide(color: Colors.purple, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addCourse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 14.0 : 16.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Add Course',
                        style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.account_tree, color: Colors.orange, size: isMobile ? 24 : 28),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Branch to ${_breadcrumb['courseName']}',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Create a new branch',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),
            TextField(
              controller: _branchController,
              decoration: InputDecoration(
                labelText: 'Branch Name (e.g., Computer Science, Mechanical)',
                prefixIcon: Icon(Icons.account_tree, color: Colors.orange),
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
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addBranch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 14.0 : 16.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Add Branch',
                        style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.schedule, color: Colors.teal, size: isMobile ? 24 : 28),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Semester to ${_breadcrumb['branchName']}',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Select semester from dropdown',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),
            DropdownButtonFormField<String>(
              value: _selectedSemester,
              decoration: InputDecoration(
                labelText: 'Select Semester',
                prefixIcon: const Icon(Icons.schedule, color: Colors.teal),
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
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: _semesterOptions.map((String semester) {
                return DropdownMenuItem<String>(
                  value: semester,
                  child: Text(semester),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedSemester = newValue;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a semester';
                }
                return null;
              },
            ),
            SizedBox(height: isMobile ? 16 : 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addSemester,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 14.0 : 16.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Add Semester',
                        style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    String currentEntity = _getTitle();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Search $currentEntity',
          hintText: 'Type to search...',
          prefixIcon: Icon(Icons.search, color: _getViewColor()),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _safeSetState(() {});
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
            borderSide: BorderSide(color: _getViewColor(), width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        onChanged: (value) => _safeSetState(() {}),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    final size = MediaQuery.of(context).size;
    
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/loading.json',
              width: size.width * 0.2,
              height: size.width * 0.2,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading ${_currentView}s...',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final size = MediaQuery.of(context).size;
    
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/error.json',
              width: size.width * 0.3,
              height: size.width * 0.3,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again later',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final size = MediaQuery.of(context).size;
    
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/empty.json',
              width: size.width * 0.4,
              height: size.width * 0.4,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_getTitle()} Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentView == 'semester' 
                  ? 'Add your first semester using the form above'
                  : 'Create your first ${_currentView.toLowerCase()} using the form above',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(Stream<QuerySnapshot> stream, Widget Function(List<QueryDocumentSnapshot>) itemBuilder) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: _getViewColor().withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(_getViewIcon(), color: _getViewColor(), size: isMobile ? 20 : 24),
                SizedBox(width: isMobile ? 8 : 12),
                Text(
                  '${_getTitle()} Directory',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingWidget();
              }

              if (snapshot.hasError) {
                return _buildErrorWidget();
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              final items = snapshot.data!.docs;
              items.sort((a, b) {
                final aName = (a.data() as Map<String, dynamic>)['name']?.toString() ?? '';
                final bName = (b.data() as Map<String, dynamic>)['name']?.toString() ?? '';
                return aName.compareTo(bName);
              });
              
              final filteredItems = _searchController.text.isEmpty
                  ? items
                  : items.where((item) {
                      final name = (item.data() as Map<String, dynamic>)['name']
                          ?.toString()
                          .toLowerCase() ?? '';
                      return name.contains(_searchController.text.toLowerCase());
                    }).toList();

              if (filteredItems.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: isMobile ? 48 : 64, color: Colors.grey.shade400),
                        SizedBox(height: isMobile ? 12 : 16),
                        Text(
                          'No Results Found',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: isMobile ? 6 : 8),
                        Text(
                          'Try adjusting your search terms',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: isMobile ? 12 : 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return itemBuilder(filteredItems);
            },
          ),
        ],
      ),
    );
  }

  bool _canModifyItem(Map<String, dynamic> itemData) {
    final createdBy = itemData['createdBy'];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    return createdBy == null || createdBy == currentUserId;
  }

  Widget _buildCourseView() {
    return Column(
      children: [
        _buildCourseForm(),
        _buildSearchField(),
        _buildListView(
          _firestore
              .collection('courses')
              .where('collegeId', isEqualTo: _staffCollegeId)
              .snapshots(),
          (items) => ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final course = items[index].data() as Map<String, dynamic>;
              final courseId = items[index].id;
              final courseName = course['name']?.toString() ?? 'Unknown Course';
              final canModify = _canModifyItem(course);
              final createdByType = course['createdByType']?.toString();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade400, Colors.purple.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.menu_book, color: Colors.white, size: 24),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          courseName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (createdByType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: createdByType == 'admin' 
                                ? Colors.blue.withOpacity(0.1) 
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            createdByType == 'admin' ? 'Admin' : 'Staff',
                            style: TextStyle(
                              color: createdByType == 'admin' ? Colors.blue : Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Tap to view branches',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.account_tree, color: Colors.orange),
                          tooltip: 'View Branches',
                          onPressed: () => _navigateToBranches(courseId, courseName),
                        ),
                      ),
                      if (canModify) ...[
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Delete Course',
                            onPressed: () => _deleteCourse(courseId, courseName),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => _navigateToBranches(courseId, courseName),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBranchView() {
    return Column(
      children: [
        _buildBranchForm(),
        _buildSearchField(),
        _buildListView(
          _firestore
              .collection('branches')
              .where('courseId', isEqualTo: _selectedCourseId)
              .snapshots(),
          (items) => ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final branch = items[index].data() as Map<String, dynamic>;
              final branchId = items[index].id;
              final branchName = branch['name']?.toString() ?? 'Unknown Branch';
              final canModify = _canModifyItem(branch);
              final createdByType = branch['createdByType']?.toString();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade400, Colors.orange.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.account_tree, color: Colors.white, size: 24),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          branchName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (createdByType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: createdByType == 'admin' 
                                ? Colors.blue.withOpacity(0.1) 
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            createdByType == 'admin' ? 'Admin' : 'Staff',
                            style: TextStyle(
                              color: createdByType == 'admin' ? Colors.blue : Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Tap to view semesters',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.schedule, color: Colors.teal),
                          tooltip: 'View Semesters',
                          onPressed: () => _navigateToSemesters(branchId, branchName),
                        ),
                      ),
                      if (canModify) ...[
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Delete Branch',
                            onPressed: () => _deleteBranch(branchId, branchName),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => _navigateToSemesters(branchId, branchName),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSemesterView() {
    return Column(
      children: [
        _buildSemesterForm(),
        _buildSearchField(),
        _buildListView(
          _firestore
              .collection('semesters')
              .where('branchId', isEqualTo: _selectedBranchId)
              .snapshots(),
          (items) => ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final semester = items[index].data() as Map<String, dynamic>;
              final semesterId = items[index].id;
              final semesterName = semester['name']?.toString() ?? 'Unknown Semester';
              final canModify = _canModifyItem(semester);
              final createdByType = semester['createdByType']?.toString();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade400, Colors.teal.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.schedule, color: Colors.white, size: 24),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          semesterName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (createdByType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: createdByType == 'admin' 
                                ? Colors.blue.withOpacity(0.1) 
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            createdByType == 'admin' ? 'Admin' : 'Staff',
                            style: TextStyle(
                              color: createdByType == 'admin' ? Colors.blue : Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Semester period',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: canModify 
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Delete Semester',
                            onPressed: () => _deleteSemester(semesterId, semesterName),
                          ),
                        )
                      : Icon(
                          Icons.lock_outline,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/loading.json',
                width: size.width * 0.3,
                height: size.width * 0.3,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  const Text(
                    'Loading your profile...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF121212),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_staffData != null) ...[
                    Text(
                      'College: ${_staffData!['collegeName'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF121212).withOpacity(0.7),
                      ),
                    ),
                    Text(
                      'University: ${_staffData!['universityName'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF121212).withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/error.json',
                width: size.width * 0.4,
                height: size.width * 0.4,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                'Unable to load staff data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please try again later',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadStaffData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    if (_isLoadingStaffData) {
      return _buildLoadingScreen();
    }

    if (_staffData == null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          _getTitle(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _getViewColor(),
        foregroundColor: Colors.white,
        centerTitle: isMobile ? true : false,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_getViewColor(), _getViewColor().withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: (_currentView == 'branch' || _currentView == 'semester')
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: _navigateBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Course Management'),
                  content: SizedBox(
                    width: isMobile ? screenWidth * 0.8 : 400,
                    child: const Text(
                      'Manage courses, branches and semesters for your college. '
                      'Navigate through the hierarchy to manage each level. '
                      'You can only delete items that you created.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'How this works',
          ),
          if (!isMobile) ...[
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getViewIcon(), size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  const Text(
                    'College-Admin Panel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _loadStaffData,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_getViewIcon(), size: 20, color: _getViewColor()),
                            const SizedBox(width: 8),
                            Text(
                              'College-Admin Panel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _getViewColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildBreadcrumb(),
                    if (_currentView == 'course')
                      _buildCourseView()
                    else if (_currentView == 'branch')
                      _buildBranchView()
                    else
                      _buildSemesterView(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: isMobile ? _buildMobileFAB() : null,
    );
  }

  Widget? _buildMobileFAB() {
    return FloatingActionButton(
      backgroundColor: _getViewColor(),
      foregroundColor: Colors.white,
      onPressed: () {
        if (_currentView == 'semester') {
          if (_selectedSemester == null) {
            _showSnackBar('Please select a semester first', isError: true);
            return;
          }
          _addSemester();
        } else if (_currentView == 'branch') {
          if (_branchController.text.trim().isEmpty) {
            _showSnackBar('Please enter branch name', isError: true);
            return;
          }
          _addBranch();
        } else if (_currentView == 'course') {
          if (_courseController.text.trim().isEmpty) {
            _showSnackBar('Please enter course name', isError: true);
            return;
          }
          _addCourse();
        }
      },
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
          : const Icon(Icons.add),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _courseController.dispose();
    _branchController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}