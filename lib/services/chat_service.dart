import 'dart:async';
import 'dart:io';

import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';

/// Chat service for managing real-time chat with Ably
class ChatService {
  final ably.Realtime _ablyClient;
  final String _currentUserId;
  final SenderType _currentUserType;
  final String _currentUserName;

  ably.RealtimeChannel? _chatChannel;
  Box<Map>? _messagesBox; // Hive box for local caching

  final _messagesController = StreamController<List<ChatMessage>>.broadcast();
  final _typingController = StreamController<bool>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();

  final List<ChatMessage> _messages = [];
  int _unreadCount = 0;
  Timer? _typingTimer;
  Timer? _cleanupTimer;

  static const String MESSAGE_EVENT = 'message';
  static const String READ_RECEIPT_EVENT = 'message:read';
  static const String REACTION_EVENT = 'message:reaction';
  static const String TYPING_EVENT = 'typing';

  ChatService({
    required ably.Realtime ablyClient,
    required String currentUserId,
    required SenderType currentUserType,
    required String currentUserName,
  })  : _ablyClient = ablyClient,
        _currentUserId = currentUserId,
        _currentUserType = currentUserType,
        _currentUserName = currentUserName;

  /// Initialize chat for a delivery
  Future<void> initializeChat(String deliveryId) async {
    try {
      debugPrint('💬 Initializing chat for delivery: $deliveryId');

      // Initialize Hive box for this delivery
      await _initializeLocalStorage(deliveryId);

      // Load cached messages
      await _loadCachedMessages(deliveryId);

      // Connect to Ably channel
      await _connectToChannel(deliveryId);

      // Fetch message history from Ably
      await _fetchMessageHistory();

      // Start cleanup timer (delete messages older than 48 hours)
      _startCleanupTimer();

      debugPrint('✅ Chat initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing chat: $e');
      rethrow;
    }
  }

  /// Initialize Hive box for local storage
  Future<void> _initializeLocalStorage(String deliveryId) async {
    final boxName = 'chat_$deliveryId';
    if (!Hive.isBoxOpen(boxName)) {
      _messagesBox = await Hive.openBox<Map>(boxName);
    } else {
      _messagesBox = Hive.box<Map>(boxName);
    }
  }

  /// Load cached messages from Hive
  Future<void> _loadCachedMessages(String deliveryId) async {
    try {
      final cachedMessages = _messagesBox?.values
          .map((map) => ChatMessage.fromHive(map))
          .where((msg) => msg.deliveryId == deliveryId)
          .toList() ?? [];

      _messages.clear();
      _messages.addAll(cachedMessages);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _messagesController.add(_messages);

      debugPrint('📦 Loaded ${_messages.length} cached messages');
    } catch (e) {
      debugPrint('❌ Error loading cached messages: $e');
    }
  }

  /// Connect to Ably channel
  Future<void> _connectToChannel(String deliveryId) async {
    final channelName = 'delivery:$deliveryId:chat';
    _chatChannel = _ablyClient.channels.get(channelName);

    // Subscribe to messages
    _chatChannel!.subscribe(name: MESSAGE_EVENT).listen(_handleNewMessage);

    // Subscribe to read receipts
    _chatChannel!.subscribe(name: READ_RECEIPT_EVENT).listen(_handleReadReceipt);

    // Subscribe to reactions
    _chatChannel!.subscribe(name: REACTION_EVENT).listen(_handleReaction);

    // Subscribe to typing indicators
    _chatChannel!.subscribe(name: TYPING_EVENT).listen(_handleTypingIndicator);

    debugPrint('🔌 Connected to Ably channel: $channelName');
  }

  /// Fetch message history from Ably (last 48 hours)
  Future<void> _fetchMessageHistory() async {
    try {
      final history = await _chatChannel!.history(
        ably.RealtimeHistoryParams(
          limit: 100,
          direction: 'backwards',
        ),
      );

      final historicalMessages = <ChatMessage>[];

      for (final message in history.items) {
        if (message.name == MESSAGE_EVENT && message.data != null) {
          try {
            final chatMessage = ChatMessage.fromJson(
              Map<String, dynamic>.from(message.data as Map),
            );

            // Only add messages from last 48 hours
            if (_isWithin48Hours(chatMessage.timestamp)) {
              historicalMessages.add(chatMessage);
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing historical message: $e');
          }
        }
      }

      // Merge with local messages (avoid duplicates)
      for (final msg in historicalMessages) {
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages.add(msg);
          await _cacheMessage(msg);
        }
      }

      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _messagesController.add(_messages);

      debugPrint('📜 Loaded ${historicalMessages.length} messages from history');
    } catch (e) {
      debugPrint('❌ Error fetching message history: $e');
    }
  }

  /// Handle new message from Ably
  void _handleNewMessage(ably.Message message) {
    try {
      final chatMessage = ChatMessage.fromJson(
        Map<String, dynamic>.from(message.data as Map),
      );

      // Avoid duplicates
      if (_messages.any((m) => m.id == chatMessage.id)) {
        return;
      }

      _messages.add(chatMessage);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Cache message locally
      _cacheMessage(chatMessage);

      // Update unread count if message is from other user
      if (!chatMessage.isFromMe(_currentUserId)) {
        _unreadCount++;
        _unreadCountController.add(_unreadCount);
      }

      _messagesController.add(_messages);

      debugPrint('📨 New message received: ${chatMessage.message}');
    } catch (e) {
      debugPrint('❌ Error handling new message: $e');
    }
  }

  /// Handle read receipt
  void _handleReadReceipt(ably.Message message) {
    try {
      final data = Map<String, dynamic>.from(message.data as Map);
      final messageId = data['messageId'] as String;
      final readBy = data['readBy'] as String;

      final msgIndex = _messages.indexWhere((m) => m.id == messageId);
      if (msgIndex != -1) {
        final updatedMessage = _messages[msgIndex].copyWith(
          readBy: [..._messages[msgIndex].readBy, readBy],
        );
        _messages[msgIndex] = updatedMessage;
        _cacheMessage(updatedMessage);
        _messagesController.add(_messages);
      }
    } catch (e) {
      debugPrint('❌ Error handling read receipt: $e');
    }
  }

  /// Handle reaction
  void _handleReaction(ably.Message message) {
    try {
      final data = Map<String, dynamic>.from(message.data as Map);
      final messageId = data['messageId'] as String;
      final emoji = data['emoji'] as String;
      final userId = data['userId'] as String;
      final action = data['action'] as String; // 'add' or 'remove'

      final msgIndex = _messages.indexWhere((m) => m.id == messageId);
      if (msgIndex != -1) {
        final reactions = Map<String, List<String>>.from(_messages[msgIndex].reactions);

        if (action == 'add') {
          reactions[emoji] = [...?reactions[emoji], userId];
        } else if (action == 'remove') {
          reactions[emoji]?.remove(userId);
          if (reactions[emoji]?.isEmpty ?? false) {
            reactions.remove(emoji);
          }
        }

        final updatedMessage = _messages[msgIndex].copyWith(reactions: reactions);
        _messages[msgIndex] = updatedMessage;
        _cacheMessage(updatedMessage);
        _messagesController.add(_messages);
      }
    } catch (e) {
      debugPrint('❌ Error handling reaction: $e');
    }
  }

  /// Handle typing indicator
  void _handleTypingIndicator(ably.Message message) {
    try {
      final data = Map<String, dynamic>.from(message.data as Map);
      final isTyping = data['typing'] as bool;
      final userId = data['userId'] as String;

      // Only show typing indicator if it's from other user
      if (userId != _currentUserId) {
        _typingController.add(isTyping);
      }
    } catch (e) {
      debugPrint('❌ Error handling typing indicator: $e');
    }
  }

  /// Send a text message
  Future<ChatMessage?> sendMessage(String messageText, String deliveryId) async {
    try {
      final message = ChatMessage(
        id: const Uuid().v4(),
        deliveryId: deliveryId,
        senderId: _currentUserId,
        senderType: _currentUserType,
        senderName: _currentUserName,
        message: messageText,
        type: MessageType.text,
        timestamp: DateTime.now(),
        isSending: true,
      );

      // Add to local list immediately (optimistic update)
      _messages.add(message);
      _messagesController.add(_messages);

      // Publish to Ably
      await _chatChannel!.publish(
        name: MESSAGE_EVENT,
        data: message.toJson(),
      );

      // Update message as sent
      final sentMessage = message.copyWith(isSending: false);
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = sentMessage;
        _messagesController.add(_messages);
      }

      // Cache message
      await _cacheMessage(sentMessage);

      debugPrint('✉️ Message sent: $messageText');
      return sentMessage;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');

      // Mark message as failed
      final failedMessage = _messages.firstWhere((m) => m.message == messageText).copyWith(
        isSending: false,
        isFailed: true,
      );
      final index = _messages.indexWhere((m) => m.message == messageText);
      if (index != -1) {
        _messages[index] = failedMessage;
        _messagesController.add(_messages);
      }

      return null;
    }
  }

  /// Send quick reply
  Future<ChatMessage?> sendQuickReply(QuickReply quickReply, String deliveryId) async {
    final message = ChatMessage(
      id: const Uuid().v4(),
      deliveryId: deliveryId,
      senderId: _currentUserId,
      senderType: _currentUserType,
      senderName: _currentUserName,
      message: '${quickReply.emoji} ${quickReply.text}',
      type: MessageType.quickReply,
      timestamp: DateTime.now(),
      quickReplyType: quickReply.id,
    );

    return sendMessage(message.message, deliveryId);
  }

  /// Send image message
  Future<ChatMessage?> sendImageMessage(String imageUrl, String deliveryId, {String? caption}) async {
    try {
      final message = ChatMessage(
        id: const Uuid().v4(),
        deliveryId: deliveryId,
        senderId: _currentUserId,
        senderType: _currentUserType,
        senderName: _currentUserName,
        message: caption ?? 'Photo',
        type: MessageType.image,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
        isSending: true,
      );

      _messages.add(message);
      _messagesController.add(_messages);

      await _chatChannel!.publish(
        name: MESSAGE_EVENT,
        data: message.toJson(),
      );

      final sentMessage = message.copyWith(isSending: false);
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = sentMessage;
        _messagesController.add(_messages);
      }

      await _cacheMessage(sentMessage);

      return sentMessage;
    } catch (e) {
      debugPrint('❌ Error sending image: $e');
      return null;
    }
  }

  /// Upload image to Supabase Storage and get public URL
  Future<String?> uploadImage(File imageFile, String deliveryId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final fileName = '${timestamp}_${const Uuid().v4()}.$extension';
      final path = 'deliveries/chat/$deliveryId/$fileName';

      debugPrint('📤 Uploading image to: $path');

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('chat-images')
          .upload(path, imageFile);

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('chat-images')
          .getPublicUrl(path);

      debugPrint('✅ Image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      return null;
    }
  }

  /// Mark message as read
  Future<void> markAsRead(String messageId) async {
    try {
      await _chatChannel!.publish(
        name: READ_RECEIPT_EVENT,
        data: {
          'messageId': messageId,
          'readBy': _currentUserId,
          'readAt': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('❌ Error marking message as read: $e');
    }
  }

  /// Add reaction to message
  Future<void> addReaction(String messageId, String emoji) async {
    try {
      await _chatChannel!.publish(
        name: REACTION_EVENT,
        data: {
          'messageId': messageId,
          'emoji': emoji,
          'userId': _currentUserId,
          'action': 'add',
        },
      );
    } catch (e) {
      debugPrint('❌ Error adding reaction: $e');
    }
  }

  /// Remove reaction from message
  Future<void> removeReaction(String messageId, String emoji) async {
    try {
      await _chatChannel!.publish(
        name: REACTION_EVENT,
        data: {
          'messageId': messageId,
          'emoji': emoji,
          'userId': _currentUserId,
          'action': 'remove',
        },
      );
    } catch (e) {
      debugPrint('❌ Error removing reaction: $e');
    }
  }

  /// Send typing indicator
  Future<void> sendTypingIndicator(bool isTyping) async {
    try {
      await _chatChannel!.publish(
        name: TYPING_EVENT,
        data: {
          'typing': isTyping,
          'userId': _currentUserId,
          'userName': _currentUserName,
        },
      );

      // Auto-stop typing after 3 seconds
      if (isTyping) {
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          sendTypingIndicator(false);
        });
      }
    } catch (e) {
      debugPrint('❌ Error sending typing indicator: $e');
    }
  }

  /// Cache message locally
  Future<void> _cacheMessage(ChatMessage message) async {
    try {
      await _messagesBox?.put(message.id, message.toHive());
    } catch (e) {
      debugPrint('❌ Error caching message: $e');
    }
  }

  /// Check if timestamp is within 48 hours
  bool _isWithin48Hours(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inHours <= 48;
  }

  /// Start cleanup timer (delete messages older than 48 hours)
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupOldMessages();
    });
  }

  /// Delete messages older than 48 hours
  Future<void> _cleanupOldMessages() async {
    try {
      final now = DateTime.now();
      final messagesToRemove = _messages.where((msg) {
        final age = now.difference(msg.timestamp);
        return age.inHours > 48;
      }).toList();

      for (final msg in messagesToRemove) {
        _messages.remove(msg);
        await _messagesBox?.delete(msg.id);
      }

      if (messagesToRemove.isNotEmpty) {
        _messagesController.add(_messages);
        debugPrint('🗑️ Cleaned up ${messagesToRemove.length} old messages');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up old messages: $e');
    }
  }

  /// Reset unread count
  void resetUnreadCount() {
    _unreadCount = 0;
    _unreadCountController.add(0);
  }

  /// Get messages stream
  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;

  /// Get typing indicator stream
  Stream<bool> get typingStream => _typingController.stream;

  /// Get unread count stream
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// Get current messages
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// Get unread count
  int get unreadCount => _unreadCount;

  /// Dispose and cleanup
  Future<void> dispose() async {
    debugPrint('👋 Disposing chat service');

    await _chatChannel?.detach();
    _chatChannel = null;

    _typingTimer?.cancel();
    _cleanupTimer?.cancel();

    await _messagesController.close();
    await _typingController.close();
    await _unreadCountController.close();

    await _messagesBox?.close();
  }
}
