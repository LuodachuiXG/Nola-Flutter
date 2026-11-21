/// 生成自适应图标前景图：将 Logo 居中缩放到安全区域内。
///
/// 运行：dart run tool/pad_icon.dart
library;

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final logo = img.decodeImage(File('assets/nola_logo.png').readAsBytesSync());
  if (logo == null) {
    stderr.writeln('无法读取 assets/nola_logo.png');
    exit(1);
  }

  // 自适应图标前景：108dp 图层，系统可见约 2/3 安全区，
  // Logo 缩放到画布 66% 并居中，避免边缘被遮罩裁切
  const canvasSize = 1024;
  const logoSize = 680; // ≈ 66%

  final resized = img.copyResize(
    logo,
    width: logoSize,
    height: logoSize,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: canvasSize, height: canvasSize);
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
  final offset = (canvasSize - logoSize) ~/ 2;
  img.compositeImage(canvas, resized, dstX: offset, dstY: offset);

  File('assets/nola_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(canvas));

  // 全平台图标底图：白色底 + 居中 Logo
  final iconCanvas = img.Image(width: canvasSize, height: canvasSize);
  img.fill(iconCanvas, color: img.ColorRgba8(255, 255, 255, 255));
  const iconLogoSize = 760;
  final resizedIcon = img.copyResize(
    logo,
    width: iconLogoSize,
    height: iconLogoSize,
    interpolation: img.Interpolation.cubic,
  );
  final iconOffset = (canvasSize - iconLogoSize) ~/ 2;
  img.compositeImage(iconCanvas, resizedIcon, dstX: iconOffset, dstY: iconOffset);

  File('assets/nola_icon.png').writeAsBytesSync(img.encodePng(iconCanvas));

  stdout.writeln('已生成 assets/nola_icon.png 与 assets/nola_icon_foreground.png');
}
