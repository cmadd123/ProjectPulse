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
      name: 'Pool Build',
      description: 'Standard 5-phase pool construction',
      milestones: [
        MilestoneTemplateItem(
          name: 'Excavation',
          description: 'Dig pool shell, grade site, haul away dirt.',
          percentage: 15,
        ),
        MilestoneTemplateItem(
          name: 'Steel & Plumbing',
          description: 'Install rebar cage, plumbing lines, pool equipment pad.',
          percentage: 20,
        ),
        MilestoneTemplateItem(
          name: 'Gunite / Shotcrete',
          description: 'Spray concrete shell. Cure period begins.',
          percentage: 25,
        ),
        MilestoneTemplateItem(
          name: 'Tile, Coping & Decking',
          description: 'Install waterline tile, coping stones, and pool deck.',
          percentage: 25,
        ),
        MilestoneTemplateItem(
          name: 'Plaster & Fill',
          description: 'Apply interior finish, fill pool, start equipment, final walkthrough.',
          percentage: 15,
        ),
      ],
    ),
    MilestoneTemplate(
      name: 'Landscape Design/Build',
      description: 'Standard 4-phase landscape transformation',
      milestones: [
        MilestoneTemplateItem(
          name: 'Site Prep & Demolition',
          description: 'Clear existing landscape, grade site, install drainage.',
          percentage: 20,
        ),
        MilestoneTemplateItem(
          name: 'Hardscape',
          description: 'Install retaining walls, patio, walkways, and outdoor structures.',
          percentage: 35,
        ),
        MilestoneTemplateItem(
          name: 'Planting & Irrigation',
          description: 'Install irrigation system, trees, shrubs, and ground cover.',
          percentage: 30,
        ),
        MilestoneTemplateItem(
          name: 'Lighting & Finish',
          description: 'Install landscape lighting, mulch, final grading, and walkthrough.',
          percentage: 15,
        ),
      ],
    ),
    MilestoneTemplate(
      name: 'Cabinet Installation',
      description: 'Standard 3-phase custom cabinet project',
      milestones: [
        MilestoneTemplateItem(
          name: 'Design & Fabrication',
          description: 'Finalize design, order materials, build cabinets in shop.',
          percentage: 40,
        ),
        MilestoneTemplateItem(
          name: 'Installation',
          description: 'Deliver and install cabinets, adjust doors and drawers.',
          percentage: 40,
        ),
        MilestoneTemplateItem(
          name: 'Hardware & Punch List',
          description: 'Install hardware, touch-up finish, final walkthrough.',
          percentage: 20,
        ),
      ],
    ),
    MilestoneTemplate(
      name: 'Flooring',
      description: 'Standard 3-phase flooring project',
      milestones: [
        MilestoneTemplateItem(
          name: 'Removal & Prep',
          description: 'Remove existing flooring, level subfloor, prep for install.',
          percentage: 25,
        ),
        MilestoneTemplateItem(
          name: 'Installation',
          description: 'Install new flooring throughout specified areas.',
          percentage: 50,
        ),
        MilestoneTemplateItem(
          name: 'Trim & Cleanup',
          description: 'Install transitions, baseboards, final cleanup and walkthrough.',
          percentage: 25,
        ),
      ],
    ),
    MilestoneTemplate(
      name: 'Addition / New Build',
      description: 'Standard 5-phase room addition or new construction',
      milestones: [
        MilestoneTemplateItem(
          name: 'Foundation',
          description: 'Excavate, form, and pour foundation. Inspection.',
          percentage: 15,
        ),
        MilestoneTemplateItem(
          name: 'Framing & Dry-In',
          description: 'Frame walls and roof, install windows, doors, and roofing.',
          percentage: 25,
        ),
        MilestoneTemplateItem(
          name: 'Rough Mechanicals',
          description: 'Electrical, plumbing, HVAC rough-in. Inspections.',
          percentage: 20,
        ),
        MilestoneTemplateItem(
          name: 'Drywall & Finishes',
          description: 'Hang and finish drywall, paint, install cabinets and flooring.',
          percentage: 25,
        ),
        MilestoneTemplateItem(
          name: 'Final & CO',
          description: 'Fixtures, appliances, trim, punch list. Certificate of Occupancy.',
          percentage: 15,
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
