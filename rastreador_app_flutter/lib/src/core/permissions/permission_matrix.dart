import '../../features/users/domain/user_role.dart';
import 'app_permission.dart';

const Map<UserRole, Set<AppPermission>> rolePermissions =
    <UserRole, Set<AppPermission>>{
  UserRole.seller: <AppPermission>{
    AppPermission.createSchedule,
    AppPermission.viewOwnSchedules,
    AppPermission.viewOwnScheduleHistory,
  },
  UserRole.admin: <AppPermission>{
    AppPermission.approveSchedule,
    AppPermission.rejectSchedule,
    AppPermission.reassignSchedule,
    AppPermission.editAnySchedule,
    AppPermission.viewAllSchedules,
    AppPermission.manageUsers,
    AppPermission.viewReports,
    AppPermission.addInternalNotes,
  },
  UserRole.technician: <AppPermission>{
    AppPermission.viewAssignedSchedules,
    AppPermission.updateTechnicalStatus,
    AppPermission.requestReschedule,
    AppPermission.uploadTechnicalEvidence,
  },
  UserRole.unknown: <AppPermission>{},
};

bool hasPermission(UserRole role, AppPermission permission) {
  return rolePermissions[role]?.contains(permission) ?? false;
}
