import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/email_service.dart';

class AdminUserDetailPage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const AdminUserDetailPage({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

// 🎀 ยืนยันสมาชิก
Future<void> _approveUser() async {
  setState(() => _isLoading = true);
  await _firestore.collection('users').doc(widget.userId).update({
    'status': 'approved',
    'rejectReason': null,
  });

  // 🔔 ส่งอีเมลแจ้งผล
  await EmailService.sendVerificationResultEmail(
    email: widget.userData['email'],
    name: widget.userData['firstname'] ?? widget.userData['username'] ?? '',
    isApproved: true, // หรือ false
    rejectReason: _reasonController.text.trim(),
  );


  setState(() => _isLoading = false);
  if (mounted) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ ยืนยันสมาชิกสำเร็จ')),
    );
  }
}

// 🎀 ปฏิเสธสมาชิก
Future<void> _rejectUser() async {
  if (_reasonController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กรุณากรอกเหตุผลการปฏิเสธ')),
    );
    return;
  }

  setState(() => _isLoading = true);
  await _firestore.collection('users').doc(widget.userId).update({
    'status': 'rejected',
    'rejectReason': _reasonController.text.trim(),
  });

  // 🔔 ส่งอีเมลแจ้งผล
  await EmailService.sendVerificationResultEmail(
    email: widget.userData['email'],
    name: widget.userData['firstname'] ?? widget.userData['username'] ?? '',
    isApproved: false,
    rejectReason: _reasonController.text.trim(),
  );

  setState(() => _isLoading = false);
  if (mounted) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ ปฏิเสธสมาชิกเรียบร้อย')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    final user = widget.userData;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF8FB1),
        title: const Text('รายละเอียดผู้สมัคร', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFFFF7FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8FB1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ชื่อ + อีเมล
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(
                          user['profileImage'] ??
                              'https://cdn-icons-png.flaticon.com/512/847/847969.png',
                        ),
                        radius: 35,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (user['firstname'] != null && user['firstname'].toString().trim().isNotEmpty)
                                  ? '${user['firstname']} ${user['lastname'] ?? ''}'
                                  : (user['username'] ?? 'ไม่ระบุชื่อ'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(user['email'] ?? '',
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 🩷 ข้อมูลผู้สมัคร
                    const Text('ข้อมูลผู้สมัคร', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('อีเมล', user['email']),
                            _buildInfoRow('ชื่อจริง', user['firstname']),
                            _buildInfoRow('นามสกุล', user['lastname']),
                            _buildInfoRow('เบอร์โทรศัพท์', user['phone']),
                          ],
                        ),
                      ),
                    ),


                  // รูปภาพบัตรประชาชน
                  const Text('📄 บัตรประชาชนที่อัปโหลด',

                  
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildImageTile('ด้านหน้า', user['idCardFront']),
                  _buildImageTile('ด้านหลัง', user['idCardBack']),
                  _buildImageTile('รูปคู่บัตร', user['selfieWithId']),

                  const SizedBox(height: 30),
                  const Divider(),

                  // ปุ่มอนุมัติ/ปฏิเสธ
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text('ยืนยัน'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF92D56F),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: _approveUser,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.cancel),
                          label: const Text('ปฏิเสธ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB84C),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () {
                            _showRejectDialog(context);
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildImageTile(String title, String? url) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              padding: const EdgeInsets.all(12),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          if (url != null && url.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(url, fit: BoxFit.cover),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('ไม่มีรูปภาพ', style: TextStyle(color: Colors.grey)),
            )
        ],
      ),
    );
  }
  Widget _buildInfoRow(String label, String? value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            value?.isNotEmpty == true ? value! : '-',
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    ),
  );
}


  void _showRejectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ปฏิเสธการสมัคร'),
          content: TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'กรอกเหตุผลการปฏิเสธ',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8FB1)),
              onPressed: () {
                Navigator.pop(context);
                _rejectUser();
              },
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );
  }
}
