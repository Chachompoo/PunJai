import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class EditPostPage extends StatefulWidget {
  final Map<String, dynamic> postData;
  const EditPostPage({super.key, required this.postData});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();

  String _deliveryMethod = 'ส่งพัสดุ';
  int _selectedDays = 1;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final data = widget.postData;
    _titleCtrl.text = data['title'] ?? '';
    _descCtrl.text = data['description'] ?? '';
    _brandCtrl.text = data['brand'] ?? '';
    _conditionCtrl.text = data['condition'] ?? '';
    _sizeCtrl.text = data['size'] ?? '';
    _deliveryMethod = data['deliveryMethod'] ?? 'ส่งพัสดุ';
    _quantityCtrl.text = data['quantity']?.toString() ?? '';
  }

  // 💾 อัปเดตโพสต์
  Future<void> _updatePost() async {
    setState(() => _isUpdating = true);
    try {
      final postId = widget.postData['postId'];
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'condition': _conditionCtrl.text.trim(),
        'size': _sizeCtrl.text.trim(),
        'deliveryMethod': _deliveryMethod,
        'quantity': int.tryParse(_quantityCtrl.text) ?? 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ แก้ไขโพสต์เรียบร้อยแล้ว')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // ❌ ลบโพสต์
  Future<void> _deletePost() async {
    final postId = widget.postData['postId'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบโพสต์นี้หรือไม่? 🗑️'),
        content: const Text('การลบนี้ไม่สามารถย้อนกลับได้!'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('โพสต์ถูกลบแล้ว 🗑️')));
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.postData;
    final type = data['type'] ?? 'donate';

    final themeColor = type == 'donate'
        ? const Color(0xFFFFF7CC)
        : type == 'request'
            ? const Color(0xFFFFE6F0)
            : const Color(0xFFE3F4FF);

    final accentColor = type == 'donate'
        ? const Color(0xFFFFC83C)
        : type == 'request'
            ? const Color(0xFFFF8FB1)
            : const Color(0xFF8CC7FF);

    final images = List<String>.from(data['images'] ?? []);
    final videos = List<String>.from(data['videos'] ?? []);

    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: const Text(
          'แก้ไขโพสต์ ✏️',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (images.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: images
                    .map((url) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(url,
                              width: 100, height: 100, fit: BoxFit.cover),
                        ))
                    .toList(),
              ),
            if (videos.isNotEmpty) ...[
              const SizedBox(height: 12),
              VideoPlayerWidget(videoUrl: videos.first),
            ],

            const SizedBox(height: 16),
            _buildInputField('ชื่อสิ่งของ', _titleCtrl),
            const SizedBox(height: 10),
            _buildInputField('รายละเอียด', _descCtrl, maxLines: 3),
            const SizedBox(height: 10),
            _buildInputField('ยี่ห้อ', _brandCtrl),
            const SizedBox(height: 10),
            _buildInputField('สภาพ (ใหม่ / มือสอง)', _conditionCtrl),
            const SizedBox(height: 10),
            _buildInputField('ขนาด', _sizeCtrl),

            if (type == 'donate') ...[
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
            const SizedBox(height: 30),

            Center(
              child: GestureDetector(
                onTap: _isUpdating ? null : _updatePost,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 80, vertical: 14),
                  decoration: BoxDecoration(
                    color:
                        _isUpdating ? Colors.grey.shade400 : accentColor,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: _isUpdating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'บันทึกการแก้ไข ✨',
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
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: _deletePost,
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'ลบโพสต์นี้',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
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
