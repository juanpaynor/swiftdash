import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'chat_message_bubble.dart';

/// Full-screen chat modal for messaging with driver
class ChatModal extends StatefulWidget {
  final ChatService chatService;
  final String deliveryId;
  final String driverName;
  final String? driverPhotoUrl;
  final VoidCallback? onMinimize;

  const ChatModal({
    super.key,
    required this.chatService,
    required this.deliveryId,
    required this.driverName,
    this.driverPhotoUrl,
    this.onMinimize,
  });

  @override
  State<ChatModal> createState() => _ChatModalState();
}

class _ChatModalState extends State<ChatModal> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  bool _isSending = false;
  bool _isUploadingImage = false;
  Timer? _typingTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Listen to messages
    widget.chatService.messagesStream.listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    });

    // Listen to typing indicator
    widget.chatService.typingStream.listen((isTyping) {
      if (mounted) {
        setState(() {
          _isTyping = isTyping;
        });
      }
    });

    // Load initial messages
    _messages = widget.chatService.messages;
    
    // Scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });

    // Reset unread count when opening
    widget.chatService.resetUnreadCount();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  void _handleTyping(String text) {
    if (text.isNotEmpty && !_isSending) {
      widget.chatService.sendTypingIndicator(true);
      
      // Auto-stop typing after 3 seconds
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        widget.chatService.sendTypingIndicator(false);
      });
    } else if (text.isEmpty) {
      widget.chatService.sendTypingIndicator(false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    // Clear input immediately (optimistic UI)
    _messageController.clear();
    _messageFocusNode.unfocus();
    
    // Stop typing indicator
    widget.chatService.sendTypingIndicator(false);
    _typingTimer?.cancel();

    try {
      await widget.chatService.sendMessage(text, widget.deliveryId);
      
      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      
      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to send message. Please try again.',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendQuickReply(QuickReply quickReply) async {
    try {
      await widget.chatService.sendQuickReply(quickReply, widget.deliveryId);
      
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('❌ Error sending quick reply: $e');
    }
  }

  void _showQuickReplies() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildQuickReplySheet(),
    );
  }

  Future<void> _handleImagePicker() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      // Show uploading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Uploading image...'),
            ],
          ),
          backgroundColor: const Color(0xFF2E4A9B),
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Upload to Supabase
      final imageFile = File(image.path);
      final imageUrl = await widget.chatService.uploadImage(imageFile, widget.deliveryId);

      // Hide uploading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      // Send image message
      await widget.chatService.sendImageMessage(imageUrl, widget.deliveryId);

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Image sent successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error picking/uploading image: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to send image. Please try again.',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _refreshMessages() async {
    if (_isLoadingHistory) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      // Messages are already loaded from ChatService
      // This is a placeholder for future pagination
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('❌ Error refreshing messages: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Driver avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                gradient: widget.driverPhotoUrl == null
                    ? const LinearGradient(
                        colors: [Colors.white24, Colors.white12],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
              ),
              child: widget.driverPhotoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        widget.driverPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.driverName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isTyping)
                    const Text(
                      'typing...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.onMinimize != null)
            IconButton(
              icon: const Icon(Icons.minimize, color: Colors.white),
              tooltip: 'Minimize',
              onPressed: () {
                Navigator.pop(context);
                widget.onMinimize?.call();
              },
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshMessages,
                color: const Color(0xFF2E4A9B),
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final showDateDivider = _shouldShowDateDivider(index);
                          
                          return Column(
                            children: [
                              if (showDateDivider)
                                _buildDateDivider(_messages[index].timestamp),
                              ChatMessageBubble(
                                message: message,
                                chatService: widget.chatService,
                                onRetry: () => _sendMessage(),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),

            // Typing indicator
            if (_isTyping)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTypingDot(0),
                          const SizedBox(width: 4),
                          _buildTypingDot(1),
                          const SizedBox(width: 4),
                          _buildTypingDot(2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Input area
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 12 + MediaQuery.of(context).padding.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Quick reply button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.bolt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: _showQuickReplies,
                      tooltip: 'Quick Replies',
                    ),

                    const SizedBox(width: 8),

                    // Image picker button
                    IconButton(
                      icon: const Icon(
                        Icons.image,
                        color: Color(0xFF6B7280),
                        size: 24,
                      ),
                      onPressed: _handleImagePicker,
                      tooltip: 'Send Image',
                    ),

                    const SizedBox(width: 8),

                    // Message input field
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 15,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                          onChanged: _handleTyping,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send button
                    GestureDetector(
                      onTap: _isSending ? null : _sendMessage,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: _messageController.text.trim().isEmpty
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _messageController.text.trim().isEmpty
                              ? const Color(0xFFE5E7EB)
                              : null,
                          shape: BoxShape.circle,
                          boxShadow: _messageController.text.trim().isEmpty
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF2E4A9B).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: _isSending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: _messageController.text.trim().isEmpty
                                    ? const Color(0xFF9CA3AF)
                                    : Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E4A9B).withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Send a message to your driver or use quick replies below',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = (value - delay).clamp(0.0, 1.0);
        final opacity = (animValue * 2).clamp(0.3, 1.0);
        
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF6B7280).withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  bool _shouldShowDateDivider(int index) {
    if (index == 0) return true;
    
    final currentMsg = _messages[index];
    final previousMsg = _messages[index - 1];
    
    final currentDate = DateTime(
      currentMsg.timestamp.year,
      currentMsg.timestamp.month,
      currentMsg.timestamp.day,
    );
    final previousDate = DateTime(
      previousMsg.timestamp.year,
      previousMsg.timestamp.month,
      previousMsg.timestamp.day,
    );
    
    return currentDate != previousDate;
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = '${date.month}/${date.day}/${date.year}';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFE5E7EB),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReplySheet() {
    final quickReplies = QuickReplies.customerReplies;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Quick Replies',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quick reply buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3,
              ),
              itemCount: quickReplies.length,
              itemBuilder: (context, index) {
                final reply = quickReplies[index];
                return _buildQuickReplyButton(reply);
              },
            ),
          ),

          SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildQuickReplyButton(QuickReply reply) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context); // Close bottom sheet
          _sendQuickReply(reply);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF2E4A9B).withOpacity(0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                reply.emoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  reply.text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E4A9B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
