import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:convert';

import 'export.dart';

import 'package:rental_domain/rental_domain.dart';

import 'data.dart';
import 'forms.dart';
import 'theme.dart';
import 'room_photo.dart';

void openDetail(
  BuildContext context,
  RentalStore store,
  Module module,
  Record record,
) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => DetailScreen(store: store, module: module, record: record),
  ),
);

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.store,
    required this.module,
    required this.record,
  });
  final RentalStore store;
  final Module module;
  final Record record;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool busy = false;
  RentalStore get s => widget.store;
  Module get m => widget.module;
  Record get row =>
      s
          .rows(m.table)
          .where((r) => '${r[m.id]}' == '${widget.record[m.id]}')
          .firstOrNull ??
      widget.record;
  Future<void> act(
    String action, {
    List<Field> fields = const [],
    Record initial = const {},
    String? message,
  }) async {
    if (busy) return;
    Record data = initial;
    if (fields.isNotEmpty) {
      final result = await inputForm(
        context,
        store: s,
        title: 'Xác nhận thao tác',
        fields: fields,
        initial: initial,
      );
      if (result == null) return;
      data = result;
    } else if (!await confirm(
      context,
      'Xác nhận',
      message ?? 'Bạn muốn thực hiện thao tác này?',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await guarded(context, () => s.action(m, row, action, data));
    if (mounted) setState(() => busy = false);
  }

  String value(String key, dynamic value) {
    if (value == null) return '—';
    final field = m.fields.where((f) => f.key == key).firstOrNull;
    if (field?.reference != null) return s.display(field!.reference!, value);
    if ([
      'gia_thue',
      'gia_thue_mmoi',
      'tien_coc',
      'tong_tien',
      'tien_phong',
      'tien_dien',
      'tien_nuoc',
      'phi_dich_vu',
      'so_tien',
      'don_gia',
      'con_no',
      'da_thanh_toan',
    ].contains(key)) {
      return money(value);
    }
    if (key == 'da_doc') return '$value' == '1' ? 'Có' : 'Chưa';
    return label('$value');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text('${m.label} #${row[m.id]}'),
        actions: [
          if (s.owner && m.editable)
            IconButton(
              tooltip: 'Chỉnh sửa',
              onPressed: busy ? null : () => editRecord(context, s, m, row),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (m.table == 'phong_tro') ...[
                RoomPhoto(row: row, height: 260),
                const SizedBox(height: 20),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.table != 'phong_tro')
                        Icon(moduleIcon(m.table), size: 32, color: brandBlue),
                      const SizedBox(height: 16),
                      Text(
                        m.title == m.id
                            ? '${m.label} #${row[m.id]}'
                            : '${row[m.title] ?? m.label}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (row['trang_thai'] != null)
                        StatusBadge('${row['trang_thai']}'),
                      const SizedBox(height: 16),
                      for (final e in row.entries.where(
                        (e) =>
                            e.key != m.id &&
                            ![
                              'mat_khau',
                              'so_lan_sai_mat_khau',
                              'trang_thai',
                              'hinh_anh',
                              'preview_photo',
                            ].contains(e.key),
                      ))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  m.fields
                                          .where((f) => f.key == e.key)
                                          .firstOrNull
                                          ?.label ??
                                      label(e.key),
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SelectableText(
                                  value(e.key, e.value),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if ('${row['hinh_anh'] ?? ''}'.startsWith('data:image/'))
                        Image.memory(
                          base64Decode('${row['hinh_anh']}'.split(',').last),
                          height: 240,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Text('Không hiển thị được ảnh'),
                        ),
                      if ('${row['hinh_anh'] ?? ''}'.startsWith('https://'))
                        Image.network(
                          row['hinh_anh'],
                          height: 240,
                          errorBuilder: (_, _, _) =>
                              const Text('Không tải được ảnh'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (s.demo)
                const Text(
                  'Chế độ xem trước • Thao tác ghi dữ liệu bị tắt.',
                  style: TextStyle(color: Colors.black54),
                ),
              if (!s.demo)
                Wrap(spacing: 10, runSpacing: 12, children: actions()),
              if (m.table == 'hoa_don') ...[
                const SizedBox(height: 28),
                Text(
                  'Lịch sử thanh toán',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final tx
                    in s
                        .rows('giao_dich')
                        .where((t) => '${t['hoa_don_id']}' == '${row[m.id]}'))
                  Card(
                    child: ListTile(
                      title: Text(money(tx['so_tien'])),
                      subtitle: Text(
                        '${label('${tx['phuong_thuc']}')} · ${label('${tx['trang_thaigd']}')}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          openDetail(context, s, moduleOf('giao_dich'), tx),
                    ),
                  ),
              ],
              if (m.table == 'phong_tro') ...[
                const SizedBox(height: 28),
                Text(
                  'Thông tin trong phòng',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final table in [
                  'tai_san_phong_tro',
                  'thanh_vien_phong_tro',
                  'hop_dong',
                ]) ...[
                  const SizedBox(height: 14),
                  Text(
                    moduleOf(table).label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final item
                      in s
                          .rows(table)
                          .where((r) => '${r['phong_id']}' == '${row[m.id]}'))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item[moduleOf(table).title]}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          openDetail(context, s, moduleOf(table), item),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
  Widget button(
    String title,
    VoidCallback action, {
    IconData icon = Icons.check,
  }) => FilledButton.tonalIcon(
    onPressed: busy ? null : action,
    icon: Icon(icon),
    label: Text(title),
  );
  List<Widget> actions() {
    final widgets = <Widget>[];
    if (['hoa_don', 'giao_dich', 'hop_dong'].contains(m.table)) {
      widgets.add(
        button(
          'In / Lưu PDF',
          () => guarded(
            context,
            () => printRecord('${m.label} #${row[m.id]}', {
              for (final e in row.entries)
                m.fields.where((f) => f.key == e.key).firstOrNull?.label ??
                    label(e.key): value(
                  e.key,
                  e.value,
                ),
            }),
          ),
          icon: Icons.picture_as_pdf_outlined,
        ),
      );
    }
    if (m.table == 'hoa_don' && integer(row['con_no']) > 0) {
      widgets.add(
        button(
          s.owner ? 'Ghi nhận thanh toán' : 'Thanh toán',
          () => act(
            'pay',
            fields: [
              const Field('so_tien', 'Số tiền (đ)', kind: 'int'),
              Field(
                'phuong_thuc',
                'Phương thức',
                options: [
                  if (s.owner) 'TIEN_MAT',
                  'CHUYEN_KHOAN',
                  if (s.onlineDemo) 'ONLINE',
                ],
              ),
              const Field('ghi_chu', 'Ghi chú', required: false),
            ],
            initial: {
              'so_tien': row['con_no'],
              'phuong_thuc': s.owner ? 'TIEN_MAT' : 'CHUYEN_KHOAN',
            },
          ),
          icon: Icons.payments_outlined,
        ),
      );
    }
    final approve =
        (m.table == 'giao_dich' &&
            s.owner &&
            row['trang_thaigd'] == 'CHO_XAC_NHAN') ||
        (['yeu_cau_gia_han', 'yeu_cau_cham_dut'].contains(m.table) &&
            s.owner &&
            row['trang_thai'] == 'CHO_PHE_DUYET') ||
        (m.table == 'phu_luc_hop_dong' &&
            !s.owner &&
            row['trang_thai'] == 'CHO_PHE_DUYET');
    if (approve) {
      widgets.add(
        button(
          'Phê duyệt',
          () => act(
            'approve',
            message: m.table == 'yeu_cau_cham_dut'
                ? 'Hợp đồng sẽ chấm dứt ngay, phòng chuyển về trống và ghi nhận khoản hoàn cọc sau trừ nợ.'
                : 'Xác nhận phê duyệt bản ghi này?',
          ),
        ),
      );
      widgets.add(
        button(
          'Từ chối',
          () => act('reject', fields: const [Field('ly_do', 'Lý do từ chối')]),
          icon: Icons.close,
        ),
      );
    }
    if (m.table == 'yeu_cau_su_co' &&
        s.owner &&
        row['trang_thai'] != 'DA_XONG') {
      const states = ['MOI', 'DA_TIEP_NHAN', 'DANG_SUA', 'DA_XONG'];
      final next = states[states.indexOf('${row['trang_thai']}') + 1];
      widgets.add(
        button(
          label(next),
          () => act(
            'status',
            fields: [
              Field('trang_thai', 'Trạng thái', options: [next]),
              const Field('ghi_chu_xu_ly', 'Ghi chú xử lý', required: false),
            ],
            initial: {'trang_thai': next},
          ),
          icon: Icons.build_outlined,
        ),
      );
    }
    if (m.table == 'hop_dong' && row['trang_thai'] != 'DA_CHAM_DUT') {
      if (s.owner) {
        widgets.add(
          button(
            'Gia hạn giữ giá',
            () => act(
              'extend',
              fields: const [
                Field('ngay_ket_thuc', 'Ngày kết thúc mới', kind: 'date'),
              ],
            ),
            icon: Icons.event_repeat,
          ),
        );
        widgets.add(
          button(
            'Chấm dứt',
            () => act(
              'terminate',
              message: 'Chấm dứt ngay hợp đồng, giải phóng phòng và ghi nhận hoàn cọc sau khi trừ dư nợ?',
            ),
            icon: Icons.logout,
          ),
        );
      } else {
        for (final table in ['yeu_cau_gia_han', 'yeu_cau_cham_dut']) {
          widgets.add(
            button(moduleOf(table).label, () async {
              final data = await inputForm(
                context,
                store: s,
                title: moduleOf(table).label,
                fields: moduleOf(table).fields,
                initial: {'hop_dong_id': row['hop_dong_id']},
              );
              if (data != null && mounted) {
                await guarded(context, () => s.save(moduleOf(table), data));
              }
            }, icon: moduleIcon(table)),
          );
        }
      }
    }
    if (m.table == 'nguoi_dung' && s.owner) {
      widgets.add(
        button(
          row['trang_thai'] == 'HOAT_DONG' ? 'Khóa tài khoản' : 'Mở khóa',
          () => act('toggle'),
          icon: Icons.lock_outline,
        ),
      );
    }
    if (m.table == 'thong_bao') {
      widgets.add(button('Đánh dấu đã đọc', () => act('read')));
    }
    if (['hoa_don', 'giao_dich', 'hop_dong'].contains(m.table)) {
      widgets.add(
        button('Sao chép nội dung', () async {
          final text =
              'TRỌ AN — ${m.label.toUpperCase()} #${row[m.id]}\n${row.entries.map((e) => '${m.fields.where((f) => f.key == e.key).firstOrNull?.label ?? label(e.key)}: ${value(e.key, e.value)}').join('\n')}';
          await Clipboard.setData(ClipboardData(text: text));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã sao chép nội dung.')),
            );
          }
        }, icon: Icons.copy_outlined),
      );
    }
    if (m.deletable && s.owner) {
      widgets.add(
        button('Xóa', () async {
          if (!await confirm(
                context,
                'Xóa ${m.label.toLowerCase()}',
                'Thao tác xóa không thể hoàn tác. Tiếp tục?',
              ) ||
              !mounted) {
            return;
          }
          setState(() => busy = true);
          try {
            await s.delete(m, row);
            if (mounted) Navigator.pop(context);
          } catch (e) {
            if (mounted) {
              setState(() => busy = false);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        }, icon: Icons.delete_outline),
      );
    }
    return widgets;
  }
}
