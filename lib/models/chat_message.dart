import 'package:flutter/foundation.dart';

/// Message types supported in chat
enum MessageType {
  text,
  image,
  quickReply,
  system,
}

/// Sender type (customer or driver)
enum SenderType {
  customer,
  driver,
}

/// Chat message model
class ChatMessage {
  final String id;
  final String deliveryId;
  final String senderId;
  final SenderType senderType;
  final String senderName;
  final String message;
  final MessageType type;
  final DateTime timestamp;
  final String? imageUrl;
  final String? quickReplyType;
  final Map<String, List<String>> reactions; // emoji -> list of user IDs
  final List<String> readBy;
  final bool isSending; // Local flag for pending messages
  final bool isFailed; // Local flag for failed messages

  ChatMessage({
    required this.id,
    required this.deliveryId,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.message,
    required this.type,
    required this.timestamp,
    this.imageUrl,
    this.quickReplyType,
    Map<String, List<String>>? reactions,
    List<String>? readBy,
    this.isSending = false,
    this.isFailed = false,
  })  : reactions = reactions ?? {},
        readBy = readBy ?? [];

  /// Create from JSON (from Ably message)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      deliveryId: json['deliveryId'] as String,
      senderId: json['senderId'] as String,
      senderType: SenderType.values.firstWhere(
        (e) => e.name == json['senderType'],
        orElse: () => SenderType.customer,
      ),
      senderName: json['senderName'] as String,
      message: json['message'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      imageUrl: json['imageUrl'] as String?,
      quickReplyType: json['quickReplyType'] as String?,
      reactions: json['reactions'] != null
          ? Map<String, List<String>>.from(
              (json['reactions'] as Map).map(
                (key, value) => MapEntry(
                  key.toString(),
                  List<String>.from(value as List),
                ),
              ),
            )
          : {},
      readBy: json['readBy'] != null
          ? List<String>.from(json['readBy'] as List)
          : [],
    );
  }

  /// Convert to JSON (for Ably message)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deliveryId': deliveryId,
      'senderId': senderId,
      'senderType': senderType.name,
      'senderName': senderName,
      'message': message,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'imageUrl': imageUrl,
      'quickReplyType': quickReplyType,
      'reactions': reactions,
      'readBy': readBy,
    };
  }

  /// Create from Hive (local storage)
  factory ChatMessage.fromHive(Map<dynamic, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      deliveryId: map['deliveryId'] as String,
      senderId: map['senderId'] as String,
      senderType: SenderType.values[map['senderType'] as int],
      senderName: map['senderName'] as String,
      message: map['message'] as String,
      type: MessageType.values[map['type'] as int],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      imageUrl: map['imageUrl'] as String?,
      quickReplyType: map['quickReplyType'] as String?,
      reactions: map['reactions'] != null
          ? Map<String, List<String>>.from(
              (map['reactions'] as Map).map(
                (key, value) => MapEntry(
                  key.toString(),
                  List<String>.from(value as List),
                ),
              ),
            )
          : {},
      readBy: map['readBy'] != null
          ? List<String>.from(map['readBy'] as List)
          : [],
    );
  }

  /// Convert to Hive format
  Map<String, dynamic> toHive() {
    return {
      'id': id,
      'deliveryId': deliveryId,
      'senderId': senderId,
      'senderType': senderType.index,
      'senderName': senderName,
      'message': message,
      'type': type.index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'imageUrl': imageUrl,
      'quickReplyType': quickReplyType,
      'reactions': reactions,
      'readBy': readBy,
    };
  }

  /// Check if message is from current user
  bool isFromMe(String currentUserId) {
    return senderId == currentUserId;
  }

  /// Check if message has been read by specific user
  bool isReadBy(String userId) {
    return readBy.contains(userId);
  }

  /// Get reaction count for emoji
  int getReactionCount(String emoji) {
    return reactions[emoji]?.length ?? 0;
  }

  /// Check if user has reacted with emoji
  bool hasUserReacted(String emoji, String userId) {
    return reactions[emoji]?.contains(userId) ?? false;
  }

  /// Copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? deliveryId,
    String? senderId,
    SenderType? senderType,
    String? senderName,
    String? message,
    MessageType? type,
    DateTime? timestamp,
    String? imageUrl,
    String? quickReplyType,
    Map<String, List<String>>? reactions,
    List<String>? readBy,
    bool? isSending,
    bool? isFailed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      deliveryId: deliveryId ?? this.deliveryId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      quickReplyType: quickReplyType ?? this.quickReplyType,
      reactions: reactions ?? this.reactions,
      readBy: readBy ?? this.readBy,
      isSending: isSending ?? this.isSending,
      isFailed: isFailed ?? this.isFailed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ChatMessage(id: $id, senderType: ${senderType.name}, message: $message, timestamp: $timestamp)';
  }
}

/// Quick reply template
class QuickReply {
  final String id;
  final String text;
  final String emoji;
  final SenderType forSender; // Who should see this quick reply

  const QuickReply({
    required this.id,
    required this.text,
    required this.emoji,
    required this.forSender,
  });
}

/// Predefined quick replies
class QuickReplies {
  static const List<QuickReply> customerReplies = [
    QuickReply(
      id: 'at_main_gate',
      text: "I'm at the main gate",
      emoji: '📍',
      forSender: SenderType.customer,
    ),
    QuickReply(
      id: 'in_lobby',
      text: "I'm in the lobby",
      emoji: '📍',
      forSender: SenderType.customer,
    ),
    QuickReply(
      id: 'running_late',
      text: "Running 5 min late",
      emoji: '⏱️',
      forSender: SenderType.customer,
    ),
    QuickReply(
      id: 'see_you',
      text: "I see you!",
      emoji: '✅',
      forSender: SenderType.customer,
    ),
    QuickReply(
      id: 'call_me',
      text: "Please call me",
      emoji: '📞',
      forSender: SenderType.customer,
    ),
    QuickReply(
      id: 'where_are_you',
      text: "Where are you?",
      emoji: '❓',
      forSender: SenderType.customer,
    ),
  ];

  static const List<QuickReply> driverReplies = [
    QuickReply(
      id: 'im_here',
      text: "I'm here",
      emoji: '🚗',
      forSender: SenderType.driver,
    ),
    QuickReply(
      id: '5_min_away',
      text: "5 min away",
      emoji: '⏱️',
      forSender: SenderType.driver,
    ),
    QuickReply(
      id: 'traffic_delay',
      text: "Traffic delay",
      emoji: '🚦',
      forSender: SenderType.driver,
    ),
    QuickReply(
      id: 'cant_find',
      text: "Can't find address",
      emoji: '❓',
      forSender: SenderType.driver,
    ),
    QuickReply(
      id: 'calling',
      text: "Calling you",
      emoji: '📞',
      forSender: SenderType.driver,
    ),
    QuickReply(
      id: 'delivered',
      text: "Package delivered",
      emoji: '✅',
      forSender: SenderType.driver,
    ),
  ];

  static List<QuickReply> getRepliesFor(SenderType senderType) {
    return senderType == SenderType.customer
        ? customerReplies
        : driverReplies;
  }
}
