import 'package:emojis/emojis.dart';

/// Curated list of construction and project-related emojis
/// Organized by category for easy contractor selection
class ConstructionEmojis {
  // General Construction & Tools
  static const String hammer = Emojis.hammer;
  static const String hammerAndWrench = Emojis.hammerAndWrench;
  static const String wrench = Emojis.wrench;
  static const String screwdriver = '🪛'; // Emojis.screwdriver
  static const String saw = '🪚'; // Saw emoji
  static const String axe = Emojis.axe;
  static const String pick = Emojis.pick;
  static const String toolbox = '🧰'; // Toolbox emoji
  static const String gear = Emojis.gear;
  static const String nut = Emojis.nutAndBolt;

  // Electrical
  static const String lightBulb = Emojis.lightBulb;
  static const String electricPlug = Emojis.electricPlug;
  static const String battery = Emojis.battery;
  static const String lightning = Emojis.highVoltage;
  static const String flashlight = Emojis.flashlight;

  // Plumbing & Water
  static const String droplet = Emojis.droplet;
  static const String shower = Emojis.shower;
  static const String bathtub = Emojis.bathtub;
  static const String toilet = Emojis.toilet;
  static const String sink = Emojis.potableWater;

  // Building Materials
  static const String brick = Emojis.brick;
  static const String wood = Emojis.wood;
  static const String rock = Emojis.rock;
  static const String roller = '🖌️'; // Paint roller emoji
  static const String paintbrush = '🖌️'; // Paintbrush emoji

  // Construction Vehicles & Equipment
  static const String constructionWorker = Emojis.constructionWorker;
  static const String tractor = Emojis.tractor;
  static const String crane = '🏗️'; // Construction crane emoji

  // Home & Rooms
  static const String house = Emojis.house;
  static const String houseWithGarden = Emojis.houseWithGarden;
  static const String door = Emojis.door;
  static const String window = Emojis.window;
  static const String bed = Emojis.bed;
  static const String couch = Emojis.couchAndLamp;
  static const String kitchen = Emojis.potOfFood;

  // Safety & Inspection
  static const String hardHat = Emojis.rescueWorkerSHelmet;
  static const String checkMark = Emojis.checkMark;
  static const String warning = Emojis.warning;
  static const String magnifyingGlass = Emojis.magnifyingGlassTiltedLeft;

  // Financial
  static const String moneyBag = Emojis.moneyBag;
  static const String dollarSign = Emojis.heavyDollarSign;
  static const String creditCard = Emojis.creditCard;
  static const String receipt = Emojis.receipt;
  static const String chart = Emojis.chartIncreasing;

  // Communication & Documentation
  static const String clipboard = Emojis.clipboard;
  static const String memo = Emojis.memo;
  static const String calendar = Emojis.calendar;
  static const String camera = Emojis.camera;
  static const String speechBalloon = Emojis.speechBalloon;

  // Status & Progress
  static const String hourglassNotDone = Emojis.hourglassNotDone;
  static const String hourglassDone = Emojis.hourglassDone;
  static const String rocket = Emojis.rocket;
  static const String party = Emojis.partyPopper;
  static const String trophy = Emojis.trophy;

  /// Get all emojis grouped by category for UI display
  static Map<String, List<EmojiOption>> getCategorizedEmojis() {
    return {
      'General Tools': [
        EmojiOption(hammer, 'Hammer'),
        EmojiOption(hammerAndWrench, 'Hammer & Wrench'),
        EmojiOption(wrench, 'Wrench'),
        EmojiOption(screwdriver, 'Screwdriver'),
        EmojiOption(saw, 'Saw'),
        EmojiOption(axe, 'Axe'),
        EmojiOption(pick, 'Pick'),
        EmojiOption(toolbox, 'Toolbox'),
        EmojiOption(gear, 'Gear'),
        EmojiOption(nut, 'Nut & Bolt'),
      ],
      'Electrical': [
        EmojiOption(lightning, 'Lightning'),
        EmojiOption(lightBulb, 'Light Bulb'),
        EmojiOption(electricPlug, 'Electric Plug'),
        EmojiOption(battery, 'Battery'),
        EmojiOption(flashlight, 'Flashlight'),
      ],
      'Plumbing': [
        EmojiOption(droplet, 'Water Droplet'),
        EmojiOption(shower, 'Shower'),
        EmojiOption(bathtub, 'Bathtub'),
        EmojiOption(toilet, 'Toilet'),
        EmojiOption(sink, 'Sink'),
      ],
      'Materials': [
        EmojiOption(brick, 'Brick'),
        EmojiOption(wood, 'Wood'),
        EmojiOption(rock, 'Rock'),
        EmojiOption(roller, 'Paint Roller'),
        EmojiOption(paintbrush, 'Paintbrush'),
      ],
      'Rooms & Structure': [
        EmojiOption(house, 'House'),
        EmojiOption(houseWithGarden, 'House with Garden'),
        EmojiOption(door, 'Door'),
        EmojiOption(window, 'Window'),
        EmojiOption(bed, 'Bedroom'),
        EmojiOption(couch, 'Living Room'),
        EmojiOption(kitchen, 'Kitchen'),
      ],
      'Financial': [
        EmojiOption(moneyBag, 'Money'),
        EmojiOption(dollarSign, 'Dollar Sign'),
        EmojiOption(creditCard, 'Payment'),
        EmojiOption(receipt, 'Receipt'),
        EmojiOption(chart, 'Budget'),
      ],
      'Other': [
        EmojiOption(constructionWorker, 'Worker'),
        EmojiOption(hardHat, 'Safety'),
        EmojiOption(checkMark, 'Complete'),
        EmojiOption(warning, 'Warning'),
        EmojiOption(clipboard, 'Checklist'),
        EmojiOption(calendar, 'Schedule'),
        EmojiOption(camera, 'Photo'),
        EmojiOption(party, 'Celebration'),
        EmojiOption(trophy, 'Achievement'),
      ],
    };
  }

  /// Get flat list of all emojis for simple selection
  static List<EmojiOption> getAllEmojis() {
    return getCategorizedEmojis().values.expand((list) => list).toList();
  }

  /// Get commonly used milestone emojis (for quick selection)
  static List<EmojiOption> getCommonMilestoneEmojis() {
    return [
      EmojiOption(moneyBag, 'Payment'),
      EmojiOption(hammer, 'Demo'),
      EmojiOption(hammerAndWrench, 'Framing'),
      EmojiOption(lightning, 'Electrical'),
      EmojiOption(droplet, 'Plumbing'),
      EmojiOption(brick, 'Masonry'),
      EmojiOption(roller, 'Painting'),
      EmojiOption(window, 'Windows'),
      EmojiOption(door, 'Doors'),
      EmojiOption(couch, 'Finishing'),
      EmojiOption(checkMark, 'Inspection'),
      EmojiOption(party, 'Complete'),
    ];
  }

  /// Get commonly used change order emojis
  static List<EmojiOption> getCommonChangeOrderEmojis() {
    return [
      EmojiOption(lightning, 'Electrical'),
      EmojiOption(droplet, 'Plumbing'),
      EmojiOption(window, 'Window'),
      EmojiOption(door, 'Door'),
      EmojiOption(lightBulb, 'Lighting'),
      EmojiOption(electricPlug, 'Outlet'),
      EmojiOption(brick, 'Structural'),
      EmojiOption(roller, 'Painting'),
      EmojiOption(wood, 'Carpentry'),
      EmojiOption(dollarSign, 'Cost Change'),
    ];
  }
}

/// Helper class for emoji selection UI
class EmojiOption {
  final String emoji;
  final String label;

  const EmojiOption(this.emoji, this.label);
}
