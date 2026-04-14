import 'package:shiksha_hub/user/cgpa_percentge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CgpaCalculatorPage extends StatefulWidget {
  const CgpaCalculatorPage({super.key});

  @override
  State<CgpaCalculatorPage> createState() => _CgpaCalculatorPageState();
}

class _CgpaCalculatorPageState extends State<CgpaCalculatorPage>
    with TickerProviderStateMixin {
  static const double _borderRadius = 24.0;
  static const double _maxCgpa = 10.0;
  static const double _minCgpa = 0.0;

  final List<TextEditingController> _sgpaControllers = List.generate(
    8,
    (index) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(8, (index) => FocusNode());

  double? _cgpa;
  double? _lastSavedCgpa;
  int? _lastSavedSemesterCount;
  String? _studentName;
  String? _studentUsn;
  bool _isLoadingProfile = true;
  bool _isExporting = false;
  late AnimationController _resultAnimationController;
  late AnimationController _summaryAnimationController;
  late Animation<double> _resultAnimation;
  late Animation<double> _summaryAnimation;

  @override
  void initState() {
    super.initState();
    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _summaryAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _resultAnimation = CurvedAnimation(
      parent: _resultAnimationController,
      curve: Curves.elasticOut,
    );
    _summaryAnimation = CurvedAnimation(
      parent: _summaryAnimationController,
      curve: Curves.easeInOut,
    );
    _loadStudentProfile();
    _loadSavedCgpaData();
  }

  @override
  void dispose() {
    for (var controller in _sgpaControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _resultAnimationController.dispose();
    _summaryAnimationController.dispose();
    super.dispose();
  }

  Future<String> _getUserCollection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');

    final studentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc('students')
        .collection('data')
        .doc(user.uid)
        .get();

    return studentDoc.exists ? 'students' : 'pending_students';
  }

  Future<void> _loadStudentProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final collection = await _getUserCollection();
      final doc = await FirebaseFirestore.instance
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
          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      setState(() => _isLoadingProfile = false);
      _showSnackBar('Failed to load profile: ${e.toString()}', isError: true);
    }
  }

  Future<void> _loadSavedCgpaData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = await _getUserCollection();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('cgpa_data')
          .doc('latest')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        int semesterCount = 0;
        if (mounted) {
          setState(() {
            for (int i = 0; i < 8; i++) {
              final sgpaValue = data['semester${i + 1}'];
              if (sgpaValue != null) {
                _sgpaControllers[i].text = sgpaValue.toString();
                semesterCount++;
              }
            }
            _cgpa = data['cgpa'];
            _lastSavedCgpa = data['cgpa'];
            _lastSavedSemesterCount = semesterCount;
          });
          if (_cgpa != null) {
            _resultAnimationController.forward();
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _summaryAnimationController.forward();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading saved CGPA data: $e');
    }
  }

  Future<void> _saveCgpaData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final sgpaData = <String, dynamic>{};
      for (int i = 0; i < _sgpaControllers.length; i++) {
        final text = _sgpaControllers[i].text.trim();
        if (text.isNotEmpty) {
          final value = double.tryParse(text);
          if (value != null) {
            sgpaData['semester${i + 1}'] = value;
          }
        }
      }
      sgpaData['cgpa'] = _cgpa;
      sgpaData['lastUpdated'] = FieldValue.serverTimestamp();

      final collection = await _getUserCollection();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('cgpa_data')
          .doc('latest')
          .set(sgpaData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving CGPA data: $e');
    }
  }

  Future<void> _exportToPdf() async {
    if (_cgpa == null) {
      _showSnackBar('Calculate CGPA first before exporting', isError: true);
      return;
    }

    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();
      final enteredSgpas = <int, String>{};
      for (int i = 0; i < _sgpaControllers.length; i++) {
        final text = _sgpaControllers[i].text.trim();
        if (text.isNotEmpty) {
          enteredSgpas[i] = text;
        }
      }

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
                          'CGPA Report',
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
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.purple100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Final CGPA:',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _cgpa!.toStringAsFixed(2),
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple900,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Semester-wise SGPA:',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerLeft,
                  headers: ['Sl.No.', 'Semester', 'SGPA'],
                  data: List.generate(enteredSgpas.length, (index) {
                    final entry = enteredSgpas.entries.elementAt(index);
                    return [
                      '${index + 1}',
                      'Semester ${entry.key + 1}',
                      entry.value,
                    ];
                  }),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Summary:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Total Semesters: ${enteredSgpas.length}'),
                      pw.Text('Average CGPA: ${_cgpa!.toStringAsFixed(2)}'),
                      pw.Text('Grade: ${_getGradeText(_cgpa!)}'),
                      pw.Text('Percentage: ${(_cgpa! * 10.0).toStringAsFixed(2)}%'),
                    ],
                  ),
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
      final file = File('${output.path}/cgpa_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'CGPA Report',
        text: 'CGPA report for ${_studentName ?? "Student"}',
      );

      _showSnackBar('PDF exported successfully');
    } catch (e) {
      _showSnackBar('Failed to export PDF: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _calculateCGPA() {
    double total = 0;
    int count = 0;

    for (int i = 0; i < _sgpaControllers.length; i++) {
      final text = _sgpaControllers[i].text.trim();
      if (text.isNotEmpty) {
        final value = double.tryParse(text);
        if (value != null && value >= _minCgpa && value <= _maxCgpa) {
          total += value;
          count++;
        }
      }
    }

    if (count == 0) {
      _showSnackBar("Please enter at least one valid SGPA value", isError: true);
      return;
    }

    setState(() {
      _cgpa = total / count;
      _lastSavedCgpa = _cgpa;
      _lastSavedSemesterCount = count;
    });

    _resultAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _summaryAnimationController.forward();
    });

    _saveCgpaData();
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearAll() {
    for (var controller in _sgpaControllers) {
      controller.clear();
    }
    setState(() {
      _cgpa = null;
    });
    _resultAnimationController.reset();
    _summaryAnimationController.reset();
    _saveCgpaData();
  }

  String _getGradeText(double cgpa) {
    if (cgpa >= 7.0) return "First Class with Distinction (FCD)";
    if (cgpa >= 6.0) return "First Class (FC)";
    if (cgpa >= 3.5) return "Second Class (SC)";
    return "Fail (F)";
  }

  String? _validateSgpaInput(String value) {
    if (value.isEmpty) return null;

    final parsedValue = double.tryParse(value);
    if (parsedValue == null) {
      return 'Invalid format';
    }

    if (parsedValue < _minCgpa || parsedValue > _maxCgpa) {
      return 'Must be 0-10';
    }

    return null;
  }

  void _onSgpaChanged(int index, String value) {
    if (_cgpa != null) {
      setState(() {
        _cgpa = null;
      });
      _resultAnimationController.reset();
      _summaryAnimationController.reset();
    }

    if (value.isNotEmpty) {
      final parsedValue = double.tryParse(value);
      if (parsedValue != null && parsedValue > _maxCgpa) {
        _sgpaControllers[index].text = _maxCgpa.toString();
        _sgpaControllers[index].selection = TextSelection.fromPosition(
          TextPosition(offset: _sgpaControllers[index].text.length),
        );
        _showSnackBar('SGPA cannot exceed 10.0', isError: true);
      }
    }

    setState(() {});
  }

  Widget _buildSgpaField(int index, double width) {
    final isMobile = width < 600;
    final List<Color> semesterColors = [
      Colors.purple,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.deepOrange,
      Colors.pink,
      Colors.indigo,
    ];

    final errorText = _validateSgpaInput(_sgpaControllers[index].text);

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isMobile ? 16 : width * 0.05,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: semesterColors[index].withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    size: 16,
                    color: semesterColors[index],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Semester ${index + 1}",
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: semesterColors[index],
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: _sgpaControllers[index],
            focusNode: _focusNodes[index],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue;
                
                final value = double.tryParse(newValue.text);
                if (value != null && value > _maxCgpa) {
                  return oldValue;
                }
                return newValue;
              }),
            ],
            onChanged: (value) => _onSgpaChanged(index, value),
            onSubmitted: (_) {
              if (index < 7) {
                _focusNodes[index + 1].requestFocus();
              } else {
                _focusNodes[index].unfocus();
              }
            },
            textInputAction: index < 7 ? TextInputAction.next : TextInputAction.done,
            decoration: InputDecoration(
              hintText: "Enter SGPA (0.0 - 10.0)",
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: isMobile ? 14 : 16,
              ),
              errorText: errorText,
              errorStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: errorText != null 
                  ? Colors.red.shade50 
                  : semesterColors[index].withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: errorText != null 
                        ? Colors.red.shade400 
                        : semesterColors[index].withOpacity(0.3), 
                    width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: errorText != null 
                        ? Colors.red.shade400 
                        : semesterColors[index].withOpacity(0.3), 
                    width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: errorText != null 
                        ? Colors.red.shade600 
                        : semesterColors[index], 
                    width: 2.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.red.shade600, width: 2.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
                vertical: isMobile ? 16 : 18,
              ),
              suffixIcon: _sgpaControllers[index].text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: errorText != null 
                            ? Colors.red.shade400 
                            : semesterColors[index].withOpacity(0.6),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _sgpaControllers[index].clear();
                        });
                      },
                    )
                  : null,
            ),
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: errorText != null ? Colors.red.shade700 : Colors.grey[800],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 200 + (index * 80)))
        .slideX(begin: 0.2, end: 0);
  }

  Widget _buildResultCard(double width) {
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1024;

    return AnimatedBuilder(
      animation: _resultAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _resultAnimation.value,
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : (isTablet ? 32 : width * 0.05),
              vertical: 12,
            ),
            padding: EdgeInsets.all(isMobile ? 24 : (isTablet ? 28 : 32)),
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
                    size: isMobile ? 48 : (isTablet ? 56 : 64),
                  ),
                ),
                SizedBox(height: isMobile ? 16 : (isTablet ? 18 : 20)),
                Text(
                  "Your CGPA",
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 18 : (isTablet ? 20 : 22),
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Text(
                  _cgpa!.toStringAsFixed(2),
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 56 : (isTablet ? 64 : 72),
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
                SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CgpaPercentageConverterPage(
                              initialCgpa: _cgpa,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text("Convert"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepPurple[700],
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 20, 
                          vertical: isMobile ? 10 : 12
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isExporting ? null : _exportToPdf,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(_isExporting ? "Exporting..." : "Export PDF"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red[700],
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 20, 
                          vertical: isMobile ? 10 : 12
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ],
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
                    _getGradeText(_cgpa!),
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

  Widget _buildSummaryCard(double width) {
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1024;
    final enteredSgpas = <int, String>{};
    
    for (int i = 0; i < _sgpaControllers.length; i++) {
      final text = _sgpaControllers[i].text.trim();
      if (text.isNotEmpty && _validateSgpaInput(text) == null) {
        enteredSgpas[i] = text;
      }
    }

    return AnimatedBuilder(
      animation: _summaryAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _summaryAnimation.value) * 50),
          child: Opacity(
            opacity: _summaryAnimation.value,
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : (isTablet ? 32 : width * 0.05),
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.blue.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(_borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.blue.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 20 : (isTablet ? 22 : 24)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade400,
                          Colors.cyan.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(_borderRadius),
                        topRight: Radius.circular(_borderRadius),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.summarize_rounded,
                            color: Colors.blue.shade600,
                            size: isMobile ? 24 : 28,
                          ),
                        ),
                        SizedBox(width: isMobile ? 16 : 20),
                        Expanded(
                          child: Text(
                            "Calculation Summary",
                            style: GoogleFonts.poppins(
                              fontSize: isMobile ? 18 : (isTablet ? 19 : 20),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 20 : (isTablet ? 22 : 24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Entered SGPA Values:",
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        ...enteredSgpas.entries
                            .map((entry) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          "Semester ${entry.key + 1}:",
                                          style: GoogleFonts.poppins(
                                            fontSize: isMobile ? 14 : 16,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 12 : 16,
                                          vertical: isMobile ? 6 : 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade100,
                                              Colors.cyan.shade100,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.blue.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          entry.value,
                                          style: GoogleFonts.poppins(
                                            fontSize: isMobile ? 14 : 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        SizedBox(height: isMobile ? 16 : 20),
                        Container(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade100,
                                Colors.teal.shade50,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      "Total Semesters:",
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 14 : 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${enteredSgpas.length}",
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isMobile ? 12 : 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      "Average CGPA:",
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _cgpa!.toStringAsFixed(2),
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 20 : 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
    final isTablet = width >= 600 && width < 1024;
    final maxContentWidth = isTablet ? 700.0 : (width > 1024 ? 900.0 : width);

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
          "CGPA Calculator",
          style: GoogleFonts.poppins(
            fontSize: isMobile ? 18 : 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_cgpa != null)
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: _clearAll,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
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
                    margin: EdgeInsets.all(isMobile ? 16 : (isTablet ? 24 : 16)),
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
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 18 : 20)),
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
                        if (_lastSavedCgpa != null && _lastSavedSemesterCount != null)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : 20,
                              vertical: isMobile ? 12 : 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade50,
                                  Colors.cyan.shade50,
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.purple.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: isMobile ? 18 : 20,
                                  color: Colors.blue[700],
                                ),
                                Text(
                                  "Last CGPA: ",
                                  style: GoogleFonts.poppins(
                                    fontSize: isMobile ? 13 : 15,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade600,
                                        Colors.cyan.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _lastSavedCgpa!.toStringAsFixed(2),
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 14 : 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  "• ${_lastSavedSemesterCount! == 1 ? '1 Sem' : '$_lastSavedSemesterCount Sems'}",
                                  style: GoogleFonts.poppins(
                                    fontSize: isMobile ? 12 : 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : (isTablet ? width * 0.06 : width * 0.04),
                        ),
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.indigo.shade50,
                              Colors.purple.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.indigo.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              color: Colors.indigo[600],
                              size: isMobile ? 24 : 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Enter SGPA for each semester (0.0 - 10.0)",
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 14 : (isTablet ? 16 : 17),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: const Duration(milliseconds: 500))
                          .slideY(begin: 0.2),
                      SizedBox(height: isMobile ? 20 : 24),
                      ...List.generate(8, (index) => _buildSgpaField(index, width)),
                      SizedBox(height: isMobile ? 24 : 32),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : (isTablet ? width * 0.06 : width * 0.05),
                        ),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.indigo.shade600,
                              Colors.purple.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _calculateCGPA,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 18 : 22,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calculate_rounded,
                                size: isMobile ? 24 : 30,
                              ),
                              SizedBox(width: isMobile ? 10 : 16),
                              Text(
                                "Calculate CGPA",
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: const Duration(milliseconds: 900))
                          .slideY(begin: 0.3),
                      if (_cgpa != null) ...[
                        SizedBox(height: isMobile ? 24 : 32),
                        _buildResultCard(width),
                        _buildSummaryCard(width),
                      ],
                      SizedBox(height: isMobile ? 24 : 32),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : (isTablet ? width * 0.06 : width * 0.05),
                        ),
                        padding: EdgeInsets.all(isMobile ? 20 : 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade50,
                              Colors.orange.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.orange.shade400,
                                        Colors.deepOrange.shade500,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: Colors.white,
                                    size: isMobile ? 22 : 24,
                                  ),
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Expanded(
                                  child: Text(
                                    "How CGPA is Calculated",
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 15 : 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isMobile ? 12 : 14),
                            Text(
                              "CGPA = (Sum of all SGPA) ÷ (Number of semesters)\n\nOnly enter SGPA values for completed semesters. Values must be between 0.0 and 10.0. Empty fields will be ignored in the calculation.",
                              style: GoogleFonts.poppins(
                                fontSize: isMobile ? 13 : 15,
                                color: Colors.grey.shade700,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: const Duration(milliseconds: 1100))
                          .slideY(begin: 0.3),
                      SizedBox(height: isMobile ? 32 : 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}