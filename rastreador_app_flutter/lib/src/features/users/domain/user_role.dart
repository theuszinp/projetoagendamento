enum UserRole {
  seller,
  admin,
  technician,
  unknown;

  static UserRole fromApi(String raw) {
    final normalized = raw.trim().toLowerCase();

    switch (normalized) {
      case 'seller':
      case 'vendedor':
        return UserRole.seller;
      case 'admin':
      case 'administrador':
        return UserRole.admin;
      case 'tech':
      case 'tecnico':
      case 'técnico':
      case 'technician':
        return UserRole.technician;
      default:
        return UserRole.unknown;
    }
  }

  String get apiValue {
    switch (this) {
      case UserRole.seller:
        return 'seller';
      case UserRole.admin:
        return 'admin';
      case UserRole.technician:
        return 'tech';
      case UserRole.unknown:
        return 'seller';
    }
  }

  String get label {
    switch (this) {
      case UserRole.seller:
        return 'Vendedor';
      case UserRole.admin:
        return 'Admin';
      case UserRole.technician:
        return 'Instalador';
      case UserRole.unknown:
        return 'Indefinido';
    }
  }
}
