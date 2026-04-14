import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffSchemeManagementPage extends StatefulWidget {
  const StaffSchemeManagementPage({super.key});

  @override
  _StaffSchemeManagementPageState createState() => _StaffSchemeManagementPageState();
}

class _StaffSchemeManagementPageState extends State<StaffSchemeManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _schemeController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingStaffData = true;
  String? _selectedCourseId;
  String? _selectedCourseName;
  
  // Staff data
  Map<String, dynamic>? _staffData;
  String? _staffUniversityId;
  String? _staffCollegeId;
  String? _staffUniversityName;
  String? _staffCollegeName;

  // Course options
  List<Map<String, dynamic>> _availableCourses = [];
  bool _isLoadingCourses = false;

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  // Load current staff data
  Future<void> _loadStaffData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc('college_staff')
          .collection('data')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _staffData = doc.data() as Map<String, dynamic>;
        _staffUniversityId = _staffData!['universityId'];
        _staffCollegeId = _staffData!['collegeId'];
        _staffUniversityName = _staffData!['universityName'];
        _staffCollegeName = _staffData!['collegeName'];
        
        await _loadCourses();
        
        setState(() {
          _isLoadingStaffData = false;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load staff data: $e', isError: true);
      setState(() => _isLoadingStaffData = false);
    }
  }

  // Load available courses for this college
  Future<void> _loadCourses() async {
    setState(() => _isLoadingCourses = true);
    
    try {
      QuerySnapshot coursesSnapshot = await _firestore
          .collection('courses')
          .where('collegeId', isEqualTo: _staffCollegeId)
          .get();

      _availableCourses = coursesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final courseName = data?['name']?.toString() ?? 'Unknown Course';
        
        return {
          'id': doc.id,
          'name': courseName,
        };
      }).toList();

      _availableCourses.sort((a, b) => a['name'].compareTo(b['name']));
      
    } catch (e) {
      _showSnackBar('Failed to load courses: $e', isError: true);
    } finally {
      setState(() => _isLoadingCourses = false);
    }
  }

  // Safe setState that checks if widget is still mounted
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // Add Scheme
  Future<void> _addScheme() async {
    if (_schemeController.text.trim().isEmpty) {
      _showSnackBar('Scheme name cannot be empty', isError: true);
      return;
    }

    if (_yearController.text.trim().isEmpty) {
      _showSnackBar('Academic year cannot be empty', isError: true);
      return;
    }

    if (_selectedCourseId == null) {
      _showSnackBar('Please select a course first', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      // Check if scheme already exists for this course and year
      QuerySnapshot existingScheme = await _firestore
          .collection('schemes')
          .where('courseId', isEqualTo: _selectedCourseId)
          .where('name', isEqualTo: _schemeController.text.trim())
          .where('academicYear', isEqualTo: _yearController.text.trim())
          .limit(1)
          .get();

      if (existingScheme.docs.isNotEmpty) {
        _showSnackBar('Scheme already exists for this course and year', isError: true);
        _safeSetState(() => _isLoading = false);
        return;
      }

      await _firestore.collection('schemes').add({
        'name': _schemeController.text.trim(),
        'academicYear': _yearController.text.trim(),
        'description': _descriptionController.text.trim(),
        'courseId': _selectedCourseId,
        'courseName': _selectedCourseName,
        'collegeId': _staffCollegeId,
        'universityId': _staffUniversityId,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByType': 'college_staff',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      
      if (mounted) {
        _showSnackBar('Scheme added successfully!');
        _schemeController.clear();
        _yearController.clear();
        _descriptionController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to add scheme: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  // Delete scheme with confirmation
  Future<void> _deleteScheme(String schemeId, String schemeName) async {
    final confirm = await _showConfirmationDialog(
      'Delete Scheme',
      'Are you sure you want to delete "$schemeName"?\nThis action cannot be undone.',
      isDangerous: true,
    );
    
    if (!confirm) return;

    _safeSetState(() => _isLoading = true);

    try {
      await _firestore.collection('schemes').doc(schemeId).delete();
      if (mounted) {
        _showSnackBar('Scheme deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete scheme: $e', isError: true);
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

  Widget _buildBreadcrumb() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.navigation, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 400;
                  
                  if (isSmallScreen) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBreadcrumbChip(_staffUniversityName ?? 'University', Colors.blue),
                        const SizedBox(height: 4),
                        _buildBreadcrumbChip(_staffCollegeName ?? 'College', Colors.green),
                        const SizedBox(height: 4),
                        _buildBreadcrumbChip('Schemes', Colors.grey),
                      ],
                    );
                  }
                  
                  return Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildBreadcrumbChip(_staffUniversityName ?? 'University', Colors.blue),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(' / ', style: TextStyle(color: Colors.grey)),
                      ),
                      _buildBreadcrumbChip(_staffCollegeName ?? 'College', Colors.green),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(' / ', style: TextStyle(color: Colors.grey)),
                      ),
                      _buildBreadcrumbChip('Schemes', Colors.grey),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormHeader(),
            const SizedBox(height: 24),
            
            LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth > 600;
                
                if (isWideScreen) {
                  return Column(
                    children: [
                      _buildCourseDropdown(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_schemeController, 'Scheme Name', Icons.schema, 'e.g., Scheme 2023, New Syllabus 2024')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField(_yearController, 'Academic Year', Icons.calendar_today, 'e.g., 2023-24, 2024-25')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_descriptionController, 'Description (Optional)', Icons.description, 'Brief description of scheme changes...', maxLines: 3),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildCourseDropdown(),
                      const SizedBox(height: 16),
                      _buildTextField(_schemeController, 'Scheme Name', Icons.schema, 'e.g., Scheme 2023'),
                      const SizedBox(height: 16),
                      _buildTextField(_yearController, 'Academic Year', Icons.calendar_today, 'e.g., 2023-24'),
                      const SizedBox(height: 16),
                      _buildTextField(_descriptionController, 'Description (Optional)', Icons.description, 'Brief description...', maxLines: 3),
                    ],
                  );
                }
              },
            ),
            
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        
        if (isSmallScreen) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.schema, color: Colors.indigo, size: 28),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add New Academic Scheme',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Create a new syllabus scheme for a course',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          );
        }
        
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schema, color: Colors.indigo, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Academic Scheme',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Create a new syllabus scheme for a course',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCourseDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedCourseId,
        decoration: const InputDecoration(
          labelText: 'Select Course',
          prefixIcon: Icon(Icons.menu_book, color: Colors.indigo),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        hint: _isLoadingCourses 
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Loading courses...'),
                ],
              )
            : const Text('Choose a course'),
        items: _availableCourses.map((course) {
          return DropdownMenuItem<String>(
            value: course['id'],
            child: Text(course['name'], overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: _isLoadingCourses ? null : (String? value) {
          setState(() {
            _selectedCourseId = value;
            if (value != null) {
              final selectedCourse = _availableCourses
                  .where((course) => course['id'] == value)
                  .firstOrNull;
              _selectedCourseName = selectedCourse?['name'] ?? '';
            } else {
              _selectedCourseName = null;
            }
          });
        },
        isExpanded: true,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.indigo),
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
          borderSide: const BorderSide(color: Colors.indigo, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _addScheme,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
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
            : const Text(
                'Create Scheme',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search Schemes',
            hintText: 'Search by scheme name or year...',
            prefixIcon: const Icon(Icons.search, color: Colors.indigo),
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
              borderSide: const BorderSide(color: Colors.indigo, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) => _safeSetState(() {}),
        ),
      ),
    );
  }

  bool _canModifyScheme(Map<String, dynamic> schemeData) {
    final createdBy = schemeData['createdBy'];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (createdBy == null) return true;
    if (currentUserId == null) return false;
    return createdBy == currentUserId;
  }

  Widget _buildSchemesList() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.schema, color: Colors.indigo, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Schemes Directory',
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
            stream: _firestore
                .collection('schemes')
                .where('collegeId', isEqualTo: _staffCollegeId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }

              if (snapshot.hasError) {
                return _buildErrorState();
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              final schemes = snapshot.data!.docs;
              
              final filteredSchemes = _searchController.text.isEmpty
                  ? schemes
                  : schemes.where((scheme) {
                      final data = scheme.data() as Map<String, dynamic>;
                      final name = data['name']?.toString().toLowerCase() ?? '';
                      final year = data['academicYear']?.toString().toLowerCase() ?? '';
                      final courseName = data['courseName']?.toString().toLowerCase() ?? '';
                      final searchTerm = _searchController.text.toLowerCase();
                      return name.contains(searchTerm) || 
                             year.contains(searchTerm) || 
                             courseName.contains(searchTerm);
                    }).toList();

              if (filteredSchemes.isEmpty) {
                return _buildNoResultsState();
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 800;
                  
                  if (isWideScreen) {
                    // Grid layout for wide screens
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: filteredSchemes.length,
                        itemBuilder: (context, index) {
                          return _buildSchemeCard(filteredSchemes[index], isGrid: true);
                        },
                      ),
                    );
                  } else {
                    // List layout for smaller screens
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredSchemes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildSchemeCard(filteredSchemes[index]);
                      },
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSchemeCard(QueryDocumentSnapshot scheme, {bool isGrid = false}) {
    final data = scheme.data() as Map<String, dynamic>;
    final schemeId = scheme.id;
    final schemeName = data['name']?.toString() ?? 'Unknown Scheme';
    final academicYear = data['academicYear']?.toString() ?? '';
    final courseName = data['courseName']?.toString() ?? 'Unknown Course';
    final description = data['description']?.toString() ?? '';
    final createdByType = data['createdByType']?.toString();
    final canModify = _canModifyScheme(data);

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.schema, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schemeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: isGrid ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              academicYear,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (createdByType != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: createdByType == 'admin' 
                                    ? Colors.blue.withOpacity(0.1) 
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
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
                        ],
                      ),
                    ],
                  ),
                ),
                if (canModify)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _deleteScheme(schemeId, schemeName),
                    tooltip: 'Delete Scheme',
                  )
                else
                  Icon(
                    Icons.lock_outline,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.menu_book, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Course: $courseName',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty && !isGrid) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.description, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 200,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.indigo),
            SizedBox(height: 16),
            Text(
              'Loading schemes...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 200,
      child: Center(
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
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
                    Icons.schema,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Schemes Found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first academic scheme using the form above',
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
      ),
    );
  }

  Widget _buildNoResultsState() {
    return SizedBox(
      height: 200,
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

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text(
                    'Loading your profile...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStaffData) {
      return _buildLoadingScreen();
    }

    if (_staffData == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
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
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Academic Schemes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.indigo.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schema, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Staff Panel',
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
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 1200;
          final padding = isWideScreen ? 24.0 : 16.0;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWideScreen ? 1200 : double.infinity,
              ),
              child: Column(
                children: [
                  _buildBreadcrumb(),
                  SizedBox(height: padding),
                  _buildAddForm(),
                  SizedBox(height: padding),
                  _buildSearchField(),
                  SizedBox(height: padding),
                  _buildSchemesList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _schemeController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}