import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';


class CreatePostPage extends StatefulWidget {
  final String type;
  const CreatePostPage({super.key, required this.type});

  static const routeName = '/createPost';

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage>
    with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  

  String _deliveryMethod = 'ส่งพัสดุ';
  int _selectedDays = 1;

  List<File> _imageFiles = [];
  List<File> _videoFiles = [];
  bool _isUploading = false;

  late final AnimationController _enterCtrl; // หน้าเข้ามาแบบนุ่ม ๆ
  late final AnimationController _glowCtrl;  // แสงวิ่งบนปุ่มโพสต์

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _glowCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _brandCtrl.dispose();
    _conditionCtrl.dispose();
    _sizeCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
    _locationCtrl.dispose();

  }

  // =====================  ระบบเดิม (ไม่แตะ)  =====================

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _imageFiles = picked.map((x) => File(x.path)).toList();
      });
    }
  }

  Future<void> _pickVideo() async {
  final picked = await _picker.pickVideo(source: ImageSource.gallery);
  if (picked != null) {
    setState(() {
      if (_videoFiles.length < 3) {
        _videoFiles.add(File(picked.path));
      } else {
        _toast('อัพโหลดได้สูงสุด 3 วิดีโอเท่านั้น 🎥');
      }
    });
  }
}


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

  Future<void> _createPost() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      _toast('กรุณากรอกชื่อและรายละเอียดโพสต์ 💬');
      return;
    }

    if (widget.type == 'donate' && _quantityCtrl.text.trim().isEmpty) {
      _toast('กรุณาระบุจำนวนสิ่งของที่จะบริจาค ✨');
      return;
    }

    if ((_deliveryMethod == 'นัดรับ' || _deliveryMethod == 'ทั้งสองทาง') &&
    _locationCtrl.text.trim().isEmpty) {
      _toast('กรุณากรอกสถานที่นัดรับ 🏠');
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
        'pickupLocation': _locationCtrl.text.trim(),
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

      _toast('โพสต์สำเร็จแล้ว 💗');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // =====================  UI  =====================

  @override
  Widget build(BuildContext context) {
    // พื้นหลังตามประเภทโพสต์
    final bgGrad = widget.type == 'donate'
        ? [const Color(0xFFFFF7CC), const Color(0xFFFFE59A)]
        : widget.type == 'request'
            ? [const Color(0xFFFFE6F0), const Color(0xFFFFC7DF)]
            : [const Color(0xFFE3F4FF), const Color(0xFFCDE7FF)];

    final accent = widget.type == 'donate'
        ? const Color(0xFFFFC83C)
        : widget.type == 'request'
            ? const Color(0xFFFF8FB1)
            : const Color(0xFF8CC7FF);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.08),
        title: const Text(
          'สร้างโพสต์ใหม่',
          style: TextStyle(
            color: Color(0xFF30343F),
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ไล่เฉด + วงกลมเบลอๆ ลอย ๆ
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: bgGrad,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // วงกลมไฟนุ่ม ๆ เพิ่มมิติ
          Positioned(
            top: -60,
            right: -40,
            child: _blurBall(color: accent.withOpacity(.35), size: 220),
          ),
          Positioned(
            bottom: -50,
            left: -40,
            child: _blurBall(color: Colors.white.withOpacity(.55), size: 260),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.white.withOpacity(0.08)),
          ),

          // เนื้อหา
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 110, 18, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fadeSlide(
                  delay: .0,
                  child: _headerBadge(),
                ),
                const SizedBox(height: 16),

                _fadeSlide(
                  delay: .05,
                  child: _glassCard(
                    child: Column(
                      children: [
                        _input('ชื่อสิ่งของ', _titleCtrl),
                        const SizedBox(height: 10),
                        _input('รายละเอียด', _descCtrl, maxLines: 3),
                        const SizedBox(height: 10),
                        _input('ยี่ห้อ', _brandCtrl),
                        const SizedBox(height: 10),
                        _input('สภาพ (ใหม่ / มือสอง)', _conditionCtrl),
                        const SizedBox(height: 10),
                        _input('ขนาด', _sizeCtrl),
                        if (widget.type == 'donate') ...[
                          const SizedBox(height: 10),
                          _input('จำนวนสิ่งของ', _quantityCtrl,
                              keyboardType: TextInputType.number),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _fadeSlide(
                  delay: .1,
                  child: _glassCard(
                    child: Column(
                      children: [
                        _dropdown<String>(
                          label: 'วิธีรับของ',
                          value: _deliveryMethod,
                          items: const [
                            DropdownMenuItem(value: 'ส่งพัสดุ', child: Text('ส่งพัสดุ 📦')),
                            DropdownMenuItem(value: 'นัดรับ', child: Text('นัดรับ 🤝')),
                            DropdownMenuItem(value: 'ทั้งสองทาง', child: Text('ทั้งสองทาง 🩷')),
                          ],
                          onChanged: (v) => setState(() => _deliveryMethod = v!),
                        ),

                        // 🏠 ถ้าเลือก นัดรับ หรือ ทั้งสองทาง → โชว์ช่องกรอกสถานที่
                        if (_deliveryMethod == 'นัดรับ' || _deliveryMethod == 'ทั้งสองทาง') ...[
                          const SizedBox(height: 10),
                          _input('สถานที่นัดรับ', _locationCtrl),
                        ],
                        const SizedBox(height: 10),
                        _dropdown<int>(
                          label: 'วันหมดอายุโพสต์',
                          value: _selectedDays,
                          items: List.generate(
                            7,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1} วัน'),
                            ),
                          ),
                          onChanged: (v) => setState(() => _selectedDays = v!),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _fadeSlide(
                  delay: .15,
                  child: _glassCard(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _pickerBtn(
                          icon: Icons.photo_rounded,
                          text: 'เลือกรูปภาพ',
                          color: accent,
                          onTap: _pickImages,
                        ),
                        _pickerBtn(
                          icon: Icons.videocam_rounded,
                          text: 'เพิ่มวิดีโอ',
                          color: accent,
                          onTap: _pickVideo,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_imageFiles.isNotEmpty) ...[
                  const SizedBox(height: 0),
                  _fadeSlide(
                    delay: .2,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,          // แสดง 3 ช่องต่อแถว
                        crossAxisSpacing: 8,        // ระยะห่างแนวนอน
                        mainAxisSpacing: 8,         // ระยะห่างแนวตั้ง
                      ),
                      itemCount: _imageFiles.length,
                      itemBuilder: (context, index) {
                        final file = _imageFiles[index];
                        return Stack(
                          children: [
                            // ✅ แสดงรูป
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                file,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),

                            // ✅ ปุ่มกากบาท (ลบรูป)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _imageFiles.removeAt(index));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],

                if (_videoFiles.isNotEmpty)
                _fadeSlide(
                  delay: .25,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _videoFiles.map((v) {
                      return VideoPlayerWidget(
                        videoFile: v,
                        onRemove: () {
                          setState(() => _videoFiles.remove(v));
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),


          // ปุ่มโพสต์แบบ Glow Motion
          Positioned(
            left: 20,
            right: 20,
            bottom: 26,
            child: _postGlowButton(accent),
          ),
        ],
      ),
    );
  }

  // --------- Widgets ย่อย (สวย + ใช้งานง่าย) ---------

  Widget _blurBall({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: color, blurRadius: 80, spreadRadius: 20),
      ]),
    );
  }

  Widget _headerBadge() {
  final info = switch (widget.type) {
    'donate' => ('🎁', 'โพสต์บริจาคสิ่งของ'),
    'request' => ('🙏', 'ขอรับบริจาคสิ่งของ'),
    _ => ('🔄', 'แลกเปลี่ยนสิ่งของ'),
  };

  return Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.$1, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            info.$2,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF2E2E2E),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (hasFocus)
                  BoxShadow(
                    color: Colors.black.withOpacity(.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
              ],
              border: Border.all(
                  color: hasFocus
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFFF1F5F9)),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: label,
                hintStyle:
                    const TextStyle(color: Color(0xFF9AA4B2), fontSize: 14.5),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _pickerBtn({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
      ),
    );
  }

  // ปุ่มโพสต์พร้อมเอฟเฟกต์ Glow Motion
  Widget _postGlowButton(Color accent) {
    return _fadeSlide(
      delay: .18,
      child: GestureDetector(
        onTap: _isUploading ? null : _createPost,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // แสงฐาน
            Container(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                gradient: LinearGradient(
                  colors: [accent, accent.withOpacity(.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(.45),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
            // แสงวิ่ง
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (context, _) {
                final t = _glowCtrl.value; // 0..1
                final dx = lerpDouble(-130, 130, t)!;
                return IgnorePointer(
                  child: Transform.translate(
                    offset: Offset(dx, 0),
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(48),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.35),
                            Colors.white.withOpacity(0.0),
                          ],
                          stops: const [0.35, 0.5, 0.65],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // เนื้อปุ่ม
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _isUploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.favorite_rounded,
                            color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'โพสต์เลย 💗',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                            fontSize: 16.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Fade + Slide (ขึ้น) แบบนุ่ม ๆ ใช้ซ้ำได้
  Widget _fadeSlide({required double delay, required Widget child}) {
    final curved = CurvedAnimation(
      parent: _enterCtrl,
      curve: Interval(delay, 1, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final dy = 18 * (1 - curved.value); // เลื่อนขึ้นตอนโผล่
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }
}

// 🎬 วิดีโอพรีวิว (ไม่แตะระบบ)
class VideoPlayerWidget extends StatefulWidget {
  final File videoFile;
  final VoidCallback onRemove;

  const VideoPlayerWidget({
    super.key,
    required this.videoFile,
    required this.onRemove,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true); // ให้เล่นวน
        _controller.setVolume(0);     // ปิดเสียงตอน preview
        _controller.play();           // เล่นอัตโนมัติ
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🎞 พรีวิววิดีโอ
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 120,
            height: 120,
            child: _controller.value.isInitialized
                ? VideoPlayer(_controller)
                : const Center(child: CircularProgressIndicator()),
          ),
        ),

        // ▶️ สัญลักษณ์บอกว่าเป็นวิดีโอ
        const Positioned(
          bottom: 6,
          right: 6,
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 26,
            shadows: [
              Shadow(blurRadius: 8, color: Colors.black45),
            ],
          ),
        ),

        // ❌ ปุ่มลบวิดีโอ
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

  
