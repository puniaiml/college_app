class Assignment {
  Assignment({
    required this.id,
    required this.channelId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.createdBy,
    required this.createdAt,
    this.isCompleted = false,
  });

  String id;
  String channelId;
  String title;
  String description;
  String dueDate; // ISO 8601 format (YYYY-MM-DD)
  String createdBy;
  String createdAt;
  bool isCompleted;

  Assignment.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        channelId = json['channelId']?.toString() ?? '',
        title = json['title']?.toString() ?? '',
        description = json['description']?.toString() ?? '',
        dueDate = json['dueDate']?.toString() ?? '',
        createdBy = json['createdBy']?.toString() ?? '',
        createdAt = json['createdAt']?.toString() ?? '',
        isCompleted = json['isCompleted'] ?? false;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channelId': channelId,
      'title': title,
      'description': description,
      'dueDate': dueDate,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'isCompleted': isCompleted,
    };
  }
}
