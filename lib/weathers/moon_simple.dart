import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';

///简单的月亮
class MoonSimple extends DrawableLayer
    with AnimationAbilityMixin, LayerLifeCycleExtendMixin {
  MoonSimple({double radius = 70, Color color = const Color(0xffe95f15)})
      : _radius = radius,
        _color = color,
        super(label: "简单月亮");

  ///半径
  final double _radius;

  ///颜色
  final Color _color;

  ///出现动画
  late AnimationController _controller;

  ///画笔们
  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint shadowPaint = Paint()
    ..isAntiAlias = true
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0);

  ///绘制路径，防止重复创建路径。
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
    double centerX = size.width - (_radius * 2);
    double centerY = _radius * 1.5;
    Path path1 = Path();
    var rect = Rect.fromLTRB(centerX - _radius, centerY - _radius,
        centerX + _radius, centerY + _radius);
    path1.addOval(rect);
    path1.close();
    Path path2 = Path();
    path2.addOval(rect.shift(Offset(_radius / 2, -_radius / 2)));
    _path = Path.combine(PathOperation.reverseDifference, path2, path1);
  }

  @override
  void draw(Canvas canvas, Size size) {
    super.draw(canvas, size);
    //绘制阴影
    canvas.drawPath(_path,
        shadowPaint..color = _color.withOpacity(_controller.value * 0.7));
    //绘制
    canvas.drawPath(
        _path, _paint..color = _color.withOpacity(_controller.value));
  }

  @override
  List<Listenable> get listenables => [_controller];
}
