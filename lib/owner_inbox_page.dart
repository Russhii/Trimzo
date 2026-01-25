// lib/owner_inbox_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'message_detail_page.dart';

class OwnerInboxPage extends StatefulWidget {
  const OwnerInboxPage({super.key});

  @override
  State<OwnerInboxPage> createState() => _OwnerInboxPageState();
}

class _OwnerInboxPageState extends State<OwnerInboxPage> {
  late Future<List<Map<String, dynamic>>> _messagesFuture;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _fetchMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _subscribeToMessages() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _channel = Supabase.instance.client.channel('owner_inbox_realtime').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'inbox_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        if (mounted) {
          setState(() {
            _messagesFuture = _fetchMessages();
          });
        }
      },
    ).subscribe();
  }

  Future<List<Map<String, dynamic>>> _fetchMessages() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // For owners, we might want to know which shop the message is for
      final response = await Supabase.instance.client
          .from('inbox_messages')
          .select('*, barber_shops(name)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching owner messages: $e');
      return [];
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await Supabase.instance.client
          .from('inbox_messages')
          .update({'is_read': true}).eq('id', id);

      setState(() {
        _messagesFuture = _fetchMessages();
      });
    } catch (e) {
      debugPrint('Error marking read: $e');
    }
  }

  String _formatTimeAgo(String timestamp) {
    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hours ago";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else {
      return "${difference.inDays} days ago";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          "Shop Inbox",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _messagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final messages = snapshot.data ?? [];

          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_as_unread_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No notifications yet",
                    style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() { _messagesFuture = _fetchMessages(); }),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isRead = msg['is_read'] as bool;
                final shopName = msg['barber_shops']?['name'] ?? 'Shop';

                return InkWell(
                  onTap: () {
                    if (!isRead) _markAsRead(msg['id']);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessageDetailPage(
                          messageId: msg['id'],
                          bookingId: msg['booking_id'],
                          title: msg["title"],
                          salon: shopName,
                          message: msg["message"],
                          time: _formatTimeAgo(msg['created_at']),
                          type: msg['type'],
                          isRead: true,
                        ),
                      ),
                    ).then((_) => setState(() { _messagesFuture = _fetchMessages(); }));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.white : Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isRead ? Colors.grey[200]! : Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.grey[100] : Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            msg['type'] == 'booking_new' ? Icons.new_releases : Icons.notifications,
                            color: isRead ? Colors.grey : Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg['title'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
                              Text(msg['message'], maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
