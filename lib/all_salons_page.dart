// lib/all_salons_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllSalonsPage extends StatelessWidget {
  const AllSalonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("All Salons", style: GoogleFonts.poppins(color: Colors.white)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // Fetch ALL salons (no limit)
        future: Supabase.instance.client.from('salons').select().order('id'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          final salons = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: salons.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final salon = salons[index];
              return _SharedSalonCard(
                name: salon['name'],
                address: salon['address'],
                distance: salon['distance'],
                rating: (salon['rating'] as num).toDouble(),
                imageUrl: salon['image_url'],
              );
            },
          );
        },
      ),
    );
  }
}

// Reusable Card Widget (Copy of your design)
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey, child: const Icon(Icons.spa, color: Colors.white54, size: 40)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text(address, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.orange),
                    Text(" $distance", style: const TextStyle(color: Colors.orange, fontSize: 13)),
                    const Spacer(),
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text("$rating", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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