class ChatUser {
  ChatUser({
    required this.image,
    required this.about,
    required this.name,
    required this.createdAt,
    required this.isOnline,
    required this.id,
    required this.lastActive,
    required this.email,
    required this.pushToken,
    this.isFocusMode = false,
    this.phone = '',
    this.college = '',
    this.department = '',
    this.userType = '',
    this.rollNo = '',
  });
  late String image;
  late String about;
  late String name;
  late String createdAt;
  late bool isOnline;
  late String id;
  late String lastActive;
  late String email;
  late String pushToken;
  late bool isFocusMode;
  late String phone;
  late String college;
  late String department;
  late String userType; // 'student', 'faculty', 'college_staff', etc.
  late String rollNo;

  ChatUser.fromJson(Map<String, dynamic> json) {
    // Support multiple possible key names (some parts of app use different conventions)
    // profile widgets use 'profileImageUrl' and 'fullName' / 'firstName' + 'lastName'
    image = json['image'] ?? json['photoURL'] ?? json['profileImageUrl'] ?? '';
    about = json['about'] ?? '';
    name = json['name'] ?? json['displayName'] ?? json['fullName'] ??
        ((json['firstName'] != null || json['lastName'] != null)
            ? '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim()
            : '');
    createdAt = json['created_at'] ?? json['createdAt'] ?? '';
    isOnline = json['is_online'] ?? json['isOnline'] ?? false;
    id = json['id'] ?? json['uid'] ?? '';
    lastActive = json['last_active'] ?? json['lastActive'] ?? '';
    email = json['email'] ?? '';
    pushToken = json['push_token'] ?? json['pushToken'] ?? '';
    isFocusMode = json['isFocusMode'] ?? json['is_focus_mode'] ?? false;
    phone = json['phone'] ?? '';
    college = json['college'] ?? '';
    department = json['department'] ?? '';
    userType = json['userType'] ?? json['user_type'] ?? '';
    rollNo = json['rollNo'] ?? json['roll_no'] ?? '';
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['image'] = image;
    data['about'] = about;
    data['name'] = name;
    data['created_at'] = createdAt;
    data['is_online'] = isOnline;
    data['id'] = id;
    data['last_active'] = lastActive;
    data['email'] = email;
    data['push_token'] = pushToken;
    data['isFocusMode'] = isFocusMode;
    data['phone'] = phone;
    data['college'] = college;
    data['department'] = department;
    data['userType'] = userType;
    data['rollNo'] = rollNo;
    return data;
  }

  /// Check if profile is complete (essential fields are filled)
  bool isProfileComplete() {
    return name.isNotEmpty &&
        email.isNotEmpty &&
        phone.isNotEmpty &&
        college.isNotEmpty;
  }
}