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

class CollegeStudentManagementPage extends StatefulWidget {
  const CollegeStudentManagementPage({super.key});

  @override
  State<CollegeStudentManagementPage> createState() => _CollegeStudentManagementPageState();
}

class _CollegeStudentManagementPageState extends State<CollegeStudentManagementPage>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? collegeData;
  List<Map<String, dynamic>> allStudents = [];
  List<Map<String, dynamic>> filteredStudents = [];
  bool isLoading = true;
  bool isExporting = false;
  Set<int> expandedCards = <int>{};

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  String? selectedBranch;
  String? selectedYear;
  String? selectedGender;
  String sortBy = 'name';
  bool isAscending = true;

  List<String> branches = [];
  List<String> years = [];
  final List<String> genders = ['Male', 'Female', 'Other'];
  final List<String> sortOptions = ['name', 'usn', 'branch', 'year', 'createdAt'];

  static const primaryBlue = Color(0xFF1A237E);
  static const deepBlack = Color(0xFF121212);
  static const lightGray = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadCollegeDataAndStudents();
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
    _applyFilters();
  }

  Future<void> _loadCollegeDataAndStudents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot collegeDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('college_heads')
          .collection('data')
          .doc(user.uid)
          .get();

      if (!collegeDoc.exists) {
        collegeDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc('college_staff')
            .collection('data')
            .doc(user.uid)
            .get();
      }

      if (!collegeDoc.exists) {
        Get.snackbar('Error', 'User profile not found in college_heads or college_staff collections');
        return;
      }

      collegeData = collegeDoc.data() as Map<String, dynamic>;
      await _loadStudents();

    } catch (e) {
      Get.snackbar('Error', 'Failed to load data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStudents() async {
    if (collegeData == null) return;

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .where('collegeId', isEqualTo: collegeData!['collegeId'])
          .where('accountStatus', isEqualTo: 'active');

      if (collegeData!['courseId'] != null) {
        query = query.where('courseId', isEqualTo: collegeData!['courseId']);
      }

      QuerySnapshot studentsQuery = await query
          .orderBy('createdAt', descending: true)
          .get();

      allStudents = studentsQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      _extractFilterOptions();
      _applyFilters();
      setState(() {});
    } catch (e) {
      try {
        QuerySnapshot fallbackQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc('students')
            .collection('data')
            .where('collegeId', isEqualTo: collegeData!['collegeId'])
            .where('accountStatus', isEqualTo: 'active')
            .orderBy('createdAt', descending: true)
            .get();

        allStudents = fallbackQuery.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        if (collegeData!['courseId'] != null) {
          allStudents = allStudents.where((student) => 
              student['courseId'] == collegeData!['courseId']).toList();
        }

        _extractFilterOptions();
        _applyFilters();
        setState(() {});
      } catch (fallbackError) {
        Get.snackbar('Error', 'Failed to load students: $fallbackError');
      }
    }
  }

  void _extractFilterOptions() {
    final branchesSet = <String>{};
    final yearsSet = <String>{};

    for (var student in allStudents) {
      if (student['branchName'] != null) {
        branchesSet.add(student['branchName']);
      }
      if (student['yearOfPassing'] != null) {
        yearsSet.add(student['yearOfPassing'].toString());
      }
    }

    branches = branchesSet.toList()..sort();
    years = yearsSet.toList()..sort();
  }

  void _applyFilters() {
    filteredStudents = allStudents.where((student) {
      final matchesSearch = searchQuery.isEmpty || 
          student['fullName']?.toLowerCase().contains(searchQuery) == true ||
          student['usn']?.toLowerCase().contains(searchQuery) == true ||
          student['email']?.toLowerCase().contains(searchQuery) == true ||
          student['phone']?.toLowerCase().contains(searchQuery) == true;

      final matchesBranch = selectedBranch == null || 
          student['branchName'] == selectedBranch;

      final matchesYear = selectedYear == null || 
          student['yearOfPassing']?.toString() == selectedYear;

      final matchesGender = selectedGender == null || 
          student['gender'] == selectedGender;

      return matchesSearch && matchesBranch && matchesYear && matchesGender;
    }).toList();

    _sortStudents();
  }

  void _sortStudents() {
    filteredStudents.sort((a, b) {
      dynamic valueA, valueB;
      
      switch (sortBy) {
        case 'name':
          valueA = a['fullName'] ?? '';
          valueB = b['fullName'] ?? '';
          break;
        case 'usn':
          valueA = a['usn'] ?? '';
          valueB = b['usn'] ?? '';
          break;
        case 'branch':
          valueA = a['branchName'] ?? '';
          valueB = b['branchName'] ?? '';
          break;
        case 'year':
          valueA = a['yearOfPassing'] ?? 0;
          valueB = b['yearOfPassing'] ?? 0;
          break;
        case 'createdAt':
          valueA = a['createdAt'] ?? Timestamp.now();
          valueB = b['createdAt'] ?? Timestamp.now();
          break;
        default:
          valueA = a['fullName'] ?? '';
          valueB = b['fullName'] ?? '';
      }

      if (valueA is Timestamp && valueB is Timestamp) {
        return isAscending 
            ? valueA.compareTo(valueB)
            : valueB.compareTo(valueA);
      }

      final comparison = valueA.toString().compareTo(valueB.toString());
      return isAscending ? comparison : -comparison;
    });
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      if (androidInfo.version.sdkInt >= 33) {
        return true;
      } else if (androidInfo.version.sdkInt >= 30) {
        final status = await Permission.manageExternalStorage.request();
        return status == PermissionStatus.granted;
      } else {
        final status = await Permission.storage.request();
        return status == PermissionStatus.granted;
      }
    }
    return true;
  }

  Future<void> _exportToExcel() async {
    setState(() => isExporting = true);

    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        Get.snackbar(
          'Permission Required',
          'Storage permission is needed to save the Excel file',
          backgroundColor: Colors.orange.withOpacity(0.1),
          colorText: Colors.orange,
          duration: const Duration(seconds: 3),
        );
        setState(() => isExporting = false);
        return;
      }

      final excel = excel_lib.Excel.createExcel();
      excel.delete('Sheet1');
      final sheetObject = excel['Students_Data'];

      final headers = [
        'S.No', 'Full Name', 'First Name', 'Last Name', 'USN', 'Email', 
        'Phone', 'Gender', 'University', 'College', 'Course', 'Branch', 
        'Year of Passing', 'Date of Birth', 'Account Status', 'Registration Date',
        'Last Updated'
      ];

      for (int i = 0; i < headers.length; i++) {
        final cell = sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = excel_lib.TextCellValue(headers[i]);
        cell.cellStyle = excel_lib.CellStyle(
          backgroundColorHex: excel_lib.ExcelColor.fromHexString('#1A237E'),
          fontColorHex: excel_lib.ExcelColor.fromHexString('#FFFFFF'),
          bold: true
        );
      }

      for (int i = 0; i < filteredStudents.length; i++) {
        final student = filteredStudents[i];
        final rowData = [
          (i + 1).toString(),
          student['fullName'] ?? '',
          student['firstName'] ?? '',
          student['lastName'] ?? '',
          student['usn'] ?? '',
          student['email'] ?? '',
          student['phone'] ?? '',
          student['gender'] ?? '',
          student['universityName'] ?? '',
          student['collegeName'] ?? '',
          student['courseName'] ?? '',
          student['branchName'] ?? '',
          student['yearOfPassing']?.toString() ?? '',
          student['dateOfBirth'] != null 
              ? DateFormat('dd/MM/yyyy').format((student['dateOfBirth'] as Timestamp).toDate())
              : '',
          student['accountStatus'] ?? '',
          student['createdAt'] != null 
              ? DateFormat('dd/MM/yyyy HH:mm').format((student['createdAt'] as Timestamp).toDate())
              : '',
          student['updatedAt'] != null 
              ? DateFormat('dd/MM/yyyy HH:mm').format((student['updatedAt'] as Timestamp).toDate())
              : '',
        ];

        for (int j = 0; j < rowData.length; j++) {
          final cell = sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
          cell.value = excel_lib.TextCellValue(rowData[j]);
        }
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'students_$timestamp.xlsx';

      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        
        if (androidInfo.version.sdkInt >= 29) {
          final directory = await getExternalStorageDirectory();
          final filePath = '${directory!.path}/$fileName';
          
          await File(filePath).writeAsBytes(excel.encode()!);
          
          await Share.shareXFiles(
            [XFile(filePath)],
            text: 'Student Data Export - ${collegeData?['collegeName'] ?? 'College'}',
          );
          
          Get.snackbar(
            'Export Successful',
            'File saved and ready to share',
            backgroundColor: Colors.green.withOpacity(0.1),
            colorText: Colors.green,
            duration: const Duration(seconds: 3),
          );
        } else {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            final filePath = '${downloadsDir.path}/$fileName';
            await File(filePath).writeAsBytes(excel.encode()!);
            
            Get.snackbar(
              'Export Successful',
              'File saved to Downloads folder',
              backgroundColor: Colors.green.withOpacity(0.1),
              colorText: Colors.green,
              duration: const Duration(seconds: 3),
            );
          } else {
            throw Exception('Downloads folder not accessible');
          }
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        
        await File(filePath).writeAsBytes(excel.encode()!);
        
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Student Data Export - ${collegeData?['collegeName'] ?? 'College'}',
        );
        
        Get.snackbar(
          'Export Successful',
          'File ready to share',
          backgroundColor: Colors.green.withOpacity(0.1),
          colorText: Colors.green,
          duration: const Duration(seconds: 3),
        );
      }

    } catch (e) {
      try {
        final excel = excel_lib.Excel.createExcel();
        excel.delete('Sheet1');
        final sheetObject = excel['Students_Data'];

        final headers = [
          'S.No', 'Full Name', 'First Name', 'Last Name', 'USN', 'Email', 
          'Phone', 'Gender', 'University', 'College', 'Course', 'Branch', 
          'Year of Passing', 'Date of Birth', 'Account Status', 'Registration Date',
          'Last Updated'
        ];

        for (int i = 0; i < headers.length; i++) {
          final cell = sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
          cell.value = excel_lib.TextCellValue(headers[i]);
          cell.cellStyle = excel_lib.CellStyle(
            backgroundColorHex: excel_lib.ExcelColor.fromHexString('#1A237E'),
            fontColorHex: excel_lib.ExcelColor.fromHexString('#FFFFFF'),
            bold: true
          );
        }

        for (int i = 0; i < filteredStudents.length; i++) {
          final student = filteredStudents[i];
          final rowData = [
            (i + 1).toString(),
            student['fullName'] ?? '',
            student['firstName'] ?? '',
            student['lastName'] ?? '',
            student['usn'] ?? '',
            student['email'] ?? '',
            student['phone'] ?? '',
            student['gender'] ?? '',
            student['universityName'] ?? '',
            student['collegeName'] ?? '',
            student['courseName'] ?? '',
            student['branchName'] ?? '',
            student['yearOfPassing']?.toString() ?? '',
            student['dateOfBirth'] != null 
                ? DateFormat('dd/MM/yyyy').format((student['dateOfBirth'] as Timestamp).toDate())
                : '',
            student['accountStatus'] ?? '',
            student['createdAt'] != null 
                ? DateFormat('dd/MM/yyyy HH:mm').format((student['createdAt'] as Timestamp).toDate())
                : '',
            student['updatedAt'] != null 
                ? DateFormat('dd/MM/yyyy HH:mm').format((student['updatedAt'] as Timestamp).toDate())
                : '',
          ];

          for (int j = 0; j < rowData.length; j++) {
            final cell = sheetObject.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
            cell.value = excel_lib.TextCellValue(rowData[j]);
          }
        }

        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'students_$timestamp.xlsx';
        
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        
        await File(filePath).writeAsBytes(excel.encode()!);
        
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Student Data Export - ${collegeData?['collegeName'] ?? 'College'}',
        );
        
        Get.snackbar(
          'Export Successful',
          'File ready to share via app documents',
          backgroundColor: Colors.green.withOpacity(0.1),
          colorText: Colors.green,
          duration: const Duration(seconds: 3),
        );
        
      } catch (shareError) {
        Get.snackbar(
          'Export Failed', 
          'Unable to export file: $shareError',
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      setState(() => isExporting = false);
    }
  }

  void _showFilterDialog() {
    String? tempBranch = selectedBranch;
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
              DropdownButtonFormField<String>(
                value: tempBranch,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Branches')),
                  ...branches.map((branch) => DropdownMenuItem(
                    value: branch,
                    child: Text(branch),
                  )),
                ],
                onChanged: (value) {
                  setDialogState(() => tempBranch = value);
                  setState(() => selectedBranch = value);
                  _applyFilters();
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: tempYear,
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
                onChanged: (value) {
                  setDialogState(() => tempYear = value);
                  setState(() => selectedYear = value);
                  _applyFilters();
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: tempGender,
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
                onChanged: (value) {
                  setDialogState(() => tempGender = value);
                  setState(() => selectedGender = value);
                  _applyFilters();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                selectedBranch = null;
                selectedYear = null;
                selectedGender = null;
              });
              _applyFilters();
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
              DropdownButtonFormField<String>(
                value: tempSortBy,
                decoration: const InputDecoration(
                  labelText: 'Sort By',
                  border: OutlineInputBorder(),
                ),
                items: sortOptions.map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(option == 'createdAt' ? 'Registration Date' : option.toUpperCase()),
                )).toList(),
                onChanged: (value) {
                  setDialogState(() => tempSortBy = value!);
                  setState(() => sortBy = value!);
                  _applyFilters();
                },
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      title: const Text('Ascending'),
                      value: true,
                      groupValue: tempIsAscending,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      onChanged: (value) {
                        setDialogState(() => tempIsAscending = value!);
                        setState(() => isAscending = value!);
                        _applyFilters();
                      },
                    ),
                    Divider(height: 1, color: Colors.grey.shade300),
                    RadioListTile<bool>(
                      title: const Text('Descending'),
                      value: false,
                      groupValue: tempIsAscending,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      onChanged: (value) {
                        setDialogState(() => tempIsAscending = value!);
                        setState(() => isAscending = value!);
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
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

  Widget _buildHeader() {
    final size = MediaQuery.of(context).size;
    
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
        child: Padding(
          padding: EdgeInsets.all(size.width * 0.05),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Students Directory',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size.width * 0.06,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: isExporting ? null : _exportToExcel,
                    icon: isExporting 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.download, color: Colors.white),
                  ),
                ],
              ),
              
              SizedBox(height: size.height * 0.02),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          allStudents.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Total Students',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    Container(height: 40, width: 1, color: Colors.white30),
                    Column(
                      children: [
                        Text(
                          filteredStudents.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Filtered Results',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, USN, email, or phone...',
              prefixIcon: const Icon(Icons.search, color: primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryBlue.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryBlue.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryBlue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.filter_list),
                  label: Text('Filter (${_getActiveFiltersCount()})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: const BorderSide(color: primaryBlue),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showSortDialog,
                  icon: Icon(isAscending ? Icons.arrow_upward : Icons.arrow_downward),
                  label: Text('Sort by ${sortBy == 'createdAt' ? 'Date' : sortBy.toUpperCase()}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: const BorderSide(color: primaryBlue),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (selectedBranch != null) count++;
    if (selectedYear != null) count++;
    if (selectedGender != null) count++;
    return count;
  }

  Widget _buildCompactStudentCard(Map<String, dynamic> student, int index) {
    final size = MediaQuery.of(context).size;
    final isExpanded = expandedCards.contains(index);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  expandedCards.remove(index);
                } else {
                  expandedCards.add(index);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: primaryBlue.withOpacity(0.1),
                    backgroundImage: student['profileImageUrl'] != null
                        ? NetworkImage(student['profileImageUrl'])
                        : null,
                    child: student['profileImageUrl'] == null
                        ? Text(
                            student['fullName']?.substring(0, 1).toUpperCase() ?? 'S',
                            style: const TextStyle(
                              color: primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['fullName'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: size.width * 0.04,
                            fontWeight: FontWeight.bold,
                            color: deepBlack,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              student['usn'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: size.width * 0.032,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                student['branchName'] ?? 'N/A',
                                style: TextStyle(
                                  fontSize: size.width * 0.028,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: size.width * 0.028,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            firstChild: Container(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.email, 'Email', student['email'] ?? 'N/A'),
                  _buildDetailRow(Icons.phone, 'Phone', student['phone'] ?? 'N/A'),
                  _buildDetailRow(Icons.person, 'Gender', student['gender'] ?? 'N/A'),
                  _buildDetailRow(Icons.calendar_today, 'Year of Passing', student['yearOfPassing']?.toString() ?? 'N/A'),
                  
                  if (student['dateOfBirth'] != null)
                    _buildDetailRow(
                      Icons.cake,
                      'Date of Birth',
                      DateFormat('dd MMM yyyy').format(
                        (student['dateOfBirth'] as Timestamp).toDate(),
                      ),
                    ),
                  
                  if (student['createdAt'] != null)
                    _buildDetailRow(
                      Icons.access_time,
                      'Registered',
                      DateFormat('dd MMM yyyy').format(
                        (student['createdAt'] as Timestamp).toDate(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: deepBlack,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final size = MediaQuery.of(context).size;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/lottie/empty.json',
            width: size.width * 0.4,
            height: size.width * 0.4,
            fit: BoxFit.contain,
          ),
          SizedBox(height: size.height * 0.02),
          Text(
            searchQuery.isNotEmpty || _getActiveFiltersCount() > 0
                ? 'No students match your search criteria.\nTry adjusting your filters.'
                : 'No students found in your college.\nStudents will appear here once they register.',
            style: TextStyle(
              fontSize: size.width * 0.04,
              color: deepBlack.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: size.height * 0.02),
          if (searchQuery.isNotEmpty || _getActiveFiltersCount() > 0)
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  searchQuery = '';
                  selectedBranch = null;
                  selectedYear = null;
                  selectedGender = null;
                  expandedCards.clear();
                });
                _applyFilters();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear Filters'),
            )
          else
            TextButton.icon(
              onPressed: _loadStudents,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(foregroundColor: primaryBlue),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: lightGray,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/loading.json',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  const Text(
                    'Loading Students...',
                    style: TextStyle(
                      fontSize: 18,
                      color: deepBlack,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (collegeData != null) ...[
                    Text(
                      'College: ${collegeData!['collegeName'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: deepBlack.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      'Course: ${collegeData!['courseName'] ?? 'N/A'}',
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
      );
    }

    return Scaffold(
      backgroundColor: lightGray,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndFilterBar(),
            
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: filteredStudents.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            return _buildCompactStudentCard(filteredStudents[index], index);
                          },
                        ),
                ),
              ),
            ),
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