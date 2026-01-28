class MilestoneTemplate {
  final String name;
  final String description;
  final List<MilestoneTemplateItem> milestones;

  MilestoneTemplate({
    required this.name,
    required this.description,
    required this.milestones,
  });
}

class MilestoneTemplateItem {
  final String name;
  final String description;
  final double percentage;

  MilestoneTemplateItem({
    required this.name,
    required this.description,
    required this.percentage,
  });
}

class MilestoneTemplates {
  static final List<MilestoneTemplate> templates = [
    MilestoneTemplate(
      name: 'Kitchen Remodel',
      description: 'Standard 4-phase kitchen renovation',
      milestones: [
        MilestoneTemplateItem(
          name: 'Demo & Prep',
          description: 'Remove old cabinets, countertops, and appliances. Dispose of debris.',
          percentage: 20,
        ),
        MilestoneTemplateItem(
          name: 'Rough Work',
          description: 'Install electrical, plumbing, HVAC. Inspect and approve rough-in work.',
          percentage: 30,
        ),
        MilestoneTemplateItem(
          name: 'Cabinets & Finishes',
          description: 'Install cabinets, countertops, backsplash, and flooring.',
          percentage: 30,
        ),
        MilestoneTemplateItem(
          name: 'Final Walkthrough',
          description: 'Install appliances, fixtures, trim. Final inspection and punch list.',
          percentage: 20,
        ),
      ],
    ),
    MilestoneTemplate(
      name: 'Bathroom Remodel',
      description: 'Standard 3-phase bathroom renovation',
      milestones: [
        MilestoneTemplateItem(
          name: 'Demo & Rough-In',
          description: 'Demo old fixtures, tile, and flooring. Rough plumbing and electrical.',
          percentage: 35,
        ),
        MilestoneTemplateItem(
          name: 'Tile & Fixtures',
          description: 'Install tile, vanity, toilet, shower/tub, and flooring.',
          percentage: 40,
        ),
        MilestoneTemplateItem(
          name: 'Final Touches',
          description: 'Paint, trim, mirrors, accessories. Final walkthrough.',
          percentage: 25,
        ),
      ],
    ),
    MilestoneTemplate(
      name: 'Roofing',
      description: 'Standard 3-phase roofing project',
      milestones: [
        MilestoneTemplateItem(
          name: 'Tear-Off & Prep',
          description: 'Remove old shingles and felt. Inspect decking, make repairs.',
          percentage: 25,
        ),
        MilestoneTemplateItem(
          name: 'Installation',
          description: 'Install underlayment, drip edge, flashing, and new shingles.',
          percentage: 50,
        ),
        MilestoneTemplateItem(
          name: 'Cleanup & Inspection',
          description: 'Final inspection, nail sweep, haul away debris.',
          percentage: 25,
        ),
      ],
    ),
    MilestoneTemplate(
      name: 'Deck Build',
      description: 'Standard 3-phase deck construction',
      milestones: [
        MilestoneTemplateItem(
          name: 'Foundation & Framing',
          description: 'Dig footings, pour concrete, install posts and beams.',
          percentage: 40,
        ),
        MilestoneTemplateItem(
          name: 'Decking & Railings',
          description: 'Install joists, decking boards, stairs, and railings.',
          percentage: 40,
        ),
        MilestoneTemplateItem(
          name: 'Finish & Seal',
          description: 'Sand, stain/seal, final inspection.',
          percentage: 20,
        ),
      ],
    ),
    MilestoneTemplate(
      name: 'Custom',
      description: 'Create your own milestone structure',
      milestones: [
        MilestoneTemplateItem(
          name: 'Phase 1',
          description: 'First phase of work',
          percentage: 25,
        ),
        MilestoneTemplateItem(
          name: 'Phase 2',
          description: 'Second phase of work',
          percentage: 25,
        ),
        MilestoneTemplateItem(
          name: 'Phase 3',
          description: 'Third phase of work',
          percentage: 25,
        ),
        MilestoneTemplateItem(
          name: 'Final Phase',
          description: 'Final walkthrough and completion',
          percentage: 25,
        ),
      ],
    ),
  ];

  static MilestoneTemplate? getTemplateByName(String name) {
    try {
      return templates.firstWhere((t) => t.name == name);
    } catch (e) {
      return null;
    }
  }
}
