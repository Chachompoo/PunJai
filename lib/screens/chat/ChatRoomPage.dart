import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatRoomPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;
  final String postId;
  final String ownerId;

  const ChatRoomPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
    required this.postId,
    required this.ownerId,
  });

  static const routeName = '/chatRoom';

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();
  final _storage = FirebaseStorage.instance;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  Map<String, dynamic>? chatData;

  @override
  void initState() {
    super.initState();
    _loadChatData();
  }

  Future<void> _loadChatData() async {
    final doc = await _firestore.collection('chats').doc(widget.chatId).get();
    if (doc.exists) {
      setState(() {
        chatData = doc.data();
      });
    }
  }

  // 🎨 พาสเทลตามประเภทโพสต์
  Color get pastelColor {
    final type = chatData?['dealType'] ?? '';
    if (type == 'donate') return const Color(0xFFFFF0B3);
    if (type == 'request') return const Color(0xFFFFC2D6);
    if (type == 'swap') return const Color(0xFFBDE6FF);
    return const Color(0xFFEDE7FF); 
  }

  // 🩷 แปลงชื่อประเภทโพสต์เป็นภาษาไทย
  String get displayType {
    switch (chatData?['dealType']) {
      case 'donate':
        return 'บริจาค';
      case 'request':
        return 'ขอรับ';
      case 'swap':
        return 'แลกเปลี่ยน';
      default:
        return 'แชททั่วไป';
    }
  }

  // 🩵 แสดงชื่อโพสต์ ถ้าไม่มีให้ fallback
  String get title =>
      chatData?['dealTitle']?.toString().isNotEmpty == true
          ? chatData!['dealTitle']
          : 'ไม่ระบุชื่อโพสต์';

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final chatId = widget.chatId;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFFFF7FB),

      // 🌈 AppBar พาสเทลน่ารัก พร้อมชื่อโพสต์
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          elevation: 2,
          backgroundColor: pastelColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherUserName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "$displayType: $title",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          centerTitle: false,
        ),
      ),

      // 💬 แสดงข้อความทั้งหมด
      body: SafeArea(
  child: Column(
    children: [
      // 💬 รายการข้อความ
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('chats')
              .doc(widget.chatId)
              .collection('messages')
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('เริ่มต้นการสนทนาได้เลย 💬'));
            }

            final messages = snapshot.data!.docs;
            return ListView.builder(
              controller: _scrollCtrl,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg =
                    messages[index].data() as Map<String, dynamic>;
                final isMe = msg['senderId'] == _auth.currentUser?.uid;

                // (ไม่ต้องแก้ส่วนนี้)
                if (msg['type'] == 'system') {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: pastelColor.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg['text'] ?? '',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87)),
                    ),
                  );
                }

                // ... image, video, text ตามเดิม
                // (ไม่ต้องเปลี่ยน)
                // ...
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      // 💖 รูปโปรไฟล์ของ "คู่สนทนา"
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.only(right: 8, top: 4),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(widget.otherUserImage),
                          ),
                        ),

                      // 💬 กล่องข้อความ
                      Flexible(
                        child: Column(
                          crossAxisAlignment:
                              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? pastelColor.withOpacity(0.9)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isMe ? 14 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 14),
                                ),
                              ),
                              child: _buildMessageContent(msg),
                            ),

                            // 🕒 เวลา
                            if (msg['createdAt'] != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 2, left: 6, right: 6),
                                child: Text(
                                  DateFormat('HH:mm')
                                      .format(msg['createdAt'].toDate()),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black45,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // 🔸 ช่องว่างให้ bubble ฝั่งเราดูบาลานซ์
                      if (isMe) const SizedBox(width: 8),
                    ],
                  ),
                );


              },
            );
          },
        ),
      ),

      // 💗 ช่องพิมพ์ข้อความ
      SafeArea(
        child: _buildMessageInput(),
      ),
    ],
  ),
),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> msg) {
  final type = msg['type'] ?? 'text';

  switch (type) {
    case 'image':
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.black.withOpacity(0.8),
              insetPadding: const EdgeInsets.all(10),
              child: InteractiveViewer(
                child: Image.network(
                  msg['url'],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('⚠️ โหลดรูปไม่สำเร็จ',
                            style: TextStyle(color: Colors.white)),
                      ),
                ),
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            msg['url'],
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Text('⚠️ โหลดรูปไม่สำเร็จ'),
          ),
        ),
      );

    case 'video':
      return SizedBox(
        width: 220,
        height: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: VideoPlayerWidget(url: msg['url']),
        ),
      );

    default:
      return Text(
        msg['text'] ?? '',
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      );
  }
}


  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo, color: Colors.pinkAccent),
            onPressed: _sendImage,
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.blueAccent),
            onPressed: _sendVideo,
          ),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              decoration: const InputDecoration(
                hintText: "พิมพ์ข้อความ...",
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.pinkAccent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  // 🚀 ส่งข้อความ
  Future<void> _sendMessage() async {
  final text = _msgCtrl.text.trim();
  if (text.isEmpty) return;

  final currentUser = _auth.currentUser;
  if (currentUser == null) return;

  // ✅ ดึงชื่อจาก Firestore
  final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
  final userData = userDoc.data();
  final firstname = userData?['firstname'] ?? '';
  final lastname = userData?['lastname'] ?? '';
  final fullName = (firstname + ' ' + lastname).trim().isNotEmpty
      ? '$firstname $lastname'
      : (currentUser.displayName ?? 'ผู้ใช้ PunJai');

  // ✅ 1. เพิ่มข้อความลง Firestore
  await _firestore
      .collection('chats')
      .doc(widget.chatId)
      .collection('messages')
      .add({
    'text': text,
    'senderId': currentUser.uid,
    'createdAt': FieldValue.serverTimestamp(),
    'type': 'text',
  });

  // ✅ 2. อัปเดต lastMessage
  await _firestore.collection('chats').doc(widget.chatId).update({
    'lastMessage': text,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  // ✅ 3. เคลียร์ช่องข้อความ
  _msgCtrl.clear();

  // ✅ 4. ดึงข้อมูลห้องแชท เพื่อหาว่าอีกฝ่ายคือใคร
  final chatDoc =
      await _firestore.collection('chats').doc(widget.chatId).get();
  final chatData = chatDoc.data();
  if (chatData != null) {
    final participants = List<String>.from(chatData['participants'] ?? []);
    final receiverId = participants.firstWhere(
      (id) => id != currentUser.uid,
      orElse: () => '',
    );

    // ✅ 5. สร้างแจ้งเตือนให้ผู้รับ (ยกเว้นข้อความ system)
    if (receiverId.isNotEmpty &&
        !text.startsWith('🎯') &&
        !text.startsWith('📦')) {
      await _firestore.collection('notifications').add({
        'toUserId': receiverId,
        'fromUserId': currentUser.uid,
        'chatId': widget.chatId,
        'type': 'chat',
        'message': 'คุณมีข้อความใหม่จาก $fullName 💬',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}




  // 🖼 ส่งรูปภาพ
  Future<void> _sendImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final ref = FirebaseStorage.instance
        .ref('chat_media/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();

    await _firestore.collection('chats').doc(widget.chatId).collection('messages').add({
      'senderId': _auth.currentUser!.uid,
      'type': 'image',
      'url': url,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 🎥 ส่งวิดีโอ
  Future<void> _sendVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final ref = FirebaseStorage.instance
        .ref('chat_media/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.mp4');
    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();

    await _firestore.collection('chats').doc(widget.chatId).collection('messages').add({
      'senderId': _auth.currentUser!.uid,
      'type': 'video',
      'url': url,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

// 🎬 วิดีโอพรีวิว widget
class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        IconButton(
          icon: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 36,
          ),
          onPressed: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
        ),
      ],
    );
  }
}
