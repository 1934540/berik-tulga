import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/components.dart';
import '../../auth/data/account_controller.dart';
import '../domain/user_profile.dart';

class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, this.edit = false});
  final bool edit;
  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, username;
  String? gender, birth, avatar;
  Uint8List? photo;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = ref.read(accountProvider).profile;
    name = TextEditingController(text: p?.name);
    username = TextEditingController(text: p?.username);
    gender = p?.gender;
    birth = p?.birthDate;
    avatar = p?.avatarUrl;
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => photo = bytes);
      }
    } catch (_) {
      if (mounted) showNotice(context, 'saveError');
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final account = ref.read(accountProvider.notifier);
    try {
      if (photo != null && account.client != null) {
        final path = '${account.userId}/avatar.jpg';
        await account.client!.storage
            .from('avatars')
            .uploadBinary(
              path,
              photo!,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );
        avatar = account.client!.storage.from('avatars').getPublicUrl(path);
      }
      await account.saveProfile(
        UserProfile(
          id: account.userId,
          name: name.text.trim(),
          username: username.text.trim().toLowerCase(),
          avatarUrl: avatar,
          teamId: ref.read(accountProvider).profile?.teamId,
          gender: gender,
          birthDate: birth,
        ),
      );
      if (mounted && widget.edit) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = 'saveError');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.edit ? AppBar(title: Text(context.t('editProfile'))) : null,
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            PageHeading(context.t('profileSetup'), context.t('city')),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.raised,
                    backgroundImage: photo != null
                        ? MemoryImage(photo!)
                        : avatar != null
                        ? NetworkImage(avatar!)
                        : null,
                    child: photo == null && avatar == null
                        ? const Icon(
                            Icons.person_outline_rounded,
                            size: 36,
                            color: AppColors.flame,
                          )
                        : null,
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : pick,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(context.t('photo')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: name,
              maxLength: 60,
              decoration: InputDecoration(labelText: context.t('name')),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? context.t('required') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: username,
              decoration: InputDecoration(
                labelText: context.t('username'),
                helperText: context.t('usernameHint'),
              ),
              validator: (v) => RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(v ?? '')
                  ? null
                  : context.t('usernameHint'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: gender ?? 'unspecified',
              decoration: InputDecoration(labelText: context.t('gender')),
              items: ['unspecified', 'male', 'female']
                  .map(
                    (v) =>
                        DropdownMenuItem(value: v, child: Text(context.t(v))),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => gender = v == 'unspecified' ? null : v,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                        initialDate: birth == null
                            ? DateTime(2000)
                            : DateTime.parse(birth!),
                      );
                      if (date != null && mounted) {
                        setState(
                          () => birth = date.toIso8601String().substring(0, 10),
                        );
                      }
                    },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(birth ?? context.t('birthDate')),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  context.t(error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: busy ? null : save,
              child: busy
                  ? const CircularProgressIndicator()
                  : Text(context.t('save')),
            ),
          ],
        ),
      ),
    ),
  );
}
