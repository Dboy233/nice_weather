import 'dart:async';

import 'package:flutter/material.dart';

import '../drawable_layer/drawable_layer.dart';
import 'sun.dart';

///天空图层显示状态
enum SkyState {
  ///开始显示
  start,

  ///完成显示
  end,
}

///天空
class Sky extends DrawableLayer
    with AnimationAbilityMixin, EventBusAbilityMixin, LayerExistAbilityMixin {
  Sky({Color? color})
      : _color = color ?? const Color(0xff378fea),
        super(label: "天空");

  late AnimationController _controller;

  late Animation<double> _alphaAnim;

  ///天空背景颜色
  final Color _color;

  ///天空透明度
  double _alpha = 0.0;

  final paint = Paint();

  @override
  List<AnimationController> get listenables => [_controller];

  @override
  void initAnim() {
    _controller =
        AnimationController(vsync: this, duration: Durations.extralong4);
    _alphaAnim = CurveTween(curve: Curves.linear).animate(_controller);
    _alphaAnim.addListener(() {
      _alpha = _alphaAnim.value;
    });
    _alphaAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        publish<SkyState>(SkyState.end);
      }
    });
  }

  @override
  void attachLayer() {
    super.attachLayer();
    _controller.forward(from: 0.0);
  }

  @override
  void draw(Canvas canvas, Size size) {
    paint.color = _color.withOpacity(_alpha);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, size.height), paint);
  }

  @override
  FutureOr<void> detachLayer() async {
    super.detachLayer();
    try {
      await _controller.reverse(from: 1.0).orCancel;
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void subscribeEvent() {
    ///不需要订阅其他代码。
  }

  @override
  void onDrawableLayerAdd(DrawableLayer drawableLayer) {
    if (drawableLayer is Sun) {
      if (_controller.isCompleted) {
        publish(SkyState.end);
      }
    }
  }
}
