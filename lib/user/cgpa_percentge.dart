import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CgpaPercentageConverterPage extends StatefulWidget {
  final double? initialCgpa;

  const CgpaPercentageConverterPage({super.key, this.initialCgpa});

  @override
  State<CgpaPercentageConverterPage> createState() =>
      _CgpaPercentageConverterPageState();
}

class _CgpaPercentageConverterPageState
    extends State<CgpaPercentageConverterPage> with TickerProviderStateMixin {
  static const double _borderRadius = 24.0;

  final TextEditingController _cgpaController = TextEditingController();
  final TextEditingController _percentageController = TextEditingController();

  double? _percentageResult;
  double? _cgpaResult;
  String? _studentName;
  String? _studentUsn;
  bool _isLoadingProfile = true;
  double? _lastSavedCgpa;
  double? _lastSavedPercentage;

  late AnimationController _cgpaResultAnimationController;
  late AnimationController _percentageResultAnimationController;
  late AnimationController _cgpaSummaryAnimationController;
  late AnimationController _percentageSummaryAnimationController;
  late Animation<double> _cgpaResultAnimation;
  late Animation<double> _percentageResultAnimation;
  late Animation<double> _cgpaSummaryAnimation;
  late Animation<double> _percentageSummaryAnimation;

  @override
  void initState() {
    super.initState();
    _cgpaResultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _percentageResultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _cgpaSummaryAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _percentageSummaryAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cgpaResultAnimation = CurvedAnimation(
      parent: _cgpaResultAnimationController,
      curve: Curves.elasticOut,
    );
    _percentageResultAnimation = CurvedAnimation(
      parent: _percentageResultAnimationController,
      curve: Curves.elasticOut,
    );
    _cgpaSummaryAnimation = CurvedAnimation(
      parent: _cgpaSummaryAnimationController,
      curve: Curves.easeInOut,
    );
    _percentageSummaryAnimation = CurvedAnimation(
      parent: _percentageSummaryAnimationController,
      curve: Curves.easeInOut,
    );

    _loadStudentProfile();
    if (widget.initialCgpa != null) {
      _cgpaController.text = widget.initialCgpa!.toStringAsFixed(2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _convertCgpaToPercentage();
      });
    } else {
      _loadSavedConversionData();
    }
  }

  @override
  void dispose() {
    _cgpaController.dispose();
    _percentageController.dispose();
    _cgpaResultAnimationController.dispose();
    _percentageResultAnimationController.dispose();
    _cgpaSummaryAnimationController.dispose();
    _percentageSummaryAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadSavedConversionData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(user.uid)
          .collection('converter_data')
          .doc('latest')
          .get();

      if (!doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc('pending_students')
            .collection('data')
            .doc(user.uid)
            .collection('converter_data')
            .doc('latest')
            .get();
      }

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          if (data['cgpa'] != null) {
            _cgpaController.text = data['cgpa'].toString();
            _lastSavedCgpa = data['cgpa'];
          }
          if (data['percentage'] != null) {
            _percentageController.text = data['percentage'].toString();
            _lastSavedPercentage = data['percentage'];
          }
          if (data['percentageResult'] != null) {
            _percentageResult = data['percentageResult'];
          }
          if (data['cgpaResult'] != null) {
            _cgpaResult = data['cgpaResult'];
          }
        });

        if (_percentageResult != null) {
          _cgpaResultAnimationController.forward();
          Future.delayed(const Duration(milliseconds: 500), () {
            _cgpaSummaryAnimationController.forward();
          });
        }
        if (_cgpaResult != null) {
          _percentageResultAnimationController.forward();
          Future.delayed(const Duration(milliseconds: 500), () {
            _percentageSummaryAnimationController.forward();
          });
        }
      }
    } catch (e) {
      print('Error loading saved conversion data: $e');
    }
  }

  Future<void> _saveConversionData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final conversionData = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (_cgpaController.text.trim().isNotEmpty) {
        conversionData['cgpa'] = double.parse(_cgpaController.text.trim());
      }
      if (_percentageController.text.trim().isNotEmpty) {
        conversionData['percentage'] =
            double.parse(_percentageController.text.trim());
      }
      if (_percentageResult != null) {
        conversionData['percentageResult'] = _percentageResult;
      }
      if (_cgpaResult != null) {
        conversionData['cgpaResult'] = _cgpaResult;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('data')
          .doc(user.uid)
          .get();

      final collection = userDoc.exists ? 'students' : 'pending_students';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(collection)
          .collection('data')
          .doc(user.uid)
          .collection('converter_data')
          .doc('latest')
          .set(conversionData, SetOptions(merge: true));

      setState(() {
        if (_cgpaController.text.trim().isNotEmpty) {
          _lastSavedCgpa = double.parse(_cgpaController.text.trim());
        }
        if (_percentageController.text.trim().isNotEmpty) {
          _lastSavedPercentage =
              double.parse(_percentageController.text.trim());
        }
      });
    } catch (e) {
      print('Error saving conversion data: $e');
    }
  }

  void _convertCgpaToPercentage() {
    final cgpaText = _cgpaController.text.trim();
    if (cgpaText.isEmpty) {
      _showErrorSnackBar("Please enter CGPA value");
      return;
    }

    final cgpa = double.tryParse(cgpaText);
    if (cgpa == null) {
      _showErrorSnackBar("Please enter a valid CGPA");
      return;
    }

    if (cgpa < 0 || cgpa > 10) {
      _showErrorSnackBar("CGPA should be between 0 and 10");
      return;
    }

    final percentage = cgpa * 10;
    setState(() {
      _percentageResult = percentage;
    });

    _cgpaResultAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _cgpaSummaryAnimationController.forward();
    });

    _saveConversionData();
  }

  void _convertPercentageToCgpa() {
    final percentageText = _percentageController.text.trim();
    if (percentageText.isEmpty) {
      _showErrorSnackBar("Please enter percentage value");
      return;
    }

    final percentage = double.tryParse(percentageText);
    if (percentage == null) {
      _showErrorSnackBar("Please enter a valid percentage");
      return;
    }

    if (percentage < 0 || percentage > 100) {
      _showErrorSnackBar("Percentage should be between 0 and 100");
      return;
    }

    final cgpa = percentage / 10;
    setState(() {
      _cgpaResult = cgpa;
    });

    _percentageResultAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _percentageSummaryAnimationController.forward();
    });

    _saveConversionData();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearAll() {
    _cgpaController.clear();
    _percentageController.clear();
    setState(() {
      _cgpaResult = null;
      _percentageResult = null;
    });
    _cgpaResultAnimationController.reset();
    _percentageResultAnimationController.reset();
    _cgpaSummaryAnimationController.reset();
    _percentageSummaryAnimationController.reset();
    _saveConversionData();
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Color color,
    required double width,
    required double? maxValue,
    required bool isCgpaField,
  }) {
    final isMobile = width < 600;

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
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCgpaField ? Icons.school_rounded : Icons.percent_rounded,
                    size: 16,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (value) {
              if (isCgpaField && _percentageResult != null) {
                setState(() {
                  _percentageResult = null;
                });
                _cgpaResultAnimationController.reset();
                _cgpaSummaryAnimationController.reset();
              } else if (!isCgpaField && _cgpaResult != null) {
                setState(() {
                  _cgpaResult = null;
                });
                _percentageResultAnimationController.reset();
                _percentageSummaryAnimationController.reset();
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: isMobile ? 14 : 16,
              ),
              filled: true,
              fillColor: color.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: color.withOpacity(0.3), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: color.withOpacity(0.3), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: color, width: 2.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
                vertical: isMobile ? 16 : 18,
              ),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: color.withOpacity(0.6), size: 20),
                      onPressed: () {
                        setState(() {
                          controller.clear();
                        });
                      },
                    )
                  : null,
            ),
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required double result,
    required String label,
    required String unit,
    required Color color,
    required Animation<double> animation,
    required double width,
  }) {
    final isMobile = width < 600;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : width * 0.05,
              vertical: 12,
            ),
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, _getDarkerShade(color)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(_borderRadius),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
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
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 18 : 22,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.toStringAsFixed(2),
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
                    if (unit.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          unit,
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 32 : 40,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String inputLabel,
    required String inputValue,
    required String outputLabel,
    required String outputValue,
    required Color color,
    required Animation<double> animation,
    required double width,
  }) {
    final isMobile = width < 600;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - animation.value) * 50),
          child: Opacity(
            opacity: animation.value,
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : width * 0.05,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, color.withOpacity(0.1)],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 20 : 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, _getDarkerShade(color)],
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
                            color: color,
                            size: isMobile ? 24 : 28,
                          ),
                        ),
                        SizedBox(width: isMobile ? 16 : 20),
                        Expanded(
                          child: Text(
                            "Conversion Summary",
                            style: GoogleFonts.poppins(
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 20 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Conversion Details:",
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "$inputLabel:",
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
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
                                      color.withOpacity(0.2),
                                      color.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: color.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  inputValue,
                                  style: GoogleFonts.poppins(
                                    fontSize: isMobile ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getDarkerShade(color),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 20),
                        Container(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.15),
                                color.withOpacity(0.05),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: color.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "$outputLabel:",
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  outputValue,
                                  style: GoogleFonts.poppins(
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
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

  Color _getDarkerShade(Color color) {
    return Color.fromARGB(
      color.alpha,
      (color.red * 0.7).round(),
      (color.green * 0.7).round(),
      (color.blue * 0.7).round(),
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
              colors: [Colors.orange.shade600, Colors.deepOrange.shade600],
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
          "CGPA ⇄ Percentage",
          style: GoogleFonts.poppins(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_cgpaResult != null || _percentageResult != null)
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
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 20,
                      vertical: isMobile ? 12 : 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.orange.shade50],
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
                              Colors.orange,
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
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.orange.shade50,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.2),
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
                                      Colors.orange.shade400,
                                      Colors.deepOrange.shade500,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.3),
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
                        if (_lastSavedCgpa != null || _lastSavedPercentage != null)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : 20,
                              vertical: isMobile ? 12 : 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade50,
                                  Colors.deepOrange.shade50,
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.orange.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  size: isMobile ? 18 : 20,
                                  color: Colors.orange[700],
                                ),
                                SizedBox(width: 8),
                                if (_lastSavedCgpa != null) ...[
                                  Text(
                                    "CGPA: ",
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 13 : 15,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
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
                                    child: Text(
                                      _lastSavedCgpa!.toStringAsFixed(2),
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 14 : 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                if (_lastSavedCgpa != null &&
                                    _lastSavedPercentage != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: Text(
                                      "•",
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 12 : 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (_lastSavedPercentage != null) ...[
                                  Text(
                                    "%: ",
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 13 : 15,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.purple.shade600,
                                          Colors.deepPurple.shade600,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.purple.withOpacity(0.3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _lastSavedPercentage!.toStringAsFixed(2),
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 14 : 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
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
                          horizontal: isMobile ? 20 : width * 0.04,
                        ),
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade50,
                              Colors.deepOrange.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.orange[600],
                              size: isMobile ? 24 : 28,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Choose your conversion type",
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 15 : 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: const Duration(milliseconds: 500))
                          .slideY(begin: 0.2),
                      SizedBox(height: isMobile ? 24 : 32),
                      _buildInputField(
                        label: "CGPA to Percentage",
                        hint: "Enter CGPA (0.0 - 10.0)",
                        controller: _cgpaController,
                        color: Colors.orange,
                        width: width,
                        maxValue: 10.0,
                        isCgpaField: true,
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 700))
                          .slideX(begin: 0.2, end: 0),
                      SizedBox(height: isMobile ? 16 : 20),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : width * 0.05,
                        ),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade600,
                              Colors.deepOrange.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _convertCgpaToPercentage,
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
                                size: isMobile ? 26 : 30,
                              ),
                              SizedBox(width: isMobile ? 12 : 16),
                              Text(
                                "Convert to %",
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 800))
                          .slideY(begin: 0.3),
                      if (_percentageResult != null) ...[
                        SizedBox(height: isMobile ? 24 : 32),
                        _buildResultCard(
                          result: _percentageResult!,
                          label: "Your Percentage",
                          unit: "%",
                          color: Colors.orange,
                          animation: _cgpaResultAnimation,
                          width: width,
                        ),
                        _buildSummaryCard(
                          inputLabel: "Input CGPA",
                          inputValue: _cgpaController.text.trim(),
                          outputLabel: "Percentage",
                          outputValue: "${_percentageResult!.toStringAsFixed(2)}%",
                          color: Colors.orange,
                          animation: _cgpaSummaryAnimation,
                          width: width,
                        ),
                      ],
                      SizedBox(height: isMobile ? 32 : 40),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : width * 0.04,
                        ),
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.grey.shade300,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 32 : 40),
                      _buildInputField(
                        label: "Percentage to CGPA",
                        hint: "Enter Percentage (0.0 - 100.0)",
                        controller: _percentageController,
                        color: Colors.purple,
                        width: width,
                        maxValue: 100.0,
                        isCgpaField: false,
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 900))
                          .slideX(begin: 0.2, end: 0),
                      SizedBox(height: isMobile ? 16 : 20),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : width * 0.05,
                        ),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade600,
                              Colors.deepPurple.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _convertPercentageToCgpa,
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
                                size: isMobile ? 26 : 30,
                              ),
                              SizedBox(width: isMobile ? 12 : 16),
                              Text(
                                "Convert to CGPA",
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 1000))
                          .slideY(begin: 0.3),
                      if (_cgpaResult != null) ...[
                        SizedBox(height: isMobile ? 24 : 32),
                        _buildResultCard(
                          result: _cgpaResult!,
                          label: "Your CGPA",
                          unit: "",
                          color: Colors.purple,
                          animation: _percentageResultAnimation,
                          width: width,
                        ),
                        _buildSummaryCard(
                          inputLabel: "Input Percentage",
                          inputValue: "${_percentageController.text.trim()}%",
                          outputLabel: "CGPA",
                          outputValue: _cgpaResult!.toStringAsFixed(2),
                          color: Colors.purple,
                          animation: _percentageSummaryAnimation,
                          width: width,
                        ),
                      ],
                      SizedBox(height: isMobile ? 24 : 32),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : width * 0.05,
                        ),
                        padding: EdgeInsets.all(isMobile ? 20 : 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade50,
                              Colors.cyan.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
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
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade400,
                                        Colors.cyan.shade500,
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
                                    "Conversion Formulas",
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 15 : 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isMobile ? 12 : 14),
                            Text(
                              "Percentage = CGPA × 10\n\nCGPA = Percentage ÷ 10\n\nNote: This is a standard conversion formula used by most institutions.",
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