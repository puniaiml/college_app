import 'dart:async';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:shiksha_hub/auth/reset_password_page.dart';
import 'package:shiksha_hub/chatBot/consts.dart';
import 'package:shiksha_hub/splash/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_notification_channel/flutter_notification_channel.dart';
import 'package:flutter_notification_channel/notification_importance.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:lottie/lottie.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterNativeSplash.preserve(
      widgetsBinding: WidgetsBinding.instance,
    );

    // Remove splash immediately — don't block on heavy services
    FlutterNativeSplash.remove();

    try {
      await _initCriticalServices();
    } catch (e, s) {
      debugPrint("Startup error: $e");
      debugPrintStack(stackTrace: s);
    }

    Get.put(ThemeController(), permanent: true);

    runApp(const College());
  }, (error, stack) {
    debugPrint("Uncaught error: $error");
    debugPrintStack(stackTrace: stack);
  });
}

Future<void> _initCriticalServices() async {
  try {
    await Firebase.initializeApp();
    await GetStorage.init();

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  } catch (e) {
    debugPrint("Critical initialization error: $e");
    log("Critical initialization error: $e");
  }
}

Future<void> _initDeferredServices() async {
  try {
    await FlutterNotificationChannel().registerNotificationChannel(
      description: 'For Showing Message Notification',
      id: 'chats',
      importance: NotificationImportance.IMPORTANCE_HIGH,
      name: 'Chats',
    );

    await FlutterNotificationChannel().registerNotificationChannel(
      description: 'For Showing Notes Upload Notifications',
      id: 'notes',
      importance: NotificationImportance.IMPORTANCE_HIGH,
      name: 'Notes',
    );

    await FlutterNotificationChannel().registerNotificationChannel(
      description: 'For Showing Timetable Update Notifications',
      id: 'timetable',
      importance: NotificationImportance.IMPORTANCE_HIGH,
      name: 'Timetable',
    );

    await FlutterNotificationChannel().registerNotificationChannel(
      description: 'For Exam Schedules and Updates',
      id: 'exams',
      importance: NotificationImportance.IMPORTANCE_HIGH,
      name: 'Exams',
    );

    await FlutterNotificationChannel().registerNotificationChannel(
      description: 'For ChatMate Messages and Academic Notifications',
      id: 'chatmate',
      importance: NotificationImportance.IMPORTANCE_HIGH,
      name: 'ChatMate',
    );

    Gemini.init(apiKey: GEMIINI_API_KEY);
  } catch (e, s) {
    debugPrint("Deferred initialization error: $e");
    debugPrintStack(stackTrace: s);
  }
}

Future<void> precacheLottie(String asset) async {
  try {
    final data = await rootBundle.load(asset);
    await LottieComposition.fromBytes(data.buffer.asUint8List());
  } catch (e) {
    debugPrint("Lottie precache error: $e");
  }
}

class College extends StatefulWidget {
  const College({super.key});

  @override
  State<College> createState() => _CollegeState();
}

class _CollegeState extends State<College> {
  late final AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  static final ThemeData _lightTheme = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6750A4),
      secondary: Color(0xFF625B71),
      surface: Colors.white,
      background: Color(0xFFFFFBFE),
    ),
    useMaterial3: true,
    textTheme: ThemeData.light(useMaterial3: true)
        .textTheme
        .apply(fontFamily: 'Poppins'),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 1,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        fontFamily: 'Poppins',
      ),
      backgroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    ),
  );

  static final ThemeData _darkTheme =
      ThemeData.dark(useMaterial3: true).copyWith(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFBB86FC),
      secondary: Color(0xFF03DAC6),
      surface: Color(0xFF1E1E1E),
      background: Color(0xFF121212),
    ),
    textTheme: ThemeData.dark(useMaterial3: true)
        .textTheme
        .apply(fontFamily: 'Poppins'),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 1,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        fontFamily: 'Poppins',
      ),
      backgroundColor: Color(0xFF1E1E1E),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
  );

  @override
  void initState() {
    super.initState();

    _initDeepLinks();

    // Both deferred — run after first frame, non-blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeferredServices();
      precacheLottie('assets/lottie/splash.json');
    });
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        final mode = uri.queryParameters['mode'];
        final oobCode = uri.queryParameters['oobCode'];

        if (mode == 'resetPassword' && oobCode != null) {
          Get.to(() => ResetPasswordPage(oobCode: oobCode));
        }
      },
      onError: (err) {
        debugPrint("Deep link error: $err");
      },
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Skisha Hub',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: Get.find<ThemeController>().themeMode,
      home: const SplashScreen(),
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

class ThemeController extends GetxController {
  final RxBool isDarkTheme = false.obs;
  final GetStorage _storage = GetStorage();

  ThemeMode get themeMode =>
      isDarkTheme.value ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();

    isDarkTheme.value = _storage.read('isDarkTheme') ?? false;

    ever(isDarkTheme, (value) {
      _storage.write('isDarkTheme', value);
      Get.changeThemeMode(themeMode);
      _updateSystemUI();
    });
  }

  void toggleTheme() {
    isDarkTheme.value = !isDarkTheme.value;
  }

  void _updateSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkTheme.value ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            isDarkTheme.value ? const Color(0xFF121212) : Colors.white,
        systemNavigationBarIconBrightness:
            isDarkTheme.value ? Brightness.light : Brightness.dark,
      ),
    );
  }
}