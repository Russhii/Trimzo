import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SalonReviewsPage extends StatefulWidget {
  final int salonId;
  final String salonName;

  const SalonReviewsPage({
    super.key,
    required this.salonId,
    required this.salonName,
  });

  @override
  State<SalonReviewsPage> createState() => _SalonReviewsPageState();
}

class _SalonReviewsPageState extends State<SalonReviewsPage> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  double _averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      // Fetch reviews and join with profiles to get user names/avatars
      final response = await Supabase.instance.client
          .from('reviews')
          .select('*, profiles(full_name)')
          .eq('salon_id', widget.salonId)
          .order('created_at', ascending: false);

      final data = List<Map<String, dynamic>>.from(response);

      // Calculate Average
      double total = 0;
      if (data.isNotEmpty) {
        for (var r in data) {
          total += (r['rating'] as num).toDouble();
        }
        _averageRating = total / data.length;
      }

      if (mounted) {
        setState(() {
          _reviews = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reviews: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // NOTE: This method is kept in case you want to re-enable it later,
  // but it is not currently connected to any button.
  void _showAddReviewSheet() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please login to write a review")));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddReviewSheet(
        salonId: widget.salonId,
        onReviewAdded: _fetchReviews,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text("Reviews", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
        children: [
          // Header Stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < _averageRating.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Based on ${_reviews.length} reviews",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Review List
          Expanded(
            child: _reviews.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("No reviews yet", style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _reviews.length,
              separatorBuilder: (context, index) => const Divider(height: 30),
              itemBuilder: (context, index) {
                final review = _reviews[index];
                final profile = review['profiles'] ?? {};
                final name = profile['full_name'] ?? 'Anonymous';
                final date = DateTime.parse(review['created_at']);
                final rating = review['rating'] as int;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          radius: 18,
                          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              Text(DateFormat('MMM d, yyyy').format(date), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text("$rating", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              const Icon(Icons.star, size: 14, color: Colors.green),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (review['comment'] != null && review['comment'].isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        review['comment'],
                        style: GoogleFonts.poppins(color: Colors.black87, height: 1.5),
                      ),
                    ]
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // REMOVED: floatingActionButton block
    );
  }
}

class _AddReviewSheet extends StatefulWidget {
  final int salonId;
  final VoidCallback onReviewAdded;

  const _AddReviewSheet({required this.salonId, required this.onReviewAdded});

  @override
  State<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<_AddReviewSheet> {
  int _selectedRating = 0;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a star rating")));
      return;
    }

    setState(() => _isSubmitting = true);

    final user = Supabase.instance.client.auth.currentUser!;

    try {
      await Supabase.instance.client.from('reviews').insert({
        'salon_id': widget.salonId,
        'user_id': user.id,
        'rating': _selectedRating,
        'comment': _commentCtrl.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context); // Close sheet
        widget.onReviewAdded(); // Refresh parent list
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review submitted!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (e.toString().contains("unique_user_salon_review")) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You have already reviewed this salon.")));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text("Rate your experience", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Star Picker
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => setState(() => _selectedRating = index + 1),
                icon: Icon(
                  index < _selectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 40,
                ),
              );
            }),
          ),

          const SizedBox(height: 20),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Share your experience (optional)",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("Submit Review", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}