import 'dart:ui';
import 'login_habitat_scene.dart';

/// Hand-inspected dry-ground centre lines in each photograph's own coordinates.
/// These are authored terrain, not automatic rock/water detection.
class LoginPenguinTerrain {
  const LoginPenguinTerrain(this.points);
  final List<Offset> points;
  static LoginPenguinTerrain forScene(LoginHabitatScene scene) =>
      LoginPenguinTerrain(_trails['${scene.weekday}_${scene.period}']!);
  static const Map<String, List<Offset>> _trails = {
    '1_morning': [
      Offset(.06, .91),
      Offset(.18, .90),
      Offset(.29, .95),
      Offset(.40, .96)
    ],
    '1_afternoon': [
      Offset(.04, .92),
      Offset(.16, .91),
      Offset(.28, .95),
      Offset(.39, .97)
    ],
    '1_evening': [
      Offset(.05, .92),
      Offset(.17, .91),
      Offset(.29, .96),
      Offset(.39, .97)
    ],
    '1_night': [
      Offset(.05, .91),
      Offset(.16, .89),
      Offset(.27, .94),
      Offset(.38, .97)
    ],
    '2_morning': [
      Offset(.06, .90),
      Offset(.20, .89),
      Offset(.34, .92),
      Offset(.47, .94)
    ],
    '2_afternoon': [
      Offset(.06, .89),
      Offset(.20, .90),
      Offset(.34, .92),
      Offset(.47, .94)
    ],
    '2_evening': [
      Offset(.06, .91),
      Offset(.20, .90),
      Offset(.34, .93),
      Offset(.47, .95)
    ],
    '2_night': [
      Offset(.06, .90),
      Offset(.20, .91),
      Offset(.34, .93),
      Offset(.47, .95)
    ],
    '3_morning': [
      Offset(.04, .91),
      Offset(.13, .91),
      Offset(.23, .94),
      Offset(.31, .96)
    ],
    '3_afternoon': [
      Offset(.04, .90),
      Offset(.13, .91),
      Offset(.23, .94),
      Offset(.31, .96)
    ],
    '3_evening': [
      Offset(.04, .91),
      Offset(.13, .92),
      Offset(.23, .95),
      Offset(.31, .96)
    ],
    '3_night': [
      Offset(.04, .90),
      Offset(.13, .91),
      Offset(.23, .93),
      Offset(.31, .95)
    ],
    '4_morning': [
      Offset(.07, .87),
      Offset(.19, .88),
      Offset(.31, .91),
      Offset(.43, .93)
    ],
    '4_afternoon': [
      Offset(.07, .86),
      Offset(.19, .88),
      Offset(.31, .90),
      Offset(.43, .93)
    ],
    '4_evening': [
      Offset(.07, .88),
      Offset(.19, .89),
      Offset(.31, .91),
      Offset(.43, .94)
    ],
    '4_night': [
      Offset(.07, .87),
      Offset(.19, .89),
      Offset(.31, .92),
      Offset(.43, .94)
    ],
    '5_morning': [
      Offset(.05, .83),
      Offset(.12, .83),
      Offset(.20, .84),
      Offset(.28, .85)
    ],
    '5_afternoon': [
      Offset(.05, .85),
      Offset(.14, .84),
      Offset(.24, .82),
      Offset(.31, .79)
    ],
    '5_evening': [
      Offset(.05, .90),
      Offset(.10, .91),
      Offset(.16, .92),
      Offset(.23, .93)
    ],
    '5_night': [
      Offset(.03, .89),
      Offset(.08, .89),
      Offset(.14, .90),
      Offset(.20, .91)
    ],
    '6_morning': [
      Offset(.07, .87),
      Offset(.19, .89),
      Offset(.31, .95),
      Offset(.43, .96)
    ],
    '6_afternoon': [
      Offset(.06, .88),
      Offset(.18, .90),
      Offset(.30, .95),
      Offset(.42, .97)
    ],
    '6_evening': [
      Offset(.06, .89),
      Offset(.18, .91),
      Offset(.30, .95),
      Offset(.42, .97)
    ],
    '6_night': [
      Offset(.06, .87),
      Offset(.18, .90),
      Offset(.30, .94),
      Offset(.42, .96)
    ],
    '7_morning': [
      Offset(.025, .963),
      Offset(.09, .956),
      Offset(.16, .964),
      Offset(.22, .977)
    ],
    '7_afternoon': [
      Offset(.025, .615),
      Offset(.08, .615),
      Offset(.14, .617),
      Offset(.20, .618)
    ],
    '7_evening': [
      Offset(.025, .593),
      Offset(.065, .594),
      Offset(.11, .596),
      Offset(.15, .600)
    ],
    '7_night': [
      Offset(.025, .905),
      Offset(.065, .90),
      Offset(.11, .90),
      Offset(.15, .905)
    ],
  };
}

/// Matches Image.asset(BoxFit.cover, alignment: Alignment.bottomLeft).
class LoginPhotoProjection {
  LoginPhotoProjection(this.imageSize, this.viewport)
      : scale = (viewport.width / imageSize.width >
                viewport.height / imageSize.height
            ? viewport.width / imageSize.width
            : viewport.height / imageSize.height);
  final Size imageSize;
  final Size viewport;
  final double scale;
  double get top => viewport.height - imageSize.height * scale;
  Offset project(Offset normalized) => Offset(
      normalized.dx * imageSize.width * scale,
      normalized.dy * imageSize.height * scale + top);
  Rect projectRect(Rect normalized) => Rect.fromPoints(
      project(normalized.topLeft), project(normalized.bottomRight));
}

String loginPenguinVariant(int daysSinceHatch) => daysSinceHatch < 12
    ? 'baby'
    : daysSinceHatch < 42
        ? 'young'
        : 'adult';
