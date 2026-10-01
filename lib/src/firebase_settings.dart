import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'data.dart';
import 'firebase_services.dart';
import 'forms.dart';

Future<String?> pickCloudPhoto(RentalStore store) async {
  store.writable();
  if (!store.firebaseConnected) await store.connectFirebase();
  if (!store.firebaseConnected) {
    throw ApiException('Firebase chưa được kết nối.');
  }
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 75,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final png =
      bytes.length > 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71;
  final jpeg =
      bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255;
  if (!png && !jpeg) throw ApiException('Vui lòng chọn ảnh JPEG hoặc PNG.');
  return FirebaseServices.upload(bytes, png: png);
}

class FirebaseSettings extends StatelessWidget {
  const FirebaseSettings({super.key, required this.store});
  final RentalStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Column(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Kết nối Firebase'),
          subtitle: Text(
            store.firebaseConnected
                ? 'Đã kết nối'
                : store.firebaseError ??
                      'Kết nối để dùng chat, ảnh và thông báo',
          ),
          onTap: () => guarded(context, () async {
            store.writable();
            if (!FirebaseServices.ready) {
              throw ApiException(
                'Chưa cấu hình Firebase. Xem tài liệu thiết lập của project.',
              );
            }
            await store.connectFirebase();
            if (!store.firebaseConnected) {
              throw ApiException(store.firebaseError!);
            }
          }),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Bật thông báo trên điện thoại'),
          onTap: () => guarded(context, () async {
            await store.enablePush();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã bật thông báo trên thiết bị.'),
                ),
              );
            }
          }),
        ),
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('Liên kết tài khoản Google'),
          subtitle: const Text(
            'Dùng Google có cùng email với tài khoản nhà trọ',
          ),
          onTap: () => guarded(context, () async {
            await store.linkGoogle();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã liên kết Google.')),
              );
            }
          }),
        ),
        ListTile(
          leading: const Icon(Icons.add_a_photo_outlined),
          title: const Text('Đổi ảnh đại diện'),
          onTap: () => guarded(context, () async {
            final url = await pickCloudPhoto(store);
            if (url == null) return;
            await store.request('PUT', 'firebase/avatar', {'url': url});
            await store.connectFirebase();
          }),
        ),
      ],
    ),
  );
}
