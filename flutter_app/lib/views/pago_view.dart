import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';

/// Resultado de un pago (simulado).
class ResultadoPago {
  final String metodo; // 'tarjeta' | 'paypal' | 'transferencia' | 'efectivo'
  final String descripcion; // Ej. "Visa •••• 4242"
  final String referencia; // Autorización / referencia
  final String estado; // 'aprobado' | 'pendiente'

  const ResultadoPago(this.metodo, this.descripcion, this.referencia, this.estado);

  bool get pendiente => estado == 'pendiente';

  /// Texto corto para historial y correo.
  String get resumen => '$descripcion · Ref. $referencia${pendiente ? ' (pendiente)' : ''}';

  static String etiqueta(String metodo) => const {
        'tarjeta': 'Tarjeta',
        'paypal': 'PayPal',
        'transferencia': 'Transferencia SPEI',
        'efectivo': 'Efectivo en tienda',
      }[metodo] ??
      metodo;

  static IconData icono(String metodo) => const {
        'tarjeta': Icons.credit_card_rounded,
        'paypal': Icons.account_balance_wallet_rounded,
        'transferencia': Icons.account_balance_rounded,
        'efectivo': Icons.payments_rounded,
      }[metodo] ??
      Icons.payment_rounded;
}

/// Pantalla de pago SIMULADA. No se realiza ningún cargo real ni se guardan
/// datos completos de la tarjeta (solo los últimos 4 dígitos).
///
/// Tarjetas de prueba:
///   4242 4242 4242 4242 → aprobada
///   4000 0000 0000 0002 → rechazada (fondos insuficientes)
class PagoView extends StatefulWidget {
  final double total;
  final String emailUsuario;

  const PagoView({super.key, required this.total, required this.emailUsuario});

  @override
  State<PagoView> createState() => _PagoViewState();
}

class _PagoViewState extends State<PagoView> {
  String _metodo = 'tarjeta';
  bool _procesando = false;
  String? _error;

  // Tarjeta
  final _formTarjeta = GlobalKey<FormState>();
  final _numeroCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _vigenciaCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  int _meses = 1;

  // PayPal
  final _formPaypal = GlobalKey<FormState>();
  late final TextEditingController _paypalCtrl;

  // Transferencia / efectivo
  late final String _referencia;
  static const _clabe = '646 180 1234 5678 9012'; // CLABE ficticia de ejemplo

  @override
  void initState() {
    super.initState();
    _paypalCtrl = TextEditingController(text: widget.emailUsuario);
    _referencia = (10000000 + Random().nextInt(89999999)).toString();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _nombreCtrl.dispose();
    _vigenciaCtrl.dispose();
    _cvvCtrl.dispose();
    _paypalCtrl.dispose();
    super.dispose();
  }

  String get _total => '\$${widget.total.toStringAsFixed(2)} MXN';
  String get _digitos => _numeroCtrl.text.replaceAll(' ', '');

  // ─── Validaciones de tarjeta ───────────────────────────────────────────────

  static String marca(String n) {
    if (n.startsWith('4')) return 'Visa';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(n)) return 'Mastercard';
    if (RegExp(r'^3[47]').hasMatch(n)) return 'American Express';
    return 'Tarjeta';
  }

  /// Algoritmo de Luhn (dígito verificador de tarjetas).
  static bool luhn(String n) {
    if (n.length < 13 || n.length > 19) return false;
    var suma = 0;
    var doble = false;
    for (var i = n.length - 1; i >= 0; i--) {
      var d = int.parse(n[i]);
      if (doble) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      suma += d;
      doble = !doble;
    }
    return suma % 10 == 0;
  }

  String? _validarVigencia(String? v) {
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(v ?? '');
    if (m == null) return 'Formato MM/AA';
    final mes = int.parse(m.group(1)!);
    final anio = 2000 + int.parse(m.group(2)!);
    if (mes < 1 || mes > 12) return 'Mes inválido';
    final ahora = DateTime.now();
    if (anio < ahora.year || (anio == ahora.year && mes < ahora.month)) return 'Tarjeta vencida';
    return null;
  }

  // ─── Pago ──────────────────────────────────────────────────────────────────

  Future<void> _pagar() async {
    setState(() => _error = null);
    if (_metodo == 'tarjeta' && !_formTarjeta.currentState!.validate()) return;
    if (_metodo == 'paypal' && !_formPaypal.currentState!.validate()) return;

    setState(() => _procesando = true);
    await Future.delayed(const Duration(seconds: 2)); // simula la pasarela
    if (!mounted) return;

    final autorizacion = 'AUT-${(100000 + Random().nextInt(899999))}';
    ResultadoPago? resultado;

    switch (_metodo) {
      case 'tarjeta':
        if (_digitos == '4000000000000002') {
          setState(() {
            _procesando = false;
            _error = 'Pago rechazado por el banco: fondos insuficientes (tarjeta de prueba).';
          });
          return;
        }
        final ultimos = _digitos.substring(_digitos.length - 4);
        resultado = ResultadoPago(
          'tarjeta',
          '${marca(_digitos)} •••• $ultimos${_meses > 1 ? ' · $_meses MSI' : ''}',
          autorizacion,
          'aprobado',
        );
        break;
      case 'paypal':
        resultado = ResultadoPago('paypal', 'PayPal (${_paypalCtrl.text.trim()})', autorizacion, 'aprobado');
        break;
      case 'transferencia':
        resultado = ResultadoPago('transferencia', 'Transferencia SPEI', _referencia, 'pendiente');
        break;
      case 'efectivo':
        resultado = ResultadoPago('efectivo', 'Efectivo en tienda', _referencia, 'pendiente');
        break;
    }
    if (mounted) Navigator.pop(context, resultado);
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_procesando,
      child: Scaffold(
        appBar: AppBar(title: const Text('💳 Método de pago')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Aviso de simulación
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.science_rounded, color: Color(0xFFF9A825)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Modo simulación: no se realiza ningún cargo real.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF8D6E00)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Total
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a pagar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                      Text(_total,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkPink)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Selección de método
              const Text('Elige cómo pagar',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: [
                  for (final m in const ['tarjeta', 'paypal', 'transferencia', 'efectivo']) _opcionMetodo(m),
                ],
              ),
              const SizedBox(height: 18),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(key: ValueKey(_metodo), child: _detalleMetodo()),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _procesando ? null : _pagar,
                  icon: _procesando
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_rounded),
                  label: Text(_procesando ? 'Procesando pago...' : _textoBoton),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 14, color: AppTheme.textMuted),
                  SizedBox(width: 4),
                  Text('Pago protegido · solo guardamos los últimos 4 dígitos',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _textoBoton {
    switch (_metodo) {
      case 'paypal':
        return 'Pagar con PayPal $_total';
      case 'transferencia':
        return 'Ya hice la transferencia';
      case 'efectivo':
        return 'Generar ficha de pago';
      default:
        return 'Pagar $_total';
    }
  }

  Widget _opcionMetodo(String m) {
    final sel = _metodo == m;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _procesando ? null : () => setState(() {
            _metodo = m;
            _error = null;
          }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: sel ? AppTheme.softPinkBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? AppTheme.darkPink : AppTheme.cardBorderPink, width: sel ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(ResultadoPago.icono(m), color: sel ? AppTheme.darkPink : AppTheme.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(ResultadoPago.etiqueta(m),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                      color: sel ? AppTheme.darkPink : AppTheme.textDark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detalleMetodo() {
    switch (_metodo) {
      case 'paypal':
        return _paypal();
      case 'transferencia':
        return _transferencia();
      case 'efectivo':
        return _efectivo();
      default:
        return _tarjeta();
    }
  }

  // ── Tarjeta ────────────────────────────────────────────────────────────────
  Widget _tarjeta() {
    final d = _digitos;
    final visibles = d.isEmpty ? '•••• •••• •••• ••••' : _numeroCtrl.text;
    return Form(
      key: _formTarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vista previa de la tarjeta
          Container(
            height: 170,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.darkPink, AppTheme.primaryPink]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: AppTheme.darkPink.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.memory_rounded, color: Colors.white70, size: 32),
                    Text(d.isEmpty ? '' : marca(d),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const Spacer(),
                Text(visibles,
                    style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _nombreCtrl.text.isEmpty ? 'NOMBRE DEL TITULAR' : _nombreCtrl.text.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    Text(_vigenciaCtrl.text.isEmpty ? 'MM/AA' : _vigenciaCtrl.text,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _numeroCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, _FormatoTarjeta()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Número de tarjeta', prefixIcon: Icon(Icons.credit_card)),
            validator: (_) => luhn(_digitos) ? null : 'Número de tarjeta inválido',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nombreCtrl,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nombre del titular', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe el nombre como aparece en la tarjeta' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _vigenciaCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, _FormatoVigencia()],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Vence (MM/AA)', prefixIcon: Icon(Icons.event)),
                  validator: _validarVigencia,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cvvCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'CVV', prefixIcon: Icon(Icons.lock_outline), counterText: ''),
                  validator: (v) {
                    final largo = marca(_digitos) == 'American Express' ? 4 : 3;
                    return (v ?? '').length == largo ? null : '$largo dígitos';
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _meses,
            decoration: const InputDecoration(labelText: 'Pagos', prefixIcon: Icon(Icons.calendar_month_outlined)),
            items: [
              for (final m in const [1, 3, 6, 12])
                DropdownMenuItem(
                  value: m,
                  child: Text(m == 1
                      ? 'Una sola exhibición'
                      : '$m meses sin intereses (\$${(widget.total / m).toStringAsFixed(2)}/mes)'),
                ),
            ],
            onChanged: (v) => setState(() => _meses = v ?? 1),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tarjetas de prueba: 4242 4242 4242 4242 (aprobada) · 4000 0000 0000 0002 (rechazada)',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  // ── PayPal ─────────────────────────────────────────────────────────────────
  Widget _paypal() => Form(
        key: _formPaypal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF003087), size: 36),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Serás redirigido a PayPal para autorizar el pago (simulado).',
                      style: TextStyle(color: Color(0xFF003087)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _paypalCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo de tu cuenta PayPal', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) => (v ?? '').contains('@') ? null : 'Correo no válido',
            ),
          ],
        ),
      );

  // ── Transferencia ──────────────────────────────────────────────────────────
  Widget _transferencia() => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Realiza una transferencia SPEI con estos datos:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              const SizedBox(height: 12),
              _datoCopiable('Banco', 'Banco de Ejemplo (simulado)'),
              _datoCopiable('Beneficiario', 'Mi Tiendita S.A. de C.V.'),
              _datoCopiable('CLABE', _clabe),
              _datoCopiable('Referencia', _referencia),
              _datoCopiable('Monto', _total),
              const SizedBox(height: 8),
              const Text(
                'Tu pedido quedará "pendiente de pago" hasta que se confirme la transferencia.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );

  // ── Efectivo ───────────────────────────────────────────────────────────────
  Widget _efectivo() => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paga en cualquier sucursal o tienda de conveniencia:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              const SizedBox(height: 12),
              _datoCopiable('Referencia de pago', _referencia),
              _datoCopiable('Monto', _total),
              _datoCopiable('Vigencia', '72 horas'),
              const SizedBox(height: 8),
              const Text('Muestra la referencia en caja. Tu pedido quedará pendiente hasta recibir el pago.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ),
      );

  Widget _datoCopiable(String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(etiqueta, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ),
            Expanded(
              child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textDark)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Copiar',
              icon: Icon(Icons.copy_rounded, size: 18, color: AppTheme.darkPink),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: valor.replaceAll(' ', '')));
                mostrarMensaje(context, '$etiqueta copiado');
              },
            ),
          ],
        ),
      );
}

/// Agrupa el número de tarjeta en bloques de 4: 4242 4242 4242 4242
class _FormatoTarjeta extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(' ', '');
    final recortado = d.length > 19 ? d.substring(0, 19) : d;
    final b = StringBuffer();
    for (var i = 0; i < recortado.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(recortado[i]);
    }
    final t = b.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// Inserta la diagonal en la vigencia: 1228 → 12/28
class _FormatoVigencia extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll('/', '');
    if (d.length > 4) d = d.substring(0, 4);
    final t = d.length > 2 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
