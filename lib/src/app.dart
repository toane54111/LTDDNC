import 'package:flutter/material.dart';
import 'package:rental_domain/rental_domain.dart';

import 'data.dart';
import 'detail.dart';
import 'forms.dart';
import 'theme.dart';
import 'room_photo.dart';

class RentalApp extends StatefulWidget {
  const RentalApp({super.key, this.store});
  final RentalStore? store;
  @override
  State<RentalApp> createState() => _RentalAppState();
}

class _RentalAppState extends State<RentalApp> {
  late final store = widget.store ?? RentalStore();
  final navigator = GlobalKey<NavigatorState>();
  bool wasAuthenticated = false;
  @override
  void initState() {
    super.initState();
    wasAuthenticated = store.user != null;
    store.addListener(sessionChanged);
  }

  void sessionChanged() {
    if (wasAuthenticated && store.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) navigator.currentState?.popUntil((route) => route.isFirst);
      });
    }
    wasAuthenticated = store.user != null;
  }

  @override
  void dispose() {
    store.removeListener(sessionChanged);
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    debugShowCheckedModeBanner: false,
    title: 'Trọ An • Quản lý nhà trọ',
    theme: appTheme(),
    home: ListenableBuilder(
      listenable: store,
      builder: (context, _) => store.user == null
          ? LoginScreen(store: store)
          : HomeScreen(
              key: ValueKey('${store.user?['user_id']}:${store.demo}'),
              store: store,
            ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});
  final RentalStore store;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, visible = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.login(email.text.trim(), password.text);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              const SizedBox(height: 40),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: brandBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.roofing_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'trọ an',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 46),
              Text(
                'Chào mừng đến Trọ An',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 14),
              const Text(
                'Đăng nhập để quản lý phòng trọ và chăm sóc không gian sống của bạn.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) => validateField(
                        const Field('email', 'Email', kind: 'email'),
                        v,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      obscureText: !visible,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: visible ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                          onPressed: () => setState(() => visible = !visible),
                          icon: Icon(
                            visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Nhập mật khẩu' : null,
                      onFieldSubmitted: (_) => busy ? null : login(),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : login,
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Đăng nhập'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  final result = await inputForm(
                    context,
                    store: widget.store,
                    title: 'Kết nối máy chủ',
                    fields: const [Field('url', 'Địa chỉ API')],
                    initial: {'url': widget.store.baseUrl},
                  );
                  if (result != null) {
                    final url = '${result['url']}'.replaceAll(
                      RegExp(r'/+$'),
                      '',
                    );
                    final uri = Uri.tryParse(url);
                    if (uri != null &&
                        ['http', 'https'].contains(uri.scheme) &&
                        uri.host.isNotEmpty) {
                      widget.store.baseUrl = url;
                      if (mounted) setState(() => error = null);
                    } else if (mounted) {
                      setState(
                        () => error =
                            'Địa chỉ phải bắt đầu bằng http:// hoặc https://',
                      );
                    }
                  }
                },
                icon: const Icon(Icons.dns_outlined, size: 18),
                label: const Text('Cấu hình máy chủ'),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Khám phá giao diện với dữ liệu mẫu',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => widget.store.preview(),
                    child: const Text('Xem vai trò chủ trọ'),
                  ),
                  TextButton(
                    onPressed: () => widget.store.preview(tenant: true),
                    child: const Text('Xem khách thuê'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final RentalStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RentalStore get s => widget.store;
  int tab = 0;
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await s.refresh();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void open(String table) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ModuleScreen(store: s, module: moduleOf(table)),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final titles = [
      'Tổng quan',
      s.owner ? 'Phòng trọ' : 'Phòng của tôi',
      'Hóa đơn',
      'Tiện ích',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.location_on, color: brandBlue, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tab == 0
                    ? (s.rows('khu_tro').isEmpty
                          ? 'Trọ An'
                          : '${s.rows('khu_tro').first['ten_khu']}')
                    : titles[tab],
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () => open('thong_bao'),
            icon: Badge(
              isLabelVisible: s
                  .rows('thong_bao')
                  .any((r) => '${r['da_doc']}' == '0'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Tài khoản',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => ProfileScreen(store: s)),
            ),
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFF0F6FF),
              child: Icon(Icons.person_outline, size: 20, color: brandBlue),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (s.demo)
            Container(
              width: double.infinity,
              color: const Color(0xFFF5F9FF),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: const Text(
                'XEM TRƯỚC • Dữ liệu mẫu, không lưu thay đổi',
                style: TextStyle(fontSize: 12, color: Color(0xFF708399)),
              ),
            ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                TextButton(onPressed: reload, child: const Text('Thử lại')),
              ],
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: reload,
              child: tab == 0
                  ? dashboard()
                  : tab == 1
                  ? ModuleContent(store: s, module: moduleOf('phong_tro'))
                  : tab == 2
                  ? ModuleContent(store: s, module: moduleOf('hoa_don'))
                  : utilities(),
            ),
          ),
        ],
      ),
      floatingActionButton: !s.demo && s.owner && [1, 2].contains(tab)
          ? FloatingActionButton.extended(
              onPressed: () => editRecord(
                context,
                s,
                moduleOf(tab == 1 ? 'phong_tro' : 'hoa_don'),
              ),
              icon: const Icon(Icons.add),
              label: Text(tab == 1 ? 'Thêm phòng' : 'Lập hóa đơn'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.door_front_door_outlined),
            label: 'Phòng trọ',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Hóa đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            label: 'Tiện ích',
          ),
        ],
      ),
    );
  }

  String roomQuery = '';
  Widget dashboard() {
    final rooms = s
        .rows('phong_tro')
        .where(
          (r) => '${r['so_phong']} ${r['mo_ta'] ?? ''}'.toLowerCase().contains(
            roomQuery.toLowerCase(),
          ),
        )
        .toList();
    final invoices = s.rows('hoa_don');
    final debt = invoices.fold<int>(0, (a, r) => a + integer(r['con_no']));
    final paid = invoices.fold<int>(
      0,
      (a, r) => a + integer(r['da_thanh_toan']),
    );
    final incidents = s
        .rows('yeu_cau_su_co')
        .where((r) => r['trang_thai'] != 'DA_XONG')
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          'Xin chào, ${s.user?['ho_ten']}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF84909F)),
        ),
        const SizedBox(height: 7),
        Text(
          s.owner ? 'Quản lý ngôi nhà của bạn' : 'Không gian sống của bạn',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          onChanged: (value) => setState(() => roomQuery = value),
          decoration: const InputDecoration(
            hintText: 'Tìm phòng, không gian sống...',
            prefixIcon: Icon(Icons.search_rounded, size: 22),
            suffixIcon: Icon(Icons.tune_rounded, size: 20),
            filled: true,
            fillColor: Color(0xFFF7F9FC),
            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            quick('Phòng trọ', 'phong_tro', Icons.home_outlined),
            quick('Hợp đồng', 'hop_dong', Icons.description_outlined),
            quick(
              s.owner ? 'Điện nước' : 'Báo sự cố',
              s.owner ? 'chi_so_dien_nuoc' : 'yeu_cau_su_co',
              s.owner ? Icons.bolt_outlined : Icons.build_outlined,
            ),
            quick(
              s.owner ? 'Khách thuê' : 'Gia hạn',
              s.owner ? 'nguoi_dung' : 'yeu_cau_gia_han',
              Icons.people_outline,
            ),
          ],
        ),
        const SizedBox(height: 24),
        section(
          s.owner ? 'Phòng trọ của bạn' : 'Phòng đang thuê',
          onTap: () => setState(() => tab = 1),
        ),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          const EmptyView(
            message: 'Chưa có phòng phù hợp',
            detail: 'Thêm phòng mới hoặc thử một từ khóa khác.',
          )
        else
          SizedBox(
            height: 326,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rooms.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) => SizedBox(
                width: MediaQuery.sizeOf(context).width < 370 ? 258 : 282,
                child: RoomCard(store: s, row: rooms[index]),
              ),
            ),
          ),
        const SizedBox(height: 26),
        section('Tài chính tổng quan', onTap: () => setState(() => tab = 2)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF6FAFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8F1FF)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.owner ? 'Đã thu' : 'Đã thanh toán',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8290A3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      money(paid),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: brandBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.owner ? 'Còn phải thu' : 'Còn phải trả',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8290A3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      money(debt),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (incidents.isNotEmpty) ...[
          const SizedBox(height: 26),
          section('Yêu cầu cần xử lý', onTap: () => open('yeu_cau_su_co')),
          const SizedBox(height: 12),
          for (final r in incidents.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RecordCard(
                store: s,
                module: moduleOf('yeu_cau_su_co'),
                row: r,
              ),
            ),
        ],
      ],
    );
  }

  Widget section(String text, {VoidCallback? onTap}) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ),
      if (onTap != null)
        TextButton(
          onPressed: onTap,
          child: const Text('Xem tất cả', style: TextStyle(fontSize: 12)),
        ),
    ],
  );
  Widget quick(String title, String table, IconData icon) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => open(table),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFF0F3F7)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, color: brandBlue, size: 27),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: ink),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget utilities() => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      Text(
        'Mọi việc, một nơi',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(
        'Không gian dành cho ${s.owner ? 'chủ trọ' : 'khách thuê'}',
        style: const TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 24),
      Card(
        child: Column(
          children: [
            for (final m in modules.where((m) => s.owner || m.tenant))
              ListTile(
                leading: Icon(moduleIcon(m.table), color: brandBlue),
                title: Text(m.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(m.table),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const Icon(Icons.bar_chart, color: brandBlue),
          title: const Text('Thống kê thu chi'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => StatisticsScreen(store: s)),
          ),
        ),
      ),
    ],
  );
}

class ModuleScreen extends StatelessWidget {
  const ModuleScreen({super.key, required this.store, required this.module});
  final RentalStore store;
  final Module module;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(module.label),
      actions: [
        if (module.table == 'hoa_don' && store.owner)
          IconButton(
            tooltip: 'Lập hóa đơn hàng loạt',
            onPressed: () => batch(context),
            icon: const Icon(Icons.playlist_add),
          ),
      ],
    ),
    body: ModuleContent(store: store, module: module),
    floatingActionButton:
        !store.demo &&
            module.creatable &&
            (store.owner ? !module.tenantCreate : module.tenantCreate)
        ? FloatingActionButton.extended(
            onPressed: () => editRecord(context, store, module),
            icon: const Icon(Icons.add),
            label: const Text('Thêm mới'),
          )
        : null,
  );
  Future<void> batch(BuildContext context) async {
    final data = await inputForm(
      context,
      store: store,
      title: 'Hóa đơn hàng loạt',
      fields: const [
        Field('ky_thanh_toan', 'Kỳ (YYYY-MM)', kind: 'month'),
        Field('han_thanh_toan', 'Hạn thanh toán', kind: 'date'),
      ],
      submit: 'Xem trước',
    );
    if (data == null || !context.mounted) return;
    await guarded(context, () async {
      store.writable();
      final rows = await store.request('POST', 'batch-invoices', {
        ...data,
        'preview': true,
      }) as List;
      if (!context.mounted) return;
      final details = rows
          .map(
            (r) =>
                'HĐ #${r['hop_dong_id']}: ${r['ok'] == true ? money(r['tong_tien']) : r['error']}',
          )
          .join('\n');
      if (!await confirm(
        context,
        'Xem trước hóa đơn',
        details.isEmpty ? 'Không có hợp đồng phù hợp' : details,
      )) {
        return;
      }
      final result = await store.request('POST', 'batch-invoices', {
        ...data,
        'preview': false,
      }) as List;
      await store.refresh();
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Kết quả lập hóa đơn'),
            content: SingleChildScrollView(
              child: Text(
                result
                    .map(
                      (r) =>
                          'HĐ #${r['hop_dong_id']}: ${r['ok'] == true ? 'Đã tạo' : r['error']}',
                    )
                    .join('\n'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    });
  }
}

class ModuleContent extends StatefulWidget {
  const ModuleContent({super.key, required this.store, required this.module});
  final RentalStore store;
  final Module module;
  @override
  State<ModuleContent> createState() => _ModuleContentState();
}

class _ModuleContentState extends State<ModuleContent> {
  String query = '', filter = 'all';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final s = widget.store, m = widget.module;
      final all = s.rows(m.table);
      final states = all
          .map((r) => r['trang_thai'] ?? r['trang_thaigd'])
          .whereType<String>()
          .toSet();
      final rows = all
          .where(
            (r) =>
                (filter == 'all' ||
                    (r['trang_thai'] ?? r['trang_thaigd']) == filter) &&
                r.values.join(' ').toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 100),
        children: [
          Text(
            '${m.label} · ${all.length}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: 'Tìm trong ${m.label.toLowerCase()}...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 14),
          if (states.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final state in ['all', ...states])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(state == 'all' ? 'Tất cả' : label(state)),
                        selected: filter == state,
                        onSelected: (_) => setState(() => filter = state),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            EmptyView(
              message: all.isEmpty
                  ? 'Chưa có ${m.label.toLowerCase()}'
                  : 'Không tìm thấy kết quả',
              detail: all.isEmpty
                  ? 'Các bản ghi sẽ xuất hiện tại đây.'
                  : 'Thử đổi từ khóa hoặc bộ lọc.',
            ),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: m.table == 'phong_tro'
                  ? RoomCard(store: s, row: r)
                  : RecordCard(store: s, module: m, row: r),
            ),
        ],
      );
    },
  );
}

// Adapts the image → category → title → location → price hierarchy of
// byMoamen/Flutter-rental-app (lib/widgets/house_card.dart).
class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.store, required this.row});
  final RentalStore store;
  final Record row;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: () => openDetail(context, store, moduleOf('phong_tro'), row),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                RoomPhoto(row: row, height: 150),
                Positioned(
                  top: 9,
                  left: 9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .96),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label('${row['trang_thai']}'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: brandBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'PHÒNG TRỌ',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: .7,
                fontWeight: FontWeight.w700,
                color: brandBlue,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Phòng ${row['so_phong']}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Color(0xFFA0AAB7),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    store.display('khu_tro', row['khu_tro_id']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF929BA8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: money(row['gia_thue']),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const TextSpan(
                          text: ' / tháng',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF929BA8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  '${row['dien_tich']} m²',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF929BA8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.store,
    required this.module,
    required this.row,
  });
  final RentalStore store;
  final Module module;
  final Record row;
  @override
  Widget build(BuildContext context) {
    final status = row['trang_thai'] ?? row['trang_thaigd'];
    final title = module.title == module.id
        ? '${module.label} #${row[module.id]}'
        : module.title == 'hop_dong_id'
        ? store.display('hop_dong', row['hop_dong_id'])
        : '${row[module.title] ?? module.label}';
    final sub =
        row['mo_ta'] ??
        row['noi_dung'] ??
        row['dia_chi'] ??
        row['email'] ??
        row['ngay_tao'] ??
        '';
    return Card(
      child: InkWell(
        onTap: () => openDetail(context, store, module, row),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF0F6FF),
                child: Icon(
                  moduleIcon(module.table),
                  color: brandBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if ('$sub'.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$sub',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (row['tong_tien'] != null ||
                        row['so_tien'] != null ||
                        row['don_gia'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        money(
                          row['tong_tien'] ?? row['so_tien'] ?? row['don_gia'],
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: brandBlue,
                        ),
                      ),
                    ],
                    if (status != null) ...[
                      const SizedBox(height: 10),
                      StatusBadge('$status'),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.store});
  final RentalStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tài khoản')),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xFFF0F6FF),
            child: Icon(Icons.person_outline, size: 46, color: brandBlue),
          ),
          const SizedBox(height: 20),
          Text(
            '${store.user?['ho_ten'] ?? ''}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            label('${store.user?['vai_tro'] ?? ''}'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Cập nhật thông tin'),
            onTap: () async {
              final result = await inputForm(
                context,
                store: store,
                title: 'Thông tin cá nhân',
                fields: const [
                  Field('ho_ten', 'Họ tên'),
                  Field('sdt', 'Điện thoại', required: false),
                  Field('cccd', 'CCCD', required: false),
                ],
                initial: store.user ?? {},
              );
              if (result != null && context.mounted) {
                await guarded(context, () async {
                  store.writable();
                  store.user = Map<String, dynamic>.from(
                    await store.request('PUT', 'profile', result),
                  );
                  await store.refresh();
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Đổi mật khẩu'),
            onTap: () async {
              final data = await inputForm(
                context,
                store: store,
                title: 'Đổi mật khẩu',
                fields: const [
                  Field('old_password', 'Mật khẩu hiện tại', kind: 'password'),
                  Field('new_password', 'Mật khẩu mới', kind: 'password'),
                ],
              );
              if (data != null && context.mounted) {
                await guarded(context, () async {
                  store.writable();
                  await store.request('POST', 'password', data);
                  await store.logout();
                  if (context.mounted) {
                    Navigator.popUntil(context, (r) => r.isFirst);
                  }
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Đăng xuất'),
            onTap: () async {
              await store.logout();
              if (context.mounted) {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'Trọ An\nĐồ án Lập trình di động nâng cao\nFlutter • Dart API • MySQL',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, height: 1.8),
          ),
        ],
      ),
    ),
  );
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, required this.store});
  final RentalStore store;
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int year = DateTime.now().year;
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final totals = List<int>.filled(12, 0);
    for (final t
        in s
            .rows('giao_dich')
            .where(
              (t) =>
                  t['hoa_don_id'] != null && t['trang_thaigd'] == 'DA_XAC_NHAN',
            )) {
      final date = DateTime.tryParse('${t['ngay_giao_dich']}');
      if (date != null && date.year == year) {
        totals[date.month - 1] += integer(t['so_tien']);
      }
    }
    final maxValue = totals.fold<int>(1, (a, b) => a > b ? a : b);
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê thu chi')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => year--),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  'Năm $year',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => year++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            money(totals.fold<int>(0, (a, b) => a + b)),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const Text(
            'Thanh toán hóa đơn đã xác nhận',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  for (var i = 0; i < 12; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tháng ${i + 1}'),
                              Text(
                                money(totals[i]),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: totals[i] / maxValue,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                            backgroundColor: const Color(0xFFF0F5FA),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Dư nợ hiện tại: ${money(s.rows('hoa_don').fold<int>(0, (a, r) => a + integer(r['con_no'])))}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tiền cọc và hoàn cọc được theo dõi trong Giao dịch, không cộng vào doanh thu tiền thuê.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
