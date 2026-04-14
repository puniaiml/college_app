import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SgpaCalculatorPage extends StatefulWidget {
  const SgpaCalculatorPage({super.key});

  @override
  State<SgpaCalculatorPage> createState() => _SgpaCalculatorPageState();
}

class _SgpaCalculatorPageState extends State<SgpaCalculatorPage>
    with TickerProviderStateMixin {
  static const double _borderRadius = 24.0;
  static const double _maxContentWidth = 1200.0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchSchemeController = TextEditingController();
  final TextEditingController _searchBranchController = TextEditingController();
  final TextEditingController _searchSemesterController = TextEditingController();

  String? _studentName;
  String? _studentUsn;
  String? _studentCourseId;
  String? _studentBranchId;
  bool _isLoadingProfile = true;
  bool _isSaving = false;
  bool _isCalculating = false;

  String? _selectedSchemeId;
  String? _selectedBranchId;
  String? _selectedSemesterId;

  List<Map<String, dynamic>> _schemes = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _subjects = [];
  final List<Map<String, dynamic>> _selectedSubjects = [];
  final Map<String, TextEditingController> _marksControllers = {};
  final Map<String, FocusNode> _marksFocusNodes = {};
  final Map<String, double> _calculatedGradePoints = {};
  final Map<String, String?> _fieldErrors = {};
  List<Map<String, dynamic>> _sgpaHistory = [];

  Timer? _debounceTimer;
  double? _sgpa;
  late AnimationController _resultAnimationController;
  late Animation<double> _resultAnimation;

  @override
  void initState() {
    super.initState();
    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _resultAnimation = CurvedAnimation(
      parent: _resultAnimationController,
      curve: Curves.elasticOut,
    );
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadStudentProfile();
    await _loadSgpaHistory();
  }

  @override
  void dispose() {
    _searchSchemeController.dispose();
    _searchBranchController.dispose();
    _searchSemesterController.dispose();
    _marksControllers.forEach((key, controller) => controller.dispose());
    _marksFocusNodes.forEach((key, node) => node.dispose());
    _resultAnimationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<String> _getUserCollection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');

    final studentDoc = await _firestore
        .collection('users')
        .doc('students')
        .collection('data')
        .doc(user.uid)
        .get();

    return studentDoc.exists ? 'students' : 'pending_students';
  }

  double _marksToGradePoint(double marks) {
    if (marks >= 90) return 10;
    if (marks >= 80) return 9;
    if (marks >= 70) return 8;
    if (marks >= 60) return 7;
    if (marks >= 55) return 6;
    if (marks >= 50) return 5;
    if (marks >= 40) return 4;
    return 0;
  }

  String _marksToLetterGrade(double marks) {
    if (marks >= 90) return 'O';
    if (marks >= 80) return 'A+';
    if (marks >= 70) return 'A';
    if (marks >= 60) return 'B+';
    if (marks >= 55) return 'B';
    if (marks >= 50) return 'C';
    if (marks >= 40) return 'P';
    return 'F';
  }

  int _extractSemesterNumber(String semesterName) {
    final match = RegExp(r'\d+').firstMatch(semesterName);
    return match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
  }

  String? _validateMarks(String value) {
    if (value.trim().isEmpty) {
      return 'Required';
    }

    final marks = double.tryParse(value.trim());
    if (marks == null) {
      return 'Invalid number';
    }

    if (marks < 0) {
      return 'Cannot be negative';
    }

    if (marks > 100) {
      return 'Cannot exceed 100';
    }

    return null;
  }

  bool _validateAllMarks() {
    bool isValid = true;
    _fieldErrors.clear();

    for (var subject in _selectedSubjects) {
      final subjectId = subject['id'];
      final marksText = _marksControllers[subjectId]?.text ?? '';
      final error = _validateMarks(marksText);
      
      if (error != null) {
        _fieldErrors[subjectId] = error;
        isValid = false;
      }
    }

    setState(() {});
    return isValid;
  }

  Future<void> _loadStudentProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final collection = await _getUserCollection();
      final doc = await _firestore
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _studentName = data['fullName'] ?? 'Student';
          _studentUsn = data['usn'] ?? 'N/A';
          _studentCourseId = data['courseId'];
          _studentBranchId = data['branchId'];
          _isLoadingProfile = false;
        });
        await _loadSchemes();
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      setState(() => _isLoadingProfile = false);
      _showSnackBar('Failed to load profile', isError: true);
    }
  }

  Future<void> _loadSgpaHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = await _getUserCollection();
      final snapshot = await _firestore
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('sgpa_history')
          .orderBy('semesterNumber')
          .get();

      setState(() {
        _sgpaHistory = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'semesterName': data['semesterName'] ?? '',
            'semesterNumber': data['semesterNumber'] ?? 0,
            'totalCredits': data['totalCredits'] ?? 0,
            'totalMarks': data['totalMarks'] ?? 0.0,
            'sgpa': data['sgpa'] ?? 0.0,
            'schemeName': data['schemeName'] ?? '',
            'branchName': data['branchName'] ?? '',
            'schemeId': data['schemeId'] ?? '',
            'branchId': data['branchId'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Failed to load SGPA history: $e');
    }
  }

  Future<void> _loadSchemes() async {
    if (_studentCourseId == null) return;

    try {
      final snapshot = await _firestore
          .collection('schemes')
          .where('courseId', isEqualTo: _studentCourseId)
          .get();

      final systemSchemes = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'academicYear': data['academicYear'] ?? '',
          'isManual': false,
        };
      }).toList();

      final manualSchemes = await _loadManualData('schemes');

      setState(() {
        _schemes = [...systemSchemes, ...manualSchemes];
      });
    } catch (e) {
      _showSnackBar('Failed to load schemes', isError: true);
    }
  }

  Future<void> _loadBranches(String schemeId) async {
    if (_studentCourseId == null) return;

    try {
      final snapshot = await _firestore
          .collection('branches')
          .where('courseId', isEqualTo: _studentCourseId)
          .get();

      final systemBranches = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'isManual': false,
        };
      }).toList();

      final manualBranches = await _loadManualData('branches');

      setState(() {
        _branches = [...systemBranches, ...manualBranches];

        if (_studentBranchId != null &&
            _branches.any((b) => b['id'] == _studentBranchId)) {
          _selectedBranchId = _studentBranchId;
          _loadSemesters(schemeId, _studentBranchId!);
        }
      });
    } catch (e) {
      _showSnackBar('Failed to load branches', isError: true);
    }
  }

  Future<void> _loadSemesters(String schemeId, String branchId) async {
    try {
      final snapshot = await _firestore
          .collection('semesters')
          .where('branchId', isEqualTo: branchId)
          .get();

      final systemSemesters = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'isManual': false,
        };
      }).toList();

      final manualSemesters = await _loadManualData('semesters');

      setState(() {
        _semesters = [...systemSemesters, ...manualSemesters];
      });
    } catch (e) {
      _showSnackBar('Failed to load semesters', isError: true);
    }
  }

  Future<void> _loadSubjects(String schemeId, String branchId, String semesterId) async {
    try {
      final snapshot = await _firestore
          .collection('subjects')
          .where('schemeId', isEqualTo: schemeId)
          .where('branchId', isEqualTo: branchId)
          .where('semesterId', isEqualTo: semesterId)
          .get();

      final systemSubjects = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'code': data['code'] ?? '',
          'credits': data['credits'] ?? 0,
          'isManual': false,
        };
      }).toList();

      final manualSubjects = await _loadManualSubjects(schemeId, branchId, semesterId);

      setState(() {
        _subjects = [...systemSubjects, ...manualSubjects];
      });

      await _loadSavedMarks(schemeId, branchId, semesterId);
    } catch (e) {
      _showSnackBar('Failed to load subjects', isError: true);
    }
  }

  Future<List<Map<String, dynamic>>> _loadManualData(String type) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final collection = await _getUserCollection();
      final doc = await _firestore
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('manual_data')
          .doc(type)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Failed to load manual $type: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadManualSubjects(
      String schemeId, String branchId, String semesterId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final collection = await _getUserCollection();
      final snapshot = await _firestore
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('manual_subjects')
          .where('schemeId', isEqualTo: schemeId)
          .where('branchId', isEqualTo: branchId)
          .where('semesterId', isEqualTo: semesterId)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'code': data['code'] ?? '',
          'credits': data['credits'] ?? 0,
          'isManual': true,
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to load manual subjects: $e');
      return [];
    }
  }

  Future<void> _saveManualData(String type, Map<String, dynamic> item) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = await _getUserCollection();
      final docRef = _firestore
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('manual_data')
          .doc(type);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        List<dynamic> items = [];
        if (doc.exists) {
          items = (doc.data()?['items'] as List<dynamic>?) ?? [];
        }
        items.add(item);
        transaction.set(docRef, {'items': items}, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('Failed to save manual $type: $e');
      rethrow;
    }
  }

  Future<void> _saveManualSubject(Map<String, dynamic> subject) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = await _getUserCollection();
      await _firestore
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('manual_subjects')
          .doc(subject['id'])
          .set({
        ...subject,
        'schemeId': _selectedSchemeId,
        'branchId': _selectedBranchId,
        'semesterId': _selectedSemesterId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to save manual subject: $e');
      rethrow;
    }
  }

  Future<void> _loadSavedMarks(String schemeId, String branchId, String semesterId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = await _getUserCollection();
      final docId = '${schemeId}_${branchId}_$semesterId';
      final doc = await _firestore
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('sgpa_data')
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final savedMarks = data['marks'] as Map<String, dynamic>?;

        if (savedMarks != null) {
          for (var entry in savedMarks.entries) {
            final subject = _subjects.firstWhere(
              (s) => s['id'] == entry.key,
              orElse: () => {},
            );

            if (subject.isNotEmpty && !_selectedSubjects.any((s) => s['id'] == entry.key)) {
              _selectedSubjects.add(subject);
              _marksControllers[entry.key] = TextEditingController(text: entry.value.toString());
              _marksFocusNodes[entry.key] = FocusNode();
              _calculatedGradePoints[entry.key] = _marksToGradePoint(entry.value.toDouble());
            }
          }
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Failed to load saved marks: $e');
    }
  }

  Future<void> _saveMarks() async {
    if (_isSaving) return;

    try {
      setState(() => _isSaving = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _selectedSchemeId == null || 
          _selectedBranchId == null || _selectedSemesterId == null) {
        return;
      }

      final collection = await _getUserCollection();
      final docId = '${_selectedSchemeId}_${_selectedBranchId}_$_selectedSemesterId';
      final marksData = <String, double>{};

      for (var subject in _selectedSubjects) {
        final marksText = _marksControllers[subject['id']]?.text.trim() ?? '';
        final marks = double.tryParse(marksText);
        if (marks != null && marks >= 0 && marks <= 100) {
          marksData[subject['id']] = marks;
        }
      }

      await _firestore
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('sgpa_data')
          .doc(docId)
          .set({
        'marks': marksData,
        'schemeId': _selectedSchemeId,
        'branchId': _selectedBranchId,
        'semesterId': _selectedSemesterId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save marks: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _onMarksChanged(String value, String subjectId) {
    _debounceTimer?.cancel();
    
    if (mounted) {
      final error = _validateMarks(value);
      setState(() {
        _fieldErrors[subjectId] = error;
        
        if (error == null) {
          final marks = double.parse(value.trim());
          _calculatedGradePoints[subjectId] = _marksToGradePoint(marks);
        } else {
          _calculatedGradePoints[subjectId] = 0;
        }
        _sgpa = null;
      });
      _resultAnimationController.reset();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted && _validateMarks(value) == null) {
        _saveMarks();
      }
    });
  }

  void _calculateSGPA() async {
    if (_isCalculating) return;

    if (_selectedSubjects.isEmpty) {
      _showSnackBar("Please add at least one subject", isError: true);
      return;
    }

    if (!_validateAllMarks()) {
      _showSnackBar("Please fix all errors before calculating", isError: true);
      return;
    }

    setState(() => _isCalculating = true);

    try {
      double totalWeightedGrade = 0;
      int totalCredits = 0;

      for (var subject in _selectedSubjects) {
        final marksText = _marksControllers[subject['id']]?.text.trim() ?? '';
        final marks = double.parse(marksText);
        final gradePoint = _marksToGradePoint(marks);
        final credits = subject['credits'] as int;
        
        totalWeightedGrade += gradePoint * credits;
        totalCredits += credits;
      }

      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _sgpa = totalWeightedGrade / totalCredits;
        _isCalculating = false;
      });

      await _saveMarks();
      await _saveSgpaToHistory();
      _resultAnimationController.forward();
    } catch (e) {
      setState(() => _isCalculating = false);
      _showSnackBar('Calculation failed', isError: true);
    }
  }

  Future<void> _saveSgpaToHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _selectedSemesterId == null || _sgpa == null ||
          _selectedSchemeId == null || _selectedBranchId == null) {
        return;
      }

      int totalCredits = 0;
      double totalMarks = 0;

      for (var subject in _selectedSubjects) {
        final marksText = _marksControllers[subject['id']]?.text.trim() ?? '';
        final marks = double.tryParse(marksText);
        if (marks != null) {
          totalCredits += subject['credits'] as int;
          totalMarks += marks;
        }
      }

      final semesterName = _semesters.firstWhere(
        (s) => s['id'] == _selectedSemesterId,
        orElse: () => {'name': 'Unknown'},
      )['name'];

      final schemeName = _schemes.firstWhere(
        (s) => s['id'] == _selectedSchemeId,
        orElse: () => {'name': 'Unknown'},
      )['name'];

      final branchName = _branches.firstWhere(
        (b) => b['id'] == _selectedBranchId,
        orElse: () => {'name': 'Unknown'},
      )['name'];

      final semesterNumber = _extractSemesterNumber(semesterName);
      final collection = await _getUserCollection();

      await _firestore
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('sgpa_history')
          .doc(_selectedSemesterId!)
          .set({
        'semesterName': semesterName,
        'semesterNumber': semesterNumber,
        'totalCredits': totalCredits,
        'totalMarks': totalMarks,
        'sgpa': _sgpa,
        'schemeName': schemeName,
        'branchName': branchName,
        'schemeId': _selectedSchemeId,
        'branchId': _selectedBranchId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _loadSgpaHistory();
    } catch (e) {
      debugPrint('Failed to save SGPA to history: $e');
    }
  }

  Future<void> _deleteSgpaRecord(String recordId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = await _getUserCollection();
      await _firestore
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('sgpa_history')
          .doc(recordId)
          .delete();

      await _loadSgpaHistory();
      _showSnackBar('Record deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete record', isError: true);
    }
  }

  Future<void> _exportToPdf(String key, List<Map<String, dynamic>> records) async {
    try {
      final pdf = pw.Document();
      final schemeName = records.first['schemeName'] ?? 'Unknown Scheme';
      final branchName = records.first['branchName'] ?? 'Unknown Branch';

      final ByteData logoData = await rootBundle.load('assets/logo/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(logoImage, width: 50, height: 50),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Shiksha Hub',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo,
                          ),
                        ),
                        pw.Text(
                          'SGPA History Report',
                          style: pw.TextStyle(
                            fontSize: 16,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 2, color: PdfColors.indigo),
                pw.SizedBox(height: 15),
                pw.Text('Student: ${_studentName ?? 'N/A'}'),
                pw.Text('USN: ${_studentUsn ?? 'N/A'}'),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Scheme: $schemeName',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text('Branch: $branchName',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerLeft,
                  headers: ['Sl.No.', 'Semester', 'Credits', 'Total Marks', 'SGPA'],
                  data: List.generate(records.length, (index) {
                    final record = records[index];
                    return [
                      '${index + 1}',
                      record['semesterName'],
                      '${record['totalCredits']}',
                      record['totalMarks'].toStringAsFixed(2),
                      record['sgpa'].toStringAsFixed(2),
                    ];
                  }),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Generated on: ${DateTime.now().toString().split('.')[0]}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/sgpa_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'SGPA History Report',
        text: 'SGPA report for $schemeName - $branchName',
      );

      _showSnackBar('PDF exported successfully');
    } catch (e) {
      _showSnackBar('Failed to export PDF', isError: true);
    }
  }

  void _addSubjectToCalculation(Map<String, dynamic> subject) {
    if (!mounted) return;

    if (_selectedSubjects.any((s) => s['id'] == subject['id'])) {
      _showSnackBar('Subject already added', isError: true);
      return;
    }

    setState(() {
      _selectedSubjects.add(subject);
      _marksControllers[subject['id']] = TextEditingController();
      _marksFocusNodes[subject['id']] = FocusNode();
      _calculatedGradePoints[subject['id']] = 0;
      _fieldErrors[subject['id']] = null;
      _sgpa = null;
    });
    _resultAnimationController.reset();
  }

  void _removeSubjectFromCalculation(String subjectId) {
    if (!mounted) return;

    setState(() {
      _selectedSubjects.removeWhere((s) => s['id'] == subjectId);
      _marksControllers[subjectId]?.dispose();
      _marksControllers.remove(subjectId);
      _marksFocusNodes[subjectId]?.dispose();
      _marksFocusNodes.remove(subjectId);
      _calculatedGradePoints.remove(subjectId);
      _fieldErrors.remove(subjectId);
      _sgpa = null;
    });
    _resultAnimationController.reset();
    _saveMarks();
  }

  void _showManualEntryDialog(String type) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final creditsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_circle, color: Colors.purple, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add $type Manually',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
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
                  labelText: '$type Name',
                  hintText: 'e.g., ${_getHintText(type)}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              if (type == "Subject") ...[
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Subject Code',
                    hintText: 'e.g., CS101',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: creditsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Credits',
                    hintText: 'e.g., 4',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                _showSnackBar('Name cannot be empty', isError: true);
                return;
              }

              try {
                if (type == "Subject") {
                  if (codeController.text.trim().isEmpty) {
                    _showSnackBar('Code cannot be empty', isError: true);
                    return;
                  }
                  final credits = int.tryParse(creditsController.text.trim());
                  if (credits == null || credits <= 0) {
                    _showSnackBar('Valid credits required', isError: true);
                    return;
                  }

                  final newSubject = {
                    'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
                    'name': nameController.text.trim(),
                    'code': codeController.text.trim(),
                    'credits': credits,
                    'isManual': true,
                  };

                  await _saveManualSubject(newSubject);

                  setState(() {
                    _subjects.add(newSubject);
                  });
                  _showSnackBar('Subject added successfully!');
                } else {
                  final newItem = {
                    'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
                    'name': nameController.text.trim(),
                    'academicYear': type == "Scheme" ? '' : null,
                    'isManual': true,
                  };

                  await _saveManualData('${type.toLowerCase()}s', newItem);

                  setState(() {
                    if (type == "Scheme") {
                      _schemes.add(newItem);
                      _selectedSchemeId = newItem['id'] as String?;
                    } else if (type == "Branch") {
                      _branches.add(newItem);
                    } else if (type == "Semester") {
                      _semesters.add(newItem);
                    }
                  });
                  _showSnackBar('$type added successfully!');
                }

                Navigator.pop(context);
              } catch (e) {
                _showSnackBar('Failed to add $type', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Add', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 300), () {
        nameController.dispose();
        codeController.dispose();
        creditsController.dispose();
      });
    });
  }

  String _getHintText(String type) {
    switch (type) {
      case "Subject":
        return "Data Structures";
      case "Scheme":
        return "Scheme 2023";
      case "Branch":
        return "Computer Science";
      case "Semester":
        return "Semester 1";
      default:
        return "";
    }
  }

  void _showDeleteConfirmation(String recordId, String semesterName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Record?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the SGPA record for $semesterName? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSgpaRecord(recordId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSearchableDialog({
    required List<Map<String, dynamic>> items,
    required String? selectedValue,
    required Function(String?) onChanged,
    required TextEditingController searchController,
    required String type,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = searchController.text.isEmpty
                ? items
                : items.where((item) {
                    final name = item['name'].toString().toLowerCase();
                    final search = searchController.text.toLowerCase();
                    return name.contains(search);
                  }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select $type',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.purple),
                        onPressed: () {
                          Navigator.pop(context);
                          _showManualEntryDialog(type);
                        },
                        tooltip: 'Add $type Manually',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search $type...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => setDialogState(() {}),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected = selectedValue == item['id'];
                          final isManual = item['isManual'] == true;

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.purple.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isManual ? Icons.edit : Icons.check_circle,
                                color: isSelected ? Colors.purple : Colors.grey,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item['name'],
                              style: GoogleFonts.poppins(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            subtitle: item['academicYear'] != null && item['academicYear'] != ''
                                ? Text(item['academicYear'], style: GoogleFonts.poppins(fontSize: 12))
                                : null,
                            trailing: isManual
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Manual',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : null,
                            selected: isSelected,
                            selectedTileColor: Colors.purple.withOpacity(0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onTap: () {
                              Navigator.pop(context);
                              if (mounted) {
                                onChanged(item['id']);
                              }
                              searchController.clear();
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    searchController.clear();
                    Navigator.pop(context);
                  },
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchableDropdown({
    required String label,
    required List<Map<String, dynamic>> items,
    required String? selectedValue,
    required Function(String?) onChanged,
    required TextEditingController searchController,
    required String type,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: items.isEmpty ? null : () => _showSearchableDialog(
            items: items,
            selectedValue: selectedValue,
            onChanged: onChanged,
            searchController: searchController,
            type: type,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: items.isEmpty ? Colors.grey.shade100 : Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedValue != null && items.isNotEmpty
                        ? items.firstWhere((item) => item['id'] == selectedValue, 
                            orElse: () => {'name': 'Select $type'})['name']
                        : 'Select $type',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: selectedValue != null && items.isNotEmpty ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSgpaHistoryTable(double width) {
    final isMobile = width < 600;

    if (_sgpaHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    Map<String, List<Map<String, dynamic>>> groupedHistory = {};

    for (var record in _sgpaHistory) {
      final key = '${record['schemeId']}_${record['branchId']}';
      if (!groupedHistory.containsKey(key)) {
        groupedHistory[key] = [];
      }
      groupedHistory[key]!.add(record);
    }

    return Column(
      children: groupedHistory.entries.map((entry) {
        final records = entry.value;
        final schemeName = records.first['schemeName'] ?? 'Unknown Scheme';
        final branchName = records.first['branchName'] ?? 'Unknown Branch';

        return Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.green.shade50],
            ),
            borderRadius: BorderRadius.circular(_borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.teal.shade500],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.history, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'SGPA History',
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    onPressed: () => _exportToPdf(entry.key, records),
                    tooltip: 'Export as PDF',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school, size: 18, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Scheme: ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            schemeName,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.account_tree, size: 18, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Branch: ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            branchName,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.green.shade100),
                  border: TableBorder.all(
                    color: Colors.green.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  headingTextStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green.shade900,
                  ),
                  dataTextStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                  columns: const [
                    DataColumn(label: Text('Sl.No.')),
                    DataColumn(label: Text('Semester')),
                    DataColumn(label: Text('Credits')),
                    DataColumn(label: Text('Avg Marks')),
                    DataColumn(label: Text('SGPA')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: List.generate(records.length, (index) {
                    final record = records[index];
                    final avgMarks = record['totalCredits'] > 0
                        ? record['totalMarks'] / record['totalCredits']
                        : 0.0;
                    return DataRow(
                      color: MaterialStateProperty.all(
                        index % 2 == 0 ? Colors.white : Colors.green.shade50,
                      ),
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(record['semesterName'])),
                        DataCell(Text('${record['totalCredits']}')),
                        DataCell(Text(avgMarks.toStringAsFixed(2))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              record['sgpa'].toStringAsFixed(2),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _showDeleteConfirmation(
                              record['id'],
                              record['semesterName'],
                            ),
                            tooltip: 'Delete',
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: const Duration(milliseconds: 300));
      }).toList(),
    );
  }

  Widget _buildFilterSection(double width) {
    final isMobile = width < 600;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.deepPurple.shade500],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.filter_list, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Select Filters',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSearchableDropdown(
            label: 'Scheme',
            items: _schemes,
            selectedValue: _selectedSchemeId,
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  _selectedSchemeId = value;
                  _selectedBranchId = null;
                  _selectedSemesterId = null;
                  _subjects.clear();
                  _selectedSubjects.clear();
                  _branches.clear();
                  _semesters.clear();
                  _sgpa = null;
                  _marksControllers.forEach((key, controller) => controller.dispose());
                  _marksControllers.clear();
                  _marksFocusNodes.forEach((key, node) => node.dispose());
                  _marksFocusNodes.clear();
                  _calculatedGradePoints.clear();
                  _fieldErrors.clear();
                });
              }
              if (value != null) _loadBranches(value);
            },
            searchController: _searchSchemeController,
            type: 'Scheme',
          ),
          const SizedBox(height: 16),
          _buildSearchableDropdown(
            label: 'Branch',
            items: _branches,
            selectedValue: _selectedBranchId,
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  _selectedBranchId = value;
                  _selectedSemesterId = null;
                  _subjects.clear();
                  _selectedSubjects.clear();
                  _semesters.clear();
                  _sgpa = null;
                  _marksControllers.forEach((key, controller) => controller.dispose());
                  _marksControllers.clear();
                  _marksFocusNodes.forEach((key, node) => node.dispose());
                  _marksFocusNodes.clear();
                  _calculatedGradePoints.clear();
                  _fieldErrors.clear();
                });
              }
              if (value != null && _selectedSchemeId != null) {
                _loadSemesters(_selectedSchemeId!, value);
              }
            },
            searchController: _searchBranchController,
            type: 'Branch',
          ),
          const SizedBox(height: 16),
          _buildSearchableDropdown(
            label: 'Semester',
            items: _semesters,
            selectedValue: _selectedSemesterId,
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  _selectedSemesterId = value;
                  _subjects.clear();
                  _selectedSubjects.clear();
                  _sgpa = null;
                  _marksControllers.forEach((key, controller) => controller.dispose());
                  _marksControllers.clear();
                  _marksFocusNodes.forEach((key, node) => node.dispose());
                  _marksFocusNodes.clear();
                  _calculatedGradePoints.clear();
                  _fieldErrors.clear();
                });
              }
              if (value != null && _selectedSchemeId != null && _selectedBranchId != null) {
                _loadSubjects(_selectedSchemeId!, _selectedBranchId!, value);
              }
            },
            searchController: _searchSemesterController,
            type: 'Semester',
          ),
        ],
      ),
    ).animate().fadeIn(delay: const Duration(milliseconds: 300));
  }

  Widget _buildSubjectSelector(double width) {
    final isMobile = width < 600;

    if (_selectedSchemeId == null || _selectedBranchId == null || _selectedSemesterId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.subject, color: Colors.teal, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Available Subjects',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.purple),
                onPressed: () => _showManualEntryDialog('Subject'),
                tooltip: 'Add Subject Manually',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_subjects.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No subjects found',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add subjects manually using the + button',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_subjects.map((subject) {
              final isAdded = _selectedSubjects.any((s) => s['id'] == subject['id']);
              final isManual = subject['isManual'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isAdded ? Colors.green.withOpacity(0.5) : Colors.grey.shade300,
                    width: isAdded ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isAdded ? Colors.green.withOpacity(0.05) : Colors.grey.shade50,
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isManual ? Icons.edit : Icons.book,
                      color: Colors.teal,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    subject['name'],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        subject['code'],
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 10, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              '${subject['credits']} Credits',
                              style: GoogleFonts.poppins(fontSize: 10, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                      ),
                      if (isManual) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Manual',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: isAdded
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.add_circle_outline, color: Colors.grey),
                  onTap: isAdded ? null : () => _addSubjectToCalculation(subject),
                ),
              );
            })),
        ],
      ),
    ).animate().fadeIn(delay: const Duration(milliseconds: 500));
  }

  Widget _buildSelectedSubjects(double width) {
    final isMobile = width < 600;

    if (_selectedSubjects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(_borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.cyan.shade500],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calculate, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Enter Marks',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              if (_isSaving)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ...(_selectedSubjects.asMap().entries.map((entry) {
            final index = entry.key;
            final subject = entry.value;
            final subjectId = subject['id'];
            final hasError = _fieldErrors[subjectId] != null;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasError ? Colors.red.withOpacity(0.5) : Colors.blue.withOpacity(0.3),
                  width: hasError ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject['name'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  subject['code'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${subject['credits']} Credits',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeSubjectFromCalculation(subjectId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _marksControllers[subjectId],
                    focusNode: _marksFocusNodes[subjectId],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: index < _selectedSubjects.length - 1 
                        ? TextInputAction.next 
                        : TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Marks (0 - 100)',
                      hintText: 'e.g., 85',
                      errorText: _fieldErrors[subjectId],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: hasError ? Colors.red.shade50 : Colors.blue.shade50,
                      prefixIcon: Icon(
                        Icons.edit_note, 
                        color: hasError ? Colors.red : Colors.blue,
                      ),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (value) => _onMarksChanged(value, subjectId),
                    onSubmitted: (_) {
                      if (index < _selectedSubjects.length - 1) {
                        _marksFocusNodes[_selectedSubjects[index + 1]['id']]?.requestFocus();
                      }
                    },
                  ),
                  if (_calculatedGradePoints[subjectId] != null &&
                      _marksControllers[subjectId]?.text.isNotEmpty == true &&
                      !hasError) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade50, Colors.blue.shade50],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.stars, color: Colors.purple.shade400, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Grade: ',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            _marksToLetterGrade(
                                double.parse(_marksControllers[subjectId]!.text)),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Grade Point: ',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            _calculatedGradePoints[subjectId]!.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          })),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCalculating ? null : _calculateSGPA,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isCalculating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Calculating...',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calculate_rounded, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Calculate SGPA',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: const Duration(milliseconds: 700));
  }

  Widget _buildResultCard(double width) {
    final isMobile = width < 600;

    return AnimatedBuilder(
      animation: _resultAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _resultAnimation.value,
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 12,
            ),
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade400,
                  Colors.deepPurple.shade500,
                  Colors.indigo.shade600
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(_borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.5),
                  spreadRadius: 3,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: isMobile ? 48 : 64,
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 20),
                Text(
                  "Your SGPA",
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 18 : 22,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Text(
                  _sgpa!.toStringAsFixed(2),
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 56 : 72,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    height: 1,
                    shadows: [
                      Shadow(
                        blurRadius: 30,
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 24,
                    vertical: isMobile ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'Based on ${_selectedSubjects.length} subject${_selectedSubjects.length > 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 14 : 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isMobile = width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade600, Colors.purple.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          "SGPA Calculator",
          style: GoogleFonts.poppins(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStudentProfile();
          await _loadSgpaHistory();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                children: [
                  if (_isLoadingProfile)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 20,
                        vertical: isMobile ? 12 : 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.blue.shade50],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.indigo,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Loading profile...",
                            style: GoogleFonts.poppins(
                              fontSize: isMobile ? 13 : 15,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.purple.shade50,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isMobile ? 12 : 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.shade400,
                                    Colors.deepPurple.shade500,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: isMobile ? 28 : 32,
                              ),
                            ),
                            SizedBox(width: isMobile ? 16 : 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _studentName ?? 'Student',
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 17 : 19,
                                      color: Colors.grey[900],
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _studentUsn ?? 'N/A',
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 13 : 15,
                                      color: Colors.grey[600],
                                      letterSpacing: 0.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
                  SizedBox(height: isMobile ? 8 : 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: isMobile ? 32 : 40),
                        _buildSgpaHistoryTable(width),
                        _buildFilterSection(width),
                        _buildSubjectSelector(width),
                        _buildSelectedSubjects(width),
                        if (_sgpa != null) _buildResultCard(width),
                        SizedBox(height: isMobile ? 32 : 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}