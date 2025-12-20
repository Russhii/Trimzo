// lib/my_bookings_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "My Bookings",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Upcoming"),
            Tab(text: "History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BookingList(statusFilter: "upcoming"),
          BookingList(statusFilter: "history"),
        ],
      ),
    );
  }
}

class BookingList extends StatelessWidget {
  final String statusFilter; // "upcoming" or "history"

  const BookingList({super.key, required this.statusFilter});

  // Sample data - replace with real data from Supabase later
  final List<Map<String, dynamic>> _bookings = const [
    {
      "id": 1,
      "salon": "Belle Curls",
      "service": "Haircut + Coloring",
      "date": "2025-12-15",
      "time": "10:30 AM",
      "price": 150.00,
      "status": "upcoming", // upcoming, completed, cancelled
      "imageUrl": "https://images.unsplash.com/photo-1600948836101-f9ffda59d76d?w=400",
    },
    {
      "id": 2,
      "salon": "Serenity Salon",
      "service": "Full Body Massage",
      "date": "2025-12-20",
      "time": "03:00 PM",
      "price": 120.00,
      "status": "upcoming",
      "imageUrl": "https://images.unsplash.com/photo-1559598467-f8b76c5e1d0f?w=400",
    },
    {
      "id": 3,
      "salon": "Pretty Parlor",
      "service": "Manicure & Pedicure",
      "date": "2025-11-28",
      "time": "02:00 PM",
      "price": 85.00,
      "status": "completed",
      "imageUrl": "https://images.unsplash.com/photo-1517838277536-f5f99be715a5?w=400",
    },
    {
      "id": 4,
      "salon": "The Razor's Edge",
      "service": "Beard Trim + Shave",
      "date": "2025-11-10",
      "time": "11:00 AM",
      "price": 45.00,
      "status": "cancelled",
      "imageUrl": "https://images.unsplash.com/photo-1521590832167-8d6d5c9e59e7?w=400",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredBookings = _bookings.where((b) {
      if (statusFilter == "upcoming") {
        return b["status"] == "upcoming";
      } else {
        return b["status"] == "completed" || b["status"] == "cancelled";
      }
    }).toList();

    if (filteredBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              statusFilter == "upcoming"
                  ? Icons.event_busy_outlined
                  : Icons.history,
              size: 80,
              color: Colors.white38,
            ),
            const SizedBox(height: 20),
            Text(
              statusFilter == "upcoming"
                  ? "No upcoming bookings"
                  : "No past bookings yet",
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusFilter == "upcoming"
                  ? "Book your next salon visit now!"
                  : "Your booking history will appear here",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredBookings.length,
      itemBuilder: (context, index) {
        final booking = filteredBookings[index];
        return BookingCard(booking: booking);
      },
    );
  }
}

class BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final isCancelled = booking["status"] == "cancelled";
    final isCompleted = booking["status"] == "completed";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              booking["imageUrl"],
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey,
                child: const Icon(Icons.spa, color: Colors.white54, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking["salon"],
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  booking["service"],
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('EEE, MMM d').format(DateTime.parse(booking["date"])),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      booking["time"],
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      "\$${booking["price"].toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? Colors.red.withOpacity(0.2)
                            : isCompleted
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isCancelled
                            ? "Cancelled"
                            : isCompleted
                            ? "Completed"
                            : "Upcoming",
                        style: GoogleFonts.poppins(
                          color: isCancelled
                              ? Colors.red
                              : isCompleted
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}