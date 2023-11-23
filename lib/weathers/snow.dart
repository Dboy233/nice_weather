import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';

final _random = math.Random();

///下雪效果，啥也不说了，和Rain一样的实现逻辑，只不过是雨换成雪。
class Snow extends DrawableLayer with AnimationAbilityMixin {
  Snow([double density = 75,this.maxVelocity = 10])
      : _density = density,
        super(label: "雪");

  //密度，密度越小，数量越多
  final double _density;
  //最大下落速度，数值越大，下落速度越快。
  final double maxVelocity;
  
  late AnimationController _controller;

  ///画笔
  Paint _paint = Paint();

  @override
  void initAnim() {
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }
  @override
  void attachLayer() {
    super.attachLayer();
    _controller.repeat();
  }

  var forIndex = 0;
  final List<_SnowData> _tops = [];
  final List<_SnowData> _rights = [];

  @override
  void draw(Canvas canvas, Size size) {
    ///处理顶部
    forIndex = 0;
    double topWidth = size.width * 0.9;
    double perSpace = size.width - topWidth;
    int topSize = topWidth ~/ _density;
    int cacheSize = _tops.length;
    if (cacheSize < topSize) {
      var createSize = topSize - cacheSize - 1;
      for (int i = 0; i < createSize; i++) {
        _tops.add(_createSnow());
      }
    }
    for (int i = 0; i < topSize - 1; i++) {
      var top = _tops[i];
      var dx = perSpace + topWidth - forIndex * _density;
      if (dx < 0) {
        // dx = perSpace + topWidth;
        break;
      }
      canvas.drawPath(
          top.move(dx, 0, 120, size), _paint..color = top.color);
      forIndex++;
    }

    ///处理右侧
    forIndex = 0;
    double rightHeight = size.height * 0.5;
    int rightSize = rightHeight ~/ _density;
    cacheSize = _rights.length;
    if (cacheSize < rightSize) {
      var createSize = rightSize - cacheSize - 1;
      for (int i = 0; i < createSize; i++) {
        _rights.add(_createSnow());
      }
    }
    for (int i = 0; i < rightSize - 1; i++) {
      var right = _rights[i];
      var dy = _density + forIndex * _density;
      if (dy > rightHeight) {
        break;
      }
      canvas.drawPath(right.move(size.width, dy, 120, size),
          _paint..color = right.color);
      forIndex++;
    }
  }

  @override
  List<Listenable> get listenables => [_controller];

  _createSnow() {
    return _SnowData(Colors.white, maxVelocity);
  }
}

class _SnowData {
  ///颜色
  late Color color;

  ///下落速度
  double maxVelocity;
  late double velocity;

  ///旋转速度
  double maxAngleVelocity;
  late double _angleVelocity;

  double _alpha = 1.0;

  ///雪花路径
  final Path _path = Path();

  ///雪花开始X
  double _startX = 0;

  ///雪花开始Y
  double _startY = 0;
  double _cacheX = 0;
  double _cacheY = 0;

  double _cacheAngle = 0.0;

  _SnowData(
      [Color snowColor = Colors.white,
      this.maxVelocity = 3,
      this.maxAngleVelocity = 1.0])
      : assert(maxVelocity >= 1),
        assert(maxAngleVelocity >= 1.0),
        color = snowColor {
    _setVelocity();
    _randomCreatePolygon();
  }

  _randomCreatePolygon() {
    _createPolygon(_path, Offset.zero, _random.nextBool() ? 5 : 6,
        _random.nextInt(10) + 10);
  }

  ///创建多边形
  ///[center] 多边形中心位置
  ///[sides] 几边形
  ///[size] 多边形边长
  _createPolygon(Path path, Offset center, int sides, double size) {
    // 确保多边形至少有三个边
    if (sides < 3) return path;
    path.reset();
    // 计算内角
    double angle = (2 * math.pi) / sides;
    // 设置起始点
    Offset startPoint = Offset(
      center.dx + size * math.cos(0),
      center.dy + size * math.sin(0),
    );
    path.moveTo(startPoint.dx, startPoint.dy);

    // 绘制多边形的边
    for (int i = 1; i <= sides; i++) {
      double x = center.dx + size * math.cos(angle * i);
      double y = center.dy + size * math.sin(angle * i);
      path.lineTo(x, y);
    }
    path.close();
  }

  _initStart(double sx, double sy) {
    if (sx != _startX || sy != _startY) {
      _startX = sx;
      _startY = sy;
      _cacheX = sx;
      _cacheY = sy;
    }
  }

  Path move(double sx, double sy, double angle, Size region) {
    _initStart(sx, sy);
    if (angle == 90) {
      _cacheY = _cacheY + velocity;
      if (!region.contains(Offset(_cacheX, _cacheY))) {
        _reset();
      }
      var matrix = Matrix4.identity();
      matrix.translate(_cacheX, _cacheY);
      matrix.rotateZ(_cacheAngle * math.pi / 180);
      _cacheAngle = _cacheAngle + _angleVelocity;
      return _path.transform(matrix.storage);
    } else if (angle > 90) {
      if (!region.contains(Offset(_cacheX, _cacheY))) {
        _reset();
      }
      var radians = angle * math.pi / 180;
      var p1 = _computeEndPoint(_startX, _startY, radians, endX: 0);
      var p2 = _computeEndPoint(_startX, _startY, radians, endY: region.height);
      var cp = _computeNear(Offset(_startX, _startY), p1, p2);
      var dx = (_startX - cp.dx).abs();
      var dy = (_startY - cp.dy).abs();

      ///如果x轴的移动距离大于y轴的距离，那y轴的移动速度要单独计算。
      if (dx > dy) {
        // 计算直线的斜率
        double k = (cp.dx - _startX) / (cp.dy - _startY);
        var vx = velocity / k;
        _cacheX = _cacheX + velocity;
        _cacheY = _cacheY + vx;
      } else {
        // 计算直线的斜率
        double k = (cp.dy - _startY) / (cp.dx - _startX);
        var vx = velocity / k;
        _cacheX = _cacheX + vx;
        _cacheY = _cacheY + velocity;
      }

      var matrix = Matrix4.identity();
      matrix.translate(_cacheX, _cacheY);
      matrix.rotateZ(_cacheAngle * math.pi / 180);
      _cacheAngle = _cacheAngle + _angleVelocity;
      return _path.transform(matrix.storage);
    }
    return _path;
  }

  Offset _computeNear(Offset start, Offset p1, Offset p2) {
    var d1 = distanceBetweenPoints(start, p1);
    var d2 = distanceBetweenPoints(start, p2);
    return d1 < d2 ? p1 : p2;
  }

  double distanceBetweenPoints(Offset p1, Offset p2) {
    double distance =
        math.sqrt(math.pow(p2.dx - p1.dx, 2) + math.pow(p2.dy - p1.dy, 2));
    return distance;
  }

  ///已知起始坐标和角度和结束坐标的X/Y,求结束坐标的X/Y
  Offset _computeEndPoint(double startX, double startY, double radians,
      {double? endX, double? endY}) {
    if (endX != null) {
      //流星结束X坐标位置与流星出现X坐标位置的差值
      final double deltaX = startX - endX;
      // deltaY 可以通过 tan(角度) * deltaX 计算
      final double deltaY = math.tan(radians) * deltaX;
      // 终点 y 坐标
      endY = startY - deltaY;
      return Offset(endX, endY);
    } else if (endY != null) {
      final double deltaY = endY - startY;
      double deltaX = deltaY / math.tan(radians);
      double endX = startX + deltaX;
      return Offset(endX, endY);
    } else {
      throw "没有endX 或 endY";
    }
  }

  _reset() {
    _cacheY = _startY;
    _cacheX = _startX;
    _randomCreatePolygon();
    _setVelocity();
  }

  _setVelocity() {
    velocity = (_random.nextDouble() * (maxVelocity - 0.5)) + 0.5;
    _angleVelocity = (_random.nextDouble() * (maxAngleVelocity - 0.5)) +
        0.5 * (_random.nextBool() ? 1 : -1);
    _alpha = (_random.nextDouble() * 90) + 0.1;
    color = color.withAlpha(100 + _random.nextInt(150));
  }
}
