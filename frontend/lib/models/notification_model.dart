class NotificationModel {
  final String notificationid;
  final String userid;
  final String type;
  final String titleAr;
  final String? titleEn;
  final String bodyAr;
  final String? bodyEn;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;
  final bool fcmSent;
  final DateTime? fcmSentAt;

  NotificationModel({
    required this.notificationid,
    required this.userid,
    required this.type,
    required this.titleAr,
    this.titleEn,
    required this.bodyAr,
    this.bodyEn,
    this.data,
    required this.read,
    this.readAt,
    required this.createdAt,
    required this.fcmSent,
    this.fcmSentAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationid: json['notificationid'] as String,
      userid: json['userid'] as String,
      type: json['type'] as String,
      titleAr: json['title_ar'] as String,
      titleEn: json['title_en'] as String?,
      bodyAr: json['body_ar'] as String,
      bodyEn: json['body_en'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      read: json['read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      fcmSent: json['fcm_sent'] as bool? ?? false,
      fcmSentAt: json['fcm_sent_at'] != null
          ? DateTime.parse(json['fcm_sent_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notificationid': notificationid,
      'userid': userid,
      'type': type,
      'title_ar': titleAr,
      'title_en': titleEn,
      'body_ar': bodyAr,
      'body_en': bodyEn,
      'data': data,
      'read': read,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'fcm_sent': fcmSent,
      'fcm_sent_at': fcmSentAt?.toIso8601String(),
    };
  }

  String getTitle(bool isArabic) {
    if (isArabic) {
      return titleAr;
    }
    return titleEn ?? titleAr;
  }

  String getBody(bool isArabic) {
    if (isArabic) {
      return bodyAr;
    }
    return bodyEn ?? bodyAr;
  }
}
