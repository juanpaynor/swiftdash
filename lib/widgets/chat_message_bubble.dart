import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'full_screen_image_viewer.dart';

/// Individual message bubble for chat
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatService chatService;
  final VoidCallback? onRetry;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.chatService,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isFromMe = message.isFromMe(chatService.messages.first.senderId);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showReactionPicker(context),
          child: Column(
            crossAxisAlignment:
                isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Message bubble
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  gradient: isFromMe
                      ? const LinearGradient(
                          colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isFromMe ? null : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isFromMe
                        ? const Radius.circular(18)
                        : const Radius.circular(4),
                    bottomRight: isFromMe
                        ? const Radius.circular(4)
                        : const Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isFromMe
                              ? const Color(0xFF2E4A9B)
                              : Colors.black)
                          .withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender name (for driver messages)
                    if (!isFromMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          message.senderName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E4A9B),
                          ),
                        ),
                      ),

                    // Quick reply badge
                    if (message.type == MessageType.quickReply)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isFromMe
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFF2E4A9B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                size: 12,
                                color: isFromMe
                                    ? Colors.white
                                    : const Color(0xFF2E4A9B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Quick Reply',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isFromMe
                                      ? Colors.white
                                      : const Color(0xFF2E4A9B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Image (if present)
                    if (message.type == MessageType.image &&
                        message.imageUrl != null) ...[
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageViewer(
                                imageUrl: message.imageUrl!,
                                senderName: message.senderName,
                                timestamp: message.timestamp,
                              ),
                              fullscreenDialog: true,
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            message.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                color: Colors.black12,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isFromMe
                                          ? Colors.white
                                          : const Color(0xFF2E4A9B),
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.black12,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: Colors.white54,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (message.message.isNotEmpty) const SizedBox(height: 8),
                    ],

                    // Message text
                    Text(
                      message.message,
                      style: TextStyle(
                        fontSize: 15,
                        color:
                            isFromMe ? Colors.white : const Color(0xFF111827),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Timestamp and status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isFromMe
                                ? Colors.white.withOpacity(0.7)
                                : const Color(0xFF6B7280),
                          ),
                        ),

                        // Status indicators (for sent messages)
                        if (isFromMe) ...[
                          const SizedBox(width: 6),
                          if (message.isSending)
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.7),
                                ),
                              ),
                            )
                          else if (message.isFailed)
                            Icon(
                              Icons.error_outline,
                              size: 14,
                              color: Colors.red.shade200,
                            )
                          else if (message.readBy.length > 1) // Read by others
                            Icon(
                              Icons.done_all,
                              size: 14,
                              color: Colors.white.withOpacity(0.9),
                            )
                          else // Sent but not read
                            Icon(
                              Icons.done,
                              size: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Reactions
              if (message.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildReactions(context, isFromMe),
                ),

              // Retry button (for failed messages)
              if (message.isFailed && isFromMe && onRetry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text(
                      'Retry',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactions(BuildContext context, bool isFromMe) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: message.reactions.entries.map((entry) {
        final emoji = entry.key;
        final users = entry.value;
        final count = users.length;
        final hasReacted = message.hasUserReacted(
          chatService.messages.first.senderId,
          emoji,
        );

        return GestureDetector(
          onTap: () => _toggleReaction(emoji, hasReacted),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasReacted
                  ? const Color(0xFF2E4A9B).withOpacity(0.15)
                  : const Color(0xFFF3F4F6),
              border: Border.all(
                color: hasReacted
                    ? const Color(0xFF2E4A9B).withOpacity(0.3)
                    : Colors.transparent,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 14),
                ),
                if (count > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasReacted
                          ? const Color(0xFF2E4A9B)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showReactionPicker(BuildContext context) {
    // Common emoji reactions
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'React to message',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),

            const SizedBox(height: 20),

            // Emoji grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: emojis.map((emoji) {
                final hasReacted = message.hasUserReacted(
                  chatService.messages.first.senderId,
                  emoji,
                );

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _toggleReaction(emoji, hasReacted);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hasReacted
                          ? const Color(0xFF2E4A9B).withOpacity(0.1)
                          : const Color(0xFFF3F4F6),
                      border: Border.all(
                        color: hasReacted
                            ? const Color(0xFF2E4A9B).withOpacity(0.3)
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _toggleReaction(String emoji, bool hasReacted) {
    if (hasReacted) {
      chatService.removeReaction(message.id, emoji);
    } else {
      chatService.addReaction(message.id, emoji);
    }
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:$minute $period';
  }
}
