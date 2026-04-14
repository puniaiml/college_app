import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shiksha_hub/auth/email_verification_page.dart';
import 'package:shiksha_hub/college_head/college_home.dart';
import 'package:shiksha_hub/department_head/hod_home.dart';
import 'package:shiksha_hub/faculty/faculty_home.dart';
import 'package:shiksha_hub/auth/login.dart';
import 'package:shiksha_hub/owner/owner_home.dart';
import 'package:shiksha_hub/user/user_home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shiksha_hub/services/notification_service.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.email == "admin@gmail.com") {
          return const OwnerDashboard();
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginPage();
        }

        final User user = snapshot.data!;
        
        if (user.email == "admin@gmail.com") {
          return const OwnerDashboard();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('user_metadata')
              .doc(user.uid)
              .snapshots(),
          builder: (context, metadataSnapshot) {
            if (metadataSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!metadataSnapshot.hasData || !metadataSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }

            final metadataData = metadataSnapshot.data!.data() as Map<String, dynamic>;
            final String userType = metadataData['userType'] ?? '';
            final String accountStatus = metadataData['accountStatus'] ?? '';

            return _handleUserStatus(user, userType, accountStatus);
          },
        );
      },
    );
  }

  Widget _handleUserStatus(User user, String userType, String accountStatus) {
    switch (accountStatus) {
      case 'pending_verification':
        return _handlePendingVerification(user, userType);
      
      case 'pending_approval':
        return _buildPendingApprovalScreen();
      
      case 'blocked':
        return _handleBlockedUser(user, userType);
      
      case 'inactive':
        return _buildInactiveAccountScreen();
      
      case 'active':
        return _handleActiveUser(user, userType);
      
      default:
        FirebaseAuth.instance.signOut();
        return const LoginPage();
    }
  }

  Widget _handlePendingVerification(User user, String userType) {
    return OtpVerificationPage(
      userId: user.uid,
      email: user.email ?? '', 
      userType: userType,
    );
  }

  Widget _handleBlockedUser(User user, String userType) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc('blocked_students')
          .collection('data')
          .doc(user.uid)
          .snapshots(),
      builder: (context, blockedSnapshot) {
        if (blockedSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (blockedSnapshot.hasData && blockedSnapshot.data!.exists) {
          final blockedData = blockedSnapshot.data!.data() as Map<String, dynamic>;
          return _buildBlockedAccountScreen(
            user: user,
            blockedData: blockedData,
            rejectionReason: blockedData['rejectionReason'],
            rejectedBy: blockedData['rejectedByName'],
            rejectedAt: blockedData['rejectedAt'],
            wasApproved: blockedData['wasApproved'] == true,
            userType: userType,
            userEmail: user.email ?? '',
          );
        }

        FirebaseAuth.instance.signOut();
        return const LoginPage();
      },
    );
  }

  Widget _handleActiveUser(User user, String userType) {
  String collectionPath = _getCollectionPath(userType);
  Widget homePage = _getHomePage(userType);

  if (collectionPath.isEmpty) {
    FirebaseAuth.instance.signOut();
    return const LoginPage();
  }

  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(collectionPath)
        .collection('data')
        .doc(user.uid)
        .snapshots(),
    builder: (context, userSnapshot) {
      if (userSnapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (userSnapshot.hasData && userSnapshot.data!.exists) {
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final accountStatus = userData['accountStatus'] ?? '';
        final isEmailVerified = userData['isEmailVerified'] ?? false;
        // REMOVED: final isActive = userData['isActive'] ?? true;
        
        // For HOD, check email verification status
        if (userType == 'department_head') {
          if (accountStatus == 'pending_verification') {
            return OtpVerificationPage(
              userId: user.uid,
              email: userData['email'] ?? user.email ?? '',
              userType: 'department_head',
            );
          }
          if (accountStatus == 'active' && !isEmailVerified) {
            return OtpVerificationPage(
              userId: user.uid,
              email: userData['email'] ?? user.email ?? '',
              userType: 'department_head',
            );
          }
        }

        // MODIFIED: Only check accountStatus, ignore isActive field
        if (accountStatus == 'active') {
          if (userType == 'department_head' && !isEmailVerified) {
            return OtpVerificationPage(
              userId: user.uid,
              email: userData['email'] ?? user.email ?? '',
              userType: 'department_head',
            );
          }
          return homePage;
        }
      }

      FirebaseAuth.instance.signOut();
      return const LoginPage();
    },
  );
}

  String _getCollectionPath(String userType) {
    switch (userType) {
      case 'student': return 'students';
      case 'college_staff': return 'college_staff';
      case 'faculty': return 'faculty';
      case 'department_head': return 'department_head';
      case 'admin': return 'admin';
      default: return '';
    }
  }

  Widget _getHomePage(String userType) {
    switch (userType) {
      case 'student': return const HomePage();
      case 'college_staff': return const CollegeStaffDashboard();
      case 'faculty': return const FacultyHomePage();
      case 'department_head': return const HodHome();
      case 'admin': return const OwnerDashboard();
      default: return const LoginPage();
    }
  }

  Widget _buildPendingApprovalScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF9800).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  size: 64,
                  color: Color(0xFFFF9800),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Approval Pending',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your email verification is complete',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Your account is currently under review by the college administration. You will receive access once your registration has been approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF424242),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2196F3).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      color: const Color(0xFF2196F3),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Approval typically takes 1-2 business days. You will be notified via email once approved.',
                        style: TextStyle(
                          color: const Color(0xFF2196F3),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF757575),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.forceAppUpdate();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedAccountScreen({
    required User user,
    required Map<String, dynamic> blockedData,
    String? rejectionReason,
    String? rejectedBy,
    Timestamp? rejectedAt,
    bool wasApproved = false,
    String userType = 'student',
    String userEmail = '',
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE53935).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    size: 64,
                    color: Color(0xFFE53935),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  wasApproved ? 'Account Suspended' : 'Application Rejected',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE53935),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    wasApproved 
                      ? 'Your account has been suspended by the college administration. This action may be due to violation of college policies or academic regulations.'
                      : 'Your registration application has been reviewed and unfortunately was not approved at this time. This decision was made by the college administration.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF424242),
                      height: 1.6,
                    ),
                  ),
                ),
                
                if (rejectionReason != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE53935).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_rounded,
                              color: const Color(0xFFE53935),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              wasApproved ? 'Suspension Reason:' : 'Rejection Reason:',
                              style: const TextStyle(
                                color: Color(0xFFE53935),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          rejectionReason,
                          style: const TextStyle(
                            color: Color(0xFF424242),
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        
                        if (rejectedBy != null || rejectedAt != null) ...[
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFFE0E0E0)),
                          const SizedBox(height: 8),
                          if (rejectedBy != null)
                            Text(
                              'Reviewed by: $rejectedBy',
                              style: const TextStyle(
                                color: Color(0xFF757575),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          if (rejectedAt != null)
                            Text(
                              'Date: ${_formatTimestamp(rejectedAt)}',
                              style: const TextStyle(
                                color: Color(0xFF757575),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF2196F3).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.contact_support_rounded,
                            color: Color(0xFF2196F3),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Available Actions',
                            style: TextStyle(
                              color: Color(0xFF2196F3),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildContactOption(
                        icon: Icons.edit_rounded,
                        title: 'Edit Registration Details',
                        subtitle: 'Update your information and resubmit for review',
                        onTap: () => _showEditDetailsDialog(user, blockedData),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildContactOption(
                        icon: Icons.person_rounded,
                        title: 'Contact Department Head',
                        subtitle: userType == 'student' 
                            ? 'For academic-related concerns and appeals'
                            : 'For department-specific queries and appeals',
                        onTap: () => _showContactDialog(
                          'Department Head',
                          'Please reach out to your department head during office hours or schedule an appointment through the department office for clarification or to discuss your account status.',
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFF9800).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_rounded,
                              color: const Color(0xFFFF9800),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your registered email:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF757575),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: userEmail));
                                      Get.snackbar(
                                        'Copied',
                                        'Email address copied to clipboard',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: const Color(0xFF4CAF50),
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 2),
                                      );
                                    },
                                    child: Text(
                                      userEmail,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF424242),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.copy_rounded,
                              color: const Color(0xFFFF9800),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDetailsDialog(User user, Map<String, dynamic> blockedData) {
    Get.dialog(
      EditDetailsDialog(user: user, blockedData: blockedData),
      barrierDismissible: false,
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF2196F3),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFBDBDBD),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog(String contactType, String message) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.contact_support_rounded,
                  color: Color(0xFF2196F3),
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Contact $contactType',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF424242),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Understood'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInactiveAccountScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF9800).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.pause_circle_outline_rounded,
                  size: 64,
                  color: Color(0xFFFF9800),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Account Inactive',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Your account is currently inactive. Please contact the college administrator to reactivate your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF424242),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class EditDetailsDialog extends StatefulWidget {
  final User user;
  final Map<String, dynamic> blockedData;

  const EditDetailsDialog({
    super.key,
    required this.user,
    required this.blockedData,
  });

  @override
  State<EditDetailsDialog> createState() => _EditDetailsDialogState();
}

class _EditDetailsDialogState extends State<EditDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _usnController;

  String? _selectedUniversityId;
  String? _selectedCollegeId;
  String? _selectedCourseId;
  String? _selectedBranchId;
  String? _selectedYearOfPassing;
  
  List<Map<String, dynamic>> _universities = [];
  List<Map<String, dynamic>> _colleges = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _branches = [];
  
  final List<String> _yearsOfPassing = [
    '2023', '2024', '2025', '2026', '2027', '2028', '2029', '2030'
  ];

  bool _isLoadingUniversities = false;
  bool _isLoadingColleges = false;
  bool _isLoadingCourses = false;
  bool _isLoadingBranches = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUniversities();
  }

  void _initializeControllers() {
    final data = widget.blockedData;
    
    _firstNameController = TextEditingController(text: data['firstName'] ?? '');
    _lastNameController = TextEditingController(text: data['lastName'] ?? '');
    _phoneController = TextEditingController(text: data['phone'] ?? '');
    _usnController = TextEditingController(text: data['usn'] ?? '');
    
    _selectedUniversityId = data['universityId'];
    _selectedCollegeId = data['collegeId'];
    _selectedCourseId = data['courseId'];
    _selectedBranchId = data['branchId'];
    _selectedYearOfPassing = data['yearOfPassing'];
  }

  Future<void> _loadUniversities() async {
    setState(() => _isLoadingUniversities = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('universities')
          .get()
          .timeout(const Duration(seconds: 10));

      final universities = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'],
        };
      }).toList();

      // Remove duplicates
      final uniqueUniversities = universities.fold<Map<String, Map<String, dynamic>>>(
        {},
        (map, uni) {
          if (!map.containsKey(uni['id'])) {
            map[uni['id']] = uni;
          }
          return map;
        },
      ).values.toList();

      setState(() {
        _universities = uniqueUniversities;
      });
      
      if (_selectedUniversityId != null && 
          _universities.any((u) => u['id'] == _selectedUniversityId)) {
        await _loadColleges(_selectedUniversityId!);
      } else {
        setState(() => _selectedUniversityId = null);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load universities: ${e.toString()}');
      setState(() => _universities = []);
    } finally {
      setState(() => _isLoadingUniversities = false);
    }
  }

  Future<void> _loadColleges(String universityId) async {
    setState(() {
      _isLoadingColleges = true;
      if (_selectedUniversityId != universityId) {
        _selectedCollegeId = null;
        _selectedCourseId = null;
        _selectedBranchId = null;
        _colleges = [];
        _courses = [];
        _branches = [];
      }
      _selectedUniversityId = universityId;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('colleges')
          .where('universityId', isEqualTo: universityId)
          .get()
          .timeout(const Duration(seconds: 10));

      final colleges = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'],
        };
      }).toList();

      // Remove duplicates
      final uniqueColleges = colleges.fold<Map<String, Map<String, dynamic>>>(
        {},
        (map, col) {
          if (!map.containsKey(col['id'])) {
            map[col['id']] = col;
          }
          return map;
        },
      ).values.toList();

      setState(() {
        _colleges = uniqueColleges;
      });
      
      if (_selectedCollegeId != null && 
          _colleges.any((c) => c['id'] == _selectedCollegeId)) {
        await _loadCourses(_selectedCollegeId!);
      } else {
        setState(() => _selectedCollegeId = null);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load colleges: ${e.toString()}');
      setState(() => _colleges = []);
    } finally {
      setState(() => _isLoadingColleges = false);
    }
  }

  Future<void> _loadCourses(String collegeId) async {
    setState(() {
      _isLoadingCourses = true;
      if (_selectedCollegeId != collegeId) {
        _selectedCourseId = null;
        _selectedBranchId = null;
        _courses = [];
        _branches = [];
      }
      _selectedCollegeId = collegeId;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('collegeId', isEqualTo: collegeId)
          .get()
          .timeout(const Duration(seconds: 10));

      final courses = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'],
        };
      }).toList();

      // Remove duplicates
      final uniqueCourses = courses.fold<Map<String, Map<String, dynamic>>>(
        {},
        (map, course) {
          if (!map.containsKey(course['id'])) {
            map[course['id']] = course;
          }
          return map;
        },
      ).values.toList();

      setState(() {
        _courses = uniqueCourses;
      });
      
      if (_selectedCourseId != null && 
          _courses.any((c) => c['id'] == _selectedCourseId)) {
        await _loadBranches(_selectedCourseId!);
      } else {
        setState(() => _selectedCourseId = null);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load courses: ${e.toString()}');
      setState(() => _courses = []);
    } finally {
      setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _loadBranches(String courseId) async {
    setState(() {
      _isLoadingBranches = true;
      if (_selectedCourseId != courseId) {
        _selectedBranchId = null;
        _branches = [];
      }
      _selectedCourseId = courseId;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('branches')
          .where('courseId', isEqualTo: courseId)
          .get()
          .timeout(const Duration(seconds: 10));

      final branches = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'],
        };
      }).toList();

      // Remove duplicates
      final uniqueBranches = branches.fold<Map<String, Map<String, dynamic>>>(
        {},
        (map, branch) {
          if (!map.containsKey(branch['id'])) {
            map[branch['id']] = branch;
          }
          return map;
        },
      ).values.toList();

      setState(() {
        _branches = uniqueBranches;
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to load branches: ${e.toString()}');
      setState(() => _branches = []);
    } finally {
      setState(() => _isLoadingBranches = false);
    }
  }

  Future<void> _updateDetails() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      if (_selectedUniversityId == null ||
          _selectedCollegeId == null ||
          _selectedCourseId == null ||
          _selectedBranchId == null ||
          _selectedYearOfPassing == null) {
        throw Exception('Please fill in all fields');
      }

      final university = _universities.firstWhere(
        (uni) => uni['id'] == _selectedUniversityId,
        orElse: () => {'name': 'Unknown'},
      );
      final college = _colleges.firstWhere(
        (col) => col['id'] == _selectedCollegeId,
        orElse: () => {'name': 'Unknown'},
      );
      final course = _courses.firstWhere(
        (c) => c['id'] == _selectedCourseId,
        orElse: () => {'name': 'Unknown'},
      );
      final branch = _branches.firstWhere(
        (b) => b['id'] == _selectedBranchId,
        orElse: () => {'name': 'Unknown'},
      );

      final updatedData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'fullName': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'phone': _phoneController.text.trim(),
        'usn': _usnController.text.trim().toUpperCase(),
        'universityId': _selectedUniversityId,
        'universityName': university['name'],
        'collegeId': _selectedCollegeId,
        'collegeName': college['name'],
        'courseId': _selectedCourseId,
        'courseName': course['name'],
        'branchId': _selectedBranchId,
        'branchName': branch['name'],
        'yearOfPassing': _selectedYearOfPassing,
        'accountStatus': 'pending_approval',
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'resubmittedAt': FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();

      final pendingStudentRef = FirebaseFirestore.instance
          .collection('users')
          .doc('pending_students')
          .collection('data')
          .doc(widget.user.uid);

      final blockedStudentRef = FirebaseFirestore.instance
          .collection('users')
          .doc('blocked_students')
          .collection('data')
          .doc(widget.user.uid);

      final metadataRef = FirebaseFirestore.instance
          .collection('user_metadata')
          .doc(widget.user.uid);

      final currentBlockedData = widget.blockedData;
      currentBlockedData.addAll(updatedData);

      batch.set(pendingStudentRef, currentBlockedData);
      batch.delete(blockedStudentRef);
      batch.update(metadataRef, {
        'accountStatus': 'pending_approval',
        'dataLocation': 'users/pending_students/data/${widget.user.uid}',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Notify HOD and Faculty about resubmitted pending approval
      try {
        await NotificationService.notifyPendingStudentSubmitted(
          college: university['name'] ?? currentBlockedData['collegeName'] ?? '',
          branch: branch['name'] ?? currentBlockedData['branchName'] ?? '',
          studentName: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        );
      } catch (_) {}

      Get.back();
      Get.snackbar(
        'Success',
        'Your details have been updated and resubmitted for review.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update details: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFE53935),
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String hintText,
    required List<Map<String, dynamic>> items,
    required String? selectedValue,
    required Function(String?) onChanged,
    bool isLoading = false,
    bool enabled = true,
  }) {
    // Filter out duplicate items
    final uniqueItems = items.fold<Map<String, Map<String, dynamic>>>(
      {},
      (map, item) {
        if (!map.containsKey(item['id'])) {
          map[item['id']] = item;
        }
        return map;
      },
    ).values.toList();

    // Check if selectedValue exists in the items
    final validSelectedValue = uniqueItems.any((item) => item['id'] == selectedValue)
        ? selectedValue
        : null;

    return DropdownButtonFormField<String>(
      value: validSelectedValue,
      items: [
        DropdownMenuItem(
          value: null,
          child: Text('Select $hintText'),
        ),
        ...uniqueItems.map((item) {
          return DropdownMenuItem(
            value: item['id'],
            child: Text(item['name']),
          );
        }),
      ],
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
      ),
      validator: (value) {
        if (value == null) {
          return 'Please select a $hintText';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Registration Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _firstNameController,
                              hint: 'First Name',
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _lastNameController,
                              hint: 'Last Name',
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _phoneController,
                        hint: 'Phone Number',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Phone number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _usnController,
                        hint: 'USN',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'USN is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDropdown(
                        hintText: 'University',
                        items: _universities,
                        selectedValue: _selectedUniversityId,
                        onChanged: (value) => _loadColleges(value!),
                        isLoading: _isLoadingUniversities,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDropdown(
                        hintText: 'College',
                        items: _colleges,
                        selectedValue: _selectedCollegeId,
                        onChanged: (value) => _loadCourses(value!),
                        isLoading: _isLoadingColleges,
                        enabled: _selectedUniversityId != null,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDropdown(
                        hintText: 'Course',
                        items: _courses,
                        selectedValue: _selectedCourseId,
                        onChanged: (value) => _loadBranches(value!),
                        isLoading: _isLoadingCourses,
                        enabled: _selectedCollegeId != null,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDropdown(
                        hintText: 'Branch',
                        items: _branches,
                        selectedValue: _selectedBranchId,
                        onChanged: (value) => setState(() => _selectedBranchId = value),
                        isLoading: _isLoadingBranches,
                        enabled: _selectedCourseId != null,
                      ),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: _selectedYearOfPassing,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Select Year of Passing'),
                          ),
                          ..._yearsOfPassing.map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year),
                            );
                          }),
                        ],
                        onChanged: (value) => setState(() => _selectedYearOfPassing = value),
                        decoration: InputDecoration(
                          labelText: 'Year of Passing',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null) {
                            return 'Please select year of passing';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Update & Resubmit'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _usnController.dispose();
    super.dispose();
  }
}