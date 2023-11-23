import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';

import '../utils.dart';

class Meteor extends DrawableLayer with AnimationAbilityMixin {
  Meteor() : super(label: "流星");

  final _random = xRandom;

  ///最多三个流星
  final _maxMeteorCount = 3;

  ///流星对象列表
  final List<_Meteor> _meteors = [];

  ///流星渐变样式
  final gradient = const LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      Colors.yellow, // 渐变开始颜色
      Colors.yellow, // 渐变开始颜色
      Colors.transparent, // 渐变结束颜色
    ],
  );

  ///进度动画
  late AnimationController _locusController;
  final List<Animation<double>> _locusAnimations = [];

  bool _isCanDraw = false;
  Timer? _delayTimer;

  @override
  void attachLayer() {
    super.attachLayer();
    _createTimer();
  }

  @override
  void initAnim() {
    _locusController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3));
    for (var i = 0; i < _maxMeteorCount; i++) {
      final start = 0.2 * i;
      final end = 0.6 + (0.2 * i);
      var animate = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _locusController,
        curve: Interval(start, end, curve: Curves.easeInCubic),
      ));
      _locusAnimations.add(animate);
    }
    _locusController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _endAnim();
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  void draw(Canvas canvas, Size size) {
    if (!_isCanDraw) return;

    ///这里根据流星列表的数量进行绘制，因为会随机创建小于[_maxMeteorCount]个数的流星。
    for (var i = 0; i < _meteors.length; i++) {
      if (_locusAnimations[i].value == 0) continue;
      _drawMeteor(canvas, size, _meteors[i], _locusAnimations[i].value);
    }
  }

  @override
  List<Listenable> get listenables => [_locusController];

  ///绘制流星
  _drawMeteor(Canvas canvas, Size size, _Meteor meteor, var progress) {
    //流星角度,没用到
    // final angle = meteor.angle;
    //弧度
    final radians = meteor.radians;
    //星星大小, 随着动画进度逐渐变大，近大远小
    final meteorSize = meteor.meteorSize * (0.1 + 0.9 * progress);
    //尾焰长度， 随着动画进度逐渐边长，近大远小
    final meteorLength = meteor.meteorLength * (0.1 + 0.9 * progress);

    //流星出现位置,在屏幕的右上方，屏幕宽度*0.2大小的正矩形中随机的位置。
    final startOffset = Offset(
      size.width * (1 + (0.4 * meteor.px)),
      -size.width * (0.4 * meteor.py),
    );

    //创建流星路径
    Path path = Path();
    path.addArc(
        Rect.fromCircle(center: Offset.zero, radius: meteorSize), 1.57, pi);
    path.lineTo(meteorLength, 0);
    path.close();
    //对流星路径进行旋转
    final matrixRotate = Matrix4.identity()..rotateZ(radians);
    path = path.transform(matrixRotate.storage);

    ///获取流星的边界位置
    var bounds = path.getBounds();

    ///流星结束X坐标位置
    final endX = -bounds.width;
    //流星结束X坐标位置与流星出现X坐标位置的差值
    final double deltaX = startOffset.dx - endX;
    // deltaY 可以通过 tan(角度) * deltaX 计算
    final double deltaY = tan(radians) * deltaX;
    // 终点 y 坐标
    // final double endY = startOffset.dy - deltaY;

    //对流星进行平移，通过动画数值改变平移的位置。
    final matrixMove = Matrix4.identity()
      ..translate(
        startOffset.dx - (deltaX * progress),
        startOffset.dy - (deltaY * progress),
      );
    path = path.transform(matrixMove.storage);
    //重新获取边界位置
    bounds = path.getBounds();
    //渐变色要跟随边界，否则渐变就偏离了。
    var createShader = gradient.createShader(Rect.fromLTRB(
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.bottom,
    ));
    canvas.drawPath(path, Paint()..shader = createShader);

    ///绘制路径
    ///流星消失位置
    // final endOffset = Offset(endX, endY);
    // canvas.drawLine(Offset(startOffset.dx, startOffset.dy),
    //     Offset(endOffset.dx, endOffset.dy), Paint()..color = Colors.white);
  }

  _startAnim() {
    _isCanDraw = true;
    _createMeteor();
    _locusController.forward(from: 0.0);
  }

  _endAnim() {
    _isCanDraw = false;
    _meteors.clear();
    _createTimer();
  }

  _createTimer() {
    _delayTimer?.cancel();

    ///延迟最多3秒后开始动画
    _delayTimer = Timer(Duration(seconds: _random.nextInt(3)), () {
      _startAnim();
    });
  }

  _createMeteor() {
    //随机创建小于[_maxMeteorCount]个流星
    final count = _random.nextInt(_maxMeteorCount);
    for (int i = 0; i < count; i++) {
      _meteors.add(_Meteor(
        -25,
        _random.nextDouble() * 3 + 2,
        _random.nextDouble() * 100 + 200,
        _random.nextDouble(),
        _random.nextDouble(),
      ));
    }
  }
}

class _Meteor {
  ///流星角度
  final double angle;

  ///弧度
  final double radians;

  ///流星大小
  final double meteorSize;

  ///流星尾焰长度
  final double meteorLength;

  ///流星x出现的百分比位置
  final double px;

  ///流星y出现的百分比位置
  final double py;

  _Meteor(this.angle, this.meteorSize, this.meteorLength, this.px, this.py)
      : radians = angle * pi / 180;
}
