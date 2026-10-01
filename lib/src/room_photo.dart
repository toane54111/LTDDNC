import 'package:flutter/material.dart';
import 'package:rental_domain/rental_domain.dart';

import 'theme.dart';

class RoomPhoto extends StatelessWidget {
  const RoomPhoto({super.key, required this.row, this.height = 160});
  final Record row;
  final double height;
  @override
  Widget build(BuildContext context) {
    final asset = row['preview_photo'];
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: asset is String && asset.startsWith('assets/images/')
            ? Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder(),
              )
            : '${row['photo_url'] ?? ''}'.startsWith('https://')
            ? Image.network(
                row['photo_url'],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder(),
              )
            : placeholder(),
      ),
    );
  }

  Widget placeholder() => Container(
    color: const Color(0xFFF4F8FE),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.home_outlined, size: 42, color: brandBlue),
        SizedBox(height: 8),
        Text(
          'Chưa có ảnh phòng',
          style: TextStyle(fontSize: 12, color: Color(0xFF8796A8)),
        ),
      ],
    ),
  );
}
