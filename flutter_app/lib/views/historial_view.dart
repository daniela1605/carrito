import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repository/database_helper.dart';
import '../theme/app_theme.dart';
import 'notificaciones_view.dart';

class HistorialView extends StatefulWidget {
  final int usuarioId;
  final bool esAdmin;

  const HistorialView({super.key, required this.usuarioId, this.esAdmin = false});

  @override
  State<HistorialView> createState() => _HistorialViewState();
}

class _HistorialViewState extends State<HistorialView> {
  List<Map<String, dynamic>> _historial = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final data = widget.esAdmin
        ? await DatabaseHelper.instance.obtenerTodoHistorial()
        : await DatabaseHelper.instance.obtenerHistorial(widget.usuarioId);
    if (mounted) setState(() { _historial = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softPinkBg,
      appBar: AppBar(
        title: Text(widget.esAdmin ? '📊 Historial General' : '📋 Mis Compras'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: Icon(Icons.refresh_rounded, color: AppTheme.darkPink),
            onPressed: _cargar,
          ),
          const NotificacionesBoton(),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.darkPink))
          : _historial.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 80, color: Colors.pink[200]),
                      const SizedBox(height: 16),
                      const Text('No hay compras aún', style: TextStyle(color: AppTheme.textMuted, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _historial.length,
                  itemBuilder: (_, i) {
                    final h = _historial[i];
                    final fecha = DateTime.tryParse(h['fecha'] as String? ?? '') ?? DateTime.now();
                    final fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
                    final total = (h['total'] as num).toDouble();
                    List productos = [];
                    try { productos = jsonDecode(h['productos_json'] as String? ?? '[]'); } catch (_) {}

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.cardBorderPink,
                          child: Icon(Icons.receipt_long_rounded, color: AppTheme.darkPink),
                        ),
                        title: Text('\$${total.toStringAsFixed(2)} MXN',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkPink, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fechaStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            if (widget.esAdmin && h['usuario_nombre'] != null)
                              Text('👤 ${h['usuario_nombre']} (${h['usuario_email']})',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            if (h['detalle_pago'] != null)
                              Text('💳 ${h['detalle_pago']}',
                                  style: TextStyle(
                                      color: h['estado_pago'] == 'pendiente' ? const Color(0xFFF57C00) : AppTheme.textMuted,
                                      fontSize: 11)),
                            if (h['transaction_id'] != null)
                              Text('ID: ${h['transaction_id']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Table(
                              columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(2)},
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: AppTheme.cardBorderPink.withOpacity(0.5)),
                                  children: const [
                                    Padding(padding: EdgeInsets.all(6), child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(6), child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(6), child: Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                ),
                                ...productos.map((p) {
                                  final precio = (p['precio'] as num).toDouble();
                                  final cant = (p['cantidad'] as num).toInt();
                                  final sub = precio * cant;
                                  return TableRow(children: [
                                    Padding(padding: const EdgeInsets.all(6),
                                        child: Text(p['nombre'] ?? p['nombre_product'] ?? '', style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                    Padding(padding: const EdgeInsets.all(6), child: Text('$cant', style: const TextStyle(fontSize: 11))),
                                    Padding(padding: const EdgeInsets.all(6),
                                        child: Text('\$${sub.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: AppTheme.darkPink, fontWeight: FontWeight.bold))),
                                  ]);
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
