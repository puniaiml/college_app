import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UniversityManagementPage extends StatefulWidget {
  const UniversityManagementPage({super.key});

  @override
  _UniversityManagementPageState createState() => _UniversityManagementPageState();
}

class _UniversityManagementPageState extends State<UniversityManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _collegeController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = false;
  String? _selectedUniversityId;
  String? _selectedCollegeId;
  String? _selectedCourseId;
  String _currentView = 'university'; // university, college, course, branch
  Map<String, String> _breadcrumb = {};

  @override
  void initState() {
    super.initState();
    _updateBreadcrumb();
  }

  // Safe setState that checks if widget is still mounted
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _updateBreadcrumb() {
    _breadcrumb = {
      'universityName': '',
      'collegeName': '',
      'courseName': '',
    };
  }

  // Add University
  Future<void> _addUniversity() async {
    if (_universityController.text.trim().isEmpty) {
      _showSnackBar('University name cannot be empty', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      await _firestore.collection('universities').add({
        'name': _universityController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showSnackBar('University added successfully!');
        _universityController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to add university: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  // Add College
  Future<void> _addCollege() async {
    if (_collegeController.text.trim().isEmpty) {
      _showSnackBar('College name cannot be empty', isError: true);
      return;
    }

    if (_selectedUniversityId == null) {
      _showSnackBar('Please select a university first', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      await _firestore.collection('colleges').add({
        'name': _collegeController.text.trim(),
        'universityId': _selectedUniversityId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showSnackBar('College added successfully!');
        _collegeController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to add college: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  // Add Course
  Future<void> _addCourse() async {
    if (_courseController.text.trim().isEmpty) {
      _showSnackBar('Course name cannot be empty', isError: true);
      return;
    }

    if (_selectedCollegeId == null) {
      _showSnackBar('Please select a college first', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      await _firestore.collection('courses').add({
        'name': _courseController.text.trim(),
        'collegeId': _selectedCollegeId,
        'universityId': _selectedUniversityId,
        'createdAt': FieldValue.serverTimestamp(),
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

  // Add Branch
  Future<void> _addBranch() async {
    if (_branchController.text.trim().isEmpty) {
      _showSnackBar('Branch name cannot be empty', isError: true);
      return;
    }

    if (_selectedCourseId == null) {
      _showSnackBar('Please select a course first', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      await _firestore.collection('branches').add({
        'name': _branchController.text.trim(),
        'courseId': _selectedCourseId,
        'collegeId': _selectedCollegeId,
        'universityId': _selectedUniversityId,
        'createdAt': FieldValue.serverTimestamp(),
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

  // Delete functions with confirmation
  Future<void> _deleteUniversity(String universityId, String universityName) async {
    final confirm = await _showConfirmationDialog(
      'Delete University',
      'Are you sure you want to delete "$universityName"?\nThis will also delete all associated colleges, courses and branches.',
      isDangerous: true,
    );
    
    if (!confirm) return;

    _safeSetState(() => _isLoading = true);

    try {
      // Delete all related colleges, courses and branches
      final colleges = await _firestore
          .collection('colleges')
          .where('universityId', isEqualTo: universityId)
          .get();

      for (var college in colleges.docs) {
        await _deleteCollegeData(college.id);
      }

      await _firestore.collection('universities').doc(universityId).delete();
      if (mounted) {
        _showSnackBar('University deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete university: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCollege(String collegeId, String collegeName) async {
    final confirm = await _showConfirmationDialog(
      'Delete College',
      'Are you sure you want to delete "$collegeName"?\nThis will also delete all associated courses and branches.',
      isDangerous: true,
    );
    
    if (!confirm) return;

    _safeSetState(() => _isLoading = true);

    try {
      await _deleteCollegeData(collegeId);
      if (mounted) {
        _showSnackBar('College deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete college: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCollegeData(String collegeId) async {
    // Delete all courses under this college
    final courses = await _firestore
        .collection('courses')
        .where('collegeId', isEqualTo: collegeId)
        .get();

    for (var course in courses.docs) {
      await _deleteCourseData(course.id);
    }

    // Delete the college
    await _firestore.collection('colleges').doc(collegeId).delete();
  }

  Future<void> _deleteCourse(String courseId, String courseName) async {
    final confirm = await _showConfirmationDialog(
      'Delete Course',
      'Are you sure you want to delete "$courseName"?\nThis will also delete all associated branches.',
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
    // Delete all branches under this course
    final branches = await _firestore
        .collection('branches')
        .where('courseId', isEqualTo: courseId)
        .get();

    for (var branch in branches.docs) {
      await _firestore.collection('branches').doc(branch.id).delete();
    }

    // Delete the course
    await _firestore.collection('courses').doc(courseId).delete();
  }

  Future<void> _deleteBranch(String branchId, String branchName) async {
    final confirm = await _showConfirmationDialog(
      'Delete Branch',
      'Are you sure you want to delete "$branchName"?',
      isDangerous: true,
    );
    
    if (!confirm) return;

    _safeSetState(() => _isLoading = true);

    try {
      await _firestore.collection('branches').doc(branchId).delete();
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

  void _navigateToColleges(String universityId, String universityName) {
    _safeSetState(() {
      _selectedUniversityId = universityId;
      _selectedCollegeId = null;
      _selectedCourseId = null;
      _currentView = 'college';
      _breadcrumb['universityName'] = universityName;
      _breadcrumb['collegeName'] = '';
      _breadcrumb['courseName'] = '';
      _searchController.clear();
    });
  }

  void _navigateToCourses(String collegeId, String collegeName) {
    _safeSetState(() {
      _selectedCollegeId = collegeId;
      _selectedCourseId = null;
      _currentView = 'course';
      _breadcrumb['collegeName'] = collegeName;
      _breadcrumb['courseName'] = '';
      _searchController.clear();
    });
  }

  void _navigateToBranches(String courseId, String courseName) {
    _safeSetState(() {
      _selectedCourseId = courseId;
      _currentView = 'branch';
      _breadcrumb['courseName'] = courseName;
      _searchController.clear();
    });
  }

  void _navigateBack() {
    _safeSetState(() {
      if (_currentView == 'branch') {
        _currentView = 'course';
        _selectedCourseId = null;
        _breadcrumb['courseName'] = '';
      } else if (_currentView == 'course') {
        _currentView = 'college';
        _selectedCollegeId = null;
        _selectedCourseId = null;
        _breadcrumb['collegeName'] = '';
        _breadcrumb['courseName'] = '';
      } else if (_currentView == 'college') {
        _currentView = 'university';
        _selectedUniversityId = null;
        _selectedCollegeId = null;
        _selectedCourseId = null;
        _breadcrumb = {};
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
      case 'university':
        return 'Universities';
      case 'college':
        return 'Colleges';
      case 'course':
        return 'Courses';
      case 'branch':
        return 'Branches';
      default:
        return 'University Management';
    }
  }

  Color _getViewColor() {
    switch (_currentView) {
      case 'university':
        return Colors.blue;
      case 'college':
        return Colors.green;
      case 'course':
        return Colors.purple;
      case 'branch':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getViewIcon() {
    switch (_currentView) {
      case 'university':
        return Icons.school;
      case 'college':
        return Icons.business;
      case 'course':
        return Icons.menu_book;
      case 'branch':
        return Icons.account_tree;
      default:
        return Icons.school;
    }
  }

  Widget _buildBreadcrumb() {
    if (_currentView == 'university') return const SizedBox.shrink();
    
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
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.navigation, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                children: [
                  GestureDetector(
                    onTap: () {
                      _safeSetState(() {
                        _currentView = 'university';
                        _selectedUniversityId = null;
                        _selectedCollegeId = null;
                        _selectedCourseId = null;
                        _breadcrumb = {};
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Universities',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const Text(' / ', style: TextStyle(color: Colors.grey)),
                  if (_currentView == 'college' || _currentView == 'course' || _currentView == 'branch')
                    Text(
                      _breadcrumb['universityName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  if (_currentView == 'course' || _currentView == 'branch') ...[
                    const Text(' / ', style: TextStyle(color: Colors.grey)),
                    if (_currentView == 'course')
                      Text(
                        _breadcrumb['collegeName'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          _safeSetState(() {
                            _currentView = 'course';
                            _selectedCourseId = null;
                            _breadcrumb['courseName'] = '';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _breadcrumb['collegeName'] ?? '',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                  if (_currentView == 'branch') ...[
                    const Text(' / ', style: TextStyle(color: Colors.grey)),
                    Text(
                      _breadcrumb['courseName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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

  Widget _buildAddForm() {
    String title = '';
    String fieldLabel = '';
    String buttonText = '';
    VoidCallback onPressed = () {};
    TextEditingController controller = TextEditingController();
    IconData icon = Icons.add;

    switch (_currentView) {
      case 'university':
        title = 'Add New University';
        fieldLabel = 'University Name';
        buttonText = 'Add University';
        onPressed = _addUniversity;
        controller = _universityController;
        icon = Icons.school;
        break;
      case 'college':
        title = 'Add New College to ${_breadcrumb['universityName']}';
        fieldLabel = 'College Name';
        buttonText = 'Add College';
        onPressed = _addCollege;
        controller = _collegeController;
        icon = Icons.business;
        break;
      case 'course':
        title = 'Add New Course to ${_breadcrumb['collegeName']}';
        fieldLabel = 'Course Name (e.g., B.Tech, B.Sc, MBA)';
        buttonText = 'Add Course';
        onPressed = _addCourse;
        controller = _courseController;
        icon = Icons.menu_book;
        break;
      case 'branch':
        title = 'Add New Branch to ${_breadcrumb['courseName']}';
        fieldLabel = 'Branch Name (e.g., Computer Science, Mechanical)';
        buttonText = 'Add Branch';
        onPressed = _addBranch;
        controller = _branchController;
        icon = Icons.account_tree;
        break;
    }

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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getViewColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _getViewColor(), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Create a new ${_currentView.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: fieldLabel,
                prefixIcon: Icon(icon, color: _getViewColor()),
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
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getViewColor(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                        buttonText,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    String currentEntity = _currentView == 'university' ? 'Universities' :
                          _currentView == 'college' ? 'Colleges' :
                          _currentView == 'course' ? 'Courses' : 'Branches';

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

  Widget _buildListView(Stream<QuerySnapshot> stream, Widget Function(List<QueryDocumentSnapshot>) itemBuilder) {
    return Expanded(
      child: Container(
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
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getViewColor().withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(_getViewIcon(), color: _getViewColor(), size: 24),
                  const SizedBox(width: 12),
                  Text(
                    '${_getTitle()} Directory',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: _getViewColor()),
                          const SizedBox(height: 16),
                          Text(
                            'Loading ${_currentView}s...',
                            style: const TextStyle(color: Colors.grey),
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
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
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
                                Icon(
                                  _getViewIcon(),
                                  size: 64,
                                  color: Colors.grey.shade400,
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
                                  'Create your first ${_currentView.toLowerCase()} using the form above',
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
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

                  return itemBuilder(filteredItems);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniversityView() {
    return Column(
      children: [
        _buildAddForm(),
        _buildSearchField(),
        _buildListView(
          _firestore.collection('universities').snapshots(),
          (items) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final university = items[index].data() as Map<String, dynamic>;
              final universityId = items[index].id;
              final universityName = university['name']?.toString() ?? 'Unknown University';

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
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
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.school, color: Colors.white, size: 24),
                  ),
                  title: Text(
                    universityName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'Tap to view colleges',
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
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.business, color: Colors.green),
                          tooltip: 'View Colleges',
                          onPressed: () => _navigateToColleges(universityId, universityName),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete University',
                          onPressed: () => _deleteUniversity(universityId, universityName),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _navigateToColleges(universityId, universityName),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollegeView() {
    return Column(
      children: [
        _buildAddForm(),
        _buildSearchField(),
        _buildListView(
          _firestore
              .collection('colleges')
              .where('universityId', isEqualTo: _selectedUniversityId)
              .snapshots(),
          (items) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final college = items[index].data() as Map<String, dynamic>;
              final collegeId = items[index].id;
              final collegeName = college['name']?.toString() ?? 'Unknown College';

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
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
                        colors: [Colors.green.shade400, Colors.green.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.business, color: Colors.white, size: 24),
                  ),
                  title: Text(
                    collegeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'Tap to view courses',
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
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.menu_book, color: Colors.purple),
                          tooltip: 'View Courses',
                          onPressed: () => _navigateToCourses(collegeId, collegeName),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete College',
                          onPressed: () => _deleteCollege(collegeId, collegeName),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _navigateToCourses(collegeId, collegeName),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCourseView() {
    return Column(
      children: [
        _buildAddForm(),
        _buildSearchField(),
        _buildListView(
          _firestore
              .collection('courses')
              .where('collegeId', isEqualTo: _selectedCollegeId)
              .snapshots(),
          (items) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final course = items[index].data() as Map<String, dynamic>;
              final courseId = items[index].id;
              final courseName = course['name']?.toString() ?? 'Unknown Course';

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
                  title: Text(
                    courseName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
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
        _buildAddForm(),
        _buildSearchField(),
        _buildListView(
          _firestore
              .collection('branches')
              .where('courseId', isEqualTo: _selectedCourseId)
              .snapshots(),
          (items) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final branch = items[index].data() as Map<String, dynamic>;
              final branchId = items[index].id;
              final branchName = branch['name']?.toString() ?? 'Unknown Branch';

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
                  title: Text(
                    branchName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'Branch department',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Container(
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
                ),
              );
            },
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
        title: Text(
          _getTitle(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _getViewColor(),
        foregroundColor: Colors.white,
        centerTitle: true,
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
        leading: _currentView != 'university'
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: _navigateBack,
              )
            : null,
        actions: [
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
                Text(
                  'Management',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildBreadcrumb(),
            Expanded(
              child: _currentView == 'university'
                  ? _buildUniversityView()
                  : _currentView == 'college'
                      ? _buildCollegeView()
                      : _currentView == 'course'
                          ? _buildCourseView()
                          : _buildBranchView(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _universityController.dispose();
    _collegeController.dispose();
    _courseController.dispose();
    _branchController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}