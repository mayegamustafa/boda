import 'dart:convert';

class Notification {
  int? id;
  String? title;
  String? message;
  String? type;
  String? url;
  String? createdAt;
  bool? isRead;

  Notification({
    this.id,
    this.title,
    this.message,
    this.type,
    this.url,
    this.createdAt,
    this.isRead,
  });

  factory Notification.fromMap(Map<String, dynamic> data) {
    return Notification(
      id: data['id'] as int?,
      title: data['title'] as String?,
      message: data['message'] as String?,
      type: data['type'] as String?,
      url: data['url'] as String?,
      createdAt: data['created_at'] as String?,
      isRead: data['is_read'] as bool?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type,
        'url': url,
        'created_at': createdAt,
        'is_read': isRead,
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Notification].
  factory Notification.fromJson(String data) {
    return Notification.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [Notification] to a JSON string.
  String toJson() => json.encode(toMap());
}
