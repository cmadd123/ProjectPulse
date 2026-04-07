// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ProjectPulse';

  @override
  String get home => 'Home';

  @override
  String get photos => 'Photos';

  @override
  String get chat => 'Chat';

  @override
  String get milestones => 'Milestones';

  @override
  String get more => 'More';

  @override
  String get schedule => 'Schedule';

  @override
  String get team => 'Team';

  @override
  String get estimates => 'Estimates';

  @override
  String get portfolio => 'Portfolio';

  @override
  String get profile => 'Profile';

  @override
  String get logout => 'Logout';

  @override
  String get projects => 'Projects';

  @override
  String get notifications => 'Notifications';

  @override
  String get today => 'Today';

  @override
  String get todaySchedule => 'Today\'s Schedule';

  @override
  String get noScheduleToday => 'No work scheduled today';

  @override
  String get allCaughtUp => 'All caught up! No action items right now.';

  @override
  String get noProjectsYet => 'No projects yet';

  @override
  String get yourGcWillAssign => 'Your GC will assign you to projects';

  @override
  String get projectsAssignedWillShow =>
      'Projects assigned to your team will show up here';

  @override
  String get active => 'Active';

  @override
  String get completed => 'Completed';

  @override
  String get pending => 'Pending';

  @override
  String get inProgress => 'In Progress';

  @override
  String get awaitingApproval => 'Awaiting Approval';

  @override
  String get approved => 'Approved';

  @override
  String get notStarted => 'Not Started';

  @override
  String get startWorking => 'Start Working';

  @override
  String get markComplete => 'Mark Complete';

  @override
  String get approveAndPay => 'Approve & Pay';

  @override
  String get reviewAndApprove => 'Review & Approve';

  @override
  String get payWithCard => 'Pay with Card';

  @override
  String get payAnotherWay => 'Pay Another Way';

  @override
  String get markAsPaid => 'Mark as Paid';

  @override
  String get confirmPayment => 'Confirm Payment';

  @override
  String get milestoneApproved => 'Milestone Approved!';

  @override
  String get amountDue => 'Amount Due';

  @override
  String get processingFeeApplies =>
      'Card, bank transfer, or wallet · processing fee applies';

  @override
  String get addExpense => 'Add Expense';

  @override
  String get saveExpense => 'Save Expense';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get totalExpenses => 'Total Expenses';

  @override
  String get scanReceipt => 'Scan a Receipt';

  @override
  String get scanReceiptTip =>
      'Take a photo and we\'ll fill in the vendor and amount for you';

  @override
  String get orEnterManually => 'or enter manually';

  @override
  String get amount => 'Amount';

  @override
  String get vendor => 'Vendor';

  @override
  String get description => 'Description';

  @override
  String get category => 'Category';

  @override
  String get materials => 'Materials';

  @override
  String get tools => 'Tools';

  @override
  String get permits => 'Permits';

  @override
  String get labor => 'Labor';

  @override
  String get other => 'Other';

  @override
  String get logTime => 'Log Time';

  @override
  String get hours => 'Hours';

  @override
  String get date => 'Date';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get done => 'Done';

  @override
  String get skip => 'Skip';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get search => 'Search';

  @override
  String get send => 'Send';

  @override
  String get share => 'Share';

  @override
  String get worker => 'Worker';

  @override
  String get foreman => 'Foreman';

  @override
  String get owner => 'Owner';

  @override
  String get crewSchedule => 'Crew Schedule';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get noPhotosYet => 'No photos posted yet';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get sendAMessage => 'Send a message';

  @override
  String get projectPhases => 'Project Phases';

  @override
  String milestonesCompleted(int completed, int total) {
    return '$completed of $total milestones completed';
  }

  @override
  String daysLeft(int days) {
    return '$days days left';
  }

  @override
  String daysOverdue(int days) {
    return '$days days overdue';
  }

  @override
  String get howWasThisPaid => 'How was this paid?';

  @override
  String get zelle => 'Zelle';

  @override
  String get check => 'Check';

  @override
  String get venmo => 'Venmo';

  @override
  String get cashApp => 'Cash App';

  @override
  String get cash => 'Cash';

  @override
  String get referenceOptional => 'Reference # (optional)';
}
