// lib/message_detail_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MessageDetailPage extends StatefulWidget {
  final int messageId;
  final int? bookingId;
  final String title;
  final String salon;
  final String message;
  final String time;
  final String? type;
  final bool isRead;

  const MessageDetailPage({
    super.key,
    required this.messageId,
    this.bookingId,
    required this.title,
    required this.salon,
    required this.message,
    required this.time,
    this.type,
    this.isRead = true,
  });

  @override
  State<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailPage> {
  bool _isProcessing = false;

  Future<void> _acceptReschedule() async {
    if (widget.bookingId == null) return;

    setState(() => _isProcessing = true);
    try {
      // 1. Get reschedule details from booking
      final bookingRes = await Supabase.instance.client
          .from('bookings')
          .select('reschedule_date, salon_id, user_id')
          .eq('id', widget.bookingId!)
          .single();

      final String newDate = bookingRes['reschedule_date'];

      // 2. Update booking
      await Supabase.instance.client.from('bookings').update({
        'booking_date': newDate,
        'status': 'accepted',
        'reschedule_requested': false,
      }).eq('id', widget.bookingId!);

      // 3. Notify the other party (sender of the reschedule request)
      // If customer accepts owner's request: user_id is customer, we notify owner
      // But wait, inbox_messages user_id is the recipient. 
      // We need to know who sent the reschedule request.
      
      // For now, let's assume if it's in this inbox, the current user is accepting.
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      
      // If current user is customer, notify owner. If owner, notify customer.
      // We can check if current user is the booking's user_id.
      final isCustomer = currentUserId == bookingRes['user_id'];
      
      String targetId = '';
      if (isCustomer) {
         final salonRes = await Supabase.instance.client.from('barber_shops').select('owner_id').eq('id', bookingRes['salon_id']).single();
         targetId = salonRes['owner_id'];
      } else {
         targetId = bookingRes['user_id'];
      }

      await Supabase.instance.client.from('inbox_messages').insert({
        'user_id': targetId,
        'salon_id': bookingRes['salon_id'],
        'booking_id': widget.bookingId,
        'title': 'Reschedule Accepted',
        'message': 'The reschedule request for the booking has been accepted.',
        'type': 'reschedule_accepted',
        'is_read': false,
      });

      // Send Push Notification
      try {
        await Supabase.instance.client.functions.invoke('send-push-notification', body: {
          'user_id': targetId,
          'title': 'Reschedule Accepted',
          'body': 'Your reschedule request is approved. New time: ${DateFormat('MMM dd, hh:mm a').format(DateTime.parse(newDate))}',
          'type': 'reschedule_accepted',
          'booking_id': widget.bookingId,
        });
      } catch (e) {
        debugPrint("Push notification error: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reschedule accepted"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Message",
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.notifications_active,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      Text(
                        "From: ${widget.salon}",
                        style: GoogleFonts.poppins(fontSize: 15, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.time,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                widget.message,
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87, height: 1.6),
              ),
            ),
            const Spacer(),
            if (widget.type == 'reschedule_request')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _acceptReschedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isProcessing 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("Accept Reschedule", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
