import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'barber_shop_details_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Listen to search changes to trigger UI updates
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(),
          _buildSearchAndTabHeader(),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildUserList(),
            _buildShopList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BarberShopDetailsPage()),
        ),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Shop", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // --- 1. SLEEK SLIVER APP BAR ---
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      actions: [
        IconButton(
          onPressed: () => _supabase.auth.signOut(),
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
        )
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text("Admin Panel",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
        background: Stack(
          children: [
            Positioned(
              right: -20, top: -20,
              child: Icon(Icons.admin_panel_settings, size: 150, color: Colors.white.withOpacity(0.05)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 60, left: 20),
              child: Row(
                children: [
                  _buildStatTile("Users", "profiles"),
                  const SizedBox(width: 24),
                  _buildStatTile("Salons", "barber_shops"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. SEARCH & TAB HEADER ---
  Widget _buildSearchAndTabHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search by name or role...",
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(onPressed: () => _searchCtrl.clear(), icon: const Icon(Icons.cancel, size: 20))
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: Colors.orange,
              tabs: const [
                Tab(text: "Management"),
                Tab(text: "Directory"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. STAT TILE ---
  Widget _buildStatTile(String label, String table) {
    return FutureBuilder(
      future: _supabase.from(table).count(),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${snapshot.data ?? '...'}",
                style: const TextStyle(color: Colors.orange, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        );
      },
    );
  }

  // --- 4. USER LIST (Management Tab) ---
  Widget _buildUserList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('profiles').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.orange));

        final filteredUsers = snapshot.data!.where((u) {
          final name = (u['full_name'] ?? "").toLowerCase();
          final type = (u['user_type'] ?? "").toLowerCase();
          return name.contains(_searchQuery) || type.contains(_searchQuery);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: Text(user['full_name']?[0] ?? "U", style: const TextStyle(color: Colors.orange)),
                ),
                title: Text(user['full_name'] ?? "No Name", style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(user['user_type'] ?? "Customer"),
                trailing: _buildRoleBadge(user['user_type']),
                onTap: () => _showUserActionSheet(user),
              ),
            );
          },
        );
      },
    );
  }

  // --- 5. SHOP LIST (Directory Tab) ---
  Widget _buildShopList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('barber_shops').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.orange));

        final filteredShops = snapshot.data!.where((s) =>
            s['name'].toLowerCase().contains(_searchQuery)
        ).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredShops.length,
          itemBuilder: (context, index) {
            final shop = filteredShops[index];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[200],
                        image: (shop['image_urls'] != null && (shop['image_urls'] as List).isNotEmpty)
                            ? DecorationImage(image: NetworkImage(shop['image_urls'][0]), fit: BoxFit.cover)
                            : null,
                      ),
                      child: (shop['image_urls'] == null || (shop['image_urls'] as List).isEmpty)
                          ? const Icon(Icons.storefront, color: Colors.grey) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text(shop['address'] ?? "No Address", style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_square, color: Colors.orange),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => BarberShopDetailsPage(shopId: shop['id']),
                      )),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- HELPERS: UI ELEMENTS ---

  Widget _buildRoleBadge(String? role) {
    Color color = Colors.blue;
    if (role?.toLowerCase() == 'admin') color = Colors.red;
    if (role?.toLowerCase() == 'owner') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(role ?? 'Customer', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showUserActionSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['full_name'] ?? "User Options", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.blue),
              title: const Text("Change User Role"),
              onTap: () {
                Navigator.pop(context);
                _showRolePicker(user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text("Suspend Account", style: TextStyle(color: Colors.red)),
              onTap: () {
                // Implement ban logic here
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRolePicker(Map<String, dynamic> user) {
    final roles = ['Customer', 'Barber', 'Owner', 'Admin'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select New Role"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: roles.map((role) => ListTile(
            title: Text(role),
            onTap: () async {
              await _supabase.from('profiles').update({'user_type': role}).eq('id', user['id']);
              if (mounted) Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }
}