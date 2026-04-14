import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class HODSemesterManagementPage extends StatefulWidget {
  const HODSemesterManagementPage({super.key});

  @override
  _HODSemesterManagementPageState createState() => _HODSemesterManagementPageState();
}

class _HODSemesterManagementPageState extends State<HODSemesterManagementPage> 
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final _semesterFormKey = GlobalKey<FormState>();
  final _sectionFormKey = GlobalKey<FormState>();
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isLoading = false;
  bool _isLoadingHODData = true;
  String? _selectedBranchId;
  String? _selectedSemesterId;
  String _currentView = 'branch';
  Map<String, String> _breadcrumb = {};
  String? _selectedSemester;
  String? _selectedSection;
  bool _semesterDropdownTouched = false;
  bool _sectionDropdownTouched = false;
  
  Map<String, dynamic>? _hodData;
  String? _hodCourseId;
  String? _hodCourseName;
  String? _hodUniversityId;
  String? _hodCollegeId;
  String? _hodUniversityName;
  String? _hodCollegeName;

  static const hodPurple = Color(0xFF7B1FA2);
  static const deepBlack = Color(0xFF121212);
  
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

  final List<String> _sectionOptions = List.generate(26, (index) => 'Section ${String.fromCharCode(65 + index)}');

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadHODData();
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

  Future<void> _loadHODData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated', isError: true);
        setState(() => _isLoadingHODData = false);
        return;
      }

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc('department_head')
          .collection('data')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _hodData = doc.data() as Map<String, dynamic>;
        _hodCourseId = _hodData!['courseId'];
        _hodCourseName = _hodData!['courseName'];
        _hodUniversityId = _hodData!['universityId'];
        _hodCollegeId = _hodData!['collegeId'];
        _hodUniversityName = _hodData!['universityName'];
        _hodCollegeName = _hodData!['collegeName'];
        
        if (_hodCourseId == null || _hodCourseId!.isEmpty) {
          _showSnackBar('HOD course information is incomplete', isError: true);
        }
        
        _updateBreadcrumb();
        
        setState(() {
          _isLoadingHODData = false;
        });
      } else {
        _showSnackBar('HOD profile not found', isError: true);
        setState(() => _isLoadingHODData = false);
      }
    } catch (e) {
      _showSnackBar('Failed to load HOD data: $e', isError: true);
      setState(() => _isLoadingHODData = false);
    }
  }

  void _updateBreadcrumb() {
    _breadcrumb = {
      'universityName': _hodUniversityName ?? '',
      'collegeName': _hodCollegeName ?? '',
      'courseName': _hodCourseName ?? '',
      'branchName': '',
      'semesterName': '',
    };
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Future<void> _addSemester() async {
    setState(() => _semesterDropdownTouched = true);
    
    if (!_semesterFormKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors before submitting', isError: true);
      return;
    }

    if (_selectedSemester == null || _selectedSemester!.trim().isEmpty) {
      _showSnackBar('Please select a semester', isError: true);
      return;
    }

    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      _showSnackBar('Invalid branch selection', isError: true);
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
        _showSnackBar('This semester already exists in the selected branch', isError: true);
        _safeSetState(() => _isLoading = false);
        return;
      }

      await _firestore.collection('semesters').add({
        'name': _selectedSemester!.trim(),
        'branchId': _selectedBranchId,
        'courseId': _hodCourseId,
        'collegeId': _hodCollegeId,
        'universityId': _hodUniversityId,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByType': 'hod',
        'createdAt': FieldValue.serverTimestamp(),
        'semesterNumber': _semesterOptions.indexOf(_selectedSemester!) + 1,
      });
      
      if (mounted) {
        _showSnackBar('✓ Semester added successfully!');
        _selectedSemester = null;
        _semesterDropdownTouched = false;
        _semesterFormKey.currentState?.reset();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to add semester: ${e.toString()}', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _addSection() async {
    setState(() => _sectionDropdownTouched = true);
    
    if (!_sectionFormKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors before submitting', isError: true);
      return;
    }

    if (_selectedSection == null || _selectedSection!.trim().isEmpty) {
      _showSnackBar('Please select a section', isError: true);
      return;
    }

    if (_selectedSemesterId == null || _selectedSemesterId!.isEmpty) {
      _showSnackBar('Invalid semester selection', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      QuerySnapshot existingSection = await _firestore
          .collection('sections')
          .where('semesterId', isEqualTo: _selectedSemesterId)
          .where('name', isEqualTo: _selectedSection!.trim())
          .limit(1)
          .get();

      if (existingSection.docs.isNotEmpty) {
        _showSnackBar('This section already exists in the selected semester', isError: true);
        _safeSetState(() => _isLoading = false);
        return;
      }

      await _firestore.collection('sections').add({
        'name': _selectedSection!.trim(),
        'semesterId': _selectedSemesterId,
        'branchId': _selectedBranchId,
        'courseId': _hodCourseId,
        'collegeId': _hodCollegeId,
        'universityId': _hodUniversityId,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByType': 'hod',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        _showSnackBar('✓ Section added successfully!');
        _selectedSection = null;
        _sectionDropdownTouched = false;
        _sectionFormKey.currentState?.reset();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to add section: ${e.toString()}', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSemester(String semesterId, String semesterName) async {
    final confirm = await _showConfirmationDialog(
      'Delete Semester',
      'Are you sure you want to delete "$semesterName"? This action cannot be undone.',
      isDangerous: true,
    );
    
    if (!confirm) return;

    _safeSetState(() => _isLoading = true);

    try {
      QuerySnapshot sectionsInSemester = await _firestore
          .collection('sections')
          .where('semesterId', isEqualTo: semesterId)
          .limit(1)
          .get();

      if (sectionsInSemester.docs.isNotEmpty) {
        _showSnackBar('Cannot delete semester with existing sections. Delete sections first.', isError: true);
        _safeSetState(() => _isLoading = false);
        return;
      }

      await _firestore.collection('semesters').doc(semesterId).delete();
      if (mounted) {
        _showSnackBar('✓ Semester deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete semester: ${e.toString()}', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSection(String sectionId, String sectionName) async {
    final confirm = await _showConfirmationDialog(
      'Delete Section',
      'Are you sure you want to delete "$sectionName"? This action cannot be undone.',
      isDangerous: true,
    );
    
    if (!confirm) return;

    _safeSetState(() => _isLoading = true);

    try {
      await _firestore.collection('sections').doc(sectionId).delete();
      if (mounted) {
        _showSnackBar('✓ Section deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete section: ${e.toString()}', isError: true);
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
              backgroundColor: isDangerous ? Colors.red : hodPurple,
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

  void _navigateToSemesters(String branchId, String branchName) {
    _safeSetState(() {
      _selectedBranchId = branchId;
      _currentView = 'semester';
      _breadcrumb['branchName'] = branchName;
      _searchController.clear();
      _selectedSemester = null;
      _semesterDropdownTouched = false;
    });
  }

  void _navigateToSections(String semesterId, String semesterName) {
    _safeSetState(() {
      _selectedSemesterId = semesterId;
      _currentView = 'section';
      _breadcrumb['semesterName'] = semesterName;
      _searchController.clear();
      _selectedSection = null;
      _sectionDropdownTouched = false;
    });
  }

  void _navigateBack() {
    _safeSetState(() {
      if (_currentView == 'section') {
        _currentView = 'semester';
        _selectedSemesterId = null;
        _breadcrumb['semesterName'] = '';
        _selectedSection = null;
        _sectionDropdownTouched = false;
      } else if (_currentView == 'semester') {
        _currentView = 'branch';
        _selectedBranchId = null;
        _breadcrumb['branchName'] = '';
        _selectedSemester = null;
        _semesterDropdownTouched = false;
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
      case 'branch':
        return 'Course Branches';
      case 'semester':
        return 'Semesters';
      case 'section':
        return 'Sections';
      default:
        return 'Branch Management';
    }
  }

  Color _getViewColor() {
    switch (_currentView) {
      case 'branch':
        return Colors.orange;
      case 'semester':
        return Colors.teal;
      case 'section':
        return Colors.indigo;
      default:
        return Colors.orange;
    }
  }

  IconData _getViewIcon() {
    switch (_currentView) {
      case 'branch':
        return Icons.account_tree;
      case 'semester':
        return Icons.schedule;
      case 'section':
        return Icons.class_;
      default:
        return Icons.account_tree;
    }
  }

  Widget _buildBreadcrumb() {
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
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _breadcrumb['universityName'] ?? 'University',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Text(' / ', style: TextStyle(color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _breadcrumb['collegeName'] ?? 'College',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Text(' / ', style: TextStyle(color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hodPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _breadcrumb['courseName'] ?? 'Course',
                      style: TextStyle(
                        color: hodPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_currentView == 'semester' || _currentView == 'section') ...[
                    const Text(' / ', style: TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: _currentView == 'semester' ? _navigateBack : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _breadcrumb['branchName'] ?? 'Branch',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_currentView == 'section') ...[
                    const Text(' / ', style: TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: _navigateBack,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _breadcrumb['semesterName'] ?? 'Semester',
                          style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
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

  Widget _buildResponsiveDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Color color,
    required Function(String?) onChanged,
    required String? Function(String?) validator,
    required bool isTouched,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade700,
            fontSize: isMobile ? 14 : 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: isMobile ? 20 : 22),
          ),
          suffixIcon: value != null
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
                  onPressed: () {
                    onChanged(null);
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
            borderSide: BorderSide(color: color, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade600, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 14 : 16,
          ),
          errorStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        hint: Text(
          'Select $label',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: isMobile ? 14 : 15,
          ),
        ),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 24),
        dropdownColor: Colors.white,
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        menuMaxHeight: 300,
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: isMobile ? 14 : 15,
          fontWeight: FontWeight.w500,
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (value == item)
                    Icon(Icons.check_circle, color: color, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: isTouched ? validator : null,
        autovalidateMode: isTouched 
            ? AutovalidateMode.onUserInteraction 
            : AutovalidateMode.disabled,
      ),
    );
  }

  Widget _buildAddSemesterForm() {
    if (_currentView != 'semester') return const SizedBox.shrink();

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
        child: Form(
          key: _semesterFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade400, Colors.teal.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.schedule, color: Colors.white, size: isMobile ? 24 : 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMobile ? 'Add Semester' : 'Add New Semester to ${_breadcrumb['branchName']}',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Select semester from dropdown',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 20 : 24),
              _buildResponsiveDropdown(
                value: _selectedSemester,
                items: _semesterOptions,
                label: 'Semester',
                icon: Icons.schedule,
                color: Colors.teal,
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
                isTouched: _semesterDropdownTouched,
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
                    shadowColor: Colors.teal.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline, size: isMobile ? 18 : 20),
                            SizedBox(width: 8),
                            Text(
                              'Add Semester',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddSectionForm() {
    if (_currentView != 'section') return const SizedBox.shrink();

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
        child: Form(
          key: _sectionFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.class_, color: Colors.white, size: isMobile ? 24 : 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMobile ? 'Add Section' : 'Add New Section to ${_breadcrumb['semesterName']}',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Select section from dropdown',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 20 : 24),
              _buildResponsiveDropdown(
                value: _selectedSection,
                items: _sectionOptions,
                label: 'Section',
                icon: Icons.class_,
                color: Colors.indigo,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSection = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a section';
                  }
                  return null;
                },
                isTouched: _sectionDropdownTouched,
              ),
              SizedBox(height: isMobile ? 16 : 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addSection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 14.0 : 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    shadowColor: Colors.indigo.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline, size: isMobile ? 18 : 20),
                            SizedBox(width: 8),
                            Text(
                              'Add Section',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
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
                  : _currentView == 'section'
                      ? 'Add your first section using the form above'
                      : 'No branches available for this course',
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

  Widget _buildBranchView() {
    return Column(
      children: [
        _buildSearchField(),
        _buildListView(
          _firestore
              .collection('branches')
              .where('courseId', isEqualTo: _hodCourseId)
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
              final createdByType = branch['createdByType']?.toString();
              final isHODBranch = branch['branchId'] == _hodData?['branchId'];

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHODBranch 
                        ? hodPurple.withOpacity(0.5)
                        : Colors.orange.shade200, 
                    width: isHODBranch ? 2 : 1.5
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isHODBranch ? hodPurple : Colors.orange).withOpacity(0.1),
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
                        colors: isHODBranch
                            ? [hodPurple.withOpacity(0.8), hodPurple]
                            : [Colors.orange.shade400, Colors.orange.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (isHODBranch ? hodPurple : Colors.orange).withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isHODBranch ? Icons.star : Icons.account_tree, 
                      color: Colors.white, 
                      size: 24
                    ),
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
                      if (isHODBranch)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hodPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Your Branch',
                            style: TextStyle(
                              color: hodPurple,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (createdByType != null && !isHODBranch)
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
                    'Tap to manage semesters',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.schedule, color: Colors.teal),
                      tooltip: 'Manage Semesters',
                      onPressed: () => _navigateToSemesters(branchId, branchName),
                    ),
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
        _buildAddSemesterForm(),
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
                                : createdByType == 'hod'
                                    ? hodPurple.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            createdByType == 'admin' 
                                ? 'Admin' 
                                : createdByType == 'hod' 
                                    ? 'HOD' 
                                    : 'Staff',
                            style: TextStyle(
                              color: createdByType == 'admin' 
                                  ? Colors.blue 
                                  : createdByType == 'hod'
                                      ? hodPurple
                                      : Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Tap to manage sections',
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
                          color: Colors.indigo.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.class_, color: Colors.indigo),
                          tooltip: 'Manage Sections',
                          onPressed: () => _navigateToSections(semesterId, semesterName),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (canModify)
                        Container(
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
                      else
                        Icon(
                          Icons.lock_outline,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                    ],
                  ),
                  onTap: () => _navigateToSections(semesterId, semesterName),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionView() {
    return Column(
      children: [
        _buildAddSectionForm(),
        _buildSearchField(),
        _buildListView(
          _firestore
              .collection('sections')
              .where('semesterId', isEqualTo: _selectedSemesterId)
              .snapshots(),
          (items) => ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final section = items[index].data() as Map<String, dynamic>;
              final sectionId = items[index].id;
              final sectionName = section['name']?.toString() ?? 'Unknown Section';
              final canModify = _canModifyItem(section);
              final createdByType = section['createdByType']?.toString();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.1),
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
                        colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.class_, color: Colors.white, size: 24),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          sectionName,
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
                                : createdByType == 'hod'
                                    ? hodPurple.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            createdByType == 'admin' 
                                ? 'Admin' 
                                : createdByType == 'hod' 
                                    ? 'HOD' 
                                    : 'Staff',
                            style: TextStyle(
                              color: createdByType == 'admin' 
                                  ? Colors.blue 
                                  : createdByType == 'hod'
                                      ? hodPurple
                                      : Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Class section',
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
                            tooltip: 'Delete Section',
                            onPressed: () => _deleteSection(sectionId, sectionName),
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
                    'Loading HOD profile...',
                    style: TextStyle(
                      fontSize: 18,
                      color: deepBlack,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_hodData != null) ...[
                    Text(
                      'Course: ${_hodData!['courseName'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: deepBlack.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      'College: ${_hodData!['collegeName'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: deepBlack.withOpacity(0.7),
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
                'Unable to load HOD data',
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
                onPressed: _loadHODData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hodPurple,
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

    if (_isLoadingHODData) {
      return _buildLoadingScreen();
    }

    if (_hodData == null) {
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
        leading: (_currentView == 'semester' || _currentView == 'section')
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
                  title: const Text('Semester & Section Management'),
                  content: SizedBox(
                    width: isMobile ? screenWidth * 0.8 : 400,
                    child: const Text(
                      'Manage semesters and sections for all branches under your course. '
                      'Select a branch to view and add semesters. '
                      'Select a semester to view and add sections. '
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
                  const Icon(Icons.admin_panel_settings, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  const Text(
                    'HOD Panel',
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
            onRefresh: _loadHODData,
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
                            const Icon(Icons.admin_panel_settings, size: 20, color: hodPurple),
                            const SizedBox(width: 8),
                            const Text(
                              'HOD Panel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: hodPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildBreadcrumb(),
                    if (_currentView == 'branch')
                      _buildBranchView()
                    else if (_currentView == 'semester')
                      _buildSemesterView()
                    else
                      _buildSectionView(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: isMobile && (_currentView == 'semester' || _currentView == 'section')
          ? FloatingActionButton(
              backgroundColor: _currentView == 'semester' ? Colors.teal : Colors.indigo,
              foregroundColor: Colors.white,
              onPressed: () {
                if (_currentView == 'semester') {
                  setState(() => _semesterDropdownTouched = true);
                  if (_selectedSemester == null) {
                    _showSnackBar('Please select a semester first', isError: true);
                    return;
                  }
                  _addSemester();
                } else {
                  setState(() => _sectionDropdownTouched = true);
                  if (_selectedSection == null) {
                    _showSnackBar('Please select a section first', isError: true);
                    return;
                  }
                  _addSection();
                }
              },
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Icon(Icons.add),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}