import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

class CreatePostPage extends StatefulWidget {
  final String type;
  const CreatePostPage({super.key, required this.type});

  static const routeName = '/createPost';

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();

  String _deliveryMethod = 'ส่งพัสดุ';
  int _selectedDays = 1;

  List<File> _imageFiles = [];
  List<File> _videoFiles = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
  }

  // 📸 เลือกรูปภาพ
  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _imageFiles = picked.map((x) => File(x.path)).toList();
      });
    }
  }

  // 🎥 เลือกวิดีโอ
  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _videoFiles = [File(picked.path)];
      });
    }
  }

  // 📤 อัปโหลดไฟล์ไป Firebase Storage
  Future<List<String>> _uploadFiles(List<File> files, String folder) async {
    List<String> urls = [];
    for (final file in files) {
      final id = const Uuid().v4();
      final ref = FirebaseStorage.instance.ref().child('$folder/$id');
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  // 💾 บันทึกโพสต์
  Future<void> _createPost() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อและรายละเอียดโพสต์ 💬')),
      );
      return;
    }

    if (widget.type == 'donate' && _quantityCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาระบุจำนวนสิ่งของที่จะบริจาค ✨')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final imageUrls = await _uploadFiles(_imageFiles, 'post_images');
      final videoUrls = await _uploadFiles(_videoFiles, 'post_videos');

      final now = Timestamp.now();
      final expiry =
          Timestamp.fromDate(DateTime.now().add(Duration(days: _selectedDays)));
      final postId = const Uuid().v4();

      final quantity =
          widget.type == 'donate' ? int.tryParse(_quantityCtrl.text) ?? 1 : 0;

      final postData = {
        'postId': postId,
        'ownerId': user.uid,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'condition': _conditionCtrl.text.trim(),
        'size': _sizeCtrl.text.trim(),
        'deliveryMethod': _deliveryMethod,
        'type': widget.type,
        'quantity': quantity,
        'quantityLeft': quantity,
        'images': imageUrls,
        'videos': videoUrls,
        'createdAt': now,
        'expiryDate': expiry,
        'isExpired': false,
        'status': 'active',
        'viewCount': 0,
        'postColorTheme': widget.type == 'donate'
            ? 'yellow'
            : widget.type == 'request'
                ? 'pink'
                : 'blue',
      };

      await _firestore.collection('posts').doc(postId).set(postData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โพสต์สำเร็จแล้ว 💛')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.type == 'donate'
        ? const Color(0xFFFFF7CC)
        : widget.type == 'request'
            ? const Color(0xFFFFE6F0)
            : const Color(0xFFE3F4FF);

    final accentColor = widget.type == 'donate'
        ? const Color(0xFFFFC83C)
        : widget.type == 'request'
            ? const Color(0xFFFF8FB1)
            : const Color(0xFF8CC7FF);

    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        title: const Text(
          'สร้างโพสต์ใหม่',
          style: TextStyle(
            color: Color(0xFF393E46),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField('ชื่อสิ่งของ', _titleCtrl),
            const SizedBox(height: 10),
            _buildInputField('รายละเอียด', _descCtrl, maxLines: 3),
            const SizedBox(height: 10),
            _buildInputField('ยี่ห้อ', _brandCtrl),
            const SizedBox(height: 10),
            _buildInputField('สภาพ (ใหม่ / มือสอง)', _conditionCtrl),
            const SizedBox(height: 10),
            _buildInputField('ขนาด', _sizeCtrl),

            if (widget.type == 'donate') ...[
              const SizedBox(height: 10),
              _buildInputField('จำนวนสิ่งของ', _quantityCtrl,
                  keyboardType: TextInputType.number),
            ],

            const SizedBox(height: 10),
            _buildDropdown<String>(
              label: 'วิธีรับของ',
              value: _deliveryMethod,
              items: const [
                DropdownMenuItem(value: 'ส่งพัสดุ', child: Text('ส่งพัสดุ 📦')),
                DropdownMenuItem(value: 'นัดรับ', child: Text('นัดรับ 🤝')),
              ],
              onChanged: (val) => setState(() => _deliveryMethod = val!),
            ),
            const SizedBox(height: 12),
            _buildDropdown<int>(
              label: 'วันหมดอายุโพสต์',
              value: _selectedDays,
              items: List.generate(
                7,
                (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} วัน')),
              ),
              onChanged: (val) => setState(() => _selectedDays = val!),
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                    Icons.photo, 'เลือกรูปภาพ', accentColor, _pickImages),
                _buildActionButton(
                    Icons.videocam, 'เพิ่มวิดีโอ', accentColor, _pickVideo),
              ],
            ),

            if (_imageFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _imageFiles
                    .map((f) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(f,
                              width: 100, height: 100, fit: BoxFit.cover),
                        ))
                    .toList(),
              ),
            ],

            if (_videoFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: VideoPlayerWidget(videoFile: _videoFiles.first),
              ),

            const SizedBox(height: 30),
            Center(
              child: GestureDetector(
                onTap: _isUploading ? null : _createPost,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 80, vertical: 14),
                  decoration: BoxDecoration(
                    color: _isUploading
                        ? Colors.grey.shade400
                        : accentColor,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'โพสต์เลย 💗',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎀 กล่อง input
  Widget _buildInputField(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // 🩷 dropdown
  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        value: value,
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  // 📸 ปุ่มเลือกรูป / วิดีโอ
  Widget _buildActionButton(
      IconData icon, String text, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// 🎬 วิดีโอพรีวิว
class VideoPlayerWidget extends StatefulWidget {
  final File videoFile;
  const VideoPlayerWidget({super.key, required this.videoFile});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  size: 60,
                  color: Colors.white,
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
          )
        : const Center(child: CircularProgressIndicator());
  }
}
