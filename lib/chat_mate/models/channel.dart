class Channel {
  Channel({
    required this.id,
    required this.name,
    this.subject = '',
    this.description = '',
    required this.createdBy,
    required this.createdAt,
    List<String>? members,
  }) : members = members ?? [];

  String id;
  String name;
  String subject;
  String description;
  String createdBy;
  String createdAt;
  List<String> members;

  Channel.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        name = json['name']?.toString() ?? '',
        subject = json['subject']?.toString() ?? '',
        description = json['description']?.toString() ?? '',
        createdBy = json['createdBy']?.toString() ?? '',
        createdAt = json['createdAt']?.toString() ?? '',
        members = (json['members'] is List) ? List<String>.from(json['members']) : [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'members': members,
    };
  }
}
