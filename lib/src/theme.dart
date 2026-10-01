import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rental_domain/rental_domain.dart';

const ink = Color(0xFF182333),
    brandBlue = Color(0xFF2388EF),
    background = Color(0xFFFFFFFF);
String money(dynamic value) =>
    '${NumberFormat.decimalPattern('vi').format(num.tryParse('$value') ?? 0)} đ';
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: background,
  colorScheme: ColorScheme.fromSeed(seedColor: brandBlue, surface: Colors.white)
      .copyWith(
        primary: brandBlue,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFEDF5FF),
        surfaceTint: Colors.transparent,
      ),
  appBarTheme: const AppBarTheme(
    backgroundColor: background,
    foregroundColor: ink,
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 27,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE8EDF3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE8EDF3)),
    ),
    contentPadding: const EdgeInsets.all(18),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFEDF0F4)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 68,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    indicatorColor: Colors.transparent,
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        size: 23,
        color: states.contains(WidgetState.selected)
            ? brandBlue
            : const Color(0xFF939AA4),
      ),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w600
            : FontWeight.w400,
        color: states.contains(WidgetState.selected)
            ? brandBlue
            : const Color(0xFF939AA4),
      ),
    ),
  ),
);
IconData moduleIcon(String table) => switch (table) {
  'khu_tro' => Icons.apartment_rounded,
  'phong_tro' => Icons.door_front_door_outlined,
  'nguoi_dung' => Icons.people_outline,
  'hop_dong' => Icons.description_outlined,
  'hoa_don' => Icons.receipt_long_outlined,
  'chi_so_dien_nuoc' => Icons.bolt_outlined,
  'dich_vu' => Icons.widgets_outlined,
  'tai_san_phong_tro' => Icons.chair_outlined,
  'thanh_vien_phong_tro' => Icons.groups_outlined,
  'yeu_cau_su_co' => Icons.handyman_outlined,
  'yeu_cau_gia_han' => Icons.event_repeat_outlined,
  'yeu_cau_cham_dut' => Icons.logout,
  'phu_luc_hop_dong' => Icons.post_add_outlined,
  'giao_dich' => Icons.account_balance_wallet_outlined,
  _ => Icons.notifications_none_rounded,
};

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final good = [
      'TRONG',
      'DA_THANH_TOAN',
      'DA_XAC_NHAN',
      'DA_XONG',
      'HOAT_DONG',
      'DANG_HIEU_LUC',
    ].contains(status);
    final color = good
        ? brandBlue
        : ['DA_HUY', 'DA_TU_CHOI', 'BI_KHOA'].contains(status)
        ? Colors.red.shade700
        : Colors.orange.shade900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.message = 'Chưa có dữ liệu',
    this.detail = 'Dữ liệu mới sẽ xuất hiện tại đây.',
  });
  final String message, detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 52, color: brandBlue),
        const SizedBox(height: 16),
        Text(message, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    ),
  );
}
