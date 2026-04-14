import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StudentDetailsExportPage extends StatefulWidget {
  const StudentDetailsExportPage({super.key});

  @override
  State<StudentDetailsExportPage> createState() =>
      _StudentDetailsExportPageState();
}

class _StudentDetailsExportPageState extends State<StudentDetailsExportPage>
    with TickerProviderStateMixin {
  static const primaryBlue = Color(0xFF1A237E);
  static const deepBlack = Color(0xFF121212);
  static const lightGray = Color(0xFFF5F5F5);
  static const premiumGold = Color(0xFFD4AF37);
  static const tableHeaderBlue = Color(0xFF2C387E);
  static const rowHoverColor = Color(0xFFF8F9FF);
  static const borderColor = Color(0xFFE0E0E0);
  static const successGreen = Color(0xFF2ECC71);
  static const dangerRed = Color(0xFFE74C3C);

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? userData;
  bool? isHOD;
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> filteredStudents = [];
  bool isLoading = true;
  bool isExporting = false;
  bool isSendingMessages = false;
  String searchQuery = '';
  String selectedExportType = 'excel';
  Set<String> selectedColumns = {};
  Map<String, Map<String, dynamic>> studentCgpaData = {};
  int? hoveredRowIndex;
  Set<String> selectedStudentIds = {};
  bool isSelectionMode = false;

  String? selectedYearFilter;
  String? selectedGenderFilter;
  double? minCgpaFilter;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cgpaController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<String> allColumns = [
    'S.No',
    'Full Name',
    'USN',
    'Email',
    'Phone',
    'Gender',
    'Date of Birth',
    'Year of Passing',
    'University',
    'College',
    'Course',
    'Branch',
    'Account Status',
    'Registration Date',
    'CGPA',
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
    _loadUserDataAndStudents();
    selectedColumns = Set.from(allColumns);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    _cgpaController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
    });
    _filterStudents();
  }

  Future<void> _loadUserDataAndStudents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot hodDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('department_head')
          .collection('data')
          .doc(user.uid)
          .get();

      if (hodDoc.exists) {
        userData = hodDoc.data() as Map<String, dynamic>;
        userData!['uid'] = user.uid;
        isHOD = true;
      } else {
        DocumentSnapshot facultyDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc('faculty')
            .collection('data')
            .doc(user.uid)
            .get();

        if (facultyDoc.exists) {
          userData = facultyDoc.data() as Map<String, dynamic>;
          userData!['uid'] = user.uid;
          isHOD = false;
        } else {
          Get.snackbar('Error', 'User data not found');
          return;
        }
      }

      await _loadStudents();
      await _loadCgpaData();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStudents() async {
    if (userData == null) return;

    try {
      QuerySnapshot studentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .where('collegeId', isEqualTo: userData!['collegeId'])
          .where('courseId', isEqualTo: userData!['courseId'])
          .where('branchId', isEqualTo: userData!['branchId'])
          .where('accountStatus', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      students = studentsQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['uid'] = doc.id;
        return data;
      }).toList();

      _filterStudents();
      setState(() {});
    } catch (e) {
      Get.snackbar('Error', 'Failed to load students: $e');
    }
  }

  Future<void> _loadCgpaData() async {
    if (students.isEmpty) return;

    try {
      for (var student in students) {
        final cgpaDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc('students')
            .collection('data')
            .doc(student['uid'])
            .collection('cgpa_data')
            .doc('latest')
            .get();

        if (cgpaDoc.exists) {
          studentCgpaData[student['uid']] =
              cgpaDoc.data() as Map<String, dynamic>;
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error loading CGPA data: $e');
    }
  }

  void _filterStudents() {
    filteredStudents = students.where((student) {
      if (searchQuery.isNotEmpty) {
        final name = (student['fullName'] ?? '').toString().toLowerCase();
        final usn = (student['usn'] ?? '').toString().toLowerCase();
        final email = (student['email'] ?? '').toString().toLowerCase();
        final phone = (student['phone'] ?? '').toString().toLowerCase();
        final query = searchQuery.toLowerCase();

        if (!name.contains(query) &&
            !usn.contains(query) &&
            !email.contains(query) &&
            !phone.contains(query)) {
          return false;
        }
      }

      if (selectedYearFilter != null) {
        final year = student['yearOfPassing']?.toString();
        if (year != selectedYearFilter) return false;
      }

      if (selectedGenderFilter != null) {
        final gender = student['gender']?.toString().toLowerCase();
        if (gender != selectedGenderFilter?.toLowerCase()) return false;
      }

      if (minCgpaFilter != null) {
        final cgpa = _getStudentCgpa(student['uid']);
        if (cgpa == null || cgpa < minCgpaFilter!) return false;
      }

      return true;
    }).toList();

    setState(() {});
  }

  void _clearFilters() {
    setState(() {
      selectedYearFilter = null;
      selectedGenderFilter = null;
      minCgpaFilter = null;
      _cgpaController.clear();
    });
    _filterStudents();
  }

  double? _getStudentCgpa(String studentId) {
    final cgpaData = studentCgpaData[studentId];
    return cgpaData?['cgpa'] != null
        ? (cgpaData!['cgpa'] as num).toDouble()
        : null;
  }

  double? _getSemesterCgpa(String studentId, int semester) {
    final cgpaData = studentCgpaData[studentId];
    return cgpaData?['semester$semester'] != null
        ? (cgpaData!['semester$semester'] as num).toDouble()
        : null;
  }

  List<Map<String, dynamic>> _getStudentsWithoutCgpa() {
    return filteredStudents.where((student) {
      final cgpa = _getStudentCgpa(student['uid']);
      return cgpa == null;
    }).toList();
  }

  int _getStudentsWithoutCgpaCount() {
    return _getStudentsWithoutCgpa().length;
  }

  String _getConversationID(String id1, String id2) {
    return id1.hashCode <= id2.hashCode ? '${id1}_$id2' : '${id2}_$id1';
  }

  Future<void> _sendCgpaReminderToStudent(String studentId, String studentName) async {
    try {
      final conversationId = _getConversationID(userData!['uid'], studentId);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final facultyName = userData!['name'] ?? 'Faculty';

      await FirebaseFirestore.instance
          .collection('chats/$conversationId/messages')
          .doc(timestamp)
          .set({
        'toId': studentId,
        'msg': '📊 CGPA Calculation Reminder\n\nHello $studentName,\n\nThis is a reminder from $facultyName to calculate and update your SGPA/CGPA in the system.\n\nPlease navigate to the CGPA section in the app and update your semester-wise grades.\n\nThank you!',
        'read': '',
        'type': 'text',
        'fromId': userData!['uid'],
        'sent': timestamp,
      });
    } catch (e) {
      debugPrint('Error sending message to $studentId: $e');
      rethrow;
    }
  }

  Future<void> _sendCgpaRemindersToSelected() async {
    if (selectedStudentIds.isEmpty) {
      _showErrorSnackbar('No students selected');
      return;
    }

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Send CGPA Reminders'),
        content: Text(
          'Send CGPA calculation reminder to ${selectedStudentIds.length} selected student(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isSendingMessages = true);

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 100,
                    child: Lottie.asset('assets/lottie/loading.json'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sending reminders...'),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    int successCount = 0;
    int failCount = 0;

    for (final studentId in selectedStudentIds) {
      try {
        final student = students.firstWhere((s) => s['uid'] == studentId);
        final studentName = student['fullName'] ?? 'Student';
        await _sendCgpaReminderToStudent(studentId, studentName);
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint('Failed to send to $studentId: $e');
      }
    }

    Get.back();

    setState(() {
      isSendingMessages = false;
      isSelectionMode = false;
      selectedStudentIds.clear();
    });

    Get.dialog(
      Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 100,
                  child: Lottie.asset('assets/lottie/Success.json'),
                ),
                const SizedBox(height: 16),
                Text('Reminders sent: $successCount'),
                if (failCount > 0) Text('Failed: $failCount'),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    Get.back();
  }

  Future<void> _sendCgpaRemindersToAll() async {
    final studentsWithoutCgpa = _getStudentsWithoutCgpa();

    if (studentsWithoutCgpa.isEmpty) {
      _showErrorSnackbar('All students have calculated their CGPA');
      return;
    }

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Send CGPA Reminders to All'),
        content: Text(
          'Send CGPA calculation reminder to all ${studentsWithoutCgpa.length} student(s) who haven\'t calculated their CGPA?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            child: const Text('Send to All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isSendingMessages = true);

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 100,
                    child: Lottie.asset('assets/lottie/loading.json'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sending reminders to all...'),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    int successCount = 0;
    int failCount = 0;

    for (final student in studentsWithoutCgpa) {
      try {
        final studentName = student['fullName'] ?? 'Student';
        await _sendCgpaReminderToStudent(student['uid'], studentName);
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint('Failed to send to ${student['uid']}: $e');
      }
    }

    Get.back();

    setState(() => isSendingMessages = false);

    Get.dialog(
      Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 100,
                  child: Lottie.asset('assets/lottie/Success.json'),
                ),
                const SizedBox(height: 16),
                Text('Reminders sent: $successCount'),
                if (failCount > 0) Text('Failed: $failCount'),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    Get.back();
  }

  void _toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedStudentIds.clear();
      }
    });
  }

  void _toggleStudentSelection(String studentId) {
    setState(() {
      if (selectedStudentIds.contains(studentId)) {
        selectedStudentIds.remove(studentId);
      } else {
        selectedStudentIds.add(studentId);
      }
    });
  }

  void _selectAllWithoutCgpa() {
    setState(() {
      final studentsWithoutCgpa = _getStudentsWithoutCgpa();
      for (final student in studentsWithoutCgpa) {
        selectedStudentIds.add(student['uid']);
      }
    });
  }

  void _deselectAll() {
    setState(() {
      selectedStudentIds.clear();
    });
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: dangerRed.withOpacity(0.1),
      colorText: dangerRed,
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
      icon: const Icon(Icons.error, color: dangerRed),
    );
  }

  Widget _buildHeader() {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryBlue,
            primaryBlue.withOpacity(0.8),
            const Color(0xFF0D47A1),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: isTablet ? 24 : 16,
            right: isTablet ? 24 : 16,
            top: isTablet ? 24 : 16,
          ),
          child: Column(
            children: [
              _buildHeaderRow(isTablet, size),
              SizedBox(height: isTablet ? 24 : 16),
              _buildUserInfoCard(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              _buildStatsCard(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              _buildSearchBar(isTablet),
              SizedBox(height: isTablet ? 16 : 12),
              _buildFilterSection(isTablet),
              SizedBox(height: isTablet ? 16 : 12),
              _buildExportOptions(isTablet),
              if (_getStudentsWithoutCgpaCount() > 0) ...[
                SizedBox(height: isTablet ? 16 : 12),
                _buildCgpaReminderSection(isTablet),
              ],
              SizedBox(height: isTablet ? 16 : 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(bool isTablet, Size size) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Get.back(),
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: isTablet ? 28 : 24,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'Student Details & Export',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 28 : size.width * 0.055,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                userData?['branchName'] ?? 'Department',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: isTablet ? 16 : size.width * 0.035,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: isExporting ? null : () => _showExportDialog(),
          icon: isExporting
              ? SizedBox(
                  width: isTablet ? 24 : 20,
                  height: isTablet ? 24 : 20,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  Icons.download,
                  color: Colors.white,
                  size: isTablet ? 28 : 24,
                ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard(bool isTablet) {
    final role = isHOD == true
        ? 'Head of Department'
        : isHOD == false
            ? 'Faculty'
            : 'Loading...';
    final icon = isHOD == true
        ? Icons.school
        : isHOD == false
            ? Icons.person
            : Icons.person_outline;

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: isTablet ? 28 : 22,
            child: Icon(
              icon,
              color: primaryBlue,
              size: isTablet ? 28 : 22,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userData?['name'] ?? role,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 18 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: isTablet ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 8,
              vertical: isTablet ? 6 : 4,
            ),
            decoration: BoxDecoration(
              color: premiumGold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: premiumGold),
            ),
            child: Text(
              'EXPORT',
              style: TextStyle(
                color: premiumGold,
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(bool isTablet) {
    final studentsWithCgpa = students
        .where((student) => _getStudentCgpa(student['uid']) != null)
        .length;
    final studentsWithoutCgpa = _getStudentsWithoutCgpaCount();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn(
            'Total Students',
            students.length.toString(),
            isTablet,
            icon: Icons.people_rounded,
          ),
          Container(
              height: isTablet ? 50 : 40, 
              width: 1.5, 
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white10,
                    Colors.white30,
                    Colors.white10,
                  ],
                ),
              ),
          ),
          _buildStatColumn(
            'Filtered',
            filteredStudents.length.toString(),
            isTablet,
            icon: Icons.filter_list_rounded,
          ),
          Container(
              height: isTablet ? 50 : 40, 
              width: 1.5, 
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white10,
                    Colors.white30,
                    Colors.white10,
                  ],
                ),
              ),
          ),
          _buildStatColumn(
            'With CGPA',
            '$studentsWithCgpa/${students.length}',
            isTablet,
            color: successGreen,
            icon: Icons.check_circle_rounded,
          ),
          if (studentsWithoutCgpa > 0) ...[
            Container(
                height: isTablet ? 50 : 40, 
                width: 1.5, 
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white10,
                      Colors.white30,
                      Colors.white10,
                    ],
                  ),
                ),
            ),
            _buildStatColumn(
              'Pending',
              studentsWithoutCgpa.toString(),
              isTablet,
              color: const Color(0xFFFF6B6B),
              icon: Icons.pending_actions_rounded,
              isPulsing: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, bool isTablet, 
      {Color? color, IconData? icon, bool isPulsing = false}) {
    final statColor = color ?? Colors.white;
    
    return Column(
      children: [
        if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(isTablet ? 8 : 6),
            decoration: BoxDecoration(
              color: statColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: statColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: statColor,
              size: isTablet ? 20 : 18,
            ),
          ),
          SizedBox(height: isTablet ? 8 : 6),
        ],
        isPulsing
            ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: 0.5 + (value * 0.5),
                    child: child,
                  );
                },
                onEnd: () {
                  if (mounted) setState(() {});
                },
                child: Text(
                  value,
                  style: TextStyle(
                    color: statColor,
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            : Text(
                value,
                style: TextStyle(
                  color: statColor,
                  fontSize: isTablet ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: statColor.withOpacity(0.8),
            fontSize: isTablet ? 12 : 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search students by name, USN, email, or phone...',
          hintStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: isTablet ? 16 : 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: primaryBlue,
            size: isTablet ? 28 : 24,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey[600],
                    size: isTablet ? 24 : 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = '');
                    _filterStudents();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 20,
            vertical: isTablet ? 20 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isTablet) {
    final hasActiveFilters = selectedYearFilter != null ||
        selectedGenderFilter != null ||
        minCgpaFilter != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list,
                  color: Colors.white, size: isTablet ? 20 : 18),
              SizedBox(width: 8),
              Text(
                'Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: Icon(Icons.clear,
                      color: Colors.white, size: isTablet ? 18 : 16),
                  label: Text(
                    'Clear All',
                    style: TextStyle(
                        color: Colors.white, fontSize: isTablet ? 14 : 12),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFilterChip(
                label: 'Year: ${selectedYearFilter ?? "All"}',
                isActive: selectedYearFilter != null,
                onTap: () => _showYearFilterDialog(),
                isTablet: isTablet,
              ),
              _buildFilterChip(
                label: 'Gender: ${selectedGenderFilter ?? "All"}',
                isActive: selectedGenderFilter != null,
                onTap: () => _showGenderFilterDialog(),
                isTablet: isTablet,
              ),
              _buildFilterChip(
                label: minCgpaFilter != null
                    ? 'CGPA ≥ ${minCgpaFilter!.toStringAsFixed(1)}'
                    : 'CGPA: All',
                isActive: minCgpaFilter != null,
                onTap: () => _showCgpaFilterDialog(),
                isTablet: isTablet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? premiumGold : Colors.white.withOpacity(0.3),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? primaryBlue : Colors.white,
                fontSize: isTablet ? 14 : 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: isActive ? primaryBlue : Colors.white,
              size: isTablet ? 20 : 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCgpaReminderSection(bool isTablet) {
    final studentsWithoutCgpa = _getStudentsWithoutCgpaCount();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.15),
            const Color(0xFFEE5A6F).withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6B6B),
                      const Color(0xFFEE5A6F),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.assignment_late_rounded,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CGPA Calculation Pending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 10 : 8,
                            vertical: isTablet ? 4 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$studentsWithoutCgpa Student${studentsWithoutCgpa > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: const Color(0xFFFF6B6B),
                              fontSize: isTablet ? 13 : 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'haven\'t calculated their CGPA',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: isTablet ? 13 : 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isSelectionMode && selectedStudentIds.isNotEmpty) ...[
            SizedBox(height: isTablet ? 16 : 12),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 12 : 10,
              ),
              decoration: BoxDecoration(
                color: successGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: successGreen.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: successGreen,
                    size: isTablet ? 20 : 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${selectedStudentIds.length} student${selectedStudentIds.length > 1 ? 's' : ''} selected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: isTablet ? 20 : 16),
          if (!isSelectionMode)
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.send_rounded,
                    label: 'Send to All',
                    onPressed: isSendingMessages ? null : _sendCgpaRemindersToAll,
                    isPrimary: true,
                    isTablet: isTablet,
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 10),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.checklist_rounded,
                    label: 'Select Students',
                    onPressed: isSendingMessages ? null : _toggleSelectionMode,
                    isPrimary: false,
                    isTablet: isTablet,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.select_all_rounded,
                        label: 'Select All',
                        onPressed: _selectAllWithoutCgpa,
                        isPrimary: false,
                        isTablet: isTablet,
                        compact: true,
                      ),
                    ),
                    SizedBox(width: isTablet ? 10 : 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.deselect_rounded,
                        label: 'Deselect',
                        onPressed: selectedStudentIds.isEmpty ? null : _deselectAll,
                        isPrimary: false,
                        isTablet: isTablet,
                        compact: true,
                      ),
                    ),
                    SizedBox(width: isTablet ? 10 : 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.close_rounded,
                        label: 'Cancel',
                        onPressed: _toggleSelectionMode,
                        isPrimary: false,
                        isTablet: isTablet,
                        isDanger: true,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                if (selectedStudentIds.isNotEmpty) ...[
                  SizedBox(height: isTablet ? 12 : 10),
                  _buildActionButton(
                    icon: Icons.send_rounded,
                    label: 'Send Reminder to ${selectedStudentIds.length} Selected',
                    onPressed: _sendCgpaRemindersToSelected,
                    isPrimary: true,
                    isTablet: isTablet,
                    isSuccess: true,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
    required bool isTablet,
    bool isSuccess = false,
    bool isDanger = false,
    bool compact = false,
  }) {
    final isDisabled = onPressed == null;

    Color getBackgroundColor() {
      if (isDisabled) return Colors.grey.withOpacity(0.3);
      if (isPrimary) {
        if (isSuccess) return successGreen;
        return const Color(0xFFFF6B6B);
      }
      return Colors.transparent;
    }

    Color getForegroundColor() {
      if (isDisabled) return Colors.grey;
      if (isPrimary) return Colors.white;
      if (isDanger) return const Color(0xFFFF6B6B);
      return Colors.white;
    }

    return Container(
      height: compact ? (isTablet ? 44 : 40) : (isTablet ? 52 : 48),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: getBackgroundColor(),
          foregroundColor: getForegroundColor(),
          elevation: isPrimary && !isDisabled ? 4 : 0,
          shadowColor: isPrimary && !isDisabled
              ? (isSuccess ? successGreen : const Color(0xFFFF6B6B)).withOpacity(0.4)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: !isPrimary
                ? BorderSide(
                    color: getForegroundColor().withOpacity(0.5),
                    width: 1.5,
                  )
                : BorderSide.none,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 14 : 12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: compact ? (isTablet ? 18 : 16) : (isTablet ? 20 : 18)),
            SizedBox(width: isTablet ? 10 : 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact ? (isTablet ? 13 : 11) : (isTablet ? 14 : 12),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showYearFilterDialog() {
    final years = students
        .map((s) => s['yearOfPassing']?.toString())
        .where((y) => y != null)
        .toSet()
        .toList()
      ..sort();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Year of Passing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('All Years'),
              leading: Radio<String?>(
                value: null,
                groupValue: selectedYearFilter,
                onChanged: (value) {
                  setState(() => selectedYearFilter = value);
                  _filterStudents();
                  Navigator.pop(context);
                },
              ),
            ),
            ...years.map((year) => ListTile(
                  title: Text(year!),
                  leading: Radio<String?>(
                    value: year,
                    groupValue: selectedYearFilter,
                    onChanged: (value) {
                      setState(() => selectedYearFilter = value);
                      _filterStudents();
                      Navigator.pop(context);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showGenderFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Gender'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('All'),
              leading: Radio<String?>(
                value: null,
                groupValue: selectedGenderFilter,
                onChanged: (value) {
                  setState(() => selectedGenderFilter = value);
                  _filterStudents();
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: Text('Male'),
              leading: Radio<String?>(
                value: 'Male',
                groupValue: selectedGenderFilter,
                onChanged: (value) {
                  setState(() => selectedGenderFilter = value);
                  _filterStudents();
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: Text('Female'),
              leading: Radio<String?>(
                value: 'Female',
                groupValue: selectedGenderFilter,
                onChanged: (value) {
                  setState(() => selectedGenderFilter = value);
                  _filterStudents();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCgpaFilterDialog() {
    final tempController =
        TextEditingController(text: minCgpaFilter?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Minimum CGPA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tempController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Minimum CGPA',
                hintText: 'e.g., 7.5',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                _buildCgpaPreset('6.0', tempController),
                _buildCgpaPreset('7.0', tempController),
                _buildCgpaPreset('8.0', tempController),
                _buildCgpaPreset('9.0', tempController),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => minCgpaFilter = null);
              _filterStudents();
              Navigator.pop(context);
            },
            child: Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(tempController.text);
              if (value != null && value >= 0 && value <= 10) {
                setState(() => minCgpaFilter = value);
                _filterStudents();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildCgpaPreset(String value, TextEditingController controller) {
    return ActionChip(
      label: Text(value),
      onPressed: () => controller.text = value,
    );
  }

  Widget _buildExportOptions(bool isTablet) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showColumnSelectionDialog(),
            icon: Icon(Icons.view_column, size: isTablet ? 20 : 18),
            label: Text(
              'Select Columns',
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 12,
              ),
            ),
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 8,
              vertical: isTablet ? 2 : 0,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: DropdownButton<String>(
              value: selectedExportType,
              icon: Icon(Icons.arrow_drop_down, color: Colors.white),
              iconSize: isTablet ? 28 : 24,
              dropdownColor: primaryBlue,
              underline: const SizedBox(),
              isExpanded: true,
              onChanged: (String? newValue) {
                setState(() {
                  selectedExportType = newValue!;
                });
              },
              items: ['excel', 'pdf'].map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        type == 'excel'
                            ? Icons.table_chart
                            : Icons.picture_as_pdf,
                        color: Colors.white,
                        size: isTablet ? 20 : 18,
                      ),
                      SizedBox(width: isTablet ? 10 : 8),
                      Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final visibleColumns =
        allColumns.where((col) => selectedColumns.contains(col)).toList();

    if (filteredStudents.isEmpty) {
      return Container();
    }

    return Container(
      margin: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildTableToolbar(isTablet),
          _buildTableContent(visibleColumns, isTablet),
        ],
      ),
    );
  }

  Widget _buildTableToolbar(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 10,
              vertical: isTablet ? 8 : 6,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, primaryBlue.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.table_chart_rounded,
                  color: Colors.white,
                  size: isTablet ? 18 : 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Student Data Table',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (isSelectionMode) ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 12 : 10,
                vertical: isTablet ? 6 : 5,
              ),
              decoration: BoxDecoration(
                color: successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: successGreen.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: successGreen,
                    size: isTablet ? 16 : 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '${selectedStudentIds.length} Selected',
                    style: TextStyle(
                      color: successGreen,
                      fontSize: isTablet ? 13 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
          ],
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 10 : 8,
              vertical: isTablet ? 6 : 5,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_rounded,
                  color: primaryBlue,
                  size: isTablet ? 16 : 14,
                ),
                SizedBox(width: 6),
                Text(
                  '${selectedColumns.length} columns',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableContent(List<String> visibleColumns, bool isTablet) {
    final adjustedColumns = isSelectionMode 
        ? ['Select', ...visibleColumns] 
        : visibleColumns;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: SizedBox(
        height: 464,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          thickness: 6,
          radius: const Radius.circular(3),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: adjustedColumns.fold<double>(
                  0, (sum, col) => sum + _getColumnWidth(col, isTablet)),
              child: Column(
                children: [
                  _buildTableHeader(adjustedColumns, isTablet),
                  Expanded(child: _buildTableBody(adjustedColumns, isTablet)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(List<String> visibleColumns, bool isTablet) {
    return Container(
      height: isTablet ? 52 : 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1E3A8A),
            const Color(0xFF1E40AF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: visibleColumns.map((column) {
          return Container(
            width: _getColumnWidth(column, isTablet),
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: column == 'Select' 
                  ? MainAxisAlignment.center 
                  : MainAxisAlignment.start,
              children: [
                if (column != 'Select') ...[
                  Icon(
                    _getColumnIcon(column),
                    color: Colors.white.withOpacity(0.9),
                    size: isTablet ? 16 : 14,
                  ),
                  SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    column,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 13 : 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getColumnIcon(String column) {
    switch (column) {
      case 'S.No':
        return Icons.tag_rounded;
      case 'Full Name':
        return Icons.person_rounded;
      case 'USN':
        return Icons.badge_rounded;
      case 'Email':
        return Icons.email_rounded;
      case 'Phone':
        return Icons.phone_rounded;
      case 'Gender':
        return Icons.wc_rounded;
      case 'Date of Birth':
        return Icons.cake_rounded;
      case 'Year of Passing':
        return Icons.event_rounded;
      case 'University':
        return Icons.account_balance_rounded;
      case 'College':
        return Icons.school_rounded;
      case 'Course':
        return Icons.menu_book_rounded;
      case 'Branch':
        return Icons.category_rounded;
      case 'Account Status':
        return Icons.verified_user_rounded;
      case 'Registration Date':
        return Icons.calendar_today_rounded;
      case 'CGPA':
        return Icons.stars_rounded;
      default:
        if (column.startsWith('Semester')) {
          return Icons.auto_graph_rounded;
        }
        return Icons.info_rounded;
    }
  }

  Widget _buildTableBody(List<String> visibleColumns, bool isTablet) {
    return ListView.builder(
      itemCount: filteredStudents.length,
      itemBuilder: (context, index) {
        final student = filteredStudents[index];
        final studentId = student['uid'];
        final hasCgpa = _getStudentCgpa(studentId) != null;
        final isSelected = selectedStudentIds.contains(studentId);
        final isHovered = hoveredRowIndex == index;

        return MouseRegion(
          onEnter: (_) => setState(() => hoveredRowIndex = index),
          onExit: (_) => setState(() => hoveredRowIndex = null),
          child: GestureDetector(
            onTap: isSelectionMode && !hasCgpa 
                ? () => _toggleStudentSelection(studentId)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          successGreen.withOpacity(0.12),
                          successGreen.withOpacity(0.06),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: !isSelected
                    ? (isHovered
                        ? const Color(0xFFF8FAFF)
                        : index % 2 == 0
                            ? Colors.white
                            : const Color(0xFFFAFBFC))
                    : null,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 0.5,
                  ),
                  left: isSelected
                      ? BorderSide(color: successGreen, width: 4)
                      : isHovered
                          ? BorderSide(color: primaryBlue.withOpacity(0.3), width: 2)
                          : BorderSide.none,
                ),
              ),
              child: _buildTableRow(
                  index, student, visibleColumns, isTablet),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableRow(int index, Map<String, dynamic> student,
      List<String> visibleColumns, bool isTablet) {
    final studentId = student['uid'];
    final cgpa = _getStudentCgpa(studentId);
    final hasCgpa = cgpa != null;
    final isSelected = selectedStudentIds.contains(studentId);

    return SizedBox(
      height: isTablet ? 60 : 54,
      child: Row(
        children: visibleColumns.map((column) {
          if (column == 'Select') {
            return Container(
              width: _getColumnWidth(column, isTablet),
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Colors.grey.shade200,
                    width: 0.5,
                  ),
                ),
              ),
              child: Center(
                child: isSelectionMode && !hasCgpa
                    ? Transform.scale(
                        scale: isTablet ? 1.15 : 1.05,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (val) => _toggleStudentSelection(studentId),
                          activeColor: successGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          side: BorderSide(
                            color: isSelected 
                                ? successGreen 
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                      )
                    : isSelectionMode && hasCgpa
                        ? Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: successGreen,
                              size: isTablet ? 18 : 16,
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            );
          }

          final value = _getColumnValue(column, index + 1, student, cgpa);
          final isNumber = column.startsWith('Semester') ||
              column == 'CGPA' ||
              column == 'S.No';

          return Container(
            width: _getColumnWidth(column, isTablet),
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Colors.grey.shade200,
                  width: 0.5,
                ),
              ),
            ),
            child: _buildCellContent(column, value, cgpa, isNumber, isTablet),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCellContent(String column, String value, double? cgpa, bool isNumber, bool isTablet) {
    if (column == 'CGPA' && cgpa != null && value != 'N/A') {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 10,
            vertical: isTablet ? 7 : 5,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getCgpaGradient(cgpa),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _getCgpaGradient(cgpa)[0].withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.stars_rounded,
                color: Colors.white,
                size: isTablet ? 14 : 12,
              ),
              SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 13 : 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (column == 'CGPA' && value == 'N/A') {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12 : 8,
            vertical: isTablet ? 6 : 4,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF6B6B),
                const Color(0xFFEE5A6F),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: isTablet ? 13 : 11,
              ),
              SizedBox(width: 4),
              Text(
                'Pending',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 11 : 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (column == 'Account Status') {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 10 : 8,
            vertical: isTablet ? 5 : 4,
          ),
          decoration: BoxDecoration(
            color: value.toLowerCase() == 'active' 
                ? successGreen.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value.toLowerCase() == 'active' 
                  ? successGreen.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: value.toLowerCase() == 'active' 
                      ? successGreen
                      : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: value.toLowerCase() == 'active' 
                      ? successGreen
                      : Colors.grey.shade700,
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (column.startsWith('Semester') && value != '—') {
      final semCgpa = double.tryParse(value);
      if (semCgpa != null) {
        return Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 10 : 8,
              vertical: isTablet ? 5 : 4,
            ),
            decoration: BoxDecoration(
              color: _getCgpaGradient(semCgpa)[0].withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getCgpaGradient(semCgpa)[0].withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: _getCgpaGradient(semCgpa)[0],
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
    }

    if (column == 'S.No') {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 10 : 8,
            vertical: isTablet ? 5 : 4,
          ),
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 12 : 10,
              color: primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isNumber ? Alignment.center : Alignment.centerLeft,
      child: Text(
        value,
        style: TextStyle(
          fontSize: isTablet ? 13 : 11,
          color: Colors.grey.shade800,
          fontWeight: column == 'Full Name' || column == 'USN'
              ? FontWeight.w600
              : FontWeight.w500,
          height: 1.4,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  double _getColumnWidth(String column, bool isTablet) {
    final baseWidth = isTablet ? 180.0 : 140.0;
    switch (column) {
      case 'Select':
        return isTablet ? 80.0 : 60.0;
      case 'S.No':
        return isTablet ? 80.0 : 60.0;
      case 'Full Name':
        return isTablet ? 200.0 : 160.0;
      case 'USN':
        return isTablet ? 150.0 : 120.0;
      case 'Email':
        return isTablet ? 280.0 : 200.0;
      case 'Phone':
        return isTablet ? 150.0 : 120.0;
      case 'Gender':
        return isTablet ? 120.0 : 90.0;
      case 'Date of Birth':
      case 'Year of Passing':
        return isTablet ? 150.0 : 120.0;
      case 'University':
      case 'College':
        return isTablet ? 220.0 : 170.0;
      case 'Course':
      case 'Branch':
        return isTablet ? 180.0 : 140.0;
      case 'Account Status':
        return isTablet ? 160.0 : 130.0;
      case 'Registration Date':
        return isTablet ? 200.0 : 160.0;
      case 'CGPA':
        return isTablet ? 150.0 : 120.0;
      case 'Semester 1':
      case 'Semester 2':
      case 'Semester 3':
      case 'Semester 4':
      case 'Semester 5':
      case 'Semester 6':
      case 'Semester 7':
      case 'Semester 8':
        return isTablet ? 130.0 : 110.0;
      default:
        return baseWidth;
    }
  }

  List<Color> _getCgpaGradient(double cgpa) {
    if (cgpa >= 9.0) return [Colors.green.shade600, Colors.green.shade400];
    if (cgpa >= 8.0) return [Colors.green.shade500, Colors.green.shade300];
    if (cgpa >= 7.0) return [Colors.blue.shade600, Colors.blue.shade400];
    if (cgpa >= 6.0) return [Colors.orange.shade600, Colors.orange.shade400];
    if (cgpa >= 5.0) return [Colors.orange.shade500, Colors.orange.shade300];
    return [Colors.red.shade600, Colors.red.shade400];
  }

  String _getColumnValue(
      String column, int index, Map<String, dynamic> student, double? cgpa) {
    final studentId = student['uid'];

    switch (column) {
      case 'S.No':
        return index.toString();
      case 'Full Name':
        return student['fullName']?.toString().trim() ?? 'N/A';
      case 'USN':
        return student['usn']?.toString().trim().toUpperCase() ?? 'N/A';
      case 'Email':
        return student['email']?.toString().trim() ?? 'N/A';
      case 'Phone':
        return student['phone']?.toString().trim() ?? 'N/A';
      case 'Gender':
        return student['gender']?.toString().trim() ?? 'N/A';
      case 'Date of Birth':
        final dob = student['dateOfBirth'];
        if (dob == null) return 'N/A';
        if (dob is Timestamp) {
          return DateFormat('dd/MM/yyyy').format(dob.toDate());
        }
        return dob.toString().trim();
      case 'Year of Passing':
        return student['yearOfPassing']?.toString().trim() ?? 'N/A';
      case 'University':
        return student['universityName']?.toString().trim() ?? 'N/A';
      case 'College':
        return student['collegeName']?.toString().trim() ?? 'N/A';
      case 'Course':
        return student['courseName']?.toString().trim() ?? 'N/A';
      case 'Branch':
        return student['branchName']?.toString().trim() ?? 'N/A';
      case 'Account Status':
        return student['accountStatus']?.toString().trim() ?? 'N/A';
      case 'Registration Date':
        final createdAt = student['createdAt'];
        if (createdAt == null) return 'N/A';
        if (createdAt is Timestamp) {
          return DateFormat('dd/MM/yyyy').format(createdAt.toDate());
        }
        return createdAt.toString().trim();
      case 'CGPA':
        return cgpa?.toStringAsFixed(2) ?? 'N/A';
      case 'Semester 1':
        return _getSemesterCgpa(studentId, 1)?.toStringAsFixed(2) ?? '—';
      case 'Semester 2':
        return _getSemesterCgpa(studentId, 2)?.toStringAsFixed(2) ?? '—';
      case 'Semester 3':
        return _getSemesterCgpa(studentId, 3)?.toStringAsFixed(2) ?? '—';
      case 'Semester 4':
        return _getSemesterCgpa(studentId, 4)?.toStringAsFixed(2) ?? '—';
      case 'Semester 5':
        return _getSemesterCgpa(studentId, 5)?.toStringAsFixed(2) ?? '—';
      case 'Semester 6':
        return _getSemesterCgpa(studentId, 6)?.toStringAsFixed(2) ?? '—';
      case 'Semester 7':
        return _getSemesterCgpa(studentId, 7)?.toStringAsFixed(2) ?? '—';
      case 'Semester 8':
        return _getSemesterCgpa(studentId, 8)?.toStringAsFixed(2) ?? '—';
      default:
        return 'N/A';
    }
  }

  Widget _buildEmptyState() {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 16,
        vertical: isTablet ? 48 : 32,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/lottie/empty.json',
            width: isTablet ? 200 : 150,
            height: isTablet ? 200 : 150,
          ),
          SizedBox(height: isTablet ? 24 : 16),
          Text(
            searchQuery.isNotEmpty
                ? 'No students found matching "$searchQuery"'
                : 'No students found in your department',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: deepBlack.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 16 : 12),
          ElevatedButton.icon(
            onPressed: _loadUserDataAndStudents,
            icon: Icon(Icons.refresh, size: isTablet ? 20 : 18),
            label: Text(
              'Refresh Data',
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 20,
                vertical: isTablet ? 16 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableFooter() {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isTablet ? 18 : 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey.shade50,
            Colors.white,
          ],
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 10 : 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryBlue.withOpacity(0.1),
                      primaryBlue.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primaryBlue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.people_rounded,
                  color: primaryBlue,
                  size: isTablet ? 20 : 18,
                ),
              ),
              SizedBox(width: isTablet ? 12 : 10),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Showing ',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: filteredStudents.length.toString(),
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' of ',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: students.length.toString(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' students',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 12 : 10,
                  vertical: isTablet ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_column_rounded,
                      color: primaryBlue,
                      size: isTablet ? 16 : 14,
                    ),
                    SizedBox(width: isTablet ? 8 : 6),
                    Text(
                      '${selectedColumns.length} columns',
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: isTablet ? 13 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isTablet ? 12 : 10),
              Container(
                padding: EdgeInsets.all(isTablet ? 8 : 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryBlue, primaryBlue.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.table_rows_rounded,
                  color: Colors.white,
                  size: isTablet ? 18 : 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showColumnSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Select Columns',
              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: selectedColumns.length == allColumns.length,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedColumns = Set.from(allColumns);
                            } else {
                              selectedColumns.clear();
                            }
                          });
                        },
                      ),
                      Text('Select All'),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedColumns = {
                              'S.No',
                              'Full Name',
                              'USN',
                              'Email',
                              'Year of Passing',
                              'CGPA',
                            };
                          });
                        },
                        child: const Text('Basic'),
                      ),
                    ],
                  ),
                  const Divider(),
                  SizedBox(
                    height: 300,
                    child: ListView(
                      children: allColumns.map((column) {
                        return CheckboxListTile(
                          title: Text(column),
                          value: selectedColumns.contains(column),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                selectedColumns.add(column);
                              } else {
                                selectedColumns.remove(column);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  this.setState(() {});
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                ),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Export Data',
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Export ${filteredStudents.length} students as ${selectedExportType.toUpperCase()}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Selected columns: ${selectedColumns.length}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exportData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
            ),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => isExporting = true);

    try {
      if (selectedExportType == 'excel') {
        await _exportToExcel();
      } else {
        await _exportToPdf();
      }
    } catch (e) {
      Get.snackbar(
        'Export Failed',
        'Failed to export data: $e',
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        duration: const Duration(seconds: 3),
      );
    } finally {
      setState(() => isExporting = false);
    }
  }

  Future<void> _exportToExcel() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      Get.snackbar(
        'Permission Required',
        'Storage permission is needed to save the Excel file',
        backgroundColor: Colors.orange.withOpacity(0.1),
        colorText: Colors.orange,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    try {
      final excel = excel_lib.Excel.createExcel();
      excel.delete('Sheet1');
      final sheetObject = excel['Student_Details'];

      final visibleColumns =
          allColumns.where((col) => selectedColumns.contains(col)).toList();

      _setExcelHeaders(sheetObject, visibleColumns);
      _populateExcelData(sheetObject, visibleColumns);

      final fileName = _generateFileName();
      final directory = await _getStorageDirectory();
      final filePath = '${directory.path}/$fileName';

      await File(filePath).writeAsBytes(excel.encode()!);

      await Share.shareXFiles(
        [XFile(filePath)],
        text:
            'Student Details Export - ${userData?['branchName'] ?? 'Department'}',
      );

      _showExportSuccess();
    } catch (e) {
      rethrow;
    }
  }

  void _setExcelHeaders(excel_lib.Sheet sheetObject, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final cell = sheetObject.cell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = excel_lib.TextCellValue(headers[i]);
      cell.cellStyle = excel_lib.CellStyle(
          backgroundColorHex: excel_lib.ExcelColor.fromHexString('#2C387E'),
          fontColorHex: excel_lib.ExcelColor.fromHexString('#FFFFFF'),
          bold: true);
    }
  }

  void _populateExcelData(excel_lib.Sheet sheetObject, List<String> headers) {
    for (int i = 0; i < filteredStudents.length; i++) {
      final student = filteredStudents[i];
      final studentId = student['uid'];
      final cgpa = _getStudentCgpa(studentId);

      for (int j = 0; j < headers.length; j++) {
        final cell = sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(
            columnIndex: j, rowIndex: i + 1));
        cell.value = excel_lib.TextCellValue(
          _getColumnValue(headers[j], i + 1, student, cgpa),
        );
      }
    }
  }

  Future<void> _exportToPdf() async {
    try {
      final pdf = pw.Document();
      final visibleColumns =
          allColumns.where((col) => selectedColumns.contains(col)).toList();

      final headerStyle = pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 10,
      );

      final cellStyle = pw.TextStyle(
        fontSize: 9,
        color: PdfColors.black,
      );

      final data = filteredStudents.map((student) {
        final studentId = student['uid'];
        final cgpa = _getStudentCgpa(studentId);
        return visibleColumns
            .map((col) => _getColumnValue(
                col, filteredStudents.indexOf(student) + 1, student, cgpa))
            .toList();
      }).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(primaryBlue.value),
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(8),
                      topRight: pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        'Student Details Report',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Spacer(),
                      pw.Text(
                        'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(
                          color: PdfColor.fromInt(0xFFFFFFCC),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Branch: ${userData?['branchName'] ?? 'N/A'} | Total Students: ${filteredStudents.length}',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Faculty/HOD: ${userData?['name'] ?? 'N/A'}',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
                pw.Expanded(
                  child: pw.Table.fromTextArray(
                    headerStyle: headerStyle,
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(primaryBlue.value),
                    ),
                    cellStyle: cellStyle,
                    cellAlignments: Map.fromIterables(
                      List.generate(visibleColumns.length, (i) => i),
                      List.generate(
                          visibleColumns.length,
                          (i) => visibleColumns[i] == 'CGPA' ||
                                  visibleColumns[i].startsWith('Semester')
                              ? pw.Alignment.center
                              : pw.Alignment.centerLeft),
                    ),
                    headers: visibleColumns,
                    data: data,
                    border: pw.TableBorder.all(
                      color: PdfColors.grey300,
                      width: 0.5,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        'Note: CGPA color coding: ',
                        style: pw.TextStyle(fontSize: 9),
                      ),
                      pw.Container(
                        width: 10,
                        height: 10,
                        color: PdfColors.green,
                        margin: const pw.EdgeInsets.only(right: 4),
                      ),
                      pw.Text('9.0+ ', style: pw.TextStyle(fontSize: 9)),
                      pw.Container(
                        width: 10,
                        height: 10,
                        color: PdfColors.blue,
                        margin: const pw.EdgeInsets.only(right: 4, left: 8),
                      ),
                      pw.Text('7.0-8.9 ', style: pw.TextStyle(fontSize: 9)),
                      pw.Container(
                        width: 10,
                        height: 10,
                        color: PdfColors.orange,
                        margin: const pw.EdgeInsets.only(right: 4, left: 8),
                      ),
                      pw.Text('5.0-6.9 ', style: pw.TextStyle(fontSize: 9)),
                      pw.Container(
                        width: 10,
                        height: 10,
                        color: PdfColors.red,
                        margin: const pw.EdgeInsets.only(right: 4, left: 8),
                      ),
                      pw.Text('<5.0', style: pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final fileName = _generateFileName().replaceAll('.xlsx', '.pdf');
      final filePath = '${output.path}/$fileName';

      await File(filePath).writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(filePath)],
        text:
            'Student Details PDF Export - ${userData?['branchName'] ?? 'Department'}',
      );

      _showExportSuccess();
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    if (androidInfo.version.sdkInt >= 33) return true;
    if (androidInfo.version.sdkInt >= 30) {
      final status = await Permission.manageExternalStorage.request();
      return status == PermissionStatus.granted;
    }

    final status = await Permission.storage.request();
    return status == PermissionStatus.granted;
  }

  Future<Directory> _getStorageDirectory() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt < 29) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          return downloadsDir;
        }
      }
      return await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  String _generateFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final branchName =
        userData?['branchName']?.replaceAll(' ', '_') ?? 'Branch';
    final type = selectedExportType == 'excel' ? 'xlsx' : 'pdf';
    return 'student_details_${branchName}_$timestamp.$type';
  }

  void _showExportSuccess() {
    Get.snackbar(
      'Export Successful',
      'File saved and ready to share',
      backgroundColor: Colors.green.withOpacity(0.1),
      colorText: Colors.green,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    if (isLoading) {
      return _buildLoadingScreen(isTablet);
    }

    return Scaffold(
      backgroundColor: lightGray,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
            if (filteredStudents.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      _buildTable(),
                      _buildTableFooter(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(bool isTablet) {
    return Scaffold(
      backgroundColor: lightGray,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/loading.json',
              width: isTablet ? 200 : 150,
              height: isTablet ? 200 : 150,
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Text(
              'Loading Student Data...',
              style: TextStyle(
                fontSize: isTablet ? 22 : 18,
                color: deepBlack,
              ),
            ),
            if (userData != null) ...[
              SizedBox(height: isTablet ? 16 : 10),
              Text(
                'Department: ${userData!['branchName'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: deepBlack.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}