// lib/message_detail_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MessageDetailPage extends StatelessWidget {
  final String title;
  final String salon;
  final String message;
  final String time;
  final bool isRead;

  const MessageDetailPage({
    super.key,
    required this.title,
    required this.salon,
    required this.message,
    required this.time,
    this.isRead = true,
  });

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
          "Message",
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: Icon(
                    isRead ? Icons.check_circle : Icons.notifications_active,
                    color: isRead ? Colors.white70 : Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        "From: $salon",
                        style: GoogleFonts.poppins(fontSize: 15, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white38),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Message Body
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, height: 1.6),
              ),
            ),

            const Spacer(),

            // Optional Action Button (e.g., View Booking)
            if (title.contains("Booking") || title.contains("confirmed"))
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Opening booking details...")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text("View Booking", style: GoogleFonts.poppins(fontSize: 18, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}