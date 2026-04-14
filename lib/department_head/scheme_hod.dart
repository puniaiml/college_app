import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class HODSchemeManagementPage extends StatefulWidget {
  const HODSchemeManagementPage({super.key});

  @override
  _HODSchemeManagementPageState createState() => _HODSchemeManagementPageState();
}

class _HODSchemeManagementPageState extends State<HODSchemeManagementPage> 
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _schemeController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isLoading = false;
  bool _isLoadingHODData = true;
  
  Map<String, dynamic>? _hodData;
  String? _hodUniversityId;
  String? _hodCollegeId;
  String? _hodCourseId;
  String? _hodUniversityName;
  String? _hodCollegeName;
  String? _hodCourseName;

  static const hodPurple = Color(0xFF7B1FA2);

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
      if (user == null) return;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc('department_head')
          .collection('data')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _hodData = doc.data() as Map<String, dynamic>;
        _hodUniversityId = _hodData!['universityId'];
        _hodCollegeId = _hodData!['collegeId'];
        _hodCourseId = _hodData!['courseId'];
        _hodUniversityName = _hodData!['universityName'];
        _hodCollegeName = _hodData!['collegeName'];
        _hodCourseName = _hodData!['courseName'];
        
        setState(() {
          _isLoadingHODData = false;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load HOD data: $e', isError: true);
      setState(() => _isLoadingHODData = false);
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _navigateToSubjectManagement(String schemeId, String schemeName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HODSubjectManagementPage(
          schemeId: schemeId,
          schemeName: schemeName,
          courseId: _hodCourseId!,
          courseName: _hodCourseName!,
        ),
      ),
    );
  }

  Future<void> _addScheme() async {
    if (_schemeController.text.trim().isEmpty) {
      _showSnackBar('Scheme name cannot be empty', isError: true);
      return;
    }

    if (_yearController.text.trim().isEmpty) {
      _showSnackBar('Academic year cannot be empty', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      QuerySnapshot existingScheme = await _firestore
          .collection('schemes')
          .where('courseId', isEqualTo: _hodCourseId)
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
        'courseId': _hodCourseId,
        'courseName': _hodCourseName,
        'collegeId': _hodCollegeId,
        'universityId': _hodUniversityId,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByType': 'department_head',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _hodUniversityName ?? 'University',
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
                      _hodCollegeName ?? 'College',
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
                      _hodCourseName ?? 'Course',
                      style: TextStyle(
                        color: hodPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Text(' / ', style: TextStyle(color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Schemes',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
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

  Widget _buildAddForm() {
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
                    color: hodPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.schema, color: hodPurple, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add New Academic Scheme',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Create a new syllabus scheme for your course',
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
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hodPurple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hodPurple.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hodPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book, color: hodPurple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Course Assignment',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hodCourseName ?? 'Unknown Course',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: hodPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Auto-Selected',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Column(
              children: [
                _buildTextField(_schemeController, 'Scheme Name', Icons.schema, 'e.g., Scheme 2023'),
                const SizedBox(height: 16),
                _buildTextField(_yearController, 'Academic Year', Icons.calendar_today, 'e.g., 2023-24'),
                const SizedBox(height: 16),
                _buildTextField(_descriptionController, 'Description (Optional)', Icons.description, 'Brief description...', maxLines: 3),
              ],
            ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addScheme,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hodPurple,
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
            ),
          ],
        ),
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
        prefixIcon: Icon(icon, color: hodPurple),
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
          borderSide: const BorderSide(color: hodPurple, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Search Schemes',
          hintText: 'Search by scheme name or year...',
          prefixIcon: const Icon(Icons.search, color: hodPurple),
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
            borderSide: const BorderSide(color: hodPurple, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        onChanged: (value) => _safeSetState(() {}),
      ),
    );
  }

  bool _canModifyScheme(Map<String, dynamic> schemeData) {
    final createdBy = schemeData['createdBy'];
    final createdByType = schemeData['createdByType'];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == null) return false;
    if (createdBy == null) return true;
    
    if (createdBy == currentUserId) return true;
    
    if (createdByType == 'college_staff') return true;
    
    return false;
  }

  Widget _buildSchemesList() {
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
              color: hodPurple.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.schema, color: hodPurple, size: 24),
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
                .where('courseId', isEqualTo: _hodCourseId)
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
                      final searchTerm = _searchController.text.toLowerCase();
                      return name.contains(searchTerm) || year.contains(searchTerm);
                    }).toList();

              if (filteredSchemes.isEmpty) {
                return _buildNoResultsState();
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 800;
                  
                  if (isWideScreen) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth > 1200 ? 3 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: constraints.maxWidth > 1200 ? 1.8 : 1.5,
                        ),
                        itemCount: filteredSchemes.length,
                        itemBuilder: (context, index) {
                          return _buildSchemeCard(filteredSchemes[index], isGrid: true);
                        },
                      ),
                    );
                  } else {
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
    final description = data['description']?.toString() ?? '';
    final createdByType = data['createdByType']?.toString();
    final canModify = _canModifyScheme(data);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hodPurple.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: hodPurple.withOpacity(0.1),
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
                      colors: [hodPurple.withOpacity(0.8), hodPurple],
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
                                    : createdByType == 'department_head'
                                        ? hodPurple.withOpacity(0.1) 
                                        : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                createdByType == 'admin' 
                                    ? 'Admin' 
                                    : createdByType == 'department_head' 
                                        ? 'HOD' 
                                        : 'Staff',
                                style: TextStyle(
                                  color: createdByType == 'admin' 
                                      ? Colors.blue 
                                      : createdByType == 'department_head' 
                                          ? hodPurple 
                                          : Colors.green,
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
            if (description.isNotEmpty && !isGrid) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.description, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      description,style: TextStyle(
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToSubjectManagement(schemeId, schemeName),
                icon: const Icon(Icons.subject, size: 18),
                label: const Text('Manage Subjects'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final size = MediaQuery.of(context).size;
    
    return SizedBox(
      height: 200,
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
              'Loading schemes...',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final size = MediaQuery.of(context).size;
    
    return SizedBox(
      height: 200,
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
      height: 200,
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
              'No Schemes Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first academic scheme for this course',
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

  Widget _buildNoResultsState() {
    final size = MediaQuery.of(context).size;
    
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/search.json',
              width: size.width * 0.3,
              height: size.width * 0.3,
              fit: BoxFit.contain,
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
      ),
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_hodData != null) ...[
                    Text(
                      'Course: ${_hodData!['courseName'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      'College: ${_hodData!['collegeName'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87.withOpacity(0.7),
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
    if (_isLoadingHODData) {
      return _buildLoadingScreen();
    }

    if (_hodData == null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Academic Schemes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: hodPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [hodPurple, const Color(0xFF4A148C)],
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
                Icon(Icons.school, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
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
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _loadHODData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildBreadcrumb(),
                  _buildAddForm(),
                  _buildSearchField(),
                  _buildSchemesList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _schemeController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class HODSubjectManagementPage extends StatefulWidget {
  final String schemeId;
  final String schemeName;
  final String courseId;
  final String courseName;

  const HODSubjectManagementPage({
    super.key,
    required this.schemeId,
    required this.schemeName,
    required this.courseId,
    required this.courseName,
  });

  @override
  _HODSubjectManagementPageState createState() => _HODSubjectManagementPageState();
}

class _HODSubjectManagementPageState extends State<HODSubjectManagementPage> 
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _subjectNameController = TextEditingController();
  final TextEditingController _subjectCodeController = TextEditingController();
  final TextEditingController _creditsController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _selectedBranchId;
  String? _selectedSemesterId;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _semesters = [];
  Map<String, String> _breadcrumb = {};

  static const hodPurple = Color(0xFF7B1FA2);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadBranches();
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

  Future<void> _loadBranches() async {
    try {
      final branchesSnapshot = await _firestore
          .collection('branches')
          .where('courseId', isEqualTo: widget.courseId)
          .get();

      _branches = branchesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Branch',
        };
      }).toList();

      _updateBreadcrumb();
      
      setState(() {
        _isLoadingData = false;
      });
    } catch (e) {
      _showSnackBar('Failed to load branches: $e', isError: true);
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _loadSemesters(String branchId) async {
    try {
      final semestersSnapshot = await _firestore
          .collection('semesters')
          .where('branchId', isEqualTo: branchId)
          .get();

      _semesters = semestersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Semester',
        };
      }).toList();

      setState(() {
        _selectedBranchId = branchId;
        _selectedSemesterId = null;
      });
    } catch (e) {
      _showSnackBar('Failed to load semesters: $e', isError: true);
    }
  }

  void _updateBreadcrumb() {
    _breadcrumb = {
      'schemeName': widget.schemeName,
      'courseName': widget.courseName,
      'branchName': _selectedBranchId != null 
          ? _branches.firstWhere((b) => b['id'] == _selectedBranchId)['name'] 
          : '',
      'semesterName': _selectedSemesterId != null 
          ? _semesters.firstWhere((s) => s['id'] == _selectedSemesterId)['name'] 
          : '',
    };
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Future<void> _addSubject() async {
    if (_subjectNameController.text.trim().isEmpty) {
      _showSnackBar('Subject name cannot be empty', isError: true);
      return;
    }

    if (_subjectCodeController.text.trim().isEmpty) {
      _showSnackBar('Subject code cannot be empty', isError: true);
      return;
    }

    if (_creditsController.text.trim().isEmpty) {
      _showSnackBar('Credits cannot be empty', isError: true);
      return;
    }

    final credits = int.tryParse(_creditsController.text.trim());
    if (credits == null || credits <= 0) {
      _showSnackBar('Please enter a valid credits value', isError: true);
      return;
    }

    if (_selectedBranchId == null) {
      _showSnackBar('Please select a branch', isError: true);
      return;
    }

    if (_selectedSemesterId == null) {
      _showSnackBar('Please select a semester', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      QuerySnapshot existingSubject = await _firestore
          .collection('subjects')
          .where('schemeId', isEqualTo: widget.schemeId)
          .where('branchId', isEqualTo: _selectedBranchId)
          .where('semesterId', isEqualTo: _selectedSemesterId)
          .where('code', isEqualTo: _subjectCodeController.text.trim())
          .limit(1)
          .get();

      if (existingSubject.docs.isNotEmpty) {
        _showSnackBar('Subject with this code already exists', isError: true);
        _safeSetState(() => _isLoading = false);
        return;
      }

      await _firestore.collection('subjects').add({
        'name': _subjectNameController.text.trim(),
        'code': _subjectCodeController.text.trim(),
        'credits': credits,
        'schemeId': widget.schemeId,
        'schemeName': widget.schemeName,
        'branchId': _selectedBranchId,
        'semesterId': _selectedSemesterId,
        'courseId': widget.courseId,
        'courseName': widget.courseName,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByType': 'department_head',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      
      if (mounted) {
        _showSnackBar('Subject added successfully!');
        _subjectNameController.clear();
        _subjectCodeController.clear();
        _creditsController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to add subject: $e', isError: true);
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _editSubject(String subjectId, Map<String, dynamic> currentData) async {
    final nameController = TextEditingController(text: currentData['name']);
    final codeController = TextEditingController(text: currentData['code']);
    final creditsController = TextEditingController(text: currentData['credits']?.toString() ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: Colors.teal, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Edit Subject',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Subject Name',
                  prefixIcon: const Icon(Icons.subject, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Subject Code',
                  prefixIcon: const Icon(Icons.code, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: creditsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Credits',
                  prefixIcon: const Icon(Icons.star, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
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
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (nameController.text.trim().isEmpty) {
        _showSnackBar('Subject name cannot be empty', isError: true);
        return;
      }

      if (codeController.text.trim().isEmpty) {
        _showSnackBar('Subject code cannot be empty', isError: true);
        return;
      }

      if (creditsController.text.trim().isEmpty) {
        _showSnackBar('Credits cannot be empty', isError: true);
        return;
      }

      final credits = int.tryParse(creditsController.text.trim());
      if (credits == null || credits <= 0) {
        _showSnackBar('Please enter a valid credits value', isError: true);
        return;
      }

      _safeSetState(() => _isLoading = true);

      try {
        await _firestore.collection('subjects').doc(subjectId).update({
          'name': nameController.text.trim(),
          'code': codeController.text.trim(),
          'credits': credits,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _showSnackBar('Subject updated successfully!');
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Failed to update subject: $e', isError: true);
        }
      } finally {
        _safeSetState(() => _isLoading = false);
      }
    }

    nameController.dispose();
    codeController.dispose();
    creditsController.dispose();
  }

  Future<void> _deleteSubject(String subjectId, String subjectName) async {
    final confirm = await _showConfirmationDialog(
      'Delete Subject',
      'Are you sure you want to delete "$subjectName"?\nThis action cannot be undone.',
      isDangerous: true,
    );
    
    if (!confirm) return;

    _safeSetState(() => _isLoading = true);

    try {
      await _firestore.collection('subjects').doc(subjectId).delete();
      if (mounted) {
        _showSnackBar('Subject deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to delete subject: $e', isError: true);
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hodPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _breadcrumb['schemeName'] ?? 'Scheme',
                      style: TextStyle(
                        color: hodPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Text(' / ', style: TextStyle(color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _breadcrumb['courseName'] ?? 'Course',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_selectedBranchId != null) ...[
                    const Text(' / ', style: TextStyle(color: Colors.grey)),
                    Container(
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
                  ],
                  if (_selectedSemesterId != null) ...[
                    const Text(' / ', style: TextStyle(color: Colors.grey)),
                    Container(
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
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.subject, color: Colors.teal, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add New Subject',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Create a new subject for ${widget.schemeName}',
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
            
            Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedBranchId,
                  decoration: InputDecoration(
                    labelText: 'Select Branch',
                    prefixIcon: const Icon(Icons.account_tree, color: Colors.orange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _branches.map((branch) {
                    return DropdownMenuItem<String>(
                      value: branch['id'],
                      child: Text(branch['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBranchId = value;
                      _selectedSemesterId = null;
                    });
                    if (value != null) {
                      _loadSemesters(value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSemesterId,
                  decoration: InputDecoration(
                    labelText: 'Select Semester',
                    prefixIcon: const Icon(Icons.schedule, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _semesters.map((semester) {
                    return DropdownMenuItem<String>(
                      value: semester['id'],
                      child: Text(semester['name']),
                    );
                  }).toList(),
                  onChanged: _selectedBranchId == null 
                      ? null 
                      : (value) {
                          setState(() {
                            _selectedSemesterId = value;
                          });
                          _updateBreadcrumb();
                        },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Column(
              children: [
                TextField(
                  controller: _subjectNameController,
                  decoration: InputDecoration(
                    labelText: 'Subject Name',
                    hintText: 'e.g., Data Structures',
                    prefixIcon: const Icon(Icons.subject, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _subjectCodeController,
                  decoration: InputDecoration(
                    labelText: 'Subject Code',
                    hintText: 'e.g., CS101',
                    prefixIcon: const Icon(Icons.code, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _creditsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Credits',
                    hintText: 'e.g., 4',
                    prefixIcon: const Icon(Icons.star, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addSubject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
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
                        'Add Subject',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Search Subjects',
          hintText: 'Search by subject name or code...',
          prefixIcon: const Icon(Icons.search, color: Colors.teal),
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
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        onChanged: (value) => _safeSetState(() {}),
      ),
    );
  }

  Widget _buildSubjectsList() {
    if (_selectedBranchId == null || _selectedSemesterId == null) {
      return Container(
        padding: const EdgeInsets.all(40),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Select Branch and Semester',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select a branch and semester to view subjects',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
              color: Colors.teal.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.subject, color: Colors.teal, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Subjects Directory',
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
                .collection('subjects')
                .where('schemeId', isEqualTo: widget.schemeId)
                .where('branchId', isEqualTo: _selectedBranchId)
                .where('semesterId', isEqualTo: _selectedSemesterId)
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

              final subjects = snapshot.data!.docs;
              
              final filteredSubjects = _searchController.text.isEmpty
                  ? subjects
                  : subjects.where((subject) {
                      final data = subject.data() as Map<String, dynamic>;
                      final name = data['name']?.toString().toLowerCase() ?? '';
                      final code = data['code']?.toString().toLowerCase() ?? '';
                      final searchTerm = _searchController.text.toLowerCase();
                      return name.contains(searchTerm) || code.contains(searchTerm);
                    }).toList();

              if (filteredSubjects.isEmpty) {
                return _buildNoResultsState();
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: filteredSubjects.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildSubjectCard(filteredSubjects[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(QueryDocumentSnapshot subject) {
    final data = subject.data() as Map<String, dynamic>;
    final subjectId = subject.id;
    final subjectName = data['name']?.toString() ?? 'Unknown Subject';
    final subjectCode = data['code']?.toString() ?? '';
    final credits = data['credits']?.toString() ?? '0';
    final createdByType = data['createdByType']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
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
                      colors: [Colors.teal.withOpacity(0.8), Colors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.subject, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              subjectCode,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 1),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 10, color: Colors.amber),
                                const SizedBox(width: 1),
                                Text(
                                  '$credits Credits',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (createdByType != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: createdByType == 'admin' 
                                    ? Colors.purple.withOpacity(0.1)
                                    : createdByType == 'department_head'
                                        ? hodPurple.withOpacity(0.1) 
                                        : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                createdByType == 'admin' 
                                    ? 'Admin' 
                                    : createdByType == 'department_head' 
                                        ? 'HOD' 
                                        : 'Staff',
                                style: TextStyle(
                                  color: createdByType == 'admin' 
                                      ? Colors.purple 
                                      : createdByType == 'department_head' 
                                          ? hodPurple 
                                          : Colors.green,
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
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.teal, size: 20),
                  onPressed: () => _editSubject(subjectId, data),
                  tooltip: 'Edit Subject',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteSubject(subjectId, subjectName),
                  tooltip: 'Delete Subject',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final size = MediaQuery.of(context).size;
    
    return SizedBox(
      height: 200,
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
              'Loading subjects...',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final size = MediaQuery.of(context).size;
    
    return SizedBox(
      height: 200,
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
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/empty.json',
              width: size.width * 0.2,
              height: size.width * 0.2,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            Text(
              'No Subjects Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first subject for this scheme',
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

  Widget _buildNoResultsState() {
    final size = MediaQuery.of(context).size;
    
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/search.json',
              width: size.width * 0.3,
              height: size.width * 0.3,
              fit: BoxFit.contain,
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
      ),
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
              const Text(
                'Loading subject management...',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
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
    if (_isLoadingData) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Subject Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.teal.shade700],
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
                Icon(Icons.school, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
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
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _loadBranches,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildBreadcrumb(),
                  _buildAddForm(),
                  _buildSearchField(),
                  _buildSubjectsList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _subjectNameController.dispose();
    _subjectCodeController.dispose();
    _creditsController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}