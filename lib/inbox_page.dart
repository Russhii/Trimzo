// lib/inbox_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'message_detail_page.dart'; // ← ADD THIS IMPORT

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final List<Map<String, dynamic>> messages = [
    {
      "title": "Booking Confirmed!",
      "salon": "Hair Force",
      "message": "Your appointment is confirmed for tomorrow at 3:00 PM with stylist Anna. See you soon!",
      "time": "2 min ago",
      "isRead": false,
    },
    {
      "title": "30% OFF Today Only",
      "salon": "Serenity Salon",
      "message": "Use code WELCOME30 on your next booking! Offer ends tonight.",
      "time": "1 hour ago",
      "isRead": true,
    },
    {
      "title": "Your review matters!",
      "salon": "The Razor's Edge",
      "message": "How was your experience with us? Leave a review and get 10% off your next visit!",
      "time": "Yesterday",
      "isRead": true,
    },
    {
      "title": "New salon near you",
      "salon": "Glow Studio",
      "message": "Just opened 2.1 km away • Check it out! Grand opening special: 20% off first visit.",
      "time": "2 days ago",
      "isRead": true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Inbox",
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined, color: Colors.orange),
            onPressed: () {
              setState(() {
                for (var msg in messages) {
                  msg["isRead"] = true;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("All messages marked as read")),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: messages.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              "No messages yet",
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.white38),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          return InkWell(
            onTap: () {
              // Mark as read when opened
              if (!msg["isRead"]) {
                setState(() => msg["isRead"] = true);
              }

              // Open detail page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessageDetailPage(
                    title: msg["title"],
                    salon: msg["salon"],
                    message: msg["message"],
                    time: msg["time"],
                    isRead: msg["isRead"],
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: msg["isRead"]
                    ? Colors.white.withOpacity(0.05)
                    : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: msg["isRead"]
                      ? Colors.white.withOpacity(0.1)
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
                      msg["isRead"] ? Icons.check_circle : Icons.notifications_active,
                      color: msg["isRead"] ? Colors.white70 : Colors.orange,
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
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg["salon"],
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
                            color: Colors.white70,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        msg["time"],
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38),
                      ),
                      if (!msg["isRead"]) ...[
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
  }
}