# Driver App Chat Integration Guide

## Overview

The customer app has a **complete real-time chat system** that allows customers to communicate with drivers during deliveries. This guide explains how to integrate the driver app with this system.

---

## 🔧 Technical Stack

- **Real-time Communication:** Ably (WebSocket-based)
- **Message Storage:** Ably History (48 hours) + Local cache
- **Image Storage:** Supabase Storage (`chat-images` bucket)
- **Message Format:** JSON via Ably channels

---

## 📡 Ably Channel Structure

### Channel Naming Convention
```
delivery:{deliveryId}:chat
```

**Example:**
```
delivery:123e4567-e89b-12d3-a456-426614174000:chat
```

### Channel Events

| Event Name | Purpose | Direction |
|------------|---------|-----------|
| `message` | New chat message | Bidirectional |
| `message:read` | Read receipt | Bidirectional |
| `message:reaction` | Emoji reaction | Bidirectional |
| `typing` | Typing indicator | Bidirectional |

---

## 💬 Message Format

### 1. Text Message (`message` event)

```json
{
  "id": "msg_123e4567-e89b-12d3-a456-426614174000",
  "deliveryId": "123e4567-e89b-12d3-a456-426614174000",
  "senderId": "driver_456",
  "senderType": "driver",
  "senderName": "Juan Driver",
  "message": "I'm 5 minutes away!",
  "type": "text",
  "timestamp": 1730000000000,
  "imageUrl": null,
  "quickReplyType": null,
  "reactions": {},
  "readBy": ["driver_456"]
}
```

**Field Descriptions:**
- `id`: Unique message ID (UUID v4)
- `deliveryId`: ID of the delivery this chat belongs to
- `senderId`: User ID of sender (customer ID or driver ID)
- `senderType`: Either `"customer"` or `"driver"`
- `senderName`: Display name of sender
- `message`: Text content of the message
- `type`: Message type: `"text"`, `"image"`, `"quickReply"`, or `"system"`
- `timestamp`: Unix timestamp in milliseconds
- `imageUrl`: URL if message contains image (null for text)
- `quickReplyType`: ID of quick reply template used (null for regular messages)
- `reactions`: Map of emoji reactions: `{"👍": ["userId1", "userId2"], "❤️": ["userId3"]}`
- `readBy`: Array of user IDs who have read the message

### 2. Image Message

```json
{
  "id": "msg_789...",
  "deliveryId": "123e4567...",
  "senderId": "driver_456",
  "senderType": "driver",
  "senderName": "Juan Driver",
  "message": "Package photo",
  "type": "image",
  "timestamp": 1730000000000,
  "imageUrl": "https://your-supabase.supabase.co/storage/v1/object/public/chat-images/deliveries/chat/123e4567.../1730000000_uuid.jpg",
  "quickReplyType": null,
  "reactions": {},
  "readBy": ["driver_456"]
}
```

### 3. Quick Reply Message

```json
{
  "id": "msg_abc...",
  "deliveryId": "123e4567...",
  "senderId": "driver_456",
  "senderType": "driver",
  "senderName": "Juan Driver",
  "message": "🚗 I'm here",
  "type": "quickReply",
  "timestamp": 1730000000000,
  "imageUrl": null,
  "quickReplyType": "driver_arrived",
  "reactions": {},
  "readBy": ["driver_456"]
}
```

---

## 📨 Sending Messages

### Send Text Message (Driver → Customer)

```dart
// Flutter/Dart Example
final message = {
  'id': Uuid().v4(),
  'deliveryId': deliveryId,
  'senderId': driverId,
  'senderType': 'driver',
  'senderName': driverName,
  'message': messageText,
  'type': 'text',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'imageUrl': null,
  'quickReplyType': null,
  'reactions': {},
  'readBy': [driverId],
};

await ablyChannel.publish(name: 'message', data: message);
```

### Send Image Message

```dart
// 1. Upload image to Supabase Storage
final path = 'deliveries/chat/$deliveryId/${timestamp}_${uuid}.$ext';
await supabase.storage.from('chat-images').upload(path, imageFile);
final imageUrl = supabase.storage.from('chat-images').getPublicUrl(path);

// 2. Send message with image URL
final message = {
  'id': Uuid().v4(),
  'deliveryId': deliveryId,
  'senderId': driverId,
  'senderType': 'driver',
  'senderName': driverName,
  'message': 'Package photo',
  'type': 'image',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'imageUrl': imageUrl,
  'quickReplyType': null,
  'reactions': {},
  'readBy': [driverId],
};

await ablyChannel.publish(name: 'message', data: message);
```

---

## 📖 Read Receipts

### Send Read Receipt

When driver reads a message from customer:

```dart
await ablyChannel.publish(
  name: 'message:read',
  data: {
    'messageId': messageId,
    'readBy': driverId,
    'readAt': DateTime.now().millisecondsSinceEpoch,
  },
);
```

### Listen for Read Receipts

```dart
ablyChannel.subscribe(name: 'message:read').listen((message) {
  final data = message.data;
  final messageId = data['messageId'];
  final readBy = data['readBy'];
  
  // Update UI: Mark message as read
});
```

---

## 😊 Reactions

### Add Reaction

```dart
await ablyChannel.publish(
  name: 'message:reaction',
  data: {
    'messageId': messageId,
    'emoji': '👍',
    'userId': driverId,
    'action': 'add',
  },
);
```

### Remove Reaction

```dart
await ablyChannel.publish(
  name: 'message:reaction',
  data: {
    'messageId': messageId,
    'emoji': '👍',
    'userId': driverId,
    'action': 'remove',
  },
);
```

### Listen for Reactions

```dart
ablyChannel.subscribe(name: 'message:reaction').listen((message) {
  final data = message.data;
  final messageId = data['messageId'];
  final emoji = data['emoji'];
  final userId = data['userId'];
  final action = data['action']; // 'add' or 'remove'
  
  // Update UI: Add/remove reaction to message
});
```

---

## ⌨️ Typing Indicators

### Send Typing Indicator

```dart
// When driver starts typing
await ablyChannel.publish(
  name: 'typing',
  data: {
    'typing': true,
    'userId': driverId,
    'userName': driverName,
  },
);

// When driver stops typing (auto after 3 seconds)
await ablyChannel.publish(
  name: 'typing',
  data: {
    'typing': false,
    'userId': driverId,
    'userName': driverName,
  },
);
```

### Listen for Typing

```dart
ablyChannel.subscribe(name: 'typing').listen((message) {
  final data = message.data;
  final isTyping = data['typing'];
  final userId = data['userId'];
  final userName = data['userName'];
  
  if (userId != driverId) {
    // Show/hide "Customer is typing..." indicator
  }
});
```

---

## ⚡ Quick Replies

### Driver Quick Reply Templates

The customer app provides these quick reply templates. Drivers should use the same format:

```dart
final driverQuickReplies = [
  {
    'id': 'driver_arrived',
    'emoji': '🚗',
    'text': "I'm here",
  },
  {
    'id': 'driver_5min',
    'emoji': '⏱️',
    'text': "5 min away",
  },
  {
    'id': 'driver_traffic',
    'emoji': '🚦',
    'text': "Traffic delay",
  },
  {
    'id': 'driver_cant_find',
    'emoji': '📍',
    'text': "Can't find location",
  },
  {
    'id': 'driver_call_me',
    'emoji': '📞',
    'text': "Please call me",
  },
  {
    'id': 'driver_delivered',
    'emoji': '✅',
    'text': "Package delivered!",
  },
];
```

### Send Quick Reply

```dart
final quickReply = driverQuickReplies[0]; // "I'm here"

final message = {
  'id': Uuid().v4(),
  'deliveryId': deliveryId,
  'senderId': driverId,
  'senderType': 'driver',
  'senderName': driverName,
  'message': '${quickReply['emoji']} ${quickReply['text']}',
  'type': 'quickReply',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'imageUrl': null,
  'quickReplyType': quickReply['id'],
  'reactions': {},
  'readBy': [driverId],
};

await ablyChannel.publish(name: 'message', data: message);
```

---

## 📜 Message History

### Fetch Previous Messages

Use Ably History API to load messages when driver opens chat:

```dart
final history = await ablyChannel.history(
  RealtimeHistoryParams(
    limit: 100,
    direction: 'backwards',
  ),
);

final messages = [];
for (final msg in history.items) {
  if (msg.name == 'message' && msg.data != null) {
    messages.add(msg.data);
  }
}

// Display messages in UI (sorted by timestamp)
messages.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
```

---

## 🔔 Notifications

### Notify Driver of New Message

When driver app receives a new message:

1. **If chat is open:** Display message immediately
2. **If chat is closed:** Show push notification

```dart
ablyChannel.subscribe(name: 'message').listen((message) {
  final data = message.data;
  
  if (data['senderType'] == 'customer') {
    // Message from customer
    if (!isChatOpen) {
      // Show push notification
      showNotification(
        title: 'New message from ${data['senderName']}',
        body: data['message'],
        deliveryId: data['deliveryId'],
      );
    }
  }
});
```

---

## 🛡️ Error Handling

### Handle Connection Issues

```dart
// Monitor connection state
ablyClient.connection.on().listen((state) {
  switch (state.event) {
    case ConnectionEvent.connected:
      print('✅ Connected to Ably');
      break;
    case ConnectionEvent.disconnected:
      print('❌ Disconnected from Ably');
      // Show offline indicator
      break;
    case ConnectionEvent.failed:
      print('❌ Connection failed');
      // Retry connection
      break;
  }
});
```

### Handle Message Send Failures

```dart
try {
  await ablyChannel.publish(name: 'message', data: message);
  print('✅ Message sent');
} catch (e) {
  print('❌ Failed to send message: $e');
  // Show error to driver
  // Retry sending
}
```

---

## 🧪 Testing

### Test Message Flow

1. **Customer sends message** → Driver receives via `message` event
2. **Driver sends message** → Customer receives via `message` event
3. **Driver marks as read** → Customer sees read receipt (✓✓)
4. **Customer reacts** → Driver sees emoji reaction
5. **Driver sends image** → Customer sees image with zoom capability

### Test Channel Name

```dart
// For delivery ID: 123e4567-e89b-12d3-a456-426614174000
final channelName = 'delivery:123e4567-e89b-12d3-a456-426614174000:chat';
final channel = ablyClient.channels.get(channelName);
```

---

## 📚 Implementation Checklist

### Required Features
- ✅ Subscribe to delivery chat channel
- ✅ Listen for `message` events
- ✅ Send text messages
- ✅ Send read receipts
- ✅ Display typing indicators
- ✅ Show message history on open
- ✅ Handle connection failures

### Optional Features
- ⚡ Quick reply templates
- 📷 Image sharing
- 😊 Emoji reactions
- 🔔 Push notifications when chat closed

---

## 🔐 Security Considerations

1. **Authentication:** Ensure driver is authenticated with Ably using their driver ID
2. **Channel Access:** Driver should only access channels for their assigned deliveries
3. **Message Validation:** Validate `senderType` is actually `"driver"` for outgoing messages
4. **Image URLs:** Use Supabase public URLs (no sensitive data in URLs)
5. **Auto-Cleanup:** Messages auto-delete after 48 hours (Ably retention)

---

## 🆘 Troubleshooting

### Messages Not Appearing
- ✅ Check channel name format: `delivery:{deliveryId}:chat`
- ✅ Verify Ably connection state is `connected`
- ✅ Ensure `senderId` and `senderType` are correct
- ✅ Check message format matches JSON structure

### Images Not Loading
- ✅ Verify image uploaded to Supabase `chat-images` bucket
- ✅ Check bucket is public
- ✅ Verify public URL is accessible
- ✅ Check file path: `deliveries/chat/{deliveryId}/{filename}`

### Read Receipts Not Working
- ✅ Ensure `message:read` event is published
- ✅ Check `messageId` matches exactly
- ✅ Verify `readBy` array is updated correctly

---

## 📞 Support

For questions or issues with chat integration, contact:
- **Customer App Team:** [Your contact info]
- **Ably Documentation:** https://ably.com/docs
- **Supabase Storage:** https://supabase.com/docs/guides/storage

---

## 🎯 Quick Start Example

```dart
// 1. Connect to Ably
final ably = Realtime(key: 'YOUR_ABLY_API_KEY');

// 2. Get chat channel
final deliveryId = 'your-delivery-id';
final channel = ably.channels.get('delivery:$deliveryId:chat');

// 3. Listen for messages
channel.subscribe(name: 'message').listen((msg) {
  print('New message: ${msg.data['message']}');
});

// 4. Send message
await channel.publish(
  name: 'message',
  data: {
    'id': Uuid().v4(),
    'deliveryId': deliveryId,
    'senderId': 'driver_123',
    'senderType': 'driver',
    'senderName': 'Juan',
    'message': 'Hello!',
    'type': 'text',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'imageUrl': null,
    'quickReplyType': null,
    'reactions': {},
    'readBy': ['driver_123'],
  },
);
```

---

**Document Version:** 1.0  
**Last Updated:** October 27, 2025  
**Customer App Chat Version:** Complete
