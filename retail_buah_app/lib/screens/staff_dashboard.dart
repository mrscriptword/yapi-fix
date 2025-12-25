import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'home_screen.dart';
import 'login.dart';
import '../widgets/theme_toggle_button.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  int _selectedIndex = 0;
  final dio = Dio();
  List<dynamic> cartItems = [];
  List<dynamic> transactionHistory = [];
  String searchQuery = '';

  String get baseUrl => 'https://vercel-fix-self.vercel.app/api';

  @override
  void initState() {
    super.initState();
    _fetchTransactionHistory();
  }

  Future<void> _fetchTransactionHistory() async {
    try {
      final response = await dio.get('$baseUrl/transactions');
      if (mounted) setState(() => transactionHistory = response.data ?? []);
    } catch (e) {
      if (mounted) _showSnackBar('Gagal memuat riwayat', Colors.red);
    }
  }

  void _addToCart(dynamic product) {
    final productId = product['id'] ?? product['_id'];
    final existingItemIndex = cartItems.indexWhere((item) => (item['id'] ?? item['_id']) == productId);
    final int quantity = product['quantity'] ?? 1;

    setState(() {
      if (existingItemIndex != -1) {
        cartItems[existingItemIndex]['quantity'] += quantity;
      } else {
        cartItems.add({
          ...product,
          'id': productId,
          'quantity': quantity
        });
      }
    });
    _showSnackBar('${product['nama']} ditambah', Colors.cyan);
  }

  Future<void> _checkout() async {
    if (cartItems.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var item in cartItems) {
        final productId = item['id'] ?? item['_id'];
        final harga = item['harga'] ?? 0;
        final qty = item['quantity'] ?? 1;

        await dio.post('$baseUrl/transactions', data: {
          'product_id': productId,
          'product_name': item['nama'],
          'quantity': qty,
          'price': harga,
          'total_price': harga * qty,
          'image_url': item['image_url'] ?? item['gambar'],
        });

        await dio.put('$baseUrl/products/$productId/reduce-stock', data: {'quantity': qty});
      }

      Navigator.pop(context); // Tutup loading
      if (_selectedIndex == 0) Navigator.pop(context); // Tutup Bottom Sheet keranjang jika terbuka
      
      setState(() => cartItems.clear());
      _fetchTransactionHistory();
      _showSnackBar('✅ Transaksi Berhasil!', Colors.green);
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('❌ Gagal Checkout', Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildPenjualanTab(isDark),
          _buildRiwayatTab(isDark),
        ],
      ),
      // Tombol Keranjang Melayang khusus untuk HP
      floatingActionButton: _selectedIndex == 0 && cartItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showCartSheet(context),
              backgroundColor: const Color(0xFF00BCD4),
              icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
              label: Text('${cartItems.length} Produk', style: const TextStyle(color: Colors.white)),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'Toko'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Riwayat'),
        ],
      ),
    );
  }

  // TAB PENJUALAN
  Widget _buildPenjualanTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SearchBar(
            hintText: 'Cari buah segar...',
            onChanged: (value) => setState(() => searchQuery = value),
            leading: const Icon(Icons.search),
            padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
            elevation: const MaterialStatePropertyAll(1),
          ),
        ),
        Expanded(
          child: HomeScreen(
            role: 'staff',
            onAddToCart: _addToCart,
            searchQuery: searchQuery,
          ),
        ),
      ],
    );
  }

  // MODAL KERANJANG UNTUK HP (Bottom Sheet)
  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          int total = cartItems.fold<int>(0, (sum, item) => sum + ((item['harga'] as int) * (item['quantity'] as int)));
          
          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pesanan Saat Ini', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['nama'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item['quantity']} x Rp ${item['harga']}'),
                        trailing: Text('Rp ${item['harga'] * item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        leading: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () {
                            setState(() => cartItems.removeAt(index));
                            setModalState(() {});
                            if (cartItems.isEmpty) Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pembayaran', style: TextStyle(fontSize: 16)),
                      Text('Rp $total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00BCD4))),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BCD4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('PROSES BAYAR', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        });
      },
    );
  }

  // TAB RIWAYAT
  Widget _buildRiwayatTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _fetchTransactionHistory,
      child: transactionHistory.isEmpty
          ? const Center(child: Text("Belum ada riwayat transaksi"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: transactionHistory.length,
              itemBuilder: (context, index) {
                final trx = transactionHistory[index];
                return Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.cyan),
                    ),
                    title: Text(trx['product_name'] ?? 'Produk', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Jumlah: ${trx['quantity']} pcs'),
                        Text(trx['tanggal']?.toString().split('T')[0] ?? '', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    trailing: Text('Rp ${trx['total_price']}', style: const TextStyle(color: Colors.pink, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                );
              },
            ),
    );
  }
}
