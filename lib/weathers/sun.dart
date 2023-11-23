import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';

import 'sky.dart';

class Sun extends DrawableLayer
    with AnimationAbilityMixin, EventBusAbilityMixin {
  Sun({DateTime? sunRiseTime, DateTime? sunFallTime})
      : sunRiseTime = sunRiseTime ?? DateTime.now().copyWith(hour: 6),
        sunFallTime = sunFallTime ?? DateTime.now().copyWith(hour: 18),
        super(label: "太阳");

  ///升起动画控制器
  late AnimationController _sunLocusController;
  late Animation<double> _riseAnim;
  late Animation<double> _fallAnim;

  ///透明度动画控制器
  late AnimationController _alphaController;
  late Animation<double> _alphaAnim;

  ///呼吸动画
  late AnimationController _breathController;
  late Animation<double> _breathAnim1;
  late Animation<double> _breathAnim2;

  ///太阳升起时间
  DateTime sunRiseTime;

  ///太阳落下时间
  DateTime sunFallTime;

  /////太阳位置
  double sunLocation = 0.0;

  ///太阳画笔
  final Paint _sunPaint = Paint();

  ///光晕画笔
  final Paint _lightPaint = Paint();

  @override
  void initAnim() {
    ///计算太阳位置
    sunLocation = 0.2;
    //根据当前事件动态获取太阳位置百分比。因为需要得到太阳升起和降落的时间。
    //所以，这个就暂时不实现，或许可以让外部提供位置，而不是时间。
    // _calculateDaylightPercentage(sunRiseTime, sunFallTime, DateTime.now()) /
    //     100;

    ///太阳位置动画
    _sunLocusController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));

    ///太阳升起动画
    _riseAnim = Tween(begin: 0.0, end: sunLocation).animate(CurvedAnimation(
        parent: _sunLocusController,
        curve: const Interval(0, 0.5, curve: Curves.decelerate)));

    ///太阳落下动画
    _fallAnim = Tween(begin: 0.0, end: 1.0 - sunLocation).animate(
        CurvedAnimation(
            parent: _sunLocusController,
            curve: const Interval(0.5, 1, curve: Curves.decelerate)));

    ///透明度动画
    _alphaController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _alphaAnim = CurveTween(curve: Curves.linear).animate(_alphaController);

    ///呼吸动画1和2的初始化
    _breathController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3));
    const interval1 = Interval(0.3, 1, curve: Curves.easeInOutSine);
    const interval2 = Interval(0.0, 0.7, curve: Curves.easeInOutSine);
    _breathAnim1 = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _breathController,
      curve: interval1,
      reverseCurve: interval2,
    ));
    _breathAnim2 = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _breathController, curve: interval2, reverseCurve: interval1));
    _breathController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _breathController.reverse(from: 1.0);
      } else if (status == AnimationStatus.dismissed) {
        _breathController.forward(from: 0.0);
      }
    });
  }

  @override
  void draw(Canvas canvas, Size size) {
    var path = _createSunLocusPath(size);
    // _drawSunLocusPath(path, canvas);
    var sunOffset = _createSunLocusOffset(path, canvas, size);
    if (sunOffset == null) {
      return;
    }
    _drawSun(canvas, size, sunOffset);
  }

  _drawSun(Canvas canvas, Size size, Offset sunOffset) {
    //太阳半径
    double sunRadius = size.width * 0.15;
    //太阳中心坐标位置
    var sunCenterX = sunOffset.dx;
    var sunCenterY = sunOffset.dy;
    final sunCenter = Offset(sunCenterX, sunCenterY);
    //太阳光晕半径
    var light1Radius = sunRadius * 1.6 + (_breathAnim1.value * 10.0);
    var light2Radius = sunRadius * 1.3 + (_breathAnim2.value * 10.0);
    ///光晕渐变
    RadialGradient lightGradient = RadialGradient(
      colors: [
        Colors.white.withOpacity(_alphaAnim.value * 0.1),
        Colors.white.withOpacity(_alphaAnim.value * 0.12),
      ],
      stops: const [0.3, 1.0],
      center: Alignment.center,
      focal: Alignment.center,
    );
    //光晕1
    _lightPaint.shader = lightGradient
        .createShader(Rect.fromCircle(center: sunCenter, radius: light1Radius));
    canvas.drawCircle(sunCenter, light1Radius, _lightPaint);
    //光晕2
    _lightPaint.shader = lightGradient
        .createShader(Rect.fromCircle(center: sunCenter, radius: light2Radius));
    canvas.drawCircle(sunCenter, light2Radius, _lightPaint);

    //太阳
    _sunPaint.color =
        const Color(0xfffae65b).withAlpha((255 * _alphaAnim.value).toInt());
    canvas.drawCircle(Offset(sunCenterX, sunCenterY), sunRadius, _sunPaint);
  }

  ///计算太阳位置
  double _calculateDaylightPercentage(
      DateTime sunrise, DateTime sunset, DateTime currentTime) {
    if (currentTime.hour <= sunrise.hour) {
      // 如果当前时间在日出之前或日落之后，白天的比例为0%
      return 0.0;
    }
    if (currentTime.hour >= sunset.hour) {
      // 如果当前时间在日出之前或日落之后，白天的比例为100%
      return 100.0;
    }

    Duration totalDaylightDuration = sunset.difference(sunrise);
    Duration durationSinceSunrise = currentTime.difference(sunrise);

    return (durationSinceSunrise.inSeconds / totalDaylightDuration.inSeconds) *
        100;
  }

  ///创建太阳移动轨迹
  Path _createSunLocusPath(Size size) {
    final horizonHeight = size.height * 0.1;
    // 创建一个路径
    var path = Path();
    path.moveTo(size.width, horizonHeight);
    path.conicTo(size.width / 2, -horizonHeight, 0, horizonHeight, 1);
    return path;
  }

  ///创建太阳轨迹坐标
  Offset? _createSunLocusOffset(Path path, Canvas canvas, Size size) {
    var percent = (_riseAnim.value + _fallAnim.value);
    PathMetrics pathMetrics = path.computeMetrics();
    PathMetric metric = pathMetrics.first;
    Tangent? tangent;
    try {
      tangent = metric.getTangentForOffset(metric.length * percent);
    } catch (e) {
      debugPrint("发生异常：${e.toString()}");
    }
    if (tangent != null) {
      return tangent.position;
    } else {
      return null;
    }
  }

  _doAnim() {
    _alphaController.forward();
    _sunLocusController.animateTo(0.5);
    _breathController.forward();
  }

  @override
  FutureOr<void> detachLayer() async {
    super.detachLayer();
    try {
      //等待太阳移动和太阳消失两个动画执行结束。
      //让太阳看上去像是真的日落了一样。
      await Future.wait([
        _sunLocusController.forward().orCancel,
        _alphaController.reverse().orCancel,
      ]);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  List<Listenable> get listenables => [
        _sunLocusController,
        _alphaController,
        _breathController,
      ];

  @override
  void subscribeEvent() {
    subscribe<SkyState>((event) {
      _doAnim();
    });
  }


}
