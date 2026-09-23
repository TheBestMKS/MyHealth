import 'package:flutter/material.dart';

import 'localization.dart';

enum AppSection {
  home,
  today,
  health,
  profile,
  medicalCard,
  labs,
  medicines,
  symptoms,
  knowledge,
  workouts,
  exercises,
  nutrition,
  recipes,
  foodPhoto,
  sleep,
  calendar,
  vacation,
  trips,
  climate,
  analytics,
  assistant,
  devices,
  documents,
  settings,
}

class SectionInfo {
  const SectionInfo(this.section, this.labelKey, this.icon);

  final AppSection section;
  final String labelKey;
  final IconData icon;

  String label(String localeCode) => AppText.get(localeCode, labelKey);
}

const allSections = <SectionInfo>[
  SectionInfo(AppSection.home, 'appName', Icons.home_outlined),
  SectionInfo(AppSection.today, 'today', Icons.today_outlined),
  SectionInfo(AppSection.health, 'health', Icons.favorite_border),
  SectionInfo(AppSection.profile, 'profile', Icons.person_outline),
  SectionInfo(AppSection.medicalCard, 'medicalCard', Icons.badge_outlined),
  SectionInfo(AppSection.labs, 'labs', Icons.science_outlined),
  SectionInfo(AppSection.medicines, 'medicines', Icons.medication_outlined),
  SectionInfo(AppSection.symptoms, 'symptoms', Icons.healing_outlined),
  SectionInfo(AppSection.knowledge, 'knowledge', Icons.local_library_outlined),
  SectionInfo(AppSection.workouts, 'workouts', Icons.fitness_center_outlined),
  SectionInfo(AppSection.exercises, 'exercises', Icons.list_alt_outlined),
  SectionInfo(AppSection.nutrition, 'nutrition', Icons.restaurant_outlined),
  SectionInfo(AppSection.recipes, 'recipes', Icons.menu_book_outlined),
  SectionInfo(AppSection.foodPhoto, 'foodPhoto', Icons.photo_camera_outlined),
  SectionInfo(AppSection.sleep, 'sleep', Icons.bedtime_outlined),
  SectionInfo(AppSection.calendar, 'calendar', Icons.calendar_month_outlined),
  SectionInfo(AppSection.vacation, 'vacation', Icons.beach_access_outlined),
  SectionInfo(AppSection.trips, 'trips', Icons.business_center_outlined),
  SectionInfo(AppSection.climate, 'climate', Icons.wb_sunny_outlined),
  SectionInfo(AppSection.analytics, 'analytics', Icons.query_stats_outlined),
  SectionInfo(AppSection.assistant, 'assistant', Icons.psychology_outlined),
  SectionInfo(AppSection.devices, 'devices', Icons.watch_outlined),
  SectionInfo(AppSection.documents, 'documents', Icons.folder_copy_outlined),
  SectionInfo(AppSection.settings, 'settings', Icons.settings_outlined),
];

const mobileSections = <AppSection>[
  AppSection.today,
  AppSection.health,
  AppSection.profile,
  AppSection.workouts,
  AppSection.nutrition,
  AppSection.calendar,
];

SectionInfo sectionInfo(AppSection section) {
  return allSections.firstWhere((item) => item.section == section);
}
