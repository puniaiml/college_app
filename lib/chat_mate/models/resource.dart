class Resource {
  Resource({
    required this.id,
    required this.channelId,
    required this.title,
    required this.description,
    required this.url,
    required this.resourceType, // 'pdf', 'image', 'document', 'link', etc.
    required this.uploadedBy,
    required this.uploadedAt,
  });

  String id;
  String channelId;
  String title;
  String description;
  String url;
  String resourceType;
  String uploadedBy;
  String uploadedAt;

  Resource.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        channelId = json['channelId']?.toString() ?? '',
        title = json['title']?.toString() ?? '',
        description = json['description']?.toString() ?? '',
        url = json['url']?.toString() ?? '',
        resourceType = json['resourceType']?.toString() ?? 'document',
        uploadedBy = json['uploadedBy']?.toString() ?? '',
        uploadedAt = json['uploadedAt']?.toString() ?? '';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channelId': channelId,
      'title': title,
      'description': description,
      'url': url,
      'resourceType': resourceType,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt,
    };
  }
}
