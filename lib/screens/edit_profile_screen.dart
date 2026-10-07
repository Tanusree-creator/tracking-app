import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/access_provider.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../l10n/l10n.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: context.read<AccessProvider>().me!.name);
  final _phone = TextEditingController();
  late final _title = TextEditingController(text: context.read<AccessProvider>().me!.title);
  Uint8List? _photo; // what is shown
  String? _photoB64; // null = unchanged, '' = removed, else the new photo
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _photo = context.read<AccessProvider>().myAvatar;
    Api.myProfile().then((p) {
      if (!mounted) return;
      setState(() {
        _phone.text = (p['phone'] ?? '') as String;
        _title.text = (p['role_title'] ?? _title.text) as String;
        _loading = false;
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    });
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final shot = await ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      setState(() {
        _photo = bytes;
        _photoB64 = base64Encode(bytes);
      });
    } catch (_) {
      if (mounted) snack(context, 'Could not open the photo. Allow camera or photo access and try again.');
    }
  }

  void _photoSheet() => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('Take a photo'.tr),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Choose from gallery'.tr),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.red),
                title: Text('Remove photo'.tr, style: TextStyle(color: AppColors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _photo = null;
                    _photoB64 = '';
                  });
                },
              ),
          ]),
        ),
      );

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AccessProvider>().updateProfile(_name.text, _phone.text, _title.text, _photoB64);
      if (!mounted) return;
      snack(context, 'Profile updated');
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AccessProvider>().me!;
    return Scaffold(
      appBar: AppBar(title: Text('Edit profile'.tr)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
              child: Form(
                key: _key,
                child: Column(children: [
                  GestureDetector(
                    onTap: _photoSheet,
                    child: Stack(children: [
                      UserAvatar(photo: _photo, initials: me.initials, radius: 56, ring: AppColors.accent),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                          child: const Icon(Icons.photo_camera, size: 18, color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                  TextButton(onPressed: _photoSheet, child: Text((_photo == null ? 'Add profile photo' : 'Change photo').tr)),
                  const SizedBox(height: Sp.m),
                  GlowTextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: 'Full name'.tr, prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: Sp.l),
                  GlowTextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: 'Position'.tr, hintText: 'e.g. Field Executive'.tr, prefixIcon: Icon(Icons.work_outline)),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: Sp.l),
                  GlowTextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: 'Phone'.tr, prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: Sp.l),
                  GlowTextField(
                    initialValue: me.email,
                    enabled: false,
                    decoration: InputDecoration(labelText: 'Email (set by admin)'.tr, prefixIcon: Icon(Icons.mail_outline)),
                  ),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: Sp.m), child: Text(_error!.tr, style: const TextStyle(color: AppColors.red))),
                  const SizedBox(height: Sp.xl),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Save changes'.tr),
                  ),
                ]),
              ),
            ),
    );
  }
}
