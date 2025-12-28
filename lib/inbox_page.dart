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
  // We use a stream or future. Future is simpler for this structure.
  late Future<List<Map<String, dynamic>>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _fetchMessages();
  }

  /// 1. Fetch Messages from Supabase
  Future<List<Map<String, dynamic>>> _fetchMessages() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await Supabase.instance.client
          .from('inbox_messages')
          .select('*, salons(name)') // Join to get salon name
          .eq('user_id', userId)
          .order('created_at', ascending: false); // Newest first

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  /// 2. Mark specific message as read in Supabase
  Future<void> _markAsRead(int id) async {
    try {
      await Supabase.instance.client
          .from('inbox_messages')
          .update({'is_read': true}).eq('id', id);

      // Refresh local UI
      setState(() {
        _messagesFuture = _fetchMessages();
      });
    } catch (e) {
      debugPrint('Error marking read: $e');
    }
  }

  /// 3. Mark ALL as read in Supabase
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

  /// Helper to format timestamps (e.g. "2 min ago")
  String _formatTimeAgo(String timestamp) {
    final date = DateTime.parse(timestamp);
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
                final salonData = msg['salons'] as Map<String, dynamic>? ?? {};
                final salonName = salonData['name'] ?? 'System';
                final isRead = msg['is_read'] as bool;
                final timeAgo = _formatTimeAgo(msg['created_at']);

                return InkWell(
                  onTap: () {
                    // 1. Mark as read in DB if not already
                    if (!isRead) {
                      _markAsRead(msg['id']);
                    }

                    // 2. Open detail page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessageDetailPage(
                          title: msg["title"],
                          salon: salonName,
                          message: msg["message"],
                          time: timeAgo,
                          isRead: true, // It is now read
                        ),
                      ),
                    );
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
                            isRead ? Icons.check_circle : Icons.notifications_active,
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
    );
  }
}