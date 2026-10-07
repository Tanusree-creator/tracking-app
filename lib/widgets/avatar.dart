import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Round profile picture; falls back to the person's initials.
class UserAvatar extends StatelessWidget {
  final Uint8List? photo;
  final String initials;
  final double radius;
  final Color? ring;
  const UserAvatar({super.key, this.photo, required this.initials, this.radius = 24, this.ring});

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent,
      backgroundImage: photo == null ? null : MemoryImage(photo!),
      child: photo == null
          ? Text(initials, style: TextStyle(fontSize: radius * .7, fontWeight: FontWeight.w700, color: Colors.white))
          : null,
    );
    if (ring == null) return avatar;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring!, width: 2.5)),
      child: avatar,
    );
  }
}
