import 'dart:io';

import 'package:image/image.dart' as img;

/// Paints the MediPulse mark (teal field, white pulse) and writes store/launcher sizes.
void main() {
  final master = _paint(1024);
  Directory('assets/branding').createSync(recursive: true);
  File('assets/branding/app_icon.png').writeAsBytesSync(img.encodePng(master));

  const android = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  for (final entry in android.entries) {
    final dir = Directory('android/app/src/main/res/${entry.key}')..createSync(recursive: true);
    final sized = img.copyResize(master, width: entry.value, height: entry.value);
    File('${dir.path}/ic_launcher.png').writeAsBytesSync(img.encodePng(sized));
  }

  const ios = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  final iosDir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset')..createSync(recursive: true);
  for (final entry in ios.entries) {
    final sized = img.copyResize(master, width: entry.value, height: entry.value);
    File('${iosDir.path}/${entry.key}').writeAsBytesSync(img.encodePng(sized));
  }
}

img.Image _paint(int size) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(0x1A, 0x7A, 0x78));
  final cx = size ~/ 2;
  final cy = size ~/ 2;
  img.fillCircle(
    image,
    x: cx,
    y: cy,
    radius: (size * 0.32).round(),
    color: img.ColorRgb8(0xF6, 0xFA, 0xFA),
  );
  final y = cy;
  final points = <({int x, int y})>[
    (x: (size * 0.22).round(), y: y),
    (x: (size * 0.34).round(), y: y),
    (x: (size * 0.40).round(), y: y - (size * 0.12).round()),
    (x: (size * 0.48).round(), y: y + (size * 0.16).round()),
    (x: (size * 0.56).round(), y: y - (size * 0.08).round()),
    (x: (size * 0.64).round(), y: y),
    (x: (size * 0.78).round(), y: y),
  ];
  for (var i = 0; i < points.length - 1; i++) {
    img.drawLine(
      image,
      x1: points[i].x,
      y1: points[i].y,
      x2: points[i + 1].x,
      y2: points[i + 1].y,
      color: img.ColorRgb8(0x1A, 0x7A, 0x78),
      thickness: (size * 0.045).round().clamp(4, 48),
      antialias: true,
    );
  }
  return image;
}
