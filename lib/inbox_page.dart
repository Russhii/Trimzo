// lib/inbox_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'message_detail_page.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
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

    _channel = Supabase.instance.client.channel('inbox_messages_realtime').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'inbox_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        if (mounted) { // Add this check
          setState(() {
            _messagesFuture = _fetchMessages();
          });
        }
      },
    ).subscribe((status, error) {
      if (error != null) {
        debugPrint('Subscription error: $error');
      }
    }); // Add subscribe callback for errors
  }

  Future<List<Map<String, dynamic>>> _fetchMessages() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No user ID found for fetching messages');
      return []; // Return empty if no user
    }

    try {
      final response = await Supabase.instance.client
          .from('inbox_messages')
          .select('*, barber_shops(name)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
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

  Future<void> _markAllAsRead() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('inbox_messages')
          .update({'is_read': true})
          .eq('user_id', userId);

      setState(() {
        _messagesFuture = _fetchMessages();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All messages marked as read")),
        );
      }
    } catch (e) {
      debugPrint('Error marking all read: $e');
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

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'booking_accepted':
        return Icons.check_circle;
      case 'booking_rejected':
      case 'booking_cancelled':
        return Icons.cancel;
      case 'reschedule_request':
        return Icons.schedule;
      default:
        return Icons.notifications_active;
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
          "Inbox",
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined, color: Colors.orange),
            onPressed: _markAllAsRead,
          ),
          const SizedBox(width: 8),
        ],
      ),
        body: RefreshIndicator( // Add this
          onRefresh: () async {
            setState(() {
              _messagesFuture = _fetchMessages();
            });
          },
      child: FutureBuilder<List<Map<String, dynamic>>>(
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
                  Icon(Icons.inbox, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No messages yet",
                    style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: Colors.orange,
            onRefresh: () async {
              setState(() {
                _messagesFuture = _fetchMessages();
              });
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final salonData = msg['barber_shops'] as Map<String, dynamic>? ?? {};
                final salonName = salonData['name'] ?? 'System';
                final isRead = msg['is_read'] as bool;
                final timeAgo = _formatTimeAgo(msg['created_at']);

                return InkWell(
                  onTap: () {
                    if (!isRead) {
                      _markAsRead(msg['id']);
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessageDetailPage(
                          messageId: msg['id'],
                          bookingId: msg['booking_id'],
                          title: msg["title"],
                          salon: salonName,
                          message: msg["message"],
                          time: timeAgo,
                          type: msg['type'],
                          isRead: true,
                        ),
                      ),
                    ).then((_) => setState(() { _messagesFuture = _fetchMessages(); }));
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.grey[100]
                          : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isRead
                            ? Colors.grey[200]!
                            : Colors.orange.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.orange.withOpacity(0.2),
                          child: Icon(
                            isRead ? Icons.check_circle_outline : _getIconForType(msg['type']),
                            color: isRead ? Colors.grey : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg["title"],
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                salonName,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                msg["message"],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              timeAgo,
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            ),
                            if (!isRead) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
        ),
    );
  }
}
