import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rental_domain/rental_domain.dart';

import 'data.dart';
import 'theme.dart';
import 'forms.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, required this.store});
  final RentalStore store;
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Future<void> start() async {
    await guarded(context, () async {
      final contacts =
          await widget.store.request('GET', 'firebase/contacts') as List;
      if (!mounted) return;
      final contact = await showModalBottomSheet<Record>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Bắt đầu cuộc trò chuyện')),
              if (contacts.isEmpty)
                const ListTile(title: Text('Chưa có người liên hệ')),
              for (final row in contacts)
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text('${row['ho_ten']}'),
                  subtitle: Text(
                    row['vai_tro'] == 'CHU_TRO' ? 'Chủ trọ' : 'Khách thuê',
                  ),
                  onTap: () =>
                      Navigator.pop(context, Map<String, dynamic>.from(row)),
                ),
            ],
          ),
        ),
      );
      if (contact == null) return;
      final result = await widget.store.request('POST', 'firebase/chat', {
        'recipient': contact['user_id'],
      });
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            store: widget.store,
            id: result['id'],
            recipient: '${contact['user_id']}',
            name: '${contact['ho_ten']}',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final uid = 'rental_${store.user?['user_id']}';
    return Scaffold(
      appBar: AppBar(title: const Text('Tin nhắn')),
      floatingActionButton: store.firebaseConnected
          ? FloatingActionButton(
              onPressed: start,
              child: const Icon(Icons.edit_outlined),
            )
          : null,
      body: !store.firebaseConnected
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Đăng nhập và kết nối Firebase trong Tài khoản để trò chuyện với chủ trọ, khách thuê.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .where('members', arrayContains: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Không tải được tin nhắn. Kiểm tra kết nối hoặc đăng nhập lại.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs.toList()
                  ..sort(
                    (a, b) => '${b.data()['updatedAt']}'.compareTo(
                      '${a.data()['updatedAt']}',
                    ),
                  );
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Chưa có cuộc trò chuyện. Bấm nút bên dưới để bắt đầu.',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index], data = doc.data();
                    final peer = (data['members'] as List)
                        .firstWhere((v) => v != uid)
                        .toString();
                    final name = '${(data['names'] as Map)[peer] ?? 'Liên hệ'}';
                    final unread =
                        data['lastSender'] != uid &&
                        '${data['lastMessage'] ?? ''}'.isNotEmpty &&
                        '${data['updatedAt']}'.compareTo(
                              '${data['read_${store.user?['user_id']}'] ?? ''}',
                            ) >
                            0;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEDF5FF),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          color: brandBlue,
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: unread
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${data['lastMessage'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: unread ? const Badge() : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(
                            store: store,
                            id: doc.id,
                            recipient: peer.replaceFirst('rental_', ''),
                            name: name,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.store,
    required this.id,
    required this.recipient,
    required this.name,
  });
  final RentalStore store;
  final String id, recipient, name;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  bool sending = false;
  String? pendingId, pendingText, lastRead;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (sending || input.text.trim().isEmpty) return;
    final text = input.text.trim();
    if (pendingText != text) {
      pendingText = text;
      pendingId = FirebaseFirestore.instance.collection('messageIds').doc().id;
    }
    setState(() => sending = true);
    try {
      await widget.store.request('POST', 'firebase/chat/send', {
        'recipient': widget.recipient,
        'text': text,
        'messageId': pendingId,
      });
      input.clear();
      pendingId = null;
      pendingText = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.name)),
    body: Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .doc(widget.id)
                .collection('messages')
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Không tải được cuộc trò chuyện.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isNotEmpty && lastRead != docs.first.id) {
                lastRead = docs.first.id;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    widget.store
                        .request('POST', 'firebase/chat/read', {
                          'recipient': widget.recipient,
                        })
                        .catchError((_) => null);
                  }
                });
              }
              if (docs.isEmpty) {
                return const Center(
                  child: Text('Gửi lời chào để bắt đầu cuộc trò chuyện.'),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final mine =
                      data['sender'] ==
                      'rental_${widget.store.user?['user_id']}';
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .78,
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: mine ? brandBlue : const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${data['text']}',
                        style: TextStyle(color: mine ? Colors.white : ink),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Nhắn tin...',
                      counterText: '',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: sending ? null : send,
                  icon: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: brandBlue),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
