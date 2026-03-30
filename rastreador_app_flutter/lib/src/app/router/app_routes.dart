class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';

  static const sellerHome = '/seller';
  static String sellerDetails(int scheduleId) => '/seller/schedules/$scheduleId';

  static const adminHome = '/admin';
  static String adminDetails(int scheduleId) => '/admin/schedules/$scheduleId';

  static const technicianHome = '/technician';
  static String technicianDetails(int scheduleId) => '/technician/jobs/$scheduleId';
}
