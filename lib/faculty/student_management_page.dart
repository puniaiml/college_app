import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:shiksha_hub/services/notification_service.dart';

class FacultyStudentManagementPage extends StatefulWidget {
  const FacultyStudentManagementPage({super.key});

  @override
  State<FacultyStudentManagementPage> createState() => _FacultyStudentManagementPageState();
}

class _FacultyStudentManagementPageState extends State<FacultyStudentManagementPage>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? facultyData;
  List<Map<String, dynamic>> pendingStudents = [];
  List<Map<String, dynamic>> approvedStudents = [];
  List<Map<String, dynamic>> blockedStudents = [];
  List<Map<String, dynamic>> filteredStudents = [];
  bool isLoading = true;
  bool hasStudentManagementPermission = false;
  String selectedTab = 'pending';
  String searchQuery = '';
  bool isSelectionMode = false;
  bool isProcessingAll = false;
  Set<String> selectedStudents = {};
  
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCards = <String>{};

  static const primaryBlue = Color(0xFF1A237E);
  static const deepBlack = Color(0xFF121212);
  static const lightGray = Color(0xFFF5F5F5);
  static const premiumGold = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadFacultyDataAndStudents();
    _searchController.addListener(_onSearchChanged);
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

  Future<void> _loadFacultyDataAndStudents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot facultyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection('data')
          .doc(user.uid)
          .get();

      if (!facultyDoc.exists) return;

      facultyData = facultyDoc.data() as Map<String, dynamic>;
      hasStudentManagementPermission = facultyData?['canHandleStudents'] == true;

      await _loadStudents();

    } catch (e) {
      Get.snackbar('Error', 'Failed to load data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStudents() async {
    if (facultyData == null) return;

    try {
      QuerySnapshot pendingQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc('pending_students')
          .collection('data')
          .where('collegeId', isEqualTo: facultyData!['collegeId'])
          .where('courseId', isEqualTo: facultyData!['courseId'])
          .where('branchId', isEqualTo: facultyData!['branchId'])
          .where('isEmailVerified', isEqualTo: true)
          .where('accountStatus', isEqualTo: 'pending_approval')
          .orderBy('createdAt', descending: true)
          .get();

      pendingStudents = pendingQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      QuerySnapshot approvedQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .where('collegeId', isEqualTo: facultyData!['collegeId'])
          .where('courseId', isEqualTo: facultyData!['courseId'])
          .where('branchId', isEqualTo: facultyData!['branchId'])
          .where('accountStatus', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      approvedStudents = approvedQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      QuerySnapshot blockedQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc('blocked_students')
          .collection('data')
          .where('collegeId', isEqualTo: facultyData!['collegeId'])
          .where('courseId', isEqualTo: facultyData!['courseId'])
          .where('branchId', isEqualTo: facultyData!['branchId'])
          .where('accountStatus', isEqualTo: 'blocked')
          .orderBy('rejectedAt', descending: true)
          .get();

      blockedStudents = blockedQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      _filterStudents();
      setState(() {});
    } catch (e) {
      Get.snackbar('Error', 'Failed to load students: $e');
    }
  }

  void _filterStudents() {
    final currentStudents = selectedTab == 'pending' 
        ? pendingStudents 
        : selectedTab == 'approved' 
            ? approvedStudents 
            : blockedStudents;

    if (searchQuery.isEmpty) {
      filteredStudents = currentStudents;
    } else {
      filteredStudents = currentStudents.where((student) {
        final name = (student['fullName'] ?? '').toString().toLowerCase();
        final usn = (student['usn'] ?? '').toString().toLowerCase();
        final email = (student['email'] ?? '').toString().toLowerCase();
        final phone = (student['phone'] ?? '').toString().toLowerCase();
        final query = searchQuery.toLowerCase();
        
        return name.contains(query) || 
               usn.contains(query) || 
               email.contains(query) || 
               phone.contains(query);
      }).toList();
    }
  }

  void _toggleStudentSelection(String studentId) {
    setState(() {
      if (selectedStudents.contains(studentId)) {
        selectedStudents.remove(studentId);
      } else {
        selectedStudents.add(studentId);
      }
    });
  }

  void _selectAllFilteredStudents() {
    setState(() {
      selectedStudents.clear();
      for (var student in filteredStudents) {
        final studentId = student['uid'] ?? student['id'] ?? '';
        if (studentId.isNotEmpty) {
          selectedStudents.add(studentId);
        }
      }
    });
  }

  Widget _buildSelectionButtons(bool isTablet) {
    if (selectedTab != 'pending' || filteredStudents.isEmpty || !hasStudentManagementPermission) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isSelectionMode = !isSelectionMode;
                      selectedStudents.clear();
                    });
                  },
                  icon: Icon(
                    isSelectionMode ? Icons.close : Icons.checklist,
                    size: isTablet ? 20 : 18,
                  ),
                  label: Text(
                    isSelectionMode ? 'Cancel Selection' : 'Select All',
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSelectionMode ? Colors.grey : premiumGold,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 16 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isSelectionMode && selectedStudents.isNotEmpty)
            SizedBox(height: isTablet ? 16 : 12),
          if (isSelectionMode && selectedStudents.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveSelectedStudents(),
                    icon: Icon(
                      Icons.check,
                      size: isTablet ? 20 : 18,
                    ),
                    label: Text(
                      'Approve All (${selectedStudents.length})',
                      style: TextStyle(fontSize: isTablet ? 16 : 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 16,
                        vertical: isTablet ? 16 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectSelectedStudents(),
                    icon: Icon(
                      Icons.close,
                      size: isTablet ? 20 : 18,
                    ),
                    label: Text(
                      'Decline All (${selectedStudents.length})',
                      style: TextStyle(fontSize: isTablet ? 16 : 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 16,
                        vertical: isTablet ? 16 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _approveSelectedStudents() async {
    if (selectedStudents.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Selected Students'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Are you sure you want to approve all selected students?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${selectedStudents.length} student(s) will be approved',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'They will gain access to the system immediately',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => isProcessingAll = true);
      _showProfessionalLoadingDialog(
        title: 'Approving Students',
        message: 'Processing ${selectedStudents.length} student(s)...',
        lottieAsset: 'assets/lottie/loading.json',
      );

      int successCount = 0;
      int failCount = 0;

      final studentsToApprove = filteredStudents
          .where((student) =>
              selectedStudents.contains(student['uid'] ?? student['id']))
          .toList();

      for (var student in studentsToApprove) {
        try {
          await _performApproval(student);
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      Get.back();
      await _showResultDialog(
        title: 'Bulk Approval Complete',
        message:
            'Successfully approved $successCount student(s).\nFailed: $failCount student(s).',
        lottieAsset: 'assets/lottie/Success.json',
        isSuccess: successCount > 0,
      );

      setState(() {
        isSelectionMode = false;
        selectedStudents.clear();
      });
      await _loadStudents();
    } catch (e) {
      Get.back();
      await _showResultDialog(
        title: 'Bulk Approval Failed',
        message: 'Failed to approve selected students. Please try again.',
        lottieAsset: 'assets/lottie/error.json',
        isSuccess: false,
      );
    } finally {
      setState(() => isProcessingAll = false);
    }
  }

  Future<void> _rejectSelectedStudents() async {
    if (selectedStudents.isEmpty) return;

    String rejectionReason = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Selected Students'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Are you sure you want to reject all selected students?'),
            const SizedBox(height: 16),
            const Text('Reason for rejection:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => rejectionReason = value,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${selectedStudents.length} student(s) will be blocked',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'They will lose access to the system immediately',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (rejectionReason.trim().isEmpty) {
      Get.snackbar('Error', 'Please provide a reason for rejection');
      return;
    }

    try {
      setState(() => isProcessingAll = true);
      _showProfessionalLoadingDialog(
        title: 'Rejecting Students',
        message: 'Processing ${selectedStudents.length} student(s)...',
        lottieAsset: 'assets/lottie/loading.json',
      );

      int successCount = 0;
      int failCount = 0;

      final studentsToReject = filteredStudents
          .where((student) =>
              selectedStudents.contains(student['uid'] ?? student['id']))
          .toList();

      for (var student in studentsToReject) {
        try {
          await _performRejection(student, rejectionReason);
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      Get.back();
      await _showResultDialog(
        title: 'Bulk Rejection Complete',
        message:
            'Successfully rejected $successCount student(s).\nFailed: $failCount student(s).',
        lottieAsset: 'assets/lottie/blocked.json',
        isSuccess: successCount > 0,
      );

      setState(() {
        isSelectionMode = false;
        selectedStudents.clear();
      });
      await _loadStudents();
    } catch (e) {
      Get.back();
      await _showResultDialog(
        title: 'Bulk Rejection Failed',
        message: 'Failed to reject selected students. Please try again.',
        lottieAsset: 'assets/lottie/error.json',
        isSuccess: false,
      );
    } finally {
      setState(() => isProcessingAll = false);
    }
  }

  Future<void> _performApproval(Map<String, dynamic> student) async {
    final batch = FirebaseFirestore.instance.batch();

    final activeStudentData = Map<String, dynamic>.from(student);
    activeStudentData['accountStatus'] = 'active';
    activeStudentData['isActive'] = true;
    activeStudentData['approvedAt'] = FieldValue.serverTimestamp();
    activeStudentData['approvedBy'] = FirebaseAuth.instance.currentUser?.uid;
    activeStudentData['approvedByName'] = facultyData!['name'];
    activeStudentData['approvedByRole'] = 'faculty';
    activeStudentData['approvedByFacultyRole'] = facultyData!['role'];
    activeStudentData['updatedAt'] = FieldValue.serverTimestamp();

    final activeStudentRef = FirebaseFirestore.instance
        .collection('users')
        .doc('students')
        .collection('data')
        .doc(student['uid']);

    batch.set(activeStudentRef, activeStudentData);

    final pendingStudentRef = FirebaseFirestore.instance
        .collection('users')
        .doc('pending_students')
        .collection('data')
        .doc(student['uid']);

    batch.delete(pendingStudentRef);

    final metadataRef = FirebaseFirestore.instance
        .collection('user_metadata')
        .doc(student['uid']);

    batch.update(metadataRef, {
      'accountStatus': 'active',
      'dataLocation': 'users/students/data/${student['uid']}',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    try {
      final token = (student['push_token'] ?? student['pushToken'] ?? '').toString();
      if (token.isNotEmpty) {
        await NotificationService.notifyStudentApproved(
          studentPushToken: token,
          approvedByName: facultyData!['name'] ?? 'Faculty',
        );
      }
    } catch (_) {}
  }

  Future<void> _performRejection(Map<String, dynamic> student, String reason) async {
    final batch = FirebaseFirestore.instance.batch();

    final blockedStudentData = Map<String, dynamic>.from(student);
    blockedStudentData['accountStatus'] = 'blocked';
    blockedStudentData['rejectionReason'] = reason.trim();
    blockedStudentData['rejectedAt'] = FieldValue.serverTimestamp();
    blockedStudentData['rejectedBy'] = FirebaseAuth.instance.currentUser?.uid;
    blockedStudentData['rejectedByName'] = facultyData!['name'];
    blockedStudentData['rejectedByRole'] = 'faculty';
    blockedStudentData['rejectedByFacultyRole'] = facultyData!['role'];
    blockedStudentData['rejectedFromStatus'] = 'pending';
    blockedStudentData['updatedAt'] = FieldValue.serverTimestamp();

    final blockedStudentRef = FirebaseFirestore.instance
        .collection('users')
        .doc('blocked_students')
        .collection('data')
        .doc(student['uid']);

    batch.set(blockedStudentRef, blockedStudentData);

    final pendingStudentRef = FirebaseFirestore.instance
        .collection('users')
        .doc('pending_students')
        .collection('data')
        .doc(student['uid']);

    batch.delete(pendingStudentRef);

    final metadataRef = FirebaseFirestore.instance
        .collection('user_metadata')
        .doc(student['uid']);

    batch.update(metadataRef, {
      'accountStatus': 'blocked',
      'dataLocation': 'users/blocked_students/data/${student['uid']}',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    try {
      final token = (student['push_token'] ?? student['pushToken'] ?? '').toString();
      if (token.isNotEmpty) {
        await NotificationService.notifyStudentRejected(
          studentPushToken: token,
          rejectedByName: facultyData!['name'] ?? 'Faculty',
          reason: reason.trim(),
        );
      }
    } catch (_) {}
  }

  void _showPermissionDeniedDialog() {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block,
                  size: 50,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Permission Denied',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You don\'t have permission to manage students. Only faculty members with student management privileges can approve, reject, or block students.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: premiumGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: premiumGold.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: premiumGold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Contact your administrator to get student management permissions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: premiumGold.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfessionalLoadingDialog({
    required String title,
    required String message,
    required String lottieAsset,
    Color? backgroundColor,
  }) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                lottieAsset,
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: deepBlack,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _showResultDialog({
    required String title,
    required String message,
    required String lottieAsset,
    required bool isSuccess,
  }) async {
    await Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                lottieAsset,
                width: 100,
                height: 100,
                fit: BoxFit.contain,
                repeat: false,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveStudent(Map<String, dynamic> student) async {
    if (!hasStudentManagementPermission) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Approve Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to approve this student?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lightGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${student['fullName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('USN: ${student['usn']}'),
                    Text('Email: ${student['email']}'),
                    Text('Branch: ${student['branchName']}'),
                    Text('Year: ${student['yearOfPassing']}'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Approve', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      _showProfessionalLoadingDialog(
        title: 'Approving Student',
        message: 'Please wait while we approve the student...',
        lottieAsset: 'assets/lottie/loading.json',
      );

      await _performApproval(student);

      Get.back();

      await _showResultDialog(
        title: 'Student Approved!',
        message: '${student['fullName']} has been successfully approved and can now access the system.',
        lottieAsset: 'assets/lottie/Success.json',
        isSuccess: true,
      );

      await _loadStudents();

    } catch (e) {
      Get.back();
      
      await _showResultDialog(
        title: 'Approval Failed',
        message: 'Failed to approve student. Please try again later.',
        lottieAsset: 'assets/lottie/error.json',
        isSuccess: false,
      );
    }
  }

  Future<void> _rejectStudent(Map<String, dynamic> student) async {
    if (!hasStudentManagementPermission) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      String rejectionReason = '';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reject Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: ${student['fullName']}'),
              const SizedBox(height: 16),
              const Text('Reason for rejection:'),
              const SizedBox(height: 8),
              TextField(
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter reason for rejection...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => rejectionReason = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true || rejectionReason.trim().isEmpty) {
        if (confirmed == true && rejectionReason.trim().isEmpty) {
          Get.snackbar('Error', 'Please provide a reason for rejection');
        }
        return;
      }

      _showProfessionalLoadingDialog(
        title: 'Rejecting Student',
        message: 'Please wait while we process the rejection...',
        lottieAsset: 'assets/lottie/loading.json',
      );

      await _performRejection(student, rejectionReason);

      Get.back();

      await _showResultDialog(
        title: 'Student Blocked',
        message: '${student['fullName']} has been rejected and blocked from the system.',
        lottieAsset: 'assets/lottie/blocked.json',
        isSuccess: false,
      );

      await _loadStudents();

    } catch (e) {
      Get.back();
      
      await _showResultDialog(
        title: 'Rejection Failed',
        message: 'Failed to reject student. Please try again later.',
        lottieAsset: 'assets/lottie/error.json',
        isSuccess: false,
      );
    }
  }

  Future<void> _blockApprovedStudent(Map<String, dynamic> student) async {
    if (!hasStudentManagementPermission) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      String blockReason = '';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              const Text('Block Approved Student'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Warning: This will block an active student',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Text('Student: ${student['fullName']}'),
                    Text('USN: ${student['usn']}'),
                    Text('Email: ${student['email']}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Reason for blocking:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter detailed reason for blocking this student...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => blockReason = value,
              ),
              const SizedBox(height: 8),
              Text(
                'Note: The student will lose access immediately and will be moved to blocked students list.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Block Student', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true || blockReason.trim().isEmpty) {
        if (confirmed == true && blockReason.trim().isEmpty) {
          Get.snackbar('Error', 'Please provide a reason for blocking this student');
        }
        return;
      }

      _showProfessionalLoadingDialog(
        title: 'Blocking Student',
        message: 'Please wait while we block the student...',
        lottieAsset: 'assets/lottie/loading.json',
      );

      final batch = FirebaseFirestore.instance.batch();

      final blockedStudentData = Map<String, dynamic>.from(student);
      blockedStudentData['accountStatus'] = 'blocked';
      blockedStudentData['rejectionReason'] = blockReason.trim();
      blockedStudentData['rejectedAt'] = FieldValue.serverTimestamp();
      blockedStudentData['rejectedBy'] = FirebaseAuth.instance.currentUser?.uid;
      blockedStudentData['rejectedByName'] = facultyData!['name'];
      blockedStudentData['rejectedByRole'] = 'faculty';
      blockedStudentData['rejectedByFacultyRole'] = facultyData!['role'];
      blockedStudentData['rejectedFromStatus'] = 'active';
      blockedStudentData['wasApproved'] = true;
      blockedStudentData['originalApprovedAt'] = student['approvedAt'];
      blockedStudentData['originalApprovedBy'] = student['approvedBy'];
      blockedStudentData['originalApprovedByName'] = student['approvedByName'];
      blockedStudentData['updatedAt'] = FieldValue.serverTimestamp();

      final blockedStudentRef = FirebaseFirestore.instance
          .collection('users')
          .doc('blocked_students')
          .collection('data')
          .doc(student['uid']);

      batch.set(blockedStudentRef, blockedStudentData);

      final approvedStudentRef = FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(student['uid']);

      batch.delete(approvedStudentRef);

      final metadataRef = FirebaseFirestore.instance
          .collection('user_metadata')
          .doc(student['uid']);

      batch.update(metadataRef, {
        'accountStatus': 'blocked',
        'dataLocation': 'users/blocked_students/data/${student['uid']}',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      Get.back();

      await _showResultDialog(
        title: 'Student Blocked',
        message: '${student['fullName']} has been blocked and can no longer access the system.',
        lottieAsset: 'assets/lottie/blocked.json',
        isSuccess: false,
      );

      await _loadStudents();

    } catch (e) {
      Get.back();
      
      await _showResultDialog(
        title: 'Block Failed',
        message: 'Failed to block student. Please try again later.',
        lottieAsset: 'assets/lottie/error.json',
        isSuccess: false,
      );
    }
  }

  Future<void> _unblockAndApproveStudent(Map<String, dynamic> student) async {
    if (!hasStudentManagementPermission) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Unblock & Approve Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to unblock and approve this student?'),
              const SizedBox(height: 12),
              if (student['rejectionReason'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['rejectedFromStatus'] == 'active' 
                        ? 'Previous block reason:' 
                        : 'Previous rejection reason:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(student['rejectionReason']),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              if (student['wasApproved'] == true)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '📝 Note: This student was previously approved and then blocked.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 8),
              Text('Name: ${student['fullName']}'),
              Text('USN: ${student['usn']}'),
              Text('Email: ${student['email']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Unblock & Approve', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      _showProfessionalLoadingDialog(
        title: 'Unblocking Student',
        message: 'Please wait while we unblock and approve the student...',
        lottieAsset: 'assets/lottie/loading.json',
      );

      final batch = FirebaseFirestore.instance.batch();

      final activeStudentData = Map<String, dynamic>.from(student);
      activeStudentData['accountStatus'] = 'active';
      activeStudentData['isActive'] = true;
      activeStudentData['approvedAt'] = FieldValue.serverTimestamp();
      activeStudentData['approvedBy'] = FirebaseAuth.instance.currentUser?.uid;
      activeStudentData['approvedByName'] = facultyData!['name'];
      activeStudentData['approvedByRole'] = 'faculty';
      activeStudentData['approvedByFacultyRole'] = facultyData!['role'];
      activeStudentData['updatedAt'] = FieldValue.serverTimestamp();
      activeStudentData.remove('rejectionReason');
      activeStudentData.remove('rejectedAt');
      activeStudentData.remove('rejectedBy');
      activeStudentData.remove('rejectedByName');
      activeStudentData.remove('rejectedByRole');
      activeStudentData.remove('rejectedByFacultyRole');
      activeStudentData.remove('rejectedFromStatus');
      activeStudentData.remove('wasApproved');

      final activeStudentRef = FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(student['uid']);

      batch.set(activeStudentRef, activeStudentData);

      final blockedStudentRef = FirebaseFirestore.instance
          .collection('users')
          .doc('blocked_students')
          .collection('data')
          .doc(student['uid']);

      batch.delete(blockedStudentRef);

      final metadataRef = FirebaseFirestore.instance
          .collection('user_metadata')
          .doc(student['uid']);

      batch.update(metadataRef, {
        'accountStatus': 'active',
        'dataLocation': 'users/students/data/${student['uid']}',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      Get.back();

      try {
        final token = (student['push_token'] ?? student['pushToken'] ?? '').toString();
        if (token.isNotEmpty) {
          await NotificationService.notifyStudentUnblocked(
            studentPushToken: token,
            approvedByName: facultyData!['name'] ?? 'Faculty',
          );
        }
      } catch (_) {}

      await _showResultDialog(
        title: 'Student Unblocked!',
        message: '${student['fullName']} has been successfully unblocked and approved.',
        lottieAsset: 'assets/lottie/Success.json',
        isSuccess: true,
      );

      await _loadStudents();

    } catch (e) {
      Get.back();
      
      await _showResultDialog(
        title: 'Unblock Failed',
        message: 'Failed to unblock student. Please try again later.',
        lottieAsset: 'assets/lottie/error.json',
        isSuccess: false,
      );
    }
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
              _buildFacultyInfoCard(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              _buildTabButtons(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              _buildSearchBar(isTablet),
              SizedBox(height: isTablet ? 16 : 12),
              _buildSelectionButtons(isTablet),
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
                'Student Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 28 : size.width * 0.055,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasStudentManagementPermission ? Icons.star : Icons.visibility,
                    color: hasStudentManagementPermission ? premiumGold : Colors.orange,
                    size: isTablet ? 18 : 16,
                  ),
                  SizedBox(width: isTablet ? 6 : 4),
                  Text(
                    hasStudentManagementPermission ? 'Student Manager Access' : 'View Only Access',
                    style: TextStyle(
                      color: hasStudentManagementPermission ? premiumGold : Colors.orange,
                      fontSize: isTablet ? 16 : size.width * 0.03,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: isTablet ? 48 : 40),
      ],
    );
  }

  Widget _buildFacultyInfoCard(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasStudentManagementPermission ? premiumGold.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: hasStudentManagementPermission ? premiumGold : Colors.orange,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: isTablet ? 28 : 22,
              child: Text(
                facultyData?['name']?.substring(0, 1).toUpperCase() ?? 'F',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 20 : 16,
                ),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facultyData?['name'] ?? 'Faculty Name',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 18 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  facultyData?['role'] ?? 'Faculty Member',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: isTablet ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 8, vertical: isTablet ? 8 : 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasStudentManagementPermission 
                  ? [premiumGold, const Color(0xFFB8860B)]
                  : [Colors.orange, const Color(0xFFFF8F00)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasStudentManagementPermission ? 'MANAGER' : 'VIEWER',
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 14 : 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButtons(bool isTablet) {
    final buttonPadding = EdgeInsets.symmetric(
      vertical: isTablet ? 16 : 12,
      horizontal: isTablet ? 16 : 8,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: isTablet
          ? Row(
              children: _getTabButtonWidgets(buttonPadding, isTablet, isTablet))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children:
                      _getTabButtonWidgets(buttonPadding, isTablet, false)),
            ),
    );
  }

  List<Widget> _getTabButtonWidgets(
      EdgeInsets buttonPadding, bool isTablet, bool shouldExpand) {
    return [
      _buildTabButton('pending', Icons.hourglass_empty, pendingStudents.length,
          buttonPadding, isTablet, shouldExpand),
      _buildTabButton('approved', Icons.check_circle, approvedStudents.length,
          buttonPadding, isTablet, shouldExpand),
      _buildTabButton('blocked', Icons.block, blockedStudents.length,
          buttonPadding, isTablet, shouldExpand),
    ];
  }

  Widget _buildTabButton(String tab, IconData icon, int count,
      EdgeInsets padding, bool isTablet, bool shouldExpand) {
    final isSelected = selectedTab == tab;

    Widget buttonContent = GestureDetector(
      onTap: () => setState(() {
        selectedTab = tab;
        if (selectedTab != 'pending') {
          isSelectionMode = false;
          selectedStudents.clear();
        }
        _filterStudents();
      }),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: shouldExpand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryBlue : Colors.white,
              size: isTablet ? 22 : 18,
            ),
            SizedBox(width: isTablet ? 10 : 8),
            Text(
              '${tab.toUpperCase()} ($count)',
              style: TextStyle(
                color: isSelected ? primaryBlue : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 16 : 12,
              ),
            ),
          ],
        ),
      ),
    );

    return shouldExpand ? Expanded(child: buttonContent) : buttonContent;
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

  Widget _buildCompactStudentCard(Map<String, dynamic> student, String tabType) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isSmallScreen = size.height < 700;
    final studentId = student['uid'] ?? student['id'] ?? '';
    final isExpanded = _expandedCards.contains(studentId);
    final isSelected = selectedStudents.contains(studentId);
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isSmallScreen ? 4 : (isTablet ? 8 : 6),
      ),
      decoration: BoxDecoration(
        color: isSelected ? primaryBlue.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: isTablet ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isSelected
            ? Border.all(color: primaryBlue, width: 2)
            : Border.all(color: Colors.transparent, width: 0),
      ),
      child: Column(
        children: [
          _buildCardHeader(student, tabType, isExpanded, studentId, isTablet, size, isSelected),
          if (isExpanded) _buildExpandedContent(student, tabType, isTablet, size),
        ],
      ),
    );
  }

  Widget _buildCardHeader(
      Map<String, dynamic> student,
      String tabType,
      bool isExpanded,
      String studentId,
      bool isTablet,
      Size size,
      bool isSelected) {
    final isSmallScreen = size.height < 700;
    return InkWell(
      onTap: () {
        if (isSelectionMode && hasStudentManagementPermission && selectedTab == 'pending') {
          _toggleStudentSelection(studentId);
        } else {
          setState(() {
            if (isExpanded) {
              _expandedCards.remove(studentId);
            } else {
              _expandedCards.add(studentId);
            }
          });
        }
      },
      onLongPress: () {
        if (hasStudentManagementPermission && selectedTab == 'pending') {
          setState(() {
            isSelectionMode = true;
            _toggleStudentSelection(studentId);
          });
        }
      },
      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : (isTablet ? 20 : 16)),
        child: Row(
          children: [
            if (isSelectionMode && hasStudentManagementPermission && selectedTab == 'pending')
              Checkbox(
                value: isSelected,
                onChanged: (value) => _toggleStudentSelection(studentId),
                activeColor: primaryBlue,
              ),
            _buildStudentAvatar(student, isTablet, size, isSelected),
            SizedBox(width: isSmallScreen ? 8 : (isTablet ? 16 : 12)),
            _buildStudentInfo(student, isTablet, size),
            _buildStatusBadge(tabType, isTablet, size),
            SizedBox(width: isSmallScreen ? 6 : (isTablet ? 12 : 8)),
            if (!isSelectionMode) _buildExpandIcon(isExpanded, isTablet, size),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(Map<String, dynamic> student, bool isTablet, Size size, bool isSelected) {
    final isSmallScreen = size.height < 700;
    final radius = isSmallScreen ? 16.0 : (isTablet ? 28.0 : 20.0);
    final fontSize = isSmallScreen ? 14.0 : (isTablet ? 20.0 : 16.0);

    return CircleAvatar(
      backgroundColor: isSelected ? Colors.white : primaryBlue.withOpacity(0.1),
      radius: radius,
      child: Text(
        student['fullName']?.substring(0, 1).toUpperCase() ?? 'S',
        style: TextStyle(
          color: isSelected ? primaryBlue : primaryBlue,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  Widget _buildStudentInfo(
      Map<String, dynamic> student, bool isTablet, Size size) {
    final isSmallScreen = size.height < 700;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            student['fullName'] ?? 'N/A',
            style: TextStyle(
              fontSize:
                  isSmallScreen ? 14 : (isTablet ? 18 : size.width * 0.042),
              fontWeight: FontWeight.bold,
              color: deepBlack,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isSmallScreen ? 2 : (isTablet ? 4 : 2)),
          Wrap(
            spacing: isSmallScreen ? 6 : (isTablet ? 12 : 8),
            runSpacing: 4,
            children: [
              Text(
                student['usn'] ?? 'N/A',
                style: TextStyle(
                  fontSize:
                      isSmallScreen ? 12 : (isTablet ? 14 : size.width * 0.035),
                  color: Colors.grey[600],
                ),
              ),
              if (student['yearOfPassing'] != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 4 : (isTablet ? 8 : 6),
                    vertical: isSmallScreen ? 2 : (isTablet ? 4 : 2),
                  ),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Year: ${student['yearOfPassing']}',
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? 10
                          : (isTablet ? 12 : size.width * 0.028),
                      color: primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String tabType, bool isTablet, Size size) {
    final isSmallScreen = size.height < 700;
    Color color;
    String text;

    switch (tabType) {
      case 'pending':
        color = Colors.orange;
        text = 'Pending';
        break;
      case 'blocked':
        color = Colors.red;
        text = 'Blocked';
        break;
      default:
        color = Colors.green;
        text = 'Active';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : (isTablet ? 12 : 8),
        vertical: isSmallScreen ? 3 : (isTablet ? 6 : 4),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: isSmallScreen ? 10 : (isTablet ? 14 : size.width * 0.028),
        ),
      ),
    );
  }

  Widget _buildExpandIcon(bool isExpanded, bool isTablet, Size size) {
    final isSmallScreen = size.height < 700;
    return AnimatedRotation(
      turns: isExpanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 200),
      child: Icon(
        Icons.keyboard_arrow_down,
        color: primaryBlue,
        size: isSmallScreen ? 20 : (isTablet ? 28 : 24),
      ),
    );
  }

  Widget _buildExpandedContent(
      Map<String, dynamic> student, String tabType, bool isTablet, Size size) {
    final isSmallScreen = size.height < 700;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isSmallScreen ? 12 : (isTablet ? 20 : 16),
          0,
          isSmallScreen ? 12 : (isTablet ? 20 : 16),
          isSmallScreen ? 12 : (isTablet ? 20 : 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            SizedBox(height: isSmallScreen ? 8 : (isTablet ? 16 : 12)),
            ..._buildStudentDetails(student, tabType, isTablet),
            ..._buildActionButtons(student, tabType, isTablet),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStudentDetails(
      Map<String, dynamic> student, String tabType, bool isTablet) {
    final details = <Widget>[
      _buildDetailRow(
          Icons.email, 'Email', student['email'] ?? 'N/A', isTablet),
      _buildDetailRow(
          Icons.phone, 'Phone', student['phone'] ?? 'N/A', isTablet),
      if (student['gender'] != null)
        _buildDetailRow(Icons.person, 'Gender', student['gender'], isTablet),
      _buildDetailRow(Icons.calendar_today, 'Year of Passing',
          student['yearOfPassing']?.toString() ?? 'N/A', isTablet),
      if (student['createdAt'] != null)
        _buildDetailRow(
          Icons.access_time,
          'Registered',
          DateFormat('dd MMM yyyy, hh:mm a')
              .format((student['createdAt'] as Timestamp).toDate()),
          isTablet,
        ),
    ];

    if (tabType == 'approved') {
      details.addAll(_buildApprovedDetails(student, isTablet));
    } else if (tabType == 'blocked') {
      details.addAll(_buildBlockedDetails(student, isTablet));
    }

    return details;
  }

  List<Widget> _buildApprovedDetails(
      Map<String, dynamic> student, bool isTablet) {
    final details = <Widget>[];

    if (student['approvedAt'] != null) {
      details.add(_buildDetailRow(
        Icons.check_circle,
        'Approved',
        DateFormat('dd MMM yyyy, hh:mm a')
            .format((student['approvedAt'] as Timestamp).toDate()),
        isTablet,
      ));
    }

    if (student['approvedByName'] != null) {
      details.add(_buildDetailRow(
        Icons.person,
        'Approved By',
        '${student['approvedByName']} (${student['approvedByRole']?.toUpperCase() ?? 'FACULTY'})',
        isTablet,
      ));

      if (student['approvedByFacultyRole'] != null) {
        details.add(_buildDetailRow(
          Icons.work,
          'Faculty Role',
          student['approvedByFacultyRole'],
          isTablet,
        ));
      }
    }

    return details;
  }

  List<Widget> _buildBlockedDetails(
      Map<String, dynamic> student, bool isTablet) {
    final details = <Widget>[];

    if (student['rejectedAt'] != null) {
      details.add(_buildDetailRow(
        Icons.block,
        student['rejectedFromStatus'] == 'active'
            ? 'Blocked On'
            : 'Rejected On',
        DateFormat('dd MMM yyyy, hh:mm a')
            .format((student['rejectedAt'] as Timestamp).toDate()),
        isTablet,
      ));
    }

    if (student['rejectedByName'] != null) {
      details.add(_buildDetailRow(
        Icons.person,
        student['rejectedFromStatus'] == 'active'
            ? 'Blocked By'
            : 'Rejected By',
        '${student['rejectedByName']} (${student['rejectedByRole']?.toUpperCase() ?? 'FACULTY'})',
        isTablet,
      ));

      if (student['rejectedByFacultyRole'] != null) {
        details.add(_buildDetailRow(
          Icons.work,
          'Faculty Role',
          student['rejectedByFacultyRole'],
          isTablet,
        ));
      }
    }

    if (student['rejectionReason'] != null) {
      details.add(_buildDetailRow(
        Icons.info,
        student['rejectedFromStatus'] == 'active'
            ? 'Block Reason'
            : 'Rejection Reason',
        student['rejectionReason'],
        isTablet,
      ));
    }

    if (student['wasApproved'] == true) {
      details.add(SizedBox(height: isTablet ? 12 : 8));
      details.add(_buildPreviousApprovalWarning(isTablet));
    }

    return details;
  }

  Widget _buildPreviousApprovalWarning(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 12 : 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue,
            size: isTablet ? 20 : 16,
          ),
          SizedBox(width: isTablet ? 8 : 6),
          Expanded(
            child: Text(
              'This student was previously approved and then blocked.',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: isTablet ? 14 : 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(
      Map<String, dynamic> student, String tabType, bool isTablet) {
    if (!hasStudentManagementPermission) {
      return [
        SizedBox(height: isTablet ? 20 : 16),
        Container(
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock,
                color: Colors.orange,
                size: isTablet ? 24 : 20,
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Expanded(
                child: Text(
                  'View Only Mode: No permission to manage students',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    if (tabType == 'pending' && !isSelectionMode) {
      return [
        SizedBox(height: isTablet ? 20 : 16),
        isTablet
            ? Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectStudent(student),
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveStudent(student),
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveStudent(student),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectStudent(student),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
      ];
    } else if (tabType == 'approved') {
      return [
        SizedBox(height: isTablet ? 20 : 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _blockApprovedStudent(student),
            icon: Icon(Icons.block, size: isTablet ? 20 : 18),
            label: const Text('Block Student'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ];
    } else if (tabType == 'blocked') {
      return [
        SizedBox(height: isTablet ? 20 : 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _unblockAndApproveStudent(student),
            icon: Icon(Icons.lock_open, size: isTablet ? 20 : 18),
            label: const Text('Unblock & Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ];
    }

    return [];
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTablet ? 4 : 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: isTablet ? 16 : 14, color: Colors.grey[600]),
          SizedBox(width: isTablet ? 8 : 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isTablet ? 14 : 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: deepBlack,
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, String lottieAsset) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isSmallScreen = size.height < 700;

    final lottieSize = isSmallScreen
        ? size.width * 0.25
        : (isTablet ? size.width * 0.2 : size.width * 0.35);

    final verticalPadding = isSmallScreen ? 16.0 : (isTablet ? 32.0 : 24.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 16,
        vertical: verticalPadding,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            lottieAsset,
            width: lottieSize,
            height: lottieSize,
            fit: BoxFit.contain,
          ),
          SizedBox(height: isSmallScreen ? 12 : (isTablet ? 24 : 20)),
          Text(
            message,
            style: TextStyle(
              fontSize:
                  isSmallScreen ? 14 : (isTablet ? 18 : size.width * 0.045),
              color: deepBlack.withOpacity(0.7),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallScreen ? 8 : (isTablet ? 16 : 12)),
          TextButton.icon(
            onPressed: _loadStudents,
            icon: Icon(
              Icons.refresh,
              size: isSmallScreen ? 18 : (isTablet ? 24 : 20),
            ),
            label: Text(
              'Refresh',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : (isTablet ? 16 : 15),
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: primaryBlue,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : (isTablet ? 24 : 20),
                vertical: isSmallScreen ? 10 : (isTablet ? 16 : 12),
              ),
              minimumSize: Size(
                isSmallScreen ? 100 : 120,
                isSmallScreen ? 40 : 44,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsHeader() {
    if (searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isTablet ? 12 : 8,
      ),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: primaryBlue,
            size: isTablet ? 24 : 20,
          ),
          SizedBox(width: isTablet ? 12 : 8),
          Expanded(
            child: Text(
              'Found ${filteredStudents.length} students matching "$searchQuery"',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: isTablet ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
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
            if (searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildSearchResultsHeader(),
              ),
            if (filteredStudents.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(
                  searchQuery.isNotEmpty
                      ? 'No students found matching "$searchQuery".\nTry a different search term.'
                      : selectedTab == 'pending'
                          ? 'No pending student applications in your department.\nAll students have been processed.'
                          : selectedTab == 'approved'
                              ? 'No approved students found in your department.\nStart approving students to see them here.'
                              : 'No blocked students found in your department.\nStudents you reject will appear here.',
                  'assets/lottie/empty.json',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildCompactStudentCard(
                      filteredStudents[index],
                      selectedTab,
                    );
                  },
                  childCount: filteredStudents.length,
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
              'Loading Students...',
              style: TextStyle(
                fontSize: isTablet ? 22 : 18,
                color: deepBlack,
              ),
            ),
            if (facultyData != null) ...[
              SizedBox(height: isTablet ? 16 : 10),
              Text(
                'Department: ${facultyData!['branchName'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: deepBlack.withOpacity(0.7),
                ),
              ),
              Text(
                'College: ${facultyData!['collegeName'] ?? 'N/A'}',
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

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}