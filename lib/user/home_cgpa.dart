import 'package:shiksha_hub/user/cgpa_calculator_page.dart';
import 'package:shiksha_hub/user/cgpa_percentge.dart';
import 'package:shiksha_hub/user/sgpa_cal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CgpaSgpaPage extends StatefulWidget {
  const CgpaSgpaPage({super.key});

  @override
  State<CgpaSgpaPage> createState() => _CgpaSgpaPageState();
}

class _CgpaSgpaPageState extends State<CgpaSgpaPage> {
  static const double _borderRadius = 24.0;

  String? _studentName;
  String? _studentUsn;
  double? _savedCgpa;
  double? _savedPercentage;
  int? _savedSemesterCount;
  bool _isLoadingProfile = true;
  bool _isLoadingCgpaData = true;

  final List<Map<String, dynamic>> calculatorItems = [
    {
      "icon": Icons.calculate_rounded,
      "title": "CGPA Calculator",
      "description": "Calculate your overall CGPA across all semesters",
      "color": Colors.purple,
      "gradient": [Colors.purple.shade400, Colors.deepPurple.shade500],
    },
    {
      "icon": Icons.analytics_rounded,
      "title": "SGPA Calculator",
      "description": "Calculate your semester grade point average",
      "color": Colors.green,
      "gradient": [Colors.green.shade400, Colors.green.shade600],
    },
    {
      "icon": Icons.swap_horiz_rounded,
      "title": "CGPA to Percentage",
      "description": "Convert your CGPA to percentage format",
      "color": Colors.orange,
      "gradient": [Colors.orange.shade400, Colors.deepOrange.shade500],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadStudentProfile();
    _loadSavedData();
  }

  Future<void> _loadStudentProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc('pending_students')
            .collection('data')
            .doc(user.uid)
            .get();
      }

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
    }
  }

  Future<void> _loadSavedData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingCgpaData = false);
        return;
      }

      DocumentSnapshot cgpaDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(user.uid)
          .collection('cgpa_data')
          .doc('latest')
          .get();

      if (!cgpaDoc.exists) {
        cgpaDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc('pending_students')
            .collection('data')
            .doc(user.uid)
            .collection('cgpa_data')
            .doc('latest')
            .get();
      }

      DocumentSnapshot converterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(user.uid)
          .collection('converter_data')
          .doc('latest')
          .get();

      if (!converterDoc.exists) {
        converterDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc('pending_students')
            .collection('data')
            .doc(user.uid)
            .collection('converter_data')
            .doc('latest')
            .get();
      }

      double? cgpa;
      double? percentage;
      int? semesterCount;

      if (cgpaDoc.exists) {
        final cgpaData = cgpaDoc.data() as Map<String, dynamic>;
        cgpa = cgpaData['cgpa'];
        
        int count = 0;
        for (int i = 0; i < 8; i++) {
          if (cgpaData['semester${i + 1}'] != null) {
            count++;
          }
        }
        semesterCount = count > 0 ? count : null;
      }

      if (converterDoc.exists) {
        final converterData = converterDoc.data() as Map<String, dynamic>;
        if (converterData['percentageResult'] != null) {
          percentage = double.tryParse(converterData['percentageResult'].toString());
        } else if (cgpa != null) {
          percentage = cgpa * 9.5;
        }
      } else if (cgpa != null) {
        percentage = cgpa * 9.5;
      }

      setState(() {
        _savedCgpa = cgpa;
        _savedPercentage = percentage;
        _savedSemesterCount = semesterCount;
        _isLoadingCgpaData = false;
      });
    } catch (e) {
      setState(() => _isLoadingCgpaData = false);
    }
  }

  Widget _buildCalculatorCard(int index, double width) {
    final item = calculatorItems[index];
    final color = item["color"] as Color;
    final gradient = item["gradient"] as List<Color>;
    final isMobile = width < 600;

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 12,
        horizontal: isMobile ? 16 : width * 0.05,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleCardTap(index),
          borderRadius: BorderRadius.circular(_borderRadius),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(_borderRadius),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  spreadRadius: 2,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 24 : 28),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      item["icon"],
                      size: isMobile ? 32 : 40,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: isMobile ? 16 : 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item["title"],
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item["description"],
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 13 : 15,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: color,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 400 + (index * 150)))
        .slideX(begin: 0.2, end: 0);
  }

  void _handleCardTap(int index) async {
    switch (index) {
      case 0:
        await _navigateToCgpaCalculator();
        break;
      case 1:
        _navigateToSgpaCalculator();
        break;
      case 2:
        await _navigateToCgpaToPercentage();
        break;
    }
  }

  Future<void> _navigateToCgpaCalculator() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CgpaCalculatorPage()),
    );
    _loadSavedData();
  }

  Future<void> _navigateToSgpaCalculator() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SgpaCalculatorPage()),
    );
    _loadSavedData();
  }

  Future<void> _navigateToCgpaToPercentage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const CgpaPercentageConverterPage()),
    );
    _loadSavedData();
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
          "Grade Calculator",
          style: GoogleFonts.poppins(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.purple.shade50],
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
                        if (!_isLoadingCgpaData &&
                            (_savedCgpa != null || _savedPercentage != null))
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_savedCgpa != null) ...[
                                  Icon(
                                    Icons.school_outlined,
                                    size: isMobile ? 18 : 20,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "CGPA: ",
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
                                      _savedCgpa!.toStringAsFixed(2),
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 14 : 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                if (_savedCgpa != null && _savedSemesterCount != null)
                                  Text(
                                    " • upto ${_savedSemesterCount! == 1 ? '1 Sem' : '$_savedSemesterCount Sems'}",
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 12 : 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (_savedCgpa != null && _savedPercentage != null)
                                  Text(
                                    " • % ",
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 12 : 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (_savedPercentage != null) ...[
                                  if (_savedCgpa == null) ...[
                                    Icon(
                                      Icons.percent_rounded,
                                      size: isMobile ? 18 : 20,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Percentage: ",
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 13 : 15,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.orange.shade600,
                                          Colors.deepOrange.shade600,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withOpacity(0.3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _savedPercentage!.toStringAsFixed(2),
                                          style: GoogleFonts.poppins(
                                            fontSize: isMobile ? 14 : 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '%',
                                          style: GoogleFonts.poppins(
                                            fontSize: isMobile ? 12 : 14,
                                            color: Colors.white.withOpacity(0.9),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
                const SizedBox(height: 8),
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
                          horizontal: isMobile ? 20 : width * 0.04,
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
                              Icons.calculate_outlined,
                              color: Colors.indigo[600],
                              size: isMobile ? 24 : 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Choose your calculation tool",
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 15 : 17,
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
                      ...List.generate(
                        calculatorItems.length,
                        (index) => _buildCalculatorCard(index, width),
                      ),
                      SizedBox(height: isMobile ? 24 : 32),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : width * 0.05,
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
                                    Icons.info_outline_rounded,
                                    color: Colors.white,
                                    size: isMobile ? 22 : 24,
                                  ),
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Expanded(
                                  child: Text(
                                    "Important Information",
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
                              "All calculations are based on standard grading systems. Results may vary based on your institution's specific grading policy. Your data is automatically saved and can be accessed anytime.",
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