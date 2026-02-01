// lib/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

import 'admin_page.dart'; // your existing Management page

class AdminNavigationWrapper extends StatefulWidget {
  const AdminNavigationWrapper({super.key});

  @override
  State<AdminNavigationWrapper> createState() => _AdminNavigationWrapperState();
}

class _AdminNavigationWrapperState extends State<AdminNavigationWrapper> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    DashboardScreen(),
    AdminPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_rounded), label: 'Management'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey.shade600,
        onTap: _onItemTapped,
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  String _timeFilter = 'All Time';

  final List<String> _filterOptions = [
    'All Time',
    'This Year',
    'Last 30 Days',
    'This Month',
    'Last 7 Days',
  ];

  DateTime? _getStartDate() {
    final now = DateTime.now();
    switch (_timeFilter) {
      case 'This Year':
        return DateTime(now.year);
      case 'Last 30 Days':
        return now.subtract(const Duration(days: 30));
      case 'This Month':
        return DateTime(now.year, now.month);
      case 'Last 7 Days':
        return now.subtract(const Duration(days: 7));
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    final startDate = _getStartDate();

    // Revenue per salon via RPC
    final revenueResult = await _supabase.rpc('get_revenue_per_salon', params: {
      'p_start_date': startDate?.toUtc().toIso8601String(),
    });

    double totalRevenue = 0.0;

    for (final row in revenueResult) {
      final rev = row['total_revenue'];
      if (rev is num) {
        totalRevenue += rev.toDouble();
      }
    }
    // Bookings count & average
    var bookingQuery = _supabase
        .from('bookings')
        .select('price')
        .eq('status', 'completed');

    if (startDate != null) {
      bookingQuery = bookingQuery.gte('created_at', startDate.toUtc().toIso8601String());
    }

    final bookings = await bookingQuery;
    final totalBookings = bookings.length;
    final sumPrice = bookings.fold<double>(0, (s, b) => s + ((b['price'] as num?)?.toDouble() ?? 0));
    final avgBooking = totalBookings > 0 ? sumPrice / totalBookings : 0.0;

    // Counts
    final usersCount = await _supabase.from('profiles').count();
    final salonsCount = await _supabase.from('barber_shops').count();

    return {
      'totalRevenue': totalRevenue,
      'totalBookings': totalBookings,
      'avgBooking': avgBooking,
      'shopRevenue': revenueResult, // list of {salon_id, salon_name, total_revenue}
      'users': usersCount,
      'salons': salonsCount,
    };
  }

  void _showCreateAnnouncementDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Announcement / Offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(labelText: 'Content / Offer details'),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and content are required')),
                );
                return;
              }

              try {
                await _supabase.from('announcements').insert({
                  'title': titleCtrl.text.trim(),
                  'content': contentCtrl.text.trim(),
                  'created_by': _supabase.auth.currentUser?.id,
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Announcement created successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Admin Dashboard", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {})),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _supabase.auth.signOut()),
        ],
      ),
      body: Column(
        children: [
          // Time filter chips
          Container(
            height: 75,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final label = _filterOptions[index];
                final isSelected = label == _timeFilter;

                return GestureDetector(
                  onTap: () => setState(() => _timeFilter = label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange.shade700 : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isSelected ? Colors.orange.shade700 : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                          : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 14.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              key: ValueKey(_timeFilter),
              future: _fetchStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        "Error loading data\n${snapshot.error.toString().split('\n').first}",
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final data = snapshot.data!;
                final revenue = data['totalRevenue'] as double;
                final bookings = data['totalBookings'] as int;
                final avg = data['avgBooking'] as double;
                final shops = data['shopRevenue'] as List<dynamic>;
                final users = data['users'] as int? ?? 0;
                final salons = data['salons'] as int? ?? 0;

                final hasData = shops.isNotEmpty && revenue > 0;

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Stats cards - 2 × 2 grid style
                      Row(
                        children: [
                          Expanded(child: _StatCard("Total Revenue", "₹${revenue.toStringAsFixed(0)}", Icons.currency_rupee_rounded, Colors.green.shade700)),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard("Total Bookings", "$bookings", Icons.event_available, Colors.blue.shade700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _StatCard("Avg. Booking Value", "₹${avg.toStringAsFixed(0)}", Icons.trending_up, Colors.purple.shade700)),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard("Total Users", "$users", Icons.people_alt, Colors.teal.shade700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StatCard("Total Salons", "$salons", Icons.storefront, Colors.orange.shade800, fullWidth: true),

                      const SizedBox(height: 24),

                      // Revenue Chart
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Revenue by Salon", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 280,
                                child: hasData
                                    ? BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: shops.isNotEmpty ? (shops[0]['total_revenue'] as num? ?? 0).toDouble() * 1.1 : 100,
                                    barGroups: shops.asMap().entries.map((e) {
                                      final index = e.key;
                                      final salon = e.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: (salon['total_revenue'] is num ? (salon['total_revenue'] as num).toDouble() : 0.0),
                                            color: Colors.orange[700],
                                            width: 24,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 50,
                                          getTitlesWidget: (value, meta) {
                                            final idx = value.toInt();
                                            if (idx >= 0 && idx < shops.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 10),
                                                child: Text(
                                                  (shops[idx]['salon_name'] as String?)?.split(' ').first ?? '?',
                                                  style: const TextStyle(fontSize: 10),
                                                  textAlign: TextAlign.center,
                                                ),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 48,
                                          getTitlesWidget: (value, meta) => Text("₹${value.toInt()}"),
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(drawVerticalLine: false),
                                    borderData: FlBorderData(show: false),
                                  ),
                                )
                                    : const Center(
                                  child: Text(
                                    "No completed bookings yet\nAdd bookings with price to see revenue chart",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, fontSize: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Announcement / Offer button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.campaign, size: 26),
                          label: const Text("Create Announcement / Special Offer", style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _showCreateAnnouncementDialog,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _StatCard(String title, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          ],
        ),
      ),
    );
  }
}