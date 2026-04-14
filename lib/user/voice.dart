// ignore_for_file: avoid_print

import 'package:shiksha_hub/user/home_cgpa.dart';
import 'package:shiksha_hub/user/result.dart';
import 'package:shiksha_hub/user/u_time_table/branch.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shiksha_hub/auth/login.dart';
import 'package:lottie/lottie.dart';

class VoicePage extends StatelessWidget {
  const VoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyHomePage();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  var textSpeech = "How can I help you today?";
  var aiResponse = "I'm listening...";
  stt.SpeechToText speechToText = stt.SpeechToText();
  var isListening = false;
  var micAvailable = false;
  String errorMessage = '';
  bool isInitializing = true;
  
  late AnimationController _animationController;
  String _currentAnimation = 'neutral';
  
  // Animation states for AI avatar
  final Map<String, String> _animations = {
    'neutral': 'assets/lottie/ai_neutral.json',
    'listening': 'assets/lottie/ai_listening.json',
    'happy': 'assets/lottie/1.json',
    'thinking': 'assets/lottie/2.json',
    'error': 'assets/lottie/3.json',
  };

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // Start with neutral animation
    _setAnimation('thinking');
    
    // Initialize microphone with delay to ensure widget is fully mounted
    Future.delayed(const Duration(milliseconds: 500), () {
      requestMicrophonePermission();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _setAnimation(String animationType) {
    setState(() {
      _currentAnimation = animationType;
      _animationController.reset();
      _animationController.forward();
    });
  }

  // Request microphone permission explicitly
  Future<void> requestMicrophonePermission() async {
    setState(() {
      isInitializing = true;
      aiResponse = "Checking microphone access...";
      _setAnimation('thinking');
    });

    try {
      // First check and request permission using permission_handler
      PermissionStatus micPermission = await Permission.microphone.status;
      
      if (micPermission != PermissionStatus.granted) {
        micPermission = await Permission.microphone.request();
      }
      
      if (micPermission == PermissionStatus.granted) {
        // Now initialize speech recognition
        await initializeSpeechRecognition();
      } else {
        setState(() {
          isInitializing = false;
          micAvailable = false;
          errorMessage = 'Microphone permission denied. Please enable it in your device settings.';
          _setAnimation('error');
          aiResponse = "I need microphone permission to work properly.";
          print("Microphone permission denied: $micPermission");
        });
        
        // Show dialog guiding user to settings
        _showPermissionDialog();
      }
    } catch (e) {
      setState(() {
        isInitializing = false;
        micAvailable = false;
        errorMessage = 'Error accessing microphone: $e';
        _setAnimation('error');
        aiResponse = "Something went wrong while accessing the microphone.";
        print("Error requesting permission: $e");
      });
    }
  }

  // Initialize speech recognition separately
  Future<void> initializeSpeechRecognition() async {
    try {
      bool available = await speechToText.initialize(
        onError: (error) => setState(() {
          isInitializing = false;
          errorMessage = 'Speech recognition error: ${error.errorMsg}';
          _setAnimation('error');
          aiResponse = "I'm having trouble with speech recognition.";
          print("Speech recognition error: ${error.errorMsg}");
        }),
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'listening') {
            _setAnimation('listening');
          } else if (status == 'notListening') {
            _setAnimation('neutral');
          }
        },
        debugLogging: true,
      );

      setState(() {
        isInitializing = false;
        micAvailable = available;
        
        if (available) {
          print("Speech recognition initialized successfully");
          errorMessage = '';
          _setAnimation('neutral');
          aiResponse = "I'm ready to help! Tap the mic button and speak.";
        } else {
          print("Speech recognition failed to initialize");
          errorMessage = 'Speech recognition not available on this device.';
          _setAnimation('error');
          aiResponse = "I couldn't access speech recognition on your device.";
        }
      });
    } catch (e) {
      setState(() {
        isInitializing = false;
        micAvailable = false;
        errorMessage = 'Failed to initialize speech recognition: $e';
        _setAnimation('error');
        aiResponse = "I encountered a problem with speech recognition.";
        print("Speech recognition initialization error: $e");
      });
    }
  }

  // Show dialog to guide user to settings
  void _showPermissionDialog() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Microphone Access Required"),
              content: const Text(
                "This app needs microphone access to function properly. "
                "Please enable microphone permission in your device settings."
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text("Open Settings"),
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                ),
                TextButton(
                  child: const Text("Try Again"),
                  onPressed: () {
                    Navigator.of(context).pop();
                    requestMicrophonePermission();
                  },
                ),
              ],
            );
          },
        );
      }
    });
  }

  void navigateToPage(String textSpeech) {
    textSpeech = textSpeech.toLowerCase();
    print("Recognized text: $textSpeech");
    
    setState(() {
      _setAnimation('thinking');
      aiResponse = "Processing your request...";
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (textSpeech.contains('notes')) {
        setState(() {
          _setAnimation('happy');
          aiResponse = "Opening notes page for you!";
        });
        print("Navigating to NotesPage");
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StudentBranchAdmin(selectedCollege: '',)),
          );
        });
      } else if (textSpeech.contains('timetable') ||
          textSpeech.contains('time table')) {
        setState(() {
          _setAnimation('happy');
          aiResponse = "Here's your timetable!";
        });
        print("Navigating to TimeTablePage");
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StudentBranchAdmin(selectedCollege: '',)),
          );
        });
      } else if (textSpeech.contains('results') ||
          textSpeech.contains('resultpage') ||
          textSpeech.contains('result')) {
        setState(() {
          _setAnimation('happy');
          aiResponse = "Getting your results ready!";
        });
        print("Navigating to ResultPage");
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ResultPage()),
          );
        });
      } else if (textSpeech.contains('cgpa calculator') ||
          textSpeech.contains('cgpa') ||
          textSpeech.contains('sgpa') ||
          textSpeech.contains('sgpa calculator') ||
          textSpeech.contains('cgpa sgpa') ||
          textSpeech.contains('sgpa cgpa')) {
        setState(() {
          _setAnimation('happy');
          aiResponse = "Opening CGPA calculator!";
        });
        print("Navigating to CgpaSgpaPage");
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CgpaSgpaPage()),
          );
        });
      } else if (textSpeech.contains('log out') ||
          textSpeech.contains('logout')) {
        setState(() {
          _setAnimation('neutral');
          aiResponse = "Logging you out now...";
        });
        print("Navigating to LoginPage");
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        });
      } else {
        setState(() {
          _setAnimation('error');
          aiResponse = "I didn't understand that. Can you try again?";
        });
        print('No matching page for the keyword: $textSpeech');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No matching page for: "$textSpeech"')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to make UI responsive
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenHeight < 600;
    
    // Calculate appropriate sizes based on screen dimensions
    final avatarSize = screenWidth * 0.4 > 200 ? 200.0 : screenWidth * 0.4;
    final fontSize = isSmallScreen ? 16.0 : 18.0;
    final spacing = isSmallScreen ? 12.0 : 20.0;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB), // Light blueish-gray background
      appBar: AppBar(
        backgroundColor: const Color(0xFF6200EE), // Purple primary color
        title: const Text(
          'Voice Assistant',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0, // No shadow for modern look
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 600,
                minHeight: screenHeight - mediaQuery.padding.top - kToolbarHeight,
              ),
              padding: EdgeInsets.symmetric(
                vertical: spacing,
                horizontal: screenWidth * 0.05,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: spacing),
                  // AI Avatar section with improved design
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6200EE).withOpacity(0.05),
                          const Color(0xFF6200EE).withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipOval(
                          child: _animations.containsKey(_currentAnimation)
                              ? Lottie.asset(
                                  _animations[_currentAnimation]!,
                                  controller: _animationController,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print("Lottie error: $error");
                                    // Always show ai_neutral.json even on error
                                    return Lottie.asset(
                                      'assets/lottie/ai_neutral.json',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, e, stackTrace) {
                                        // Very fallback option if ai_neutral.json also fails
                                        return Container(
                                          width: avatarSize,
                                          height: avatarSize,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6200EE).withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.face,
                                            size: 80,
                                            color: Color(0xFF6200EE),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                )
                              : Lottie.asset(
                                  'assets/lottie/ai_neutral.json',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, e, stackTrace) {
                                    return Container(
                                      width: avatarSize,
                                      height: avatarSize,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6200EE).withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.face,
                                        size: 80,
                                        color: Color(0xFF6200EE),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (isInitializing)
                          CircularProgressIndicator(
                            color: const Color(0xFF6200EE),
                            strokeWidth: 3,
                            backgroundColor: Colors.white.withOpacity(0.5),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing * 1.5),
                  
                  // AI Response bubble with enhanced design
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing * 1.2,
                      vertical: spacing * 0.9,
                    ),
                    margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF6200EE).withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      aiResponse,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF424242),
                        height: 1.3,
                      ),
                    ),
                  ),
                  SizedBox(height: spacing * 1.5),
                  
                  // User speech text with improved design
                  Container(
                    padding: EdgeInsets.all(spacing),
                    margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6200EE).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6200EE).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "You said:",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6200EE),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: spacing * 0.5),
                        Text(
                          isListening ? "Listening..." : textSpeech,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: fontSize + 2,
                            fontWeight: FontWeight.bold,
                            color: isListening ? Colors.grey : Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.all(spacing * 0.8),
                      child: Container(
                        padding: EdgeInsets.all(spacing * 0.8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    errorMessage,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: spacing * 0.8),
                            ElevatedButton(
                              onPressed: () {
                                requestMicrophonePermission();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                foregroundColor: Colors.red,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              child: const Text(
                                "Try Again",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: spacing * 2),
                  
                  // Mic button with enhanced design
                  GestureDetector(
                    onTap: () async {
                      if (isInitializing) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Still initializing microphone. Please wait...'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                          ),
                        );
                        return;
                      }
                      
                      if (!micAvailable) {
                        requestMicrophonePermission();
                        return;
                      }
                      
                      if (!isListening) {
                        setState(() {
                          isListening = true;
                          errorMessage = '';
                          _setAnimation('listening');
                          aiResponse = "I'm listening to you...";
                        });

                        try {
                          await speechToText.listen(
                            listenFor: const Duration(seconds: 10),
                            pauseFor: const Duration(seconds: 3),
                            // ignore: deprecated_member_use
                            partialResults: true,
                            onResult: (result) {
                              setState(() {
                                textSpeech = result.recognizedWords;
                                isListening = false;
                              });

                              print("Detected words: ${result.recognizedWords}");
                              if (result.recognizedWords.isNotEmpty) {
                                navigateToPage(textSpeech);
                              } else {
                                setState(() {
                                  _setAnimation('error');
                                  aiResponse = "I didn't hear anything. Please try again.";
                                });
                              }
                            },
                          );
                        } catch (e) {
                          setState(() {
                            isListening = false;
                            errorMessage = 'Error listening: $e';
                            _setAnimation('error');
                            aiResponse = "I encountered a problem while listening.";
                            print("Speech listening error: $e");
                          });
                        }
                      } else {
                        setState(() {
                          isListening = false;
                          speechToText.stop();
                          _setAnimation('neutral');
                          aiResponse = "I stopped listening.";
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.all(isSmallScreen ? 15 : 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isInitializing
                              ? [Colors.grey, Colors.grey.shade600]
                              : isListening
                                ? [Colors.red.shade400, Colors.red.shade700]
                                : [const Color(0xFF6200EE), const Color(0xFF3700B3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: (isInitializing 
                              ? Colors.grey 
                              : isListening ? Colors.red : const Color(0xFF6200EE)).withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        isInitializing ? Icons.hourglass_top :
                        isListening ? Icons.mic_off : Icons.mic,
                        size: isSmallScreen ? 28 : 34,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: spacing),
                  
                  // Help text with animated pulse effect
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: isListening ? 0.7 : 1.0,
                    child: Text(
                      isInitializing ? "Initializing..." :
                      isListening ? "Tap to stop" : "Tap to speak",
                      style: TextStyle(
                        fontSize: 14,
                        color: isListening 
                          ? Colors.red.shade700 
                          : isInitializing 
                            ? Colors.grey.shade600 
                            : const Color(0xFF6200EE),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: spacing * 2),
                  
                  // Available commands section with enhanced design
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                    padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing * 1.2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF6200EE).withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tips_and_updates_outlined, 
                              size: 18, 
                              color: const Color(0xFF6200EE),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Try saying:",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6200EE),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        SizedBox(height: spacing * 0.3),
                        _buildCommandChip("Notes", Icons.note_alt_outlined),
                        _buildCommandChip("Time Table", Icons.calendar_today_outlined),
                        _buildCommandChip("Results", Icons.assessment_outlined),
                        _buildCommandChip("CGPA Calculator", Icons.calculate_outlined),
                        _buildCommandChip("Log Out", Icons.logout_outlined),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing * 1.5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCommandChip(String command, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF6200EE).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon, 
              size: 18, 
              color: const Color(0xFF6200EE),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            command,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF424242),
            ),
          ),
        ],
      ),
    );
  }
}