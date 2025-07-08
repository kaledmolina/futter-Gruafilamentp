import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import 'order_detail_screen.dart'; // Importar la nueva pantalla

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = _apiService.getOrders();
    });
  }

  void _logout() async {
    await AuthService.instance.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Órdenes'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tienes órdenes asignadas.'));
          }
          
          final orders = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _loadOrders(),
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text('Orden #${order['numero_orden']}'),
                    subtitle: Text('Cliente: ${order['nombre_cliente']}\nEstado: ${order['status']}'),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      child: const Text('Ver'),
                      onPressed: () async {
                        // Navega a la pantalla de detalles y espera un resultado
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(orderId: order['id']),
                          ),
                        );
                        // Si el resultado es 'refresh', recarga la lista de órdenes
                        if (result == 'refresh' && mounted) {
                          _loadOrders();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}