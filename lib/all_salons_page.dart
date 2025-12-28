// lib/all_salons_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllSalonsPage extends StatelessWidget {
  const AllSalonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
            "All Salons",
            style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // Fetch ALL salons, newest first
        future: Supabase.instance.client
            .from('salons')
            .select()
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          // 2. Error State
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // 3. Data State
          final salons = snapshot.data ?? [];

          if (salons.isEmpty) {
            return Center(
                child: Text(
                    "No salons added yet.",
                    style: GoogleFonts.poppins(color: Colors.grey)
                )
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: salons.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final salon = salons[index];
              return _SharedSalonCard(
                // Use '??' to provide fallbacks if data is missing in DB
                name: salon['name'] ?? 'Unknown Salon',
                address: salon['address'] ?? 'No address provided',
                distance: salon['distance'] ?? 'Nearby',
                rating: (salon['rating'] as num?)?.toDouble() ?? 5.0,
                imageUrl: salon['image_url'] ?? '',
              );
            },
          );
        },
      ),
    );
  }
}

// Reusable Card Widget
class _SharedSalonCard extends StatelessWidget {
  final String name;
  final String address;
  final String distance;
  final double rating;
  final String imageUrl;

  const _SharedSalonCard({
    required this.name,
    required this.address,
    required this.distance,
    required this.rating,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with Error Handling
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              // If image URL is broken or empty, show icon
              errorBuilder: (_, __, ___) => Container(
                width: 90,
                height: 90,
                color: Colors.grey[300],
                child: const Icon(Icons.store, color: Colors.grey, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Text Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                        distance,
                        style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500)
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                              rating.toString(),
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)
                          ),
                        ],
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