class RegistrationData {
  // Step 1: Personal Info
  String? firstName;
  String? lastName;
  int? birthMonth;
  int? birthDay;
  int? birthYear;
  String? gender;
  String? race;
  String? ethnicity;

  // Step 2: Contact Info
  String? email;
  String? phoneNumber;
  String? address;

  // Step 3: Work Info
  String? union;
  int? unionId; // Actual backend union ID
  String? status; // Active or Retired
  String? rank;

  // Step 4: Health Info
  int? heightFeet;
  int? heightInches;
  int? weight;
  List<String> chronicConditions = [];
  String? otherConditions;
  bool? hasHighBloodPressure;
  String? medications;
  String? smokingStatus;
  bool? onBPMedication;
  int? missedDoses;

  // Consent
  String? initials;
  bool consentAgreed = false;

  // Step 5: Lifestyle (completed after first reading)
  int? exerciseDaysPerWeek;
  int? exerciseMinutesPerSession;
  Map<String, String> foodFrequency = {};
  String? financialStress;
  String? stressLevel;
  String? loneliness;
  int? sleepQuality;

  // Status
  RegistrationStatus registrationStatus = RegistrationStatus.notStarted;
  CuffRequestStatus cuffRequestStatus = CuffRequestStatus.none;
  bool lifestyleCompleted = false;

  DateTime? get dateOfBirth {
    if (birthMonth != null && birthDay != null && birthYear != null) {
      return DateTime(birthYear!, birthMonth!, birthDay!);
    }
    return null;
  }

  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  String get heightDisplay {
    if (heightFeet != null && heightInches != null) {
      return "$heightFeet' $heightInches\"";
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'race': race,
      'ethnicity': ethnicity,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'union': union,
      'unionId': unionId,
      'status': status,
      'rank': rank,
      'heightFeet': heightFeet,
      'heightInches': heightInches,
      'weight': weight,
      'chronicConditions': chronicConditions,
      'otherConditions': otherConditions,
      'hasHighBloodPressure': hasHighBloodPressure,
      'medications': medications,
      'smokingStatus': smokingStatus,
      'onBPMedication': onBPMedication,
      'missedDoses': missedDoses,
      'initials': initials,
      'consentAgreed': consentAgreed,
      'exerciseDaysPerWeek': exerciseDaysPerWeek,
      'exerciseMinutesPerSession': exerciseMinutesPerSession,
      'foodFrequency': foodFrequency,
      'financialStress': financialStress,
      'stressLevel': stressLevel,
      'loneliness': loneliness,
      'sleepQuality': sleepQuality,
    };
  }
}

enum RegistrationStatus {
  notStarted,
  inProgress,
  pendingApproval,
  approved,
  rejected,
  completed,
}

enum CuffRequestStatus {
  none,
  requested,
  approved,
  shipped,
  received,
}

// Constants for form options
class RegistrationOptions {
  static const List<String> genders = [
    'Male',
    'Female',
    'Prefer not to say',
  ];

  static const List<String> races = [
    'African American',
    'American Indian',
    'Asian',
    'Pacific Islander',
    'White',
    'Other',
  ];

  static const List<String> ethnicities = [
    'Hispanic or Latino',
    'Not Hispanic or Latino',
    'Other',
  ];

  static const List<String> unions = [
    'UFOA',
    'UFA',
    'UFADBA',
    'LBA',
    'Mount Sinai',
    'Other',
  ];

  static const List<String> statuses = [
    'Active',
    'Retired',
  ];

  static const List<String> ranks = [
    'Lieutenant',
    'Captain',
    'Battalion Chief',
    'Firefighter',
    'Fire Alarm Dispatcher',
    'Supervising Fire Alarm Dispatcher',
    'Chief Dispatcher',
    'Supervising Fire Marshal',
    'Deputy Chief',
    'Staff Chief',
    'Other',
  ];

  static const List<String> chronicConditionOptions = [
    'Asthma',
    'High Blood Pressure',
    'COPD',
    'Diabetes',
    'No chronic conditions',
    'Other',
  ];

  static const List<String> smokingStatuses = [
    'Current smoker',
    'Former smoker',
    'No significant smoking history',
  ];

  static const List<String> financialStressOptions = [
    'Very hard',
    'Somewhat hard',
    'Not hard at all',
  ];

  static const List<String> stressLevelOptions = [
    'Not at all',
    'A little bit',
    'Somewhat',
    'Quite a bit',
    'Very much',
  ];

  static const List<String> lonelinessOptions = [
    'Never',
    'Rarely',
    'Sometimes',
    'Often',
    'Always',
  ];

  static const List<int> exerciseDaysOptions = [0, 1, 2, 3, 4, 5, 6, 7];

  static const List<int> exerciseMinutesOptions = [
    0, 10, 20, 30, 40, 50, 60, 90, 120, 150
  ];

  static const List<String> foodCategories = [
    'Fresh fruits',
    'Vegetables',
    'Beans, nuts, seeds',
    'Fish or seafood',
    'Whole grains (brown rice, whole wheat)',
    'Refined grains (white bread, pasta, bagel)',
    'Low-fat dairy (skim milk, low-fat yogurt)',
    'High-fat dairy (whole milk, butter, cream)',
    'Sweets & sweet foods',
    'Sweetened beverages',
    'Fried foods',
    'Red meat/processed meat',
  ];

  static const List<String> foodFrequencyOptions = [
    'None',
    '<3/week',
    '4-6/week',
    '1-3/day',
    '4+/day',
  ];
}
