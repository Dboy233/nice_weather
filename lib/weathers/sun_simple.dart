import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';

///简单的太阳
class SunSimple extends DrawableLayer
    with AnimationAbilityMixin, LayerLifeCycleExtendMixin {
  SunSimple({double radius = 70})
      : _radius = radius,
        super(label: "简单太阳");

  ///太阳的半径
  final double _radius;

  ///出现动画
  late AnimationController _controller;

  ///画笔们
  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint _shadowPaint = Paint()
    ..isAntiAlias = true
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0);

  ///缓存绘制路径，防止每次刷新都创建
  late Path _path;

  @override
  void initAnim() {
    _controller =
        AnimationController(vsync: this, duration: Durations.extralong4);
  }

  @override
  void attachLayer() {
    super.attachLayer();
    _controller.forward();
  }

  @override
  FutureOr<void> detachLayer() async {
    super.detachLayer();
    try {
      await _controller.reverse().orCancel;
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void onSizeChange(Canvas canvas, Size preSize, Size size) {
    _path = Path();
    double centerX = size.width - (_radius * 2);
    double centerY = _radius * 1.5;
    _path.addOval(Rect.fromLTRB(centerX - _radius, centerY - _radius,
        centerX + _radius, centerY + _radius));
    _path.close();
  }

  @override
  void draw(Canvas canvas, Size size) {
    super.draw(canvas, size);
    //绘制阴影
    canvas.drawPath(
        _path,
        _shadowPaint
          ..color = Colors.white.withOpacity(_controller.value * 0.7));
    //绘制太阳
    canvas.drawPath(
        _path, _paint..color = Colors.white.withOpacity(_controller.value));
  }

  @override
  List<Listenable> get listenables => [_controller];
}
