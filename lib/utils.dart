import 'dart:math';

import 'package:flutter/material.dart';

final xRandom = Random();

///使用 catmull rom spline 将控制点转换成平滑的路径。
convertPoints2Path(Path path, List<Offset> controlPoints) {
  var catmullRomSpline = CatmullRomSpline(controlPoints);
  var generateSamples = catmullRomSpline.generateSamples();
  List<Offset> offsets = [];
  for (var value in generateSamples) {
    offsets.add(value.value);
  }
  path.moveTo(offsets[0].dx, offsets[0].dy);
  for (int i = 0; i < offsets.length; i++) {
    path.lineTo(offsets[i].dx, offsets[i].dy);
  }
}