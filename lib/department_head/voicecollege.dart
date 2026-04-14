// ignore_for_file: avoid_print

import 'package:shiksha_hub/department_head/d_notes/ad_branch.dart';
import 'package:shiksha_hub/department_head/d_time_table/branch.dart';
import 'package:shiksha_hub/user/home_cgpa.dart';
import 'package:shiksha_hub/user/result.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shiksha_hub/auth/login.dart';


class VoicePage extends StatelessWidget {
  const VoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var textSpeech = "CLICK ON MIC TO RECORD";
  SpeechToText speechToText = SpeechToText();
  var isListening = false;
  var micAvailable = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    checkMic();
  }

  void checkMic() async {
    micAvailable = await speechToText.initialize(
      onError: (error) => setState(() {
        errorMessage = 'Failed to initialize: $error';
        print(errorMessage);
      }),
      onStatus: (status) => print('Speech recognition status: $status'),
    );

    setState(() {
      if (micAvailable) {
        print("Microphone Available");
        errorMessage = '';
      } else {
        print("User Denied the use of speech microphone");
        errorMessage = 'Microphone access denied. Please enable it in settings.';
      }
    });
  }

  void navigateToPage(String textSpeech) {
    textSpeech = textSpeech.toLowerCase();
    print("Recognized text: $textSpeech");

    if (textSpeech.contains('notes')) {
      print("Navigating to NotesPage");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SelectBranchAdmin(selectedCollege: '',)),
      );
    } else if (textSpeech.contains('timetable') ||
        textSpeech.contains('time table')) {
      print("Navigating to TimeTablePage");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BranchAdmin(selectedCollege: '',)),
      );
    } else if (textSpeech.contains('results') ||
        textSpeech.contains('resultpage') ||
        textSpeech.contains('result')) {
      print("Navigating to ResultPage");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ResultPage()),
      );
    } else if (textSpeech.contains('cgpa calculator') ||
        textSpeech.contains('cgpa') ||
        textSpeech.contains('sgpa') ||
        textSpeech.contains('sgpa calculator') ||
        textSpeech.contains('cgpa sgpa') ||
        textSpeech.contains('sgpa cgpa')) {
      print("Navigating to CgpaSgpaPage");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CgpaSgpaPage()),
      );
    } else if (textSpeech.contains('log out') ||
        textSpeech.contains('logout')) {
      print("Navigating to LoginPage");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } else {
      print('No matching page for the keyword: $textSpeech');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No matching page for: "$textSpeech"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Voice Page'),
      // ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                textSpeech,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  if (!isListening && micAvailable) {
                    setState(() {
                      isListening = true;
                      errorMessage = '';
                    });

                    speechToText.listen(
                      listenFor: const Duration(seconds: 20),
                      onResult: (result) {
                        setState(() {
                          textSpeech = result.recognizedWords;
                          isListening = false;
                        });

                        print("Detected words: ${result.recognizedWords}");
                        navigateToPage(textSpeech);
                      },
                    );
                  } else if (!micAvailable) {
                    setState(() {
                      errorMessage = 'Microphone not available. Please check settings.';
                    });
                  } else {
                    setState(() {
                      isListening = false;
                      speechToText.stop();
                    });
                  }
                },
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: isListening ? Colors.red : Colors.blue,
                  child: Icon(
                    isListening ? Icons.mic_off : Icons.mic,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
