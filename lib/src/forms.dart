import 'package:flutter/material.dart';
import 'package:rental_domain/rental_domain.dart';

import 'data.dart';
import 'firebase_services.dart';

import 'dart:convert';

import 'package:image_picker/image_picker.dart';

Future<Record?> inputForm(
  BuildContext context, {
  required RentalStore store,
  required String title,
  required List<Field> fields,
  Record initial = const {},
  bool draft = false,
  String submit = 'Lưu',
  Future<void> Function(Record)? onSubmit,
}) => showModalBottomSheet<Record>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => DataForm(
    store: store,
    title: title,
    fields: fields,
    initial: initial,
    draft: draft,
    submit: submit,
    onSubmit: onSubmit,
  ),
);

class DataForm extends StatefulWidget {
  const DataForm({
    super.key,
    required this.store,
    required this.title,
    required this.fields,
    required this.initial,
    required this.draft,
    required this.submit,
    this.onSubmit,
  });
  final RentalStore store;
  final String title, submit;
  final List<Field> fields;
  final Record initial;
  final bool draft;
  final Future<void> Function(Record)? onSubmit;
  @override
  State<DataForm> createState() => _DataFormState();
}

class _DataFormState extends State<DataForm> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final drafts = MeterDrafts();
  bool savingDraft = false;
  bool submitting = false;
  String? error;
  String get account =>
      '${widget.store.baseUrl}|${widget.store.user?['user_id']}';
  @override
  void initState() {
    super.initState();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    for (final f in widget.fields) {
      controllers[f.key] = TextEditingController(
        text:
            '${widget.initial[f.key] ?? f.defaultValue ?? (f.kind == 'date'
                    ? date
                    : f.kind == 'month'
                    ? date.substring(0, 7)
                    : '')}',
      );
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Record values() => {
    for (final e in controllers.entries) e.key: e.value.text.trim(),
  };
  Future<void> local(bool restore) async {
    setState(() => savingDraft = true);
    try {
      if (restore) {
        final data = await drafts.read(account);
        if (!mounted) return;
        if (data == null) {
          setState(() => error = 'Chưa có bản nháp trên thiết bị.');
        } else {
          for (final e in data.entries) {
            controllers[e.key]?.text = '${e.value}';
          }
          setState(() => error = null);
        }
      } else {
        await drafts.save(account, values());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã lưu nháp trên điện thoại. Chưa gửi lên máy chủ.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Không lưu/đọc được bản nháp trên thiết bị.');
      }
    } finally {
      if (mounted) setState(() => savingDraft = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      16,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: Form(
        key: form,
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: field(f),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            if (widget.draft && drafts.supported)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: savingDraft ? null : () => local(false),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Lưu nháp trên máy'),
                  ),
                  TextButton(
                    onPressed: savingDraft ? null : () => local(true),
                    child: const Text('Khôi phục bản nháp'),
                  ),
                ],
              ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      final data = values();
                      setState(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        await widget.onSubmit?.call(data);
                        if (context.mounted) Navigator.pop(context, data);
                      } catch (e) {
                        if (mounted) setState(() => error = '$e');
                      } finally {
                        if (mounted) setState(() => submitting = false);
                      }
                    },
              child: Text(submitting ? 'Đang lưu…' : widget.submit),
            ),
          ],
        ),
      ),
    ),
  );
  Widget field(Field f) {
    final c = controllers[f.key]!;
    if (f.key == 'hinh_anh') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.text.isNotEmpty) const Text('Đã đính kèm ảnh từ thiết bị'),
          Wrap(
            spacing: 8,
            children: [
              for (final source in [ImageSource.gallery, ImageSource.camera])
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final photo = await ImagePicker().pickImage(
                        source: source,
                        maxWidth: 1200,
                        imageQuality: 65,
                      );
                      if (photo == null) return;
                      final bytes = await photo.readAsBytes();
                      if (bytes.length > 3 * 1024 * 1024) {
                        if (mounted) setState(() => error = 'Ảnh tối đa 3 MB');
                        return;
                      }
                      final png =
                          bytes.length > 8 &&
                          bytes[0] == 137 &&
                          bytes[1] == 80 &&
                          bytes[2] == 78 &&
                          bytes[3] == 71;
                      final jpeg =
                          bytes.length > 3 &&
                          bytes[0] == 255 &&
                          bytes[1] == 216 &&
                          bytes[2] == 255;
                      if (!png && !jpeg) {
                        if (mounted) {
                          setState(
                            () => error = 'Vui lòng chọn ảnh JPEG hoặc PNG.',
                          );
                        }
                        return;
                      }
                      c.text = widget.store.firebaseConnected
                          ? await FirebaseServices.upload(bytes, png: png)
                          : 'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';
                      if (mounted) setState(() => error = null);
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => error = 'Không truy cập được ảnh/camera. Kiểm tra quyền ứng dụng.',
                        );
                      }
                    }
                  },
                  icon: Icon(
                    source == ImageSource.gallery
                        ? Icons.photo_library_outlined
                        : Icons.camera_alt_outlined,
                  ),
                  label: Text(
                    source == ImageSource.gallery ? 'Chọn ảnh' : 'Chụp ảnh',
                  ),
                ),
              if (c.text.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => c.clear()),
                  child: const Text('Bỏ ảnh'),
                ),
            ],
          ),
        ],
      );
    }
    if (f.reference != null || f.options.isNotEmpty) {
      final options = <String, String>{};
      if (f.reference != null) {
        final module = moduleOf(f.reference!);
        for (final row in widget.store.rows(f.reference!)) {
          options['${row[module.id]}'] = widget.store.display(
            f.reference!,
            row[module.id],
          );
        }
      } else {
        for (final o in f.options) {
          options[o] = label(o);
        }
      }
      if (c.text.isNotEmpty && !options.containsKey(c.text)) {
        options[c.text] = label(c.text);
      }
      return DropdownButtonFormField<String>(
        key: ValueKey('${f.key}:${c.text}'),
        initialValue: options.containsKey(c.text) ? c.text : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: f.label),
        items: options.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => c.text = v ?? ''),
        validator: (v) => validateField(f, v),
      );
    }
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: f.label,
        suffixIcon: f.kind == 'date'
            ? IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(c.text) ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    c.text = picked.toIso8601String().substring(0, 10);
                  }
                },
              )
            : null,
      ),
      obscureText: f.kind == 'password',
      keyboardType: ['number', 'int'].contains(f.kind)
          ? TextInputType.number
          : f.kind == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      maxLines: f.kind == 'password'
          ? 1
          : ['mo_ta', 'noi_dung', 'ghi_chu', 'ly_do'].contains(f.key)
          ? 3
          : 1,
      validator: (v) => validateField(f, v),
    );
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> guarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã cập nhật dữ liệu.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade800),
      );
    }
  }
}

Future<void> editRecord(
  BuildContext context,
  RentalStore store,
  Module module, [
  Record? row,
]) async {
  if (store.demo) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Dữ liệu xem trước chỉ dùng để xem giao diện. Đăng nhập để thêm/sửa.',
        ),
      ),
    );
    return;
  }
  final fields = module.fields
      .where(
        (f) =>
            !(row != null && f.key == 'mat_khau') &&
            !(row?['trang_thai'] == 'DA_THUE' && f.key == 'trang_thai'),
      )
      .toList();
  final result = await inputForm(
    context,
    store: store,
    title: '${row == null ? 'Thêm' : 'Sửa'} ${module.label.toLowerCase()}',
    fields: fields,
    initial: row ?? {},
    draft: module.table == 'chi_so_dien_nuoc',
    onSubmit: (data) async {
      await store.save(module, data, row);
      if (module.table == 'chi_so_dien_nuoc') {
        await MeterDrafts().remove(
          '${store.baseUrl}|${store.user?['user_id']}',
        );
      }
    },
  );
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã lưu dữ liệu.')));
  }
}
