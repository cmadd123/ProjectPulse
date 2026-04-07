// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'ProjectPulse';

  @override
  String get home => 'Inicio';

  @override
  String get photos => 'Fotos';

  @override
  String get chat => 'Chat';

  @override
  String get milestones => 'Fases';

  @override
  String get more => 'Más';

  @override
  String get schedule => 'Horario';

  @override
  String get team => 'Equipo';

  @override
  String get estimates => 'Presupuestos';

  @override
  String get portfolio => 'Portafolio';

  @override
  String get profile => 'Perfil';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get projects => 'Proyectos';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get today => 'Hoy';

  @override
  String get todaySchedule => 'Horario de hoy';

  @override
  String get noScheduleToday => 'No hay trabajo programado hoy';

  @override
  String get allCaughtUp => '¡Todo al día! No hay tareas pendientes.';

  @override
  String get noProjectsYet => 'Sin proyectos aún';

  @override
  String get yourGcWillAssign => 'Tu contratista te asignará proyectos';

  @override
  String get projectsAssignedWillShow =>
      'Los proyectos asignados aparecerán aquí';

  @override
  String get active => 'Activo';

  @override
  String get completed => 'Completado';

  @override
  String get pending => 'Pendiente';

  @override
  String get inProgress => 'En progreso';

  @override
  String get awaitingApproval => 'Esperando aprobación';

  @override
  String get approved => 'Aprobado';

  @override
  String get notStarted => 'Sin comenzar';

  @override
  String get startWorking => 'Comenzar trabajo';

  @override
  String get markComplete => 'Marcar completo';

  @override
  String get approveAndPay => 'Aprobar y pagar';

  @override
  String get reviewAndApprove => 'Revisar y aprobar';

  @override
  String get payWithCard => 'Pagar con tarjeta';

  @override
  String get payAnotherWay => 'Pagar de otra forma';

  @override
  String get markAsPaid => 'Marcar como pagado';

  @override
  String get confirmPayment => 'Confirmar pago';

  @override
  String get milestoneApproved => '¡Fase aprobada!';

  @override
  String get amountDue => 'Monto a pagar';

  @override
  String get processingFeeApplies =>
      'Tarjeta, transferencia o wallet · aplica cargo por procesamiento';

  @override
  String get addExpense => 'Agregar gasto';

  @override
  String get saveExpense => 'Guardar gasto';

  @override
  String get exportCsv => 'Exportar CSV';

  @override
  String get totalExpenses => 'Gastos totales';

  @override
  String get scanReceipt => 'Escanear recibo';

  @override
  String get scanReceiptTip =>
      'Toma una foto y llenamos el vendedor y monto por ti';

  @override
  String get orEnterManually => 'o ingresa manualmente';

  @override
  String get amount => 'Monto';

  @override
  String get vendor => 'Vendedor';

  @override
  String get description => 'Descripción';

  @override
  String get category => 'Categoría';

  @override
  String get materials => 'Materiales';

  @override
  String get tools => 'Herramientas';

  @override
  String get permits => 'Permisos';

  @override
  String get labor => 'Mano de obra';

  @override
  String get other => 'Otro';

  @override
  String get logTime => 'Registrar horas';

  @override
  String get hours => 'Horas';

  @override
  String get date => 'Fecha';

  @override
  String get camera => 'Cámara';

  @override
  String get gallery => 'Galería';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get back => 'Atrás';

  @override
  String get next => 'Siguiente';

  @override
  String get done => 'Listo';

  @override
  String get skip => 'Omitir';

  @override
  String get close => 'Cerrar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get search => 'Buscar';

  @override
  String get send => 'Enviar';

  @override
  String get share => 'Compartir';

  @override
  String get worker => 'Trabajador';

  @override
  String get foreman => 'Capataz';

  @override
  String get owner => 'Dueño';

  @override
  String get crewSchedule => 'Horario del equipo';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signOutConfirm => '¿Estás seguro que quieres cerrar sesión?';

  @override
  String get noPhotosYet => 'No hay fotos aún';

  @override
  String get noMessagesYet => 'No hay mensajes aún';

  @override
  String get sendAMessage => 'Enviar un mensaje';

  @override
  String get projectPhases => 'Fases del proyecto';

  @override
  String milestonesCompleted(int completed, int total) {
    return '$completed de $total fases completadas';
  }

  @override
  String daysLeft(int days) {
    return '$days días restantes';
  }

  @override
  String daysOverdue(int days) {
    return '$days días de retraso';
  }

  @override
  String get howWasThisPaid => '¿Cómo se pagó?';

  @override
  String get zelle => 'Zelle';

  @override
  String get check => 'Cheque';

  @override
  String get venmo => 'Venmo';

  @override
  String get cashApp => 'Cash App';

  @override
  String get cash => 'Efectivo';

  @override
  String get referenceOptional => '# de referencia (opcional)';
}
