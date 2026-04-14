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
import '../services/mentor_chatmate_integration_service.dart';

class MentorMenteeManagementPage extends StatefulWidget {
  const MentorMenteeManagementPage({super.key});

  @override
  State<MentorMenteeManagementPage> createState() =>
      _MentorMenteeManagementPageState();
}

class _MentorMenteeManagementPageState
    extends State<MentorMenteeManagementPage> with TickerProviderStateMixin {
  static const primaryBlue = Color(0xFF0A1E42);
  static const accentBlue = Color(0xFF1A3A6B);
  static const lightBlue = Color(0xFF2E5C9A);
  static const deepBlack = Color(0xFF121212);
  static const lightGray = Color(0xFFF8F9FA);
  static const premiumGold = Color(0xFFD4AF37);
  static const cardWhite = Color(0xFFFFFFFF);
  static const successGreen = Color(0xFF2ECC71);
  static const warningOrange = Color(0xFFF39C12);
  static const dangerRed = Color(0xFFE74C3C);

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> allStudents = [];
  List<Map<String, dynamic>> menteeStudents = [];
  List<Map<String, dynamic>> availableStudents = [];
  List<Map<String, dynamic>> meetings = [];
  Map<String, Map<String, dynamic>> studentCgpaData = {};
  Map<String, List<Map<String, dynamic>>> studentProgressData = {};

  bool isLoading = true;
  bool isProcessing = false;
  String? selectedYearFilter;
  int selectedTabIndex = 0;
  String searchQuery = '';

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserDataAndStudents();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _fadeController.forward();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadUserDataAndStudents() async {
    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackbar('No user logged in');
        setState(() => isLoading = false);
        return;
      }

      DocumentSnapshot facultyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .doc(user.uid)
          .get();

      if (facultyDoc.exists) {
        userData = facultyDoc.data() as Map<String, dynamic>;
        userData!['uid'] = user.uid;
      } else {
        DocumentSnapshot hodDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc('department_head')
            .collection('data')
            .doc(user.uid)
            .get();

        if (hodDoc.exists) {
          userData = hodDoc.data() as Map<String, dynamic>;
          userData!['uid'] = user.uid;
        } else {
          _showErrorSnackbar('User data not found');
          setState(() => isLoading = false);
          return;
        }
      }

      await Future.wait([
        _loadAllStudents(),
        _loadMenteeStudents(),
        _loadMeetings(),
      ]);
    } catch (e) {
      _showErrorSnackbar('Failed to load data: $e');
      debugPrint('Error in _loadUserDataAndStudents: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAllStudents() async {
    if (userData == null) return;

    try {
      Query studentsQuery = FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .where('accountStatus', isEqualTo: 'active');

      if (userData!['collegeId'] != null) {
        studentsQuery = studentsQuery.where('collegeId', isEqualTo: userData!['collegeId']);
      }

      if (userData!['courseId'] != null) {
        studentsQuery = studentsQuery.where('courseId', isEqualTo: userData!['courseId']);
      }

      if (userData!['branchId'] != null) {
        studentsQuery = studentsQuery.where('branchId', isEqualTo: userData!['branchId']);
      }

      QuerySnapshot snapshot = await studentsQuery.get();

      allStudents = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['uid'] = doc.id;
        return data;
      }).toList();

      allStudents.sort((a, b) {
        final nameA = (a['fullName'] ?? '').toString().toLowerCase();
        final nameB = (b['fullName'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      await _loadCgpaData();
    } catch (e) {
      debugPrint('Error loading students: $e');
    }
  }

  Future<void> _loadMenteeStudents() async {
    if (userData == null) return;

    try {
      QuerySnapshot menteeQuery = await FirebaseFirestore.instance
          .collection('mentor_mentee')
          .where('mentorId', isEqualTo: userData!['uid'])
          .where('status', isEqualTo: 'active')
          .get();

      final menteeIds =
          menteeQuery.docs.map((doc) => doc['studentId'] as String).toList();

      QuerySnapshot allMenteesQuery = await FirebaseFirestore.instance
          .collection('mentor_mentee')
          .where('status', isEqualTo: 'active')
          .get();

      final allAssignedStudentIds = allMenteesQuery.docs
          .map((doc) => doc['studentId'] as String)
          .toSet();

      if (menteeIds.isEmpty) {
        menteeStudents = [];
        availableStudents = allStudents
            .where((s) => !allAssignedStudentIds.contains(s['uid']))
            .toList();
        return;
      }

      menteeStudents =
          allStudents.where((s) => menteeIds.contains(s['uid'])).toList();
      availableStudents = allStudents
          .where((s) => !allAssignedStudentIds.contains(s['uid']))
          .toList();

      await Future.wait(
        menteeStudents.map((student) => _loadStudentProgress(student['uid']))
      );
    } catch (e) {
      debugPrint('Error in _loadMenteeStudents: $e');
    }
  }

  Future<void> _loadCgpaData() async {
    if (allStudents.isEmpty) return;

    try {
      await Future.wait(allStudents.map((student) async {
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
      }));
    } catch (e) {
      debugPrint('Error loading CGPA data: $e');
    }
  }

  Future<void> _loadStudentProgress(String studentId) async {
    try {
      final menteeSnapshot = await FirebaseFirestore.instance
          .collection('mentor_mentee')
          .where('studentId', isEqualTo: studentId)
          .where('mentorId', isEqualTo: userData!['uid'])
          .where('status', isEqualTo: 'active')
          .get();

      if (menteeSnapshot.docs.isEmpty) {
        studentProgressData[studentId] = [];
        return;
      }

      final menteeDocRef = menteeSnapshot.docs.first.reference;

      QuerySnapshot progressQuery = await menteeDocRef
          .collection('progress_reports')
          .orderBy('semester', descending: true)
          .get();

      studentProgressData[studentId] = progressQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error loading student progress: $e');
      studentProgressData[studentId] = [];
    }
  }

  Future<void> _loadMeetings() async {
    if (userData == null) return;

    try {
      QuerySnapshot meetingsQuery = await FirebaseFirestore.instance
          .collection('mentor_meetings')
          .where('mentorId', isEqualTo: userData!['uid'])
          .orderBy('scheduledDate', descending: true)
          .limit(20)
          .get();

      meetings = meetingsQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Failed to load meetings: $e');
    }
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

  List<Map<String, dynamic>> _getFilteredStudents(List<Map<String, dynamic>> students) {
    return students.where((student) {
      if (searchQuery.isNotEmpty) {
        final name = (student['fullName'] ?? '').toString().toLowerCase();
        final usn = (student['usn'] ?? '').toString().toLowerCase();
        final email = (student['email'] ?? '').toString().toLowerCase();
        final query = searchQuery.toLowerCase();
        
        if (!name.contains(query) && 
            !usn.contains(query) && 
            !email.contains(query)) {
          return false;
        }
      }

      if (selectedYearFilter != null) {
        final year = student['yearOfPassing']?.toString();
        if (year != selectedYearFilter) return false;
      }

      return true;
    }).toList();
  }

  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'Success',
      message,
      backgroundColor: successGreen.withOpacity(0.1),
      colorText: successGreen,
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
      icon: const Icon(Icons.check_circle, color: successGreen),
    );
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

  Widget _buildHeader(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, accentBlue, lightBlue],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: Column(
            children: [
              _buildHeaderRow(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              _buildUserInfoCard(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              _buildStatsCards(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              _buildTabSelector(isTablet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(bool isTablet) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Get.back(),
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: isTablet ? 24 : 20,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'Mentor-Mentee Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 24 : 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'Track Progress & Schedule Meetings',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: isTablet ? 14 : 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _showQuickActions(isTablet),
          icon: Icon(
            Icons.more_vert,
            color: Colors.white,
            size: isTablet ? 24 : 20,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: premiumGold,
            radius: isTablet ? 24 : 20,
            child: Icon(
              Icons.person,
              color: primaryBlue,
              size: isTablet ? 28 : 24,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userData?['name'] ?? 'Faculty',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${userData?['branchName'] ?? 'Department'} • Mentor',
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
              color: successGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: successGreen),
            ),
            child: Text(
              '${menteeStudents.length} Mentees',
              style: TextStyle(
                color: successGreen,
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isTablet) {
    final upcomingMeetings =
        meetings.where((m) => _isMeetingUpcoming(m)).length;
    final completedMeetings =
        meetings.where((m) => m['status'] == 'completed').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Mentees',
            menteeStudents.length.toString(),
            Icons.people,
            successGreen,
            isTablet,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: _buildStatCard(
            'Upcoming',
            upcomingMeetings.toString(),
            Icons.event,
            warningOrange,
            isTablet,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            completedMeetings.toString(),
            Icons.check_circle,
            lightBlue,
            isTablet,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isTablet ? 28 : 24),
          SizedBox(height: isTablet ? 8 : 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: isTablet ? 12 : 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(bool isTablet) {
    final tabs = [
      {'label': 'My Mentees', 'icon': Icons.people},
      {'label': 'Add Students', 'icon': Icons.person_add},
      {'label': 'Meetings', 'icon': Icons.event},
      {'label': 'Reports', 'icon': Icons.assessment},
    ];

    return Container(
      height: isTablet ? 60 : 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedTabIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.all(isTablet ? 6 : 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[index]['icon'] as IconData,
                      color: isSelected ? primaryBlue : Colors.white70,
                      size: isTablet ? 22 : 18,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tabs[index]['label'] as String,
                      style: TextStyle(
                        color: isSelected ? primaryBlue : Colors.white70,
                        fontSize: isTablet ? 11 : 9,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isTablet) {
    final years = allStudents
        .map((s) => s['yearOfPassing']?.toString())
        .where((y) => y != null)
        .toSet()
        .toList()
      ..sort();

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, USN, or email...',
              hintStyle: TextStyle(fontSize: isTablet ? 14 : 12),
              prefixIcon: const Icon(Icons.search, color: primaryBlue),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: lightGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: lightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String?>(
                    value: selectedYearFilter,
                    hint: const Text('All Years'),
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: primaryBlue),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Years')),
                      ...years.map((year) => DropdownMenuItem(
                            value: year,
                            child: Text(year!),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => selectedYearFilter = value);
                    },
                  ),
                ),
              ),
              if (selectedYearFilter != null || searchQuery.isNotEmpty) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      selectedYearFilter = null;
                      searchQuery = '';
                      _searchController.clear();
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dangerRed,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 16 : 12,
                      vertical: isTablet ? 14 : 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyMenteesTab(bool isTablet) {
    final filteredMentees = _getFilteredStudents(menteeStudents);

    if (filteredMentees.isEmpty) {
      return _buildEmptyState(
        'No mentees assigned',
        'Add students to start mentoring',
        'assets/lottie/empty.json',
        isTablet,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      itemCount: filteredMentees.length,
      itemBuilder: (context, index) {
        return _buildMenteeCard(filteredMentees[index], isTablet);
      },
    );
  }

  Widget _buildMenteeCard(Map<String, dynamic> student, bool isTablet) {
    final cgpa = _getStudentCgpa(student['uid']);
    final progressReports = studentProgressData[student['uid']] ?? [];

    return Card(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showStudentDetailsDialog(student, isTablet),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primaryBlue.withOpacity(0.1),
                    radius: isTablet ? 28 : 24,
                    child: Text(
                      student['fullName']?.toString().substring(0, 1) ?? 'S',
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['fullName'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: deepBlack,
                          ),
                        ),
                        Text(
                          student['usn']?.toString().toUpperCase() ?? 'N/A',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cgpa != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 8,
                        vertical: isTablet ? 8 : 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getCgpaGradient(cgpa),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            cgpa.toStringAsFixed(2),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'CGPA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 10 : 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: isTablet ? 16 : 12),
              Wrap(
                spacing: isTablet ? 12 : 8,
                runSpacing: isTablet ? 8 : 6,
                children: [
                  _buildInfoChip(
                    Icons.calendar_today,
                    'Year: ${student['yearOfPassing'] ?? 'N/A'}',
                    isTablet,
                  ),
                  _buildInfoChip(
                    Icons.phone,
                    student['phone'] ?? 'N/A',
                    isTablet,
                  ),
                  _buildInfoChip(
                    Icons.assignment,
                    '${progressReports.length} Reports',
                    isTablet,
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 12 : 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addProgressReport(student, isTablet),
                      icon: Icon(Icons.add, size: isTablet ? 18 : 16),
                      label: Text(
                        'Add Report',
                        style: TextStyle(fontSize: isTablet ? 14 : 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryBlue,
                        side: const BorderSide(color: primaryBlue),
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 12 : 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showStudentDetailsDialog(student, isTablet),
                      icon: Icon(Icons.visibility, size: isTablet ? 18 : 16),
                      label: Text(
                        'View Details',
                        style: TextStyle(fontSize: isTablet ? 14 : 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 12 : 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removeMentee(student['uid']),
                    icon: const Icon(Icons.remove_circle, color: dangerRed),
                    tooltip: 'Remove Mentee',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 8,
        vertical: isTablet ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: lightGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isTablet ? 14 : 12, color: primaryBlue),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 12 : 10,
              color: deepBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddStudentsTab(bool isTablet) {
    final filteredAvailable = _getFilteredStudents(availableStudents);

    if (allStudents.isEmpty) {
      return _buildEmptyState(
        'No Students Found',
        'No active students found for your department',
        'assets/lottie/empty.json',
        isTablet,
        action: ElevatedButton.icon(
          onPressed: () {
            setState(() => isLoading = true);
            _loadUserDataAndStudents();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 20,
              vertical: isTablet ? 16 : 12,
            ),
          ),
        ),
      );
    }

    if (filteredAvailable.isEmpty) {
      return _buildEmptyState(
        'No Students Available',
        'All filtered students are already assigned to mentors',
        'assets/lottie/empty.json',
        isTablet,
        action: (selectedYearFilter != null || searchQuery.isNotEmpty)
            ? OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    selectedYearFilter = null;
                    searchQuery = '';
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBlue,
                  side: const BorderSide(color: primaryBlue),
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 20,
                    vertical: isTablet ? 16 : 12,
                  ),
                ),
              )
            : null,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      itemCount: filteredAvailable.length,
      itemBuilder: (context, index) {
        return _buildAvailableStudentCard(filteredAvailable[index], isTablet);
      },
    );
  }

  Widget _buildAvailableStudentCard(Map<String, dynamic> student, bool isTablet) {
    final cgpa = _getStudentCgpa(student['uid']);

    return Card(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 16 : 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: lightBlue.withOpacity(0.2),
              radius: isTablet ? 24 : 20,
              child: Text(
                student['fullName']?.toString().substring(0, 1) ?? 'S',
                style: TextStyle(
                  color: primaryBlue,
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: isTablet ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['fullName'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${student['usn']?.toString().toUpperCase() ?? 'N/A'} • ${student['yearOfPassing'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: isTablet ? 13 : 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (cgpa != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCgpaGradient(cgpa)[0].withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'CGPA: ${cgpa.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          color: _getCgpaGradient(cgpa)[0],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: isProcessing ? null : () => _addMentee(student['uid']),
              icon: Icon(Icons.add, size: isTablet ? 18 : 16),
              label: Text(
                'Add',
                style: TextStyle(fontSize: isTablet ? 14 : 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: successGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 16 : 12,
                  vertical: isTablet ? 12 : 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingsTab(bool isTablet) {
    if (meetings.isEmpty) {
      return _buildEmptyState(
        'No meetings scheduled',
        'Schedule your first meeting',
        'assets/lottie/empty.json',
        isTablet,
        action: ElevatedButton.icon(
          onPressed: () => _scheduleMeeting(isTablet),
          icon: const Icon(Icons.add),
          label: const Text('Schedule Meeting'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 20,
              vertical: isTablet ? 16 : 12,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        return _buildMeetingCard(meetings[index], isTablet);
      },
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting, bool isTablet) {
    final isUpcoming = _isMeetingUpcoming(meeting);
    final date = (meeting['scheduledDate'] as Timestamp).toDate();
    final status = meeting['status'] ?? 'scheduled';

    return Card(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showMeetingDetailsDialog(meeting, isTablet),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: isUpcoming
                          ? warningOrange.withOpacity(0.1)
                          : successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isUpcoming ? Icons.event : Icons.event_available,
                      color: isUpcoming ? warningOrange : successGreen,
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meeting['title'] ?? 'Mentor Meeting',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEE, dd MMM yyyy • hh:mm a').format(date),
                          style: TextStyle(
                            fontSize: isTablet ? 13 : 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status, isTablet),
                ],
              ),
              if (meeting['description'] != null) ...[
                SizedBox(height: isTablet ? 12 : 8),
                Text(
                  meeting['description'],
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: isTablet ? 12 : 8),
              Row(
                children: [
                  const Icon(Icons.people, size: 16, color: primaryBlue),
                  const SizedBox(width: 4),
                  Text(
                    '${meeting['attendees']?.length ?? 0} Attendees',
                    style: const TextStyle(
                      fontSize: 13,
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (isUpcoming) ...[
                    IconButton(
                      onPressed: () => _addMeetingParticipants(meeting, isTablet),
                      icon: const Icon(Icons.person_add, size: 20),
                      tooltip: 'Add Participants',
                      color: lightBlue,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _completeMeeting(meeting['id']),
                      icon: const Icon(Icons.check_circle, size: 20),
                      tooltip: 'Mark Complete',
                      color: successGreen,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteMeeting(meeting['id'], meeting['title']),
                      icon: const Icon(Icons.delete, size: 20),
                      tooltip: 'Delete Meeting',
                      color: dangerRed,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ] else ...[
                    IconButton(
                      onPressed: () => _deleteMeeting(meeting['id'], meeting['title']),
                      icon: const Icon(Icons.delete, size: 20),
                      tooltip: 'Delete Meeting',
                      color: dangerRed,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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

  Widget _buildStatusBadge(String status, bool isTablet) {
    Color color;
    String label;

    switch (status) {
      case 'completed':
        color = successGreen;
        label = 'Completed';
        break;
      case 'cancelled':
        color = dangerRed;
        label = 'Cancelled';
        break;
      default:
        color = warningOrange;
        label = 'Scheduled';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 8,
        vertical: isTablet ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: isTablet ? 11 : 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReportsTab(bool isTablet) {
    if (menteeStudents.isEmpty) {
      return _buildEmptyState(
        'No reports available',
        'Add mentees to track progress',
        'assets/lottie/empty.json',
        isTablet,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      itemCount: menteeStudents.length,
      itemBuilder: (context, index) {
        final student = menteeStudents[index];
        final reports = studentProgressData[student['uid']] ?? [];
        return _buildReportCard(student, reports, isTablet);
      },
    );
  }

  Widget _buildReportCard(Map<String, dynamic> student,
      List<Map<String, dynamic>> reports, bool isTablet) {
    return Card(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: primaryBlue.withOpacity(0.1),
          child: Text(
            student['fullName']?.toString().substring(0, 1) ?? 'S',
            style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          student['fullName'] ?? 'N/A',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${reports.length} Reports Available',
          style: TextStyle(fontSize: isTablet ? 13 : 11),
        ),
        children: reports.isEmpty
            ? [
                Padding(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  child: Text(
                    'No reports added yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ]
            : reports.map((report) {
                return ListTile(
                  leading: const Icon(Icons.assignment, color: lightBlue),
                  title: Text('Semester ${report['semester']}'),
                  subtitle: Text(report['remarks'] ?? 'No remarks'),
                  trailing: IconButton(
                    icon: const Icon(Icons.visibility, color: primaryBlue),
                    onPressed: () =>
                        _showReportDetailsDialog(student, report, isTablet),
                  ),
                );
              }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, String animationPath,
      bool isTablet, {Widget? action}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: isTablet ? 200 : 150,
              child: Lottie.asset(animationPath),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            Text(
              title,
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: deepBlack,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 8 : 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              SizedBox(height: isTablet ? 24 : 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  List<Color> _getCgpaGradient(double cgpa) {
    if (cgpa >= 9.0) return [Colors.green.shade600, Colors.green.shade400];
    if (cgpa >= 8.0) return [Colors.green.shade500, Colors.green.shade300];
    if (cgpa >= 7.0) return [Colors.blue.shade600, Colors.blue.shade400];
    if (cgpa >= 6.0) return [Colors.orange.shade600, Colors.orange.shade400];
    if (cgpa >= 5.0) return [Colors.orange.shade500, Colors.orange.shade300];
    return [Colors.red.shade600, Colors.red.shade400];
  }

  bool _isMeetingUpcoming(Map<String, dynamic> meeting) {
    final date = (meeting['scheduledDate'] as Timestamp).toDate();
    return date.isAfter(DateTime.now()) && meeting['status'] != 'completed';
  }

  Future<void> _addMentee(String studentId) async {
    if (isProcessing) return;

    try {
      setState(() => isProcessing = true);

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
                    child: Lottie.asset('assets/lottie/loading.json'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Adding mentee...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      await FirebaseFirestore.instance.collection('mentor_mentee').add({
        'mentorId': userData!['uid'],
        'studentId': studentId,
        'status': 'active',
        'assignedDate': FieldValue.serverTimestamp(),
      });

      final student = allStudents.firstWhere((s) => s['uid'] == studentId);
      final studentName = student['fullName'] ?? 'Student';
      final branchName = userData!['branchName'] ?? 'Department';
      final yearOfPassing = student['yearOfPassing']?.toString() ?? '';

      final success = await MentorChatMateIntegrationService.establishMentorshipConnection(
        mentorId: userData!['uid'],
        studentId: studentId,
        branchName: branchName,
      );

      if (yearOfPassing.isNotEmpty) {
        await _updateYearWiseChannel();
      }

      await _loadMenteeStudents();

      Get.back();

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
                  Text('$studentName added as mentee!'),
                ],
              ),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      Get.back();

      setState(() {});
    } catch (e) {
      Get.back();
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
                    child: Lottie.asset('assets/lottie/error.json'),
                  ),
                  const SizedBox(height: 16),
                  Text('Failed to add mentee: $e'),
                ],
              ),
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      Get.back();
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _removeMentee(String studentId) async {
    final student = menteeStudents.firstWhere((s) => s['uid'] == studentId);
    final studentName = student['fullName'] ?? 'Student';

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Remove Mentee?'),
        content: Text('Are you sure you want to remove $studentName?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: dangerRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => isProcessing = true);

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
                    child: Lottie.asset('assets/lottie/loading.json'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Removing mentee...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final docs = await FirebaseFirestore.instance
          .collection('mentor_mentee')
          .where('mentorId', isEqualTo: userData!['uid'])
          .where('studentId', isEqualTo: studentId)
          .get();

      for (var doc in docs.docs) {
        await doc.reference.update({
          'status': 'inactive',
          'removedAt': FieldValue.serverTimestamp(),
        });
      }

      final mentorName = userData!['name'] ?? 'Your Mentor';

      await MentorChatMateIntegrationService.notifyMenteeRemoval(
        mentorId: userData!['uid'],
        mentorName: mentorName,
        studentId: studentId,
        studentName: studentName,
      );

      await _loadMenteeStudents();

      Get.back();

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
                  const Text('Mentee removed successfully!'),
                ],
              ),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      Get.back();

      setState(() {});
    } catch (e) {
      Get.back();
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
                    child: Lottie.asset('assets/lottie/error.json'),
                  ),
                  const SizedBox(height: 16),
                  Text('Failed to remove mentee: $e'),
                ],
              ),
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      Get.back();
    } finally {
      setState(() => isProcessing = false);
    }
  }

  void _addProgressReport(Map<String, dynamic> student, bool isTablet) {
    final semesterController = TextEditingController();
    final cgpaController = TextEditingController();
    final attendanceController = TextEditingController();
    final remarksController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Add Progress Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: semesterController,
                decoration: const InputDecoration(
                  labelText: 'Semester (1-8) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cgpaController,
                decoration: const InputDecoration(
                  labelText: 'CGPA (0-10)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: attendanceController,
                decoration: const InputDecoration(
                  labelText: 'Attendance % (0-100)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final semester = semesterController.text.trim();
              if (semester.isEmpty) {
                _showErrorSnackbar('Please enter semester');
                return;
              }

              final semesterNum = int.tryParse(semester);
              if (semesterNum == null || semesterNum < 1 || semesterNum > 8) {
                _showErrorSnackbar('Semester must be between 1 and 8');
                return;
              }

              double? cgpaValue;
              if (cgpaController.text.isNotEmpty) {
                cgpaValue = double.tryParse(cgpaController.text);
                if (cgpaValue == null || cgpaValue < 0 || cgpaValue > 10) {
                  _showErrorSnackbar('CGPA must be between 0 and 10');
                  return;
                }
              }

              int? attendanceValue;
              if (attendanceController.text.isNotEmpty) {
                attendanceValue = int.tryParse(attendanceController.text);
                if (attendanceValue == null || attendanceValue < 0 || attendanceValue > 100) {
                  _showErrorSnackbar('Attendance must be between 0 and 100');
                  return;
                }
              }

              Get.back();

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
                            child: Lottie.asset('assets/lottie/loading.json'),
                          ),
                          const SizedBox(height: 16),
                          const Text('Adding report...'),
                        ],
                      ),
                    ),
                  ),
                ),
                barrierDismissible: false,
              );

              try {
                final menteeSnapshot = await FirebaseFirestore.instance
                    .collection('mentor_mentee')
                    .where('mentorId', isEqualTo: userData!['uid'])
                    .where('studentId', isEqualTo: student['uid'])
                    .where('status', isEqualTo: 'active')
                    .get();

                if (menteeSnapshot.docs.isEmpty) {
                  Get.back();
                  _showErrorSnackbar('Mentee not found');
                  return;
                }

                final menteeDocRef = menteeSnapshot.docs.first.reference;

                await menteeDocRef.collection('progress_reports').add({
                  'semester': semesterNum,
                  'cgpa': cgpaValue,
                  'attendance': attendanceValue,
                  'remarks': remarksController.text.isEmpty ? null : remarksController.text,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': userData!['name'] ?? 'Unknown',
                });

                await MentorChatMateIntegrationService.notifyProgressReportAdded(
                  mentorId: userData!['uid'],
                  mentorName: userData!['name'] ?? 'Your Mentor',
                  studentId: student['uid'],
                  studentName: student['fullName'] ?? 'Student',
                  semester: semesterNum,
                  cgpa: cgpaValue,
                  attendance: attendanceValue,
                  remarks: remarksController.text.isEmpty ? null : remarksController.text,
                );

                await _loadStudentProgress(student['uid']);

                Get.back();

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
                            const Text('Report added successfully!'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                await Future.delayed(const Duration(seconds: 2));
                Get.back();

                setState(() {});
              } catch (e) {
                Get.back();
                _showErrorSnackbar('Failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _scheduleMeeting(bool isTablet) async {
    if (menteeStudents.isEmpty) {
      _showErrorSnackbar('No mentees available to schedule a meeting');
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    List<String> selectedAttendees = [];

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Schedule Meeting'),
          content: SizedBox(
            width: isTablet ? 500 : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 100,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setState(() => selectedDate = date);
                    },
                  ),
                  ListTile(
                    title: const Text('Time'),
                    subtitle: Text(selectedTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) setState(() => selectedTime = time);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Attendees *', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: menteeStudents.length,
                      itemBuilder: (context, index) {
                        final student = menteeStudents[index];
                        return CheckboxListTile(
                          title: Text(student['fullName'] ?? 'N/A'),
                          subtitle: Text(student['usn'] ?? ''),
                          value: selectedAttendees.contains(student['uid']),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedAttendees.add(student['uid']);
                              } else {
                                selectedAttendees.remove(student['uid']);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  _showErrorSnackbar('Please enter a title');
                  return;
                }
                if (selectedAttendees.isEmpty) {
                  _showErrorSnackbar('Please select at least one attendee');
                  return;
                }

                final meetingDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                if (meetingDateTime.isBefore(DateTime.now())) {
                  _showErrorSnackbar('Meeting time must be in the future');
                  return;
                }

                Get.back();

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
                              child: Lottie.asset('assets/lottie/loading.json'),
                            ),
                            const SizedBox(height: 16),
                            const Text('Scheduling meeting...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  barrierDismissible: false,
                );

                try {
                  final meetingId = DateTime.now().millisecondsSinceEpoch.toString();

                  await FirebaseFirestore.instance
                      .collection('mentor_meetings')
                      .doc(meetingId)
                      .set({
                    'id': meetingId,
                    'mentorId': userData!['uid'],
                    'mentorName': userData!['name'] ?? 'Unknown',
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    'scheduledDate': Timestamp.fromDate(meetingDateTime),
                    'attendees': selectedAttendees,
                    'status': 'scheduled',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  await MentorChatMateIntegrationService.notifyMeetingScheduled(
                    mentorId: userData!['uid'],
                    mentorName: userData!['name'] ?? 'Your Mentor',
                    studentIds: selectedAttendees,
                    meetingTitle: titleController.text.trim(),
                    meetingDescription: descriptionController.text.trim(),
                    meetingDate: meetingDateTime,
                  );

                  await _loadMeetings();

                  Get.back();

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
                              const Text('Meeting scheduled successfully!'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  await Future.delayed(const Duration(seconds: 2));
                  Get.back();

                  setState(() {});
                } catch (e) {
                  Get.back();
                  _showErrorSnackbar('Failed: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateYearWiseChannel() async {
    try {
      if (userData == null || menteeStudents.isEmpty) return;

      final Map<String, List<String>> yearWiseStudents = {};

      for (final student in menteeStudents) {
        final year = student['yearOfPassing']?.toString();
        if (year != null && year.isNotEmpty) {
          yearWiseStudents.putIfAbsent(year, () => []);
          yearWiseStudents[year]!.add(student['uid']);
        }
      }

      await MentorChatMateIntegrationService.createAllYearChannels(
        mentorId: userData!['uid'],
        mentorName: userData!['name'] ?? 'Your Mentor',
        branchName: userData!['branchName'] ?? 'Department',
        yearWiseStudents: yearWiseStudents,
      );
    } catch (e) {
      debugPrint('Error updating year-wise channel: $e');
    }
  }

  Future<void> _completeMeeting(String meetingId) async {
    try {
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
                    child: Lottie.asset('assets/lottie/loading.json'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Completing meeting...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final meetingDoc = await FirebaseFirestore.instance
          .collection('mentor_meetings')
          .doc(meetingId)
          .get();

      if (!meetingDoc.exists) {
        Get.back();
        _showErrorSnackbar('Meeting not found');
        return;
      }

      await FirebaseFirestore.instance
          .collection('mentor_meetings')
          .doc(meetingId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      await _loadMeetings();

      Get.back();

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
                  const Text('Meeting marked as completed!'),
                ],
              ),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      Get.back();

      setState(() {});
    } catch (e) {
      Get.back();
      _showErrorSnackbar('Failed to update meeting: $e');
    }
  }

  Future<void> _addMeetingParticipants(Map<String, dynamic> meeting, bool isTablet) async {
    final currentAttendees = List<String>.from(meeting['attendees'] ?? []);
    final availableMentees = menteeStudents
        .where((student) => !currentAttendees.contains(student['uid']))
        .toList();

    if (availableMentees.isEmpty) {
      _showErrorSnackbar('All mentees are already added to this meeting');
      return;
    }

    List<String> newAttendees = [];

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Participants'),
          content: SizedBox(
            width: isTablet ? 500 : double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Meeting: ${meeting['title']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select students to add:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: availableMentees.isEmpty
                      ? const Center(
                          child: Text('All mentees are already participants'),
                        )
                      : ListView.builder(
                          itemCount: availableMentees.length,
                          itemBuilder: (context, index) {
                            final student = availableMentees[index];
                            return CheckboxListTile(
                              title: Text(student['fullName'] ?? 'N/A'),
                              subtitle: Text(student['usn'] ?? ''),
                              value: newAttendees.contains(student['uid']),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    newAttendees.add(student['uid']);
                                  } else {
                                    newAttendees.remove(student['uid']);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: newAttendees.isEmpty
                  ? null
                  : () async {
                      Get.back();

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
                                    child: Lottie.asset('assets/lottie/loading.json'),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Adding participants...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        barrierDismissible: false,
                      );

                      try {
                        final updatedAttendees = [...currentAttendees, ...newAttendees];

                        await FirebaseFirestore.instance
                            .collection('mentor_meetings')
                            .doc(meeting['id'])
                            .update({
                          'attendees': updatedAttendees,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        final meetingDateTime =
                            (meeting['scheduledDate'] as Timestamp).toDate();

                        await MentorChatMateIntegrationService.notifyMeetingScheduled(
                          mentorId: userData!['uid'],
                          mentorName: userData!['name'] ?? 'Your Mentor',
                          studentIds: newAttendees,
                          meetingTitle: meeting['title'],
                          meetingDescription: meeting['description'] ?? '',
                          meetingDate: meetingDateTime,
                        );

                        await _loadMeetings();

                        Get.back();

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
                                    Text(
                                        '${newAttendees.length} participant(s) added successfully!'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        await Future.delayed(const Duration(seconds: 2));
                        Get.back();

                        this.setState(() {});
                      } catch (e) {
                        Get.back();
                        _showErrorSnackbar('Failed to add participants: $e');
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
              child: Text('Add ${newAttendees.length} Participant(s)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMeeting(String meetingId, String? meetingTitle) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Meeting?'),
        content: Text(
          'Are you sure you want to delete "${meetingTitle ?? 'this meeting'}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
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
                    child: Lottie.asset('assets/lottie/loading.json'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Deleting meeting...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final meetingDoc = await FirebaseFirestore.instance
          .collection('mentor_meetings')
          .doc(meetingId)
          .get();

      if (meetingDoc.exists) {
        final meetingData = meetingDoc.data()!;
        final attendeeIds = List<String>.from(meetingData['attendees'] ?? []);

        for (final studentId in attendeeIds) {
          try {
            final conversationId = _getConversationID(userData!['uid'], studentId);
            final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

            await FirebaseFirestore.instance
                .collection('chats/$conversationId/messages')
                .doc(timestamp)
                .set({
              'toId': studentId,
              'msg': '🗑️ Meeting Cancelled\n\nThe meeting "${meetingTitle ?? 'Mentor Meeting'}" scheduled by ${userData!['name'] ?? 'your mentor'} has been cancelled.',
              'read': '',
              'type': 'text',
              'fromId': userData!['uid'],
              'sent': timestamp,
            });
          } catch (e) {
            debugPrint('Error notifying student $studentId: $e');
          }
        }

        await FirebaseFirestore.instance
            .collection('mentor_meetings')
            .doc(meetingId)
            .delete();
      }

      await _loadMeetings();

      Get.back();

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
                  const Text('Meeting deleted successfully!'),
                ],
              ),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      Get.back();

      setState(() {});
    } catch (e) {
      Get.back();
      _showErrorSnackbar('Failed to delete meeting: $e');
    }
  }

  String _getConversationID(String id1, String id2) {
    return id1.hashCode <= id2.hashCode ? '${id1}_$id2' : '${id2}_$id1';
  }

  void _showStudentDetailsDialog(Map<String, dynamic> student, bool isTablet) {
    final cgpa = _getStudentCgpa(student['uid']);
    final reports = studentProgressData[student['uid']] ?? [];

    Get.dialog(
      Dialog(
        child: Container(
          width: isTablet ? 600 : double.infinity,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryBlue.withOpacity(0.1),
                      radius: isTablet ? 32 : 28,
                      child: Text(
                        student['fullName']?.toString().substring(0, 1) ?? 'S',
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['fullName'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            student['usn']?.toString().toUpperCase() ?? 'N/A',
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: lightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Email', student['email'] ?? 'N/A', Icons.email),
                      const Divider(),
                      _buildDetailRow('Phone', student['phone'] ?? 'N/A', Icons.phone),
                      const Divider(),
                      _buildDetailRow('Gender', student['gender'] ?? 'N/A', Icons.person),
                      const Divider(),
                      _buildDetailRow(
                          'Year', student['yearOfPassing'] ?? 'N/A', Icons.calendar_today),
                      if (cgpa != null) ...[
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.school, color: primaryBlue, size: 20),
                            const SizedBox(width: 12),
                            const Text('CGPA:', style: TextStyle(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: _getCgpaGradient(cgpa)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                cgpa.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Semester-wise Performance',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) {
                      final semester = index + 1;
                      final semCgpa = _getSemesterCgpa(student['uid'], semester);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryBlue.withOpacity(0.1),
                          child: Text('S$semester',
                              style: const TextStyle(color: primaryBlue, fontSize: 12)),
                        ),
                        title: Text('Semester $semester'),
                        trailing: semCgpa != null
                            ? Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getCgpaGradient(semCgpa)[0].withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  semCgpa.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getCgpaGradient(semCgpa)[0],
                                  ),
                                ),
                              )
                            : Text('—', style: TextStyle(color: Colors.grey)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Progress Reports (${reports.length})',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: reports.isEmpty
                      ? Center(
                          child: Text('No reports added yet',
                              style: TextStyle(color: Colors.grey[600])),
                        )
                      : ListView.builder(
                          itemCount: reports.length,
                          itemBuilder: (context, index) {
                            final report = reports[index];
                            return ListTile(
                              leading: const Icon(Icons.assignment, color: lightBlue),
                              title: Text('Semester ${report['semester']}'),
                              subtitle: Text(report['remarks'] ?? 'No remarks'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showReportDetailsDialog(student, report, isTablet),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryBlue, size: 20),
        const SizedBox(width: 12),
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _showMeetingDetailsDialog(Map<String, dynamic> meeting, bool isTablet) {
    final date = (meeting['scheduledDate'] as Timestamp).toDate();
    final attendeeIds = List<String>.from(meeting['attendees'] ?? []);
    final attendees =
        menteeStudents.where((s) => attendeeIds.contains(s['uid'])).toList();
    final isUpcoming = _isMeetingUpcoming(meeting);

    Get.dialog(
      Dialog(
        child: Container(
          width: isTablet ? 500 : double.infinity,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event, color: primaryBlue, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        meeting['title'] ?? 'Meeting',
                        style: TextStyle(
                          fontSize: isTablet ? 20 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                    'Date', DateFormat('dd MMM yyyy').format(date), Icons.calendar_today),
                const SizedBox(height: 8),
                _buildDetailRow('Time', DateFormat('hh:mm a').format(date), Icons.access_time),
                const SizedBox(height: 8),
                _buildDetailRow('Status', meeting['status'] ?? 'Scheduled', Icons.info),
                if (meeting['description'] != null) ...[
                  const SizedBox(height: 16),
                  const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(meeting['description'], style: TextStyle(color: Colors.grey[700])),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Attendees (${attendees.length}):',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (isUpcoming)
                      TextButton.icon(
                        onPressed: () {
                          Get.back();
                          _addMeetingParticipants(meeting, isTablet);
                        },
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(foregroundColor: lightBlue),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: attendees.isEmpty
                      ? const Center(child: Text('No attendees'))
                      : ListView.builder(
                          itemCount: attendees.length,
                          itemBuilder: (context, index) {
                            final student = attendees[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primaryBlue.withOpacity(0.1),
                                child: Text(
                                  student['fullName']?.toString().substring(0, 1) ?? 'S',
                                  style: const TextStyle(
                                      color: primaryBlue, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(student['fullName'] ?? 'N/A'),
                              subtitle: Text(student['usn'] ?? 'N/A'),
                              trailing: isUpcoming
                                  ? IconButton(
                                      icon: const Icon(Icons.remove_circle, color: dangerRed, size: 20),
                                      onPressed: () => _removeAttendeeFromMeeting(
                                          meeting['id'], student['uid'], student['fullName']),
                                      tooltip: 'Remove from meeting',
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (isUpcoming)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Get.back();
                            _completeMeeting(meeting['id']);
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Mark Complete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: successGreen,
                            side: const BorderSide(color: successGreen),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (isUpcoming) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Get.back();
                          _deleteMeeting(meeting['id'], meeting['title']);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dangerRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _removeAttendeeFromMeeting(
      String meetingId, String studentId, String? studentName) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Remove Attendee?'),
        content: Text(
          'Are you sure you want to remove ${studentName ?? 'this student'} from the meeting?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: dangerRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
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
                    child: Lottie.asset('assets/lottie/loading.json'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Removing attendee...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final meetingDoc =
          await FirebaseFirestore.instance.collection('mentor_meetings').doc(meetingId).get();

      if (meetingDoc.exists) {
        final currentAttendees = List<String>.from(meetingDoc.data()!['attendees'] ?? []);
        currentAttendees.remove(studentId);

        if (currentAttendees.isEmpty) {
          Get.back();
          _showErrorSnackbar('Cannot remove last attendee. Delete the meeting instead.');
          return;
        }

        await FirebaseFirestore.instance.collection('mentor_meetings').doc(meetingId).update({
          'attendees': currentAttendees,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final conversationId = _getConversationID(userData!['uid'], studentId);
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

        await FirebaseFirestore.instance
            .collection('chats/$conversationId/messages')
            .doc(timestamp)
            .set({
          'toId': studentId,
          'msg':
              '🗑️ Removed from Meeting\n\nYou have been removed from the meeting "${meetingDoc.data()!['title']}" by ${userData!['name'] ?? 'your mentor'}.',
          'read': '',
          'type': 'text',
          'fromId': userData!['uid'],
          'sent': timestamp,
        });

        await _loadMeetings();

        Get.back();

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
                    const Text('Attendee removed successfully!'),
                  ],
                ),
              ),
            ),
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        Get.back();

        setState(() {});
      }
    } catch (e) {
      Get.back();
      _showErrorSnackbar('Failed to remove attendee: $e');
    }
  }

  void _showReportDetailsDialog(
      Map<String, dynamic> student, Map<String, dynamic> report, bool isTablet) {
    Get.dialog(
      Dialog(
        child: Container(
          width: isTablet ? 500 : double.infinity,
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment, color: primaryBlue, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress Report',
                            style: TextStyle(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            student['fullName'] ?? 'N/A',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: lightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Semester', report['semester']?.toString() ?? 'N/A',
                          Icons.school),
                      if (report['cgpa'] != null) ...[
                        const Divider(),
                        _buildDetailRow(
                            'CGPA', report['cgpa'].toStringAsFixed(2), Icons.grade),
                      ],
                      if (report['attendance'] != null) ...[
                        const Divider(),
                        _buildDetailRow(
                            'Attendance', '${report['attendance']}%', Icons.checklist),
                      ],
                    ],
                  ),
                ),
                if (report['remarks'] != null) ...[
                  const SizedBox(height: 16),
                  const Text('Remarks:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightGray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      report['remarks'],
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
                if (report['createdAt'] != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Added on: ${DateFormat('dd MMM yyyy').format((report['createdAt'] as Timestamp).toDate())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickActions(bool isTablet) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.event, color: primaryBlue),
              title: const Text('Schedule Meeting'),
              onTap: () {
                Get.back();
                _scheduleMeeting(isTablet);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: primaryBlue),
              title: const Text('Add Students'),
              onTap: () {
                Get.back();
                setState(() => selectedTabIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: primaryBlue),
              title: const Text('Export Reports'),
              onTap: () {
                Get.back();
                _exportAllReports(isTablet);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: primaryBlue),
              title: const Text('Refresh Data'),
              onTap: () {
                Get.back();
                setState(() => isLoading = true);
                _loadUserDataAndStudents();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAllReports(bool isTablet) async {
    if (menteeStudents.isEmpty) {
      _showErrorSnackbar('No mentees to export');
      return;
    }

    try {
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
                    child: Lottie.asset('assets/lottie/loading.json'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Exporting reports...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(primaryBlue.value),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Mentor-Mentee Progress Report',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Mentor: ${userData?['name'] ?? 'N/A'}',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 14),
                    ),
                    pw.Text(
                      'Department: ${userData?['branchName'] ?? 'N/A'}',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 14),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total Mentees: ${menteeStudents.length}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              ...menteeStudents.map((student) {
                final cgpa = _getStudentCgpa(student['uid']);
                final reports = studentProgressData[student['uid']] ?? [];

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                student['fullName'] ?? 'N/A',
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                student['usn']?.toString().toUpperCase() ?? 'N/A',
                                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                              ),
                            ],
                          ),
                          if (cgpa != null)
                            pw.Container(
                              padding:
                                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromInt(_getCgpaGradient(cgpa)[0].value),
                                borderRadius:
                                    const pw.BorderRadius.all(pw.Radius.circular(20)),
                              ),
                              child: pw.Text(
                                'CGPA: ${cgpa.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                    color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text(
                          'Contact: ${student['phone'] ?? 'N/A'} | ${student['email'] ?? 'N/A'}'),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        'Semester-wise Performance:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Table.fromTextArray(
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        headers: [
                          'Sem 1',
                          'Sem 2',
                          'Sem 3',
                          'Sem 4',
                          'Sem 5',
                          'Sem 6',
                          'Sem 7',
                          'Sem 8'
                        ],
                        data: [
                          List.generate(8, (i) {
                            final sem = _getSemesterCgpa(student['uid'], i + 1);
                            return sem?.toStringAsFixed(2) ?? '—';
                          }),
                        ],
                      ),
                      if (reports.isNotEmpty) ...[
                        pw.SizedBox(height: 12),
                        pw.Text(
                          'Progress Reports:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 8),
                        ...reports.map(
                          (report) => pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 8),
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey100,
                              borderRadius:
                                  const pw.BorderRadius.all(pw.Radius.circular(8)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Semester ${report['semester']}',
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                                ),
                                if (report['cgpa'] != null)
                                  pw.Text('CGPA: ${report['cgpa'].toStringAsFixed(2)}'),
                                if (report['attendance'] != null)
                                  pw.Text('Attendance: ${report['attendance']}%'),
                                if (report['remarks'] != null)
                                  pw.Text('Remarks: ${report['remarks']}'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final fileName =
          'mentor_mentee_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final filePath = '${output.path}/$fileName';

      await File(filePath).writeAsBytes(await pdf.save());

      Get.back();

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Mentor-Mentee Progress Report',
      );

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
                  const Text('Report exported successfully!'),
                ],
              ),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      Get.back();
    } catch (e) {
      Get.back();
      _showErrorSnackbar('Failed to export report: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    if (isLoading) {
      return Scaffold(
        backgroundColor: lightGray,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 200,
                child: Lottie.asset('assets/lottie/loading.json'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading mentor-mentee data...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightGray,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(isTablet),
            ),
            if (selectedTabIndex == 0 || selectedTabIndex == 1)
              SliverToBoxAdapter(
                child: _buildSearchAndFilter(isTablet),
              ),
            SliverFillRemaining(
              hasScrollBody: true,
              child: IndexedStack(
                index: selectedTabIndex,
                children: [
                  _buildMyMenteesTab(isTablet),
                  _buildAddStudentsTab(isTablet),
                  _buildMeetingsTab(isTablet),
                  _buildReportsTab(isTablet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}