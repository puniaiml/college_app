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
import 'package:shiksha_hub/services/notification_service.dart';

class HODStudentManagementPage extends StatefulWidget {
  const HODStudentManagementPage({super.key});

  @override
  State<HODStudentManagementPage> createState() =>
      _HODStudentManagementPageState();
}

class _HODStudentManagementPageState extends State<HODStudentManagementPage>
    with TickerProviderStateMixin {
  static const primaryBlue = Color(0xFF1A237E);
  static const deepBlack = Color(0xFF121212);
  static const lightGray = Color(0xFFF5F5F5);

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? hodData;
  List<Map<String, dynamic>> pendingStudents = [];
  List<Map<String, dynamic>> approvedStudents = [];
  List<Map<String, dynamic>> blockedStudents = [];
  List<Map<String, dynamic>> filteredStudents = [];

  bool isLoading = true;
  bool isExporting = false;
  bool isProcessingAll = false;
  String selectedTab = 'pending';
  String searchQuery = '';
  String? selectedYear;
  String? selectedGender;
  String sortBy = 'name';
  bool isAscending = true;
  bool isSelectionMode = false;
  Set<String> selectedStudents = {};

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCards = <String>{};

  List<String> years = [];
  final List<String> genders = ['Male', 'Female', 'Other'];
  final List<String> sortOptions = ['name', 'usn', 'year', 'createdAt'];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadHODDataAndStudents();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
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

  Future<void> _loadHODDataAndStudents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot hodDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('department_head')
          .collection('data')
          .doc(user.uid)
          .get();

      if (!hodDoc.exists) return;

      hodData = hodDoc.data() as Map<String, dynamic>;
      await _loadStudents();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStudents() async {
    if (hodData == null) return;

    try {
      final Map<String, dynamic> whereClause = {
        'collegeId': hodData!['collegeId'],
        'courseId': hodData!['courseId'],
        'branchId': hodData!['branchId'],
      };

      final pendingQuery = await _getStudentQuery('pending_students', {
        ...whereClause,
        'isEmailVerified': true,
        'accountStatus': 'pending_approval',
      });

      final approvedQuery = await _getStudentQuery('students', {
        ...whereClause,
        'accountStatus': 'active',
      });

      final blockedQuery = await _getStudentQuery('blocked_students', {
        ...whereClause,
        'accountStatus': 'blocked',
      });

      pendingStudents = _mapQueryResults(pendingQuery);
      approvedStudents = _mapQueryResults(approvedQuery);
      blockedStudents = _mapQueryResults(blockedQuery);

      _extractFilterOptions();
      _filterStudents();
      setState(() {});
    } catch (e) {
      Get.snackbar('Error', 'Failed to load students: $e');
    }
  }

  Future<QuerySnapshot> _getStudentQuery(
      String collection, Map<String, dynamic> conditions) async {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(collection)
        .collection('data');

    conditions.forEach((key, value) {
      query = query.where(key, isEqualTo: value);
    });

    final orderByField =
        collection == 'blocked_students' ? 'rejectedAt' : 'createdAt';
    return await query.orderBy(orderByField, descending: true).get();
  }

  List<Map<String, dynamic>> _mapQueryResults(QuerySnapshot query) {
    return query.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  void _extractFilterOptions() {
    final yearsSet = <String>{};
    final allLists = [pendingStudents, approvedStudents, blockedStudents];

    for (var list in allLists) {
      for (var student in list) {
        if (student['yearOfPassing'] != null) {
          yearsSet.add(student['yearOfPassing'].toString());
        }
      }
    }

    years = yearsSet.toList()..sort();
  }

  void _filterStudents() {
    final currentStudents = _getCurrentStudentsList();

    filteredStudents = currentStudents.where((student) {
      return _matchesSearch(student) &&
          _matchesYear(student) &&
          _matchesGender(student);
    }).toList();

    _sortStudents();
  }

  List<Map<String, dynamic>> _getCurrentStudentsList() {
    switch (selectedTab) {
      case 'pending':
        return pendingStudents;
      case 'approved':
        return approvedStudents;
      case 'blocked':
        return blockedStudents;
      default:
        return pendingStudents;
    }
  }

  bool _matchesSearch(Map<String, dynamic> student) {
    if (searchQuery.isEmpty) return true;

    final searchFields = [
      student['fullName']?.toLowerCase(),
      student['usn']?.toLowerCase(),
      student['email']?.toLowerCase(),
      student['phone']?.toLowerCase(),
    ];

    return searchFields.any((field) => field?.contains(searchQuery) == true);
  }

  bool _matchesYear(Map<String, dynamic> student) {
    return selectedYear == null ||
        student['yearOfPassing']?.toString() == selectedYear;
  }

  bool _matchesGender(Map<String, dynamic> student) {
    return selectedGender == null || student['gender'] == selectedGender;
  }

  void _sortStudents() {
    filteredStudents.sort((a, b) {
      dynamic valueA = _getSortValue(a);
      dynamic valueB = _getSortValue(b);

      if (valueA is Timestamp && valueB is Timestamp) {
        return isAscending
            ? valueA.compareTo(valueB)
            : valueB.compareTo(valueA);
      }

      final comparison = valueA.toString().compareTo(valueB.toString());
      return isAscending ? comparison : -comparison;
    });
  }

  dynamic _getSortValue(Map<String, dynamic> student) {
    switch (sortBy) {
      case 'name':
        return student['fullName'] ?? '';
      case 'usn':
        return student['usn'] ?? '';
      case 'year':
        return student['yearOfPassing'] ?? 0;
      case 'createdAt':
        return student['createdAt'] ?? Timestamp.now();
      default:
        return student['fullName'] ?? '';
    }
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (selectedYear != null) count++;
    if (selectedGender != null) count++;
    return count;
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

  Future<void> _exportToExcel() async {
    setState(() => isExporting = true);

    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        _showPermissionError();
        return;
      }

      final excel = _createExcelFile();
      final fileName = _generateFileName();

      await _saveAndShareFile(excel, fileName);
      _showExportSuccess();
    } catch (e) {
      await _handleExportError();
    } finally {
      setState(() => isExporting = false);
    }
  }

  excel_lib.Excel _createExcelFile() {
    final excel = excel_lib.Excel.createExcel();
    excel.delete('Sheet1');
    final sheetObject = excel['${selectedTab.toUpperCase()}_Students'];

    final headers = _getExcelHeaders();
    _setExcelHeaders(sheetObject, headers);
    _populateExcelData(sheetObject, headers);

    return excel;
  }

  List<String> _getExcelHeaders() {
    final baseHeaders = [
      'S.No',
      'Full Name',
      'First Name',
      'Last Name',
      'USN',
      'Email',
      'Phone',
      'Gender',
      'University',
      'College',
      'Course',
      'Branch',
      'Year of Passing',
      'Date of Birth',
      'Account Status',
      'Registration Date',
      'Last Updated'
    ];

    if (selectedTab == 'approved') {
      baseHeaders.addAll(['Approved Date', 'Approved By', 'Approved By Role']);
    } else if (selectedTab == 'blocked') {
      baseHeaders.addAll(['Rejected Date', 'Rejected By', 'Rejection Reason']);
    }

    return baseHeaders;
  }

  void _setExcelHeaders(excel_lib.Sheet sheetObject, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final cell = sheetObject.cell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = excel_lib.TextCellValue(headers[i]);
      cell.cellStyle = excel_lib.CellStyle(
          backgroundColorHex: excel_lib.ExcelColor.fromHexString('#1A237E'),
          fontColorHex: excel_lib.ExcelColor.fromHexString('#FFFFFF'),
          bold: true);
    }
  }

  void _populateExcelData(excel_lib.Sheet sheetObject, List<String> headers) {
    for (int i = 0; i < filteredStudents.length; i++) {
      final student = filteredStudents[i];
      final rowData = _getStudentRowData(student, i + 1);

      for (int j = 0; j < rowData.length; j++) {
        final cell = sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(
            columnIndex: j, rowIndex: i + 1));
        cell.value = excel_lib.TextCellValue(rowData[j]);
      }
    }
  }

  List<String> _getStudentRowData(Map<String, dynamic> student, int index) {
    final baseData = [
      index.toString(),
      student['fullName']?.toString() ?? '',
      student['firstName']?.toString() ?? '',
      student['lastName']?.toString() ?? '',
      student['usn']?.toString() ?? '',
      student['email']?.toString() ?? '',
      student['phone']?.toString() ?? '',
      student['gender']?.toString() ?? '',
      student['universityName']?.toString() ?? '',
      student['collegeName']?.toString() ?? '',
      student['courseName']?.toString() ?? '',
      student['branchName']?.toString() ?? '',
      student['yearOfPassing']?.toString() ?? '',
      _formatTimestamp(student['dateOfBirth'], 'dd/MM/yyyy'),
      student['accountStatus']?.toString() ?? '',
      _formatTimestamp(student['createdAt'], 'dd/MM/yyyy HH:mm'),
      _formatTimestamp(student['updatedAt'], 'dd/MM/yyyy HH:mm'),
    ];

    if (selectedTab == 'approved') {
      baseData.addAll([
        _formatTimestamp(student['approvedAt'], 'dd/MM/yyyy HH:mm'),
        student['approvedByName']?.toString() ?? '',
        student['approvedByHODRole']?.toString() ?? '',
      ]);
    } else if (selectedTab == 'blocked') {
      baseData.addAll([
        _formatTimestamp(student['rejectedAt'], 'dd/MM/yyyy HH:mm'),
        student['rejectedByName']?.toString() ?? '',
        student['rejectionReason']?.toString() ?? '',
      ]);
    }

    return baseData;
  }

  String _formatTimestamp(dynamic timestamp, String pattern) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return DateFormat(pattern).format(timestamp.toDate());
    }
    return '';
  }

  String _generateFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final branchName = hodData?['branchName']?.replaceAll(' ', '_') ?? 'Branch';
    return '${selectedTab}_students_${branchName}_$timestamp.xlsx';
  }

  Future<void> _saveAndShareFile(excel_lib.Excel excel, String fileName) async {
    final directory = await _getStorageDirectory();
    final filePath = '${directory.path}/$fileName';

    await File(filePath).writeAsBytes(excel.encode()!);

    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 29) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text:
              '${selectedTab.toUpperCase()} Students Export - ${hodData?['branchName'] ?? 'Department'}',
        );
      }
    } else {
      await Share.shareXFiles(
        [XFile(filePath)],
        text:
            '${selectedTab.toUpperCase()} Students Export - ${hodData?['branchName'] ?? 'Department'}',
      );
    }
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

  void _showPermissionError() {
    Get.snackbar(
      'Permission Required',
      'Storage permission is needed to save the Excel file',
      backgroundColor: Colors.orange.withOpacity(0.1),
      colorText: Colors.orange,
      duration: const Duration(seconds: 3),
    );
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

  Future<void> _handleExportError() async {
    try {
      final excel = _createExcelFile();
      final fileName =
          '${selectedTab}_students_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      await File(filePath).writeAsBytes(excel.encode()!);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: '${selectedTab.toUpperCase()} Students Export',
      );

      _showExportSuccess();
    } catch (shareError) {
      Get.snackbar(
        'Export Failed',
        'Unable to export file: $shareError',
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _showFilterDialog() {
    String? tempYear = selectedYear;
    String? tempGender = selectedGender;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Filter Students'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildYearDropdown(tempYear, (value) {
                setDialogState(() => tempYear = value);
                setState(() => selectedYear = value);
                _filterStudents();
              }),
              const SizedBox(height: 16),
              _buildGenderDropdown(tempGender, (value) {
                setDialogState(() => tempGender = value);
                setState(() => selectedGender = value);
                _filterStudents();
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                selectedYear = null;
                selectedGender = null;
              });
              _filterStudents();
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildYearDropdown(String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Year of Passing',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Years')),
        ...years.map((year) => DropdownMenuItem(
              value: year,
              child: Text(year),
            )),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildGenderDropdown(String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Gender',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Genders')),
        ...genders.map((gender) => DropdownMenuItem(
              value: gender,
              child: Text(gender),
            )),
      ],
      onChanged: onChanged,
    );
  }

  void _showSortDialog() {
    String tempSortBy = sortBy;
    bool tempIsAscending = isAscending;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sort Students'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortDropdown(tempSortBy, (value) {
                setDialogState(() => tempSortBy = value!);
                setState(() => sortBy = value!);
                _filterStudents();
              }),
              const SizedBox(height: 16),
              _buildSortOrderRadio(tempIsAscending, (value) {
                setDialogState(() => tempIsAscending = value!);
                setState(() => isAscending = value!);
                _filterStudents();
              }),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSortDropdown(String value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Sort By',
        border: OutlineInputBorder(),
      ),
      items: sortOptions
          .map((option) => DropdownMenuItem(
                value: option,
                child: Text(option == 'createdAt'
                    ? 'Registration Date'
                    : option.toUpperCase()),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSortOrderRadio(bool value, Function(bool?) onChanged) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          RadioListTile<bool>(
            title: const Text('Ascending'),
            value: true,
            groupValue: value,
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            onChanged: onChanged,
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          RadioListTile<bool>(
            title: const Text('Descending'),
            value: false,
            groupValue: value,
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog({
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
              Lottie.asset(lottieAsset,
                  width: 80, height: 80, fit: BoxFit.contain),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: deepBlack),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
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
              Lottie.asset(lottieAsset,
                  width: 100, height: 100, fit: BoxFit.contain, repeat: false),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green : Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
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
    final confirmed = await _showApprovalConfirmation(student);
    if (!confirmed) return;

    try {
      _showLoadingDialog(
        title: 'Approving Student',
        message: 'Please wait while we approve the student...',
        lottieAsset: 'assets/lottie/loading.json',
      );

      await _performApproval(student);

      Get.back();
      await _showResultDialog(
        title: 'Student Approved!',
        message:
            '${student['fullName']} has been successfully approved and can now access the system.',
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

  Future<bool> _showApprovalConfirmation(Map<String, dynamic> student) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Approve Student'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Are you sure you want to approve this student?'),
                const SizedBox(height: 12),
                _buildStudentSummaryCard(student),
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
                child: const Text('Approve',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildStudentSummaryCard(Map<String, dynamic> student) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Name: ${student['fullName']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('USN: ${student['usn']}'),
          Text('Email: ${student['email']}'),
          Text('Branch: ${student['branchName']}'),
          Text('Year: ${student['yearOfPassing']}'),
        ],
      ),
    );
  }

  Future<void> _performApproval(Map<String, dynamic> student) async {
    final batch = FirebaseFirestore.instance.batch();

    final activeStudentData = Map<String, dynamic>.from(student);
    activeStudentData.addAll({
      'accountStatus': 'active',
      'isActive': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': FirebaseAuth.instance.currentUser?.uid,
      'approvedByName': hodData!['name'],
      'approvedByRole': 'hod',
      'approvedByHODRole': hodData!['role'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

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
      final token = (student['push_token'] ?? student['pushToken'] ?? '')
          .toString();
      if (token.isNotEmpty) {
        await NotificationService.notifyStudentApproved(
          studentPushToken: token,
          approvedByName: hodData!['name'] ?? 'HOD',
        );
      }
    } catch (_) {}
  }

  Future<void> _rejectStudent(Map<String, dynamic> student) async {
    final result = await _showRejectionDialog(student);
    if (result == null) return;

    try {
      _showLoadingDialog(
        title: 'Rejecting Student',
        message: 'Please wait while we process the rejection...',
        lottieAsset: 'assets/lottie/loading.json',
      );

      await _performRejection(student, result);

      Get.back();
      await _showResultDialog(
        title: 'Student Blocked',
        message:
            '${student['fullName']} has been rejected and blocked from the system.',
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

  Future<String?> _showRejectionDialog(Map<String, dynamic> student) async {
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

    if (confirmed == true && rejectionReason.trim().isNotEmpty) {
      return rejectionReason.trim();
    }

    if (confirmed == true && rejectionReason.trim().isEmpty) {
      Get.snackbar('Error', 'Please provide a reason for rejection');
    }

    return null;
  }

  Future<void> _performRejection(
      Map<String, dynamic> student, String reason) async {
    final batch = FirebaseFirestore.instance.batch();

    final blockedStudentData = Map<String, dynamic>.from(student);
    blockedStudentData.addAll({
      'accountStatus': 'blocked',
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
      'rejectedByName': hodData!['name'],
      'rejectedByRole': 'hod',
      'rejectedByHODRole': hodData!['role'],
      'rejectedFromStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });

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
    });

    await batch.commit();

    try {
      final token = (student['push_token'] ?? student['pushToken'] ?? '')
          .toString();
      if (token.isNotEmpty) {
        await NotificationService.notifyStudentRejected(
          studentPushToken: token,
          rejectedByName: hodData!['name'] ?? 'HOD',
          reason: reason,
        );
      }
    } catch (_) {}
  }

  Future<void> _blockApprovedStudent(Map<String, dynamic> student) async {
    final reason = await _showBlockDialog(student);
    if (reason == null) return;

    try {
      _showLoadingDialog(
        title: 'Blocking Student',
        message: 'Please wait while we block the student...',
        lottieAsset: 'assets/lottie/loading.json',
      );

      await _performBlocking(student, reason);

      Get.back();
      await _showResultDialog(
        title: 'Student Blocked',
        message:
            '${student['fullName']} has been blocked and can no longer access the system.',
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

  Future<String?> _showBlockDialog(Map<String, dynamic> student) async {
    String blockReason = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Text('Block Approved Student'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWarningCard(student),
            const SizedBox(height: 16),
            const Text('Reason for blocking:',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
            child: const Text('Block Student',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && blockReason.trim().isNotEmpty) {
      return blockReason.trim();
    }

    if (confirmed == true && blockReason.trim().isEmpty) {
      Get.snackbar(
          'Error', 'Please provide a reason for blocking this student');
    }

    return null;
  }

  Widget _buildWarningCard(Map<String, dynamic> student) {
    return Container(
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
    );
  }

  Future<void> _performBlocking(
      Map<String, dynamic> student, String reason) async {
    final batch = FirebaseFirestore.instance.batch();

    final blockedStudentData = Map<String, dynamic>.from(student);
    blockedStudentData.addAll({
      'accountStatus': 'blocked',
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
      'rejectedByName': hodData!['name'],
      'rejectedByRole': 'hod',
      'rejectedByHODRole': hodData!['role'],
      'rejectedFromStatus': 'active',
      'wasApproved': true,
      'originalApprovedAt': student['approvedAt'],
      'originalApprovedBy': student['approvedBy'],
      'originalApprovedByName': student['approvedByName'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

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
  }

  Future<void> _unblockAndApproveStudent(Map<String, dynamic> student) async {
    final confirmed = await _showUnblockConfirmation(student);
    if (!confirmed) return;

    try {
      _showLoadingDialog(
        title: 'Unblocking Student',
        message: 'Please wait while we unblock and approve the student...',
        lottieAsset: 'assets/lottie/loading.json',
      );

      await _performUnblocking(student);

      Get.back();
      await _showResultDialog(
        title: 'Student Unblocked!',
        message:
            '${student['fullName']} has been successfully unblocked and approved.',
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

  Future<bool> _showUnblockConfirmation(Map<String, dynamic> student) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Unblock & Approve Student'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Are you sure you want to unblock and approve this student?'),
                const SizedBox(height: 12),
                if (student['rejectionReason'] != null) ...[
                  _buildRejectionReasonCard(student),
                  const SizedBox(height: 12),
                ],
                if (student['wasApproved'] == true) ...[
                  _buildPreviousApprovalNote(),
                  const SizedBox(height: 8),
                ],
                _buildBasicStudentInfo(student),
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
                child: const Text('Unblock & Approve',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildRejectionReasonCard(Map<String, dynamic> student) {
    return Column(
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
      ],
    );
  }

  Widget _buildPreviousApprovalNote() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '📝 Note: This student was previously approved and then blocked.',
        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildBasicStudentInfo(Map<String, dynamic> student) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Name: ${student['fullName']}'),
        Text('USN: ${student['usn']}'),
        Text('Email: ${student['email']}'),
      ],
    );
  }

  Widget _buildPreviousApprovalWarning(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 12 : 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.orange,
            size: isTablet ? 20 : 16,
          ),
          SizedBox(width: isTablet ? 8 : 6),
          Expanded(
            child: Text(
              'This student was previously approved before being blocked.',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performUnblocking(Map<String, dynamic> student) async {
    final batch = FirebaseFirestore.instance.batch();

    final activeStudentData = Map<String, dynamic>.from(student);

    final fieldsToRemove = [
      'rejectionReason',
      'rejectedAt',
      'rejectedBy',
      'rejectedByName',
      'rejectedByRole',
      'rejectedByHODRole',
      'rejectedFromStatus',
      'wasApproved'
    ];

    for (final field in fieldsToRemove) {
      activeStudentData.remove(field);
    }

    activeStudentData.addAll({
      'accountStatus': 'active',
      'isActive': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': FirebaseAuth.instance.currentUser?.uid,
      'approvedByName': hodData!['name'],
      'approvedByRole': 'hod',
      'approvedByHODRole': hodData!['role'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

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
            const Color(0xFF0D47A1)
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
              _buildHODInfoCard(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              _buildStatsCard(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              _buildTabButtons(isTablet),
              SizedBox(height: isTablet ? 24 : 16),
              _buildSearchBar(isTablet),
              SizedBox(height: isTablet ? 16 : 12),
              _buildFilterSortButtons(isTablet),
              SizedBox(height: isTablet ? 16 : 12),
              _buildSelectionButtons(isTablet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionButtons(bool isTablet) {
    if (selectedTab != 'pending' || filteredStudents.isEmpty) {
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
                        isSelectionMode ? Colors.grey : primaryBlue,
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
      _showLoadingDialog(
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
      _showLoadingDialog(
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
              Text(
                hodData?['branchName'] ?? 'Department',
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
          onPressed: isExporting ? null : _exportToExcel,
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

  Widget _buildHODInfoCard(bool isTablet) {
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
            child: Text(
              hodData?['name']?.substring(0, 1).toUpperCase() ?? 'H',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 20 : 16,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hodData?['name'] ?? 'HOD Name',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 18 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  hodData?['role'] ?? 'Head of Department',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: isTablet ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn(
            'Total Students',
            (pendingStudents.length +
                    approvedStudents.length +
                    blockedStudents.length)
                .toString(),
            isTablet,
          ),
          Container(
              height: isTablet ? 50 : 40, width: 1, color: Colors.white30),
          _buildStatColumn(
              'Filtered Results', filteredStudents.length.toString(), isTablet),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, bool isTablet) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isTablet ? 28 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: isTablet ? 14 : 12,
          ),
        ),
      ],
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

  Widget _buildFilterSortButtons(bool isTablet) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showFilterDialog,
            icon: Icon(Icons.filter_list, size: isTablet ? 20 : 18),
            label: Text(
              'Filter (${_getActiveFiltersCount()})',
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
          child: OutlinedButton.icon(
            onPressed: _showSortDialog,
            icon: Icon(
              isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: isTablet ? 20 : 18,
            ),
            label: Text(
              'Sort by ${sortBy == 'createdAt' ? 'Date' : sortBy.toUpperCase()}',
              style: TextStyle(fontSize: isTablet ? 16 : 14),
              overflow: TextOverflow.ellipsis,
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
      ],
    );
  }

  Widget _buildCompactStudentCard(
      Map<String, dynamic> student, String tabType) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.of(context).size;
        final isTablet = size.width > 600;
        final isSmallScreen = size.height < 700;
        final studentId = student['uid'] ?? student['id'] ?? '';
        final isExpanded = _expandedCards.contains(studentId);
        final isSelected = selectedStudents.contains(studentId);

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth > 800 ? 32 : 16,
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
              _buildCardHeader(student, tabType, isExpanded, studentId,
                  isTablet, size, isSelected),
              if (isExpanded) _buildExpandedContent(student, tabType, isTablet),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandedContent(
      Map<String, dynamic> student, String tabType, bool isTablet) {
    final size = MediaQuery.of(context).size;
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
        if (isSelectionMode) {
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
        if (selectedTab == 'pending') {
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
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (value) => _toggleStudentSelection(studentId),
                activeColor: primaryBlue,
              ),
            _buildStudentAvatar(student, isTablet, isSelected),
            SizedBox(width: isSmallScreen ? 8 : (isTablet ? 16 : 12)),
            _buildStudentInfo(student, isTablet, size),
            _buildStatusBadge(tabType, isTablet),
            SizedBox(width: isSmallScreen ? 6 : (isTablet ? 12 : 8)),
            if (!isSelectionMode) _buildExpandIcon(isExpanded, isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(
      Map<String, dynamic> student, bool isTablet, bool isSelected) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;
    final radius = isSmallScreen ? 16.0 : (isTablet ? 28.0 : 20.0);
    final fontSize = isSmallScreen ? 14.0 : (isTablet ? 20.0 : 16.0);

    return CircleAvatar(
      backgroundColor:
          isSelected ? Colors.white : primaryBlue.withOpacity(0.1),
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

  Widget _buildStatusBadge(String tabType, bool isTablet) {
    final size = MediaQuery.of(context).size;
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

  Widget _buildExpandIcon(bool isExpanded, bool isTablet) {
    final size = MediaQuery.of(context).size;
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
        '${student['approvedByName']} (${student['approvedByRole']?.toUpperCase() ?? 'HOD'})',
        isTablet,
      ));

      if (student['approvedByHODRole'] != null) {
        details.add(_buildDetailRow(
          Icons.work,
          'HOD Role',
          student['approvedByHODRole'],
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
        '${student['rejectedByName']} (${student['rejectedByRole']?.toUpperCase() ?? 'HOD'})',
        isTablet,
      ));

      if (student['rejectedByHODRole'] != null) {
        details.add(_buildDetailRow(
          Icons.work,
          'HOD Role',
          student['rejectedByHODRole'],
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

  List<Widget> _buildActionButtons(
      Map<String, dynamic> student, String tabType, bool isTablet) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
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
              _buildEmptyStateAction(isTablet),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyStateAction(bool isTablet) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;

    if (searchQuery.isNotEmpty || _getActiveFiltersCount() > 0) {
      return ElevatedButton(
        onPressed: () {
          _searchController.clear();
          setState(() {
            searchQuery = '';
            selectedYear = null;
            selectedGender = null;
            _expandedCards.clear();
            selectedStudents.clear();
            isSelectionMode = false;
          });
          _filterStudents();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : (isTablet ? 24 : 20),
            vertical: isSmallScreen ? 10 : (isTablet ? 16 : 12),
          ),
          minimumSize: Size(
            isSmallScreen ? 120 : 140,
            isSmallScreen ? 40 : 44,
          ),
        ),
        child: Text(
          'Clear Filters',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : (isTablet ? 16 : 15),
          ),
        ),
      );
    }

    return TextButton.icon(
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
    );
  }

  Widget _buildSearchResultsHeader() {
    if (searchQuery.isEmpty && _getActiveFiltersCount() == 0) {
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
            searchQuery.isNotEmpty ? Icons.search : Icons.filter_list,
            color: primaryBlue,
            size: isTablet ? 24 : 20,
          ),
          SizedBox(width: isTablet ? 12 : 8),
          Expanded(
            child: Text(
              searchQuery.isNotEmpty
                  ? 'Found ${filteredStudents.length} students matching "$searchQuery"'
                  : 'Found ${filteredStudents.length} students with applied filters',
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
            if (searchQuery.isNotEmpty || _getActiveFiltersCount() > 0)
              SliverToBoxAdapter(
                child: _buildSearchResultsHeader(),
              ),
            if (filteredStudents.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(
                  _getEmptyStateMessage(),
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
            if (hodData != null) ...[
              SizedBox(height: isTablet ? 16 : 10),
              Text(
                'Department: ${hodData!['branchName'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: deepBlack.withOpacity(0.7),
                ),
              ),
              Text(
                'College: ${hodData!['collegeName'] ?? 'N/A'}',
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

  String _getEmptyStateMessage() {
    if (searchQuery.isNotEmpty || _getActiveFiltersCount() > 0) {
      return 'No students found matching your search criteria.\nTry adjusting your search terms or filters.';
    }

    switch (selectedTab) {
      case 'pending':
        return 'No pending student applications in your department.\nAll students have been processed.';
      case 'approved':
        return 'No approved students found in your department.\nStart approving students to see them here.';
      case 'blocked':
        return 'No blocked students found in your department.\nStudents you reject will appear here.';
      default:
        return 'No students found.';
    }
  }
}