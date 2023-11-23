import 'dart:core';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';

import '../utils.dart';

///遮天的云层
class CloudFullSky extends DrawableLayer with AnimationAbilityMixin {
  CloudFullSky({double? cloudHeight, Color? cloudColor, Duration? floatingTime})
      : _cloudColor = cloudColor ?? const Color(0xff0b4c7a),
        _cloudHeight = cloudHeight ?? 20,
        floatingTime = floatingTime ?? const Duration(seconds: 1),super(label: "乌云");

  ///云层高度
  final double _cloudHeight;

  ///云层颜色
  final Color _cloudColor;

  ///云层浮动时间
  final Duration floatingTime;

  ///云层绘制画笔
  var paint = Paint();

  ///随机点
  late List<Offset> _randomPoints;

  ///在屏幕中心控制点个数，用来绘制二阶贝塞尔曲线的控制点
  final _controlPointSize = 3;

  //云层显示动画
  late AnimationController _showController;
  late Animation<double> _showAnimation;

  late AnimationController _floatController;
  late Animation<double> _floatX;
  late Animation<double> _floatY;

  @override
  void initAnim() {
    _showController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _showAnimation = CurveTween(curve: Curves.easeOut).animate(_showController);

    _floatController = AnimationController(vsync: this, duration: floatingTime);
    _floatX = Tween(begin: -1.0, end: 1.0).animate(
        CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    _floatY = CurveTween(curve: Curves.easeInOut).animate(_floatController);
  }

  @override
  void init() {
    super.init();

    paint
      ..color = _cloudColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    _randomPoints = _createControlPoints();
  }

  @override
  void attachLayer() {
    super.attachLayer();
    _showController.forward();
    _floatController.repeat(reverse: true);
  }

  @override
  void draw(Canvas canvas, Size size) {
    //每个点所在位置，大概宽度
    var stepWidth = size.width / (_controlPointSize + 1);
    //二阶贝塞尔曲线起始点
    const startPoint = Offset(-50, -50);
    //二阶贝塞尔曲线终点
    final endPoint = Offset(size.width + 50, -50);

    //根据随机的控制点位置，计算出确切的控制点位置
    //_controlPointSize是初始化的时候随机的位置。
    //controlPoints是将随机位置转化为具体坐标位置。
    List<Offset> controlPoints = [];
    //手动添加两个是为了让贝塞尔曲线绘制出屏幕否则在屏幕内会出现断层
    controlPoints.add(startPoint);
    controlPoints.add(Offset(0, _cloudHeight / 2));
    for (int i = 0; i < _controlPointSize; i++) {
      var offset = Offset(
        (stepWidth * i) + (stepWidth * _randomPoints[i].dx),
        _cloudHeight + (_randomPoints[i].dy * 35),
      );
      controlPoints.add(offset);
    }
    var last = controlPoints.last;
    //手动添加两个是为了让贝塞尔曲线绘制出屏幕否则在屏幕内会出现断层
    controlPoints.add(Offset(size.width+50, last.dy + (_cloudHeight * 2)));
    controlPoints.add(endPoint);

    //根据控制点位置计算出坐标位置。
    //还是查看文章https://zhuanlan.zhihu.com/p/437529481
    List<Offset> positionPoints = _create2PointCenterPoint(controlPoints);

    //组合路径
    Path path = Path();

    ///移动到起始点
    path.moveTo(startPoint.dx, startPoint.dy);
    for (int i = 0; i < positionPoints.length - 1; i++) {
      if (i == 0) {
        var start = positionPoints[i];
        path.lineTo(start.dx, start.dy);
      }
      var controlPos = controlPoints[i + 1];
      var end = positionPoints[i + 1];
      path.conicTo(
        controlPos.dx,
        controlPos.dy,
        end.dx,
        end.dy,
        1.5,
      );
    }

    ///将路径移动到结束点
    path.lineTo(endPoint.dx, endPoint.dy);
    path.close();

    //动画操作
    var bounds = path.getBounds();
    var matrix4 = Matrix4.identity();
    var bottom = bounds.bottom;
    var left = bounds.left;

    ///这是为了让贝塞尔曲线从顶部屏幕外移动到顶部屏幕内
    matrix4.translate(
      -left * (1 - _showAnimation.value),
      -bottom * (1 - _showAnimation.value),
    );
    ///让绘制的内容有浮动动画效果
    matrix4.translate(30 * _floatX.value, -30 * _floatY.value);

    path = path.transform(matrix4.storage);

    // 在绘制路径之前绘制阴影
    canvas.drawShadow(
        path, Colors.black.withOpacity(0.5), 4.0, false); // 阴影颜色，高度和是否固态

    canvas.drawPath(path, paint);
  }

  ///创建随机的控制点
  ///x坐标的随机，y坐标的随机
  List<Offset> _createControlPoints() {
    List<Offset> points = [];
    for (int i = 0; i < _controlPointSize; i++) {
      var x = 0.2+0.4*xRandom.nextDouble();
      double y = xRandom.nextDouble();
      if (i % 2 == 0) {
        y = 0.7 + 0.3 * xRandom.nextDouble();
      } else {
        y = 0.3 * xRandom.nextDouble();
      }
      points.add(Offset(x, y));
    }
    return points;
  }


  ///创建两点组成的线段中间的点
  ///为了让多个贝塞尔曲线连接的时候可以保持连接处平滑。
  ///需要保证 b0曲线和b1曲线的连接点和两者的控制点在同一条直线上。
  ///参考文章 https://zhuanlan.zhihu.com/p/437529481
  List<Offset> _create2PointCenterPoint(List<Offset> points) {
    if (points.isEmpty) return [];
    List<Offset> centerPoints = [];
    for (int i = 0; i < points.length - 1; i++) {
      final currentPoint = points[i];
      final nextPoint = points[i + 1];
      var offset = _calculatesLineCenterPoint(currentPoint, nextPoint, 0.5);
      centerPoints.add(offset);
    }
    return centerPoints;
  }

  ///两点之间的任意一点
  ///已知两点所组成的线段，求线段上计算任意一点
  ///[t]为计算的点位于 p1和p2之间的百分比 0.0 - 1.0
  Offset _calculatesLineCenterPoint(Offset point1, Offset point2, double t) {
    return Offset(
      point1.dx + (point2.dx - point1.dx) * t,
      point1.dy + (point2.dy - point1.dy) * t,
    );
  }

  @override
  List<Listenable> get listenables => [_showController, _floatController];
}
