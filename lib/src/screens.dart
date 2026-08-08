import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

import 'ble_service.dart';
import 'assistant_engine.dart';
import 'catalog.dart';
import 'date_input.dart';
import 'document_vault_service.dart';
import 'expanded_catalog.dart';
import 'geo_workout.dart';
import 'health_platform_service.dart';
import 'localization.dart';
import 'location_catalog.dart';
import 'media_import_service.dart';
import 'model.dart';
import 'navigation.dart';
import 'notification_service.dart';
import 'offline_map_service.dart';
import 'repository.dart';
import 'security_service.dart';
import 'unit_format.dart';
import 'widgets.dart';
import 'weather_service.dart';
import 'workout_adaptation.dart';

part 'screens/routing.dart';
part 'screens/dashboard_screens.dart';
part 'screens/medical_screens.dart';
part 'screens/fitness_screens.dart';
part 'screens/nutrition_screens.dart';
part 'screens/planning_screens.dart';
part 'screens/assistant_screen.dart';
part 'screens/devices_screen.dart';
part 'screens/devices_helpers.dart';
part 'screens/health_platform_panel.dart';
part 'screens/documents_screen.dart';
part 'screens/settings_screen.dart';
part 'screens/catalog_details.dart';
part 'screens/calendar_helpers.dart';
part 'screens/calendar_screen.dart';
part 'screens/symptom_helpers.dart';
part 'screens/sleep_helpers.dart';
part 'screens/alarm_helpers.dart';
part 'screens/profile_helpers.dart';
part 'screens/schedule_helpers.dart';
part 'screens/medical_helpers.dart';
part 'screens/workout_helpers.dart';
part 'screens/workout_player.dart';
part 'screens/medication_helpers.dart';
part 'screens/lab_helpers.dart';
part 'screens/nutrition_helpers.dart';
part 'screens/recognition_helpers.dart';
part 'screens/shared_helpers.dart';
part 'screens/analytics_widgets.dart';

class Text extends StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    return material.Text(
      AppText.phrase(context, data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null
          ? null
          : AppText.phrase(context, semanticsLabel!),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
