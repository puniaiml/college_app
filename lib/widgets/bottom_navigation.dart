// import 'package:college_app/chatBot/chat_bot_ai.dart';
// import 'package:college_app/login.dart';
// import 'package:college_app/user/user_home.dart';
// import 'package:college_app/user/voice.dart';
// import 'package:college_app/widgets/drawer_user.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// class BottomNavigationPage extends StatefulWidget {
//   const BottomNavigationPage({super.key});

//   @override
//   State<BottomNavigationPage> createState() => _BottomNavigationPageState();
// }

// class _BottomNavigationPageState extends State<BottomNavigationPage> {
//   final user = FirebaseAuth.instance.currentUser;
//   int _currentIndex = 0;

//   final List<Widget> pages = const [
//     HomePage(),
//     VoicePage(),
//     ChatBot(),
//     // Removed LoginPage here as it's handled in the logout confirmation
//   ];

//   void _confirmLogout() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text("Confirm Logout"),
//           content: const Text("Are you sure you want to logout?"),
//           actions: <Widget>[
//             TextButton(
//               child: const Text("Cancel"),
//               onPressed: () {
//                 Navigator.of(context).pop(); // Close the dialog
//               },
//             ),
//             TextButton(
//               child: const Text("Logout"),
//               onPressed: () {
//                 FirebaseAuth.instance.signOut().then((_) {
//                   Navigator.pushReplacement(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const LoginPage(),
//                     ),
//                   );
//                 });
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       resizeToAvoidBottomInset: true,
//       drawer: const UserDrawer(),
//       appBar: PreferredSize(
//         preferredSize: const Size.fromHeight(80.0),
//         child: AppBar(
//           backgroundColor: Colors.indigo,
//           leading: Padding(
//             padding: const EdgeInsets.only(left: 20.0, top: 5),
//             child: Builder(
//               builder: (context) {
//                 return IconButton(
//                   icon: const Icon(Icons.sort, color: Colors.white, size: 50),
//                   onPressed: () {
//                     Scaffold.of(context).openDrawer();
//                   },
//                 );
//               },
//             ),
//           ),
//           actions: [
//             Padding(
//               padding: const EdgeInsets.only(right: 20.0),
//               child: Container(
//                 height: 50,
//                 width: 50,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(10),
//                   color: Colors.white,
//                   image: const DecorationImage(
//                     image: AssetImage("assets/images/user2.png"),
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//       body: IndexedStack(
//         index: _currentIndex,
//         children: pages,
//       ),
//       bottomNavigationBar: SafeArea(
//         child: Container(
//           margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
//           decoration: BoxDecoration(
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 blurRadius: 30,
//                 offset: const Offset(0, 20),
//               ),
//             ],
//             borderRadius: BorderRadius.circular(30),
//           ),
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(30),
//             child: BottomNavigationBar(
//               currentIndex: _currentIndex,
//               backgroundColor: Colors.blue,
//               selectedItemColor: const Color.fromARGB(255, 21, 51, 201),
//               unselectedItemColor: Colors.black,
//               selectedFontSize: 12,
//               showSelectedLabels: true,
//               showUnselectedLabels: false,
//               onTap: (index) {
//                 if (index == 3) {
//                   _confirmLogout(); // Call the logout confirmation function
//                 } else {
//                   setState(() {
//                     _currentIndex = index;
//                   });
//                 }
//               },
//               items: const [
//                 BottomNavigationBarItem(
//                   icon: Icon(Icons.home_outlined),
//                   label: 'Home',
//                 ),
//                 BottomNavigationBarItem(
//                   icon: Icon(Icons.mic_none),
//                   label: 'VoiceBot',
//                 ),
//                 BottomNavigationBarItem(
//                   icon: Icon(Icons.chat_bubble_outline),
//                   label: 'ChatBot',
//                 ),
//                 BottomNavigationBarItem(
//                   icon: Icon(Icons.logout),
//                   label: 'Logout',
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
