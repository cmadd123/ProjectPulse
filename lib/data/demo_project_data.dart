import 'package:cloud_firestore/cloud_firestore.dart';

/// Static demo project data used for the "See a Demo Project" feature
/// shown to new GCs who haven't created any projects yet.
class DemoProjectData {
  static Map<String, dynamic> get project => {
        'project_name': 'Johnson Kitchen Remodel',
        'client_name': 'Sarah Johnson',
        'client_email': 'sarah.johnson@example.com',
        'client_phone': '(555) 987-6543',
        'contractor_business_name': 'Smith Construction',
        'status': 'active',
        'original_cost': 45000.0,
        'current_cost': 47500.0,
        'start_date': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 21))),
        'estimated_end_date':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 35))),
        'milestones_enabled': true,
        'payment_status': 'partial',
        'created_at': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 21))),
        'updated_at': Timestamp.now(),
      };

  static const String demoProjectId = '__demo__';

  static List<Map<String, dynamic>> get milestones => [
        {
          'name': 'Demolition & Prep',
          'description': 'Remove existing cabinets, countertops, and flooring. Prep walls and plumbing.',
          'amount': 8000.0,
          'status': 'approved',
          'order': 0,
          'photo_urls': [
            'https://picsum.photos/seed/demo1/400/300',
            'https://picsum.photos/seed/demo2/400/300',
          ],
        },
        {
          'name': 'Rough-In (Plumbing & Electrical)',
          'description': 'Run new plumbing lines, electrical wiring, and gas line for range.',
          'amount': 12000.0,
          'status': 'approved',
          'order': 1,
          'photo_urls': [
            'https://picsum.photos/seed/demo3/400/300',
          ],
        },
        {
          'name': 'Cabinets & Countertops',
          'description': 'Install custom shaker cabinets and quartz countertops.',
          'amount': 18000.0,
          'status': 'awaiting_approval',
          'order': 2,
          'photo_urls': [
            'https://picsum.photos/seed/demo4/400/300',
            'https://picsum.photos/seed/demo5/400/300',
            'https://picsum.photos/seed/demo6/400/300',
          ],
        },
        {
          'name': 'Final Walkthrough & Punch List',
          'description': 'Final inspection, touch-ups, appliance installation, and client walkthrough.',
          'amount': 9500.0,
          'status': 'pending',
          'order': 3,
          'photo_urls': [],
        },
      ];
}
