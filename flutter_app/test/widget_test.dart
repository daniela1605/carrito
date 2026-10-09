import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/security_service.dart';

void main() {
  group('Política de contraseñas por rol', () {
    test('el administrador exige contraseña más fuerte', () {
      expect(PoliticaRol.admin.validarPassword('password123'), isNotNull);
      expect(PoliticaRol.admin.validarPassword('Segura#2026x'), isNull);
    });

    test('el comprador acepta letras y números', () {
      expect(PoliticaRol.lector.validarPassword('password123'), isNull);
      expect(PoliticaRol.lector.validarPassword('corta1'), isNotNull);
    });
  });

  test('los códigos OTP tienen 6 dígitos', () {
    final c = SecurityService.generarCodigo();
    expect(c.length, 6);
    expect(SecurityService.compararCodigo(c, SecurityService.hashCodigo(c)), isTrue);
  });
}
