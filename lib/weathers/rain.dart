import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';

final _random = math.Random();

///下雨效果
class Rain extends DrawableLayer with AnimationAbilityMixin {
  Rain([double density = 30, this.maxVelocity = 10])
      : _density = density,
        super(label: "雨");

  //密度
  final double _density;

  //最大下落速度
  final double maxVelocity;

  late AnimationController _controller;

  ///顶部雨滴列表
  final List<_RainData> _tops = [];

  ///侧面雨滴数量
  final List<_RainData> _rights = [];

  ///画笔
  Paint paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void initAnim() {
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  ///处理循环的下标
  var forIndex = 1;

  ///用来存列表数据量
  var listSize = 0;

  ///雨滴倾斜角度
  var angle = 120.0;

  @override
  void attachLayer() {
    super.attachLayer();
    _controller.repeat();
  }
  @override
  void draw(Canvas canvas, Size size) {
    ///处理顶部雨滴
    forIndex = 0;
    listSize = _tops.length;

    ///计算出顶部需要下雨的空间宽度
    double topWidth = size.width * 0.9;

    ///因为angle不是90度垂直下，靠近最左边的话，雨滴的开始位置和结束位置靠的太近，雨滴循环播放的时候会连城线
    ///所以最右边预留出一部分。
    double perSpace = size.width - topWidth;

    ///宽度/密度 得到顶部有几个雨滴
    int topSize = topWidth ~/ _density;

    ///检查列表中是否存在足够数量的雨滴数，如果不够就增加，如果够了就不增加了。
    if (listSize < topSize) {
      var createSize = topSize - listSize - 1;
      for (int i = 0; i < createSize; i++) {
        _tops.add(_createRain());
      }
    }

    ///根据计算得到的顶部数量，遍历雨滴对象，进行雨滴的移动
    for (int i = 0; i < topSize - 1; i++) {
      var topRain = _tops[i];

      ///动态计算出雨滴所在的x y坐标位置。
      var dx = perSpace + topWidth - forIndex * _density;
      if (dx > size.width) {
        break;
      }
      canvas.drawPath(
          topRain.move(dx, 0, angle, size), paint..color = topRain.color);
      forIndex++;
    }

    ///处理侧面雨滴
    forIndex = 1;
    listSize = _rights.length;

    double rightHeight = size.height * 0.5;
    int rightSize = rightHeight ~/ _density;
    if (listSize < rightSize) {
      var createSize = rightSize - listSize - 1;
      for (int i = 0; i < createSize; i++) {
        _rights.add(_createRain());
      }
    }
    for (int i = 0; i < rightSize - 1; i++) {
      var rightRain = _rights[i];
      var dy = forIndex * _density;
      if (dy > rightHeight) {
        break;
      }
      canvas.drawPath(rightRain.move(size.width, dy, angle, size),
          paint..color = rightRain.color);
      forIndex++;
    }
  }

  @override
  List<Listenable> get listenables => [
        _controller,
      ];

  _RainData _createRain() {
    var d = maxVelocity / 2;
    var velocity = d + _random.nextInt(d.toInt());
    return _RainData(
        const Color(0xffcbd4df), _random.nextInt(40) + 10.toDouble(), velocity);
  }
}

class _RainData {
  ///雨滴颜色
  Color color;

  ///雨滴长度。
  double length;

  ///雨滴的断层位置。每个雨滴视觉效果上大概是这样    ———— —
  ///中间空白的地方就是要断开的。
  double fault = 0;

  ///雨滴下落速度
  double velocity;

  ///雨滴绘制路径。
  final Path _path = Path();

  double _startX = 0;
  double _startY = 0;
  double _cacheX = 0;
  double _cacheY = 0;

  _RainData(this.color, this.length, this.velocity) {
    fault = _random.nextDouble() * length;
    _path.moveTo(0, 0);
    _path.lineTo(fault, 0);
    _path.relativeMoveTo(5, 0);
    _path.lineTo(length, 0);
  }

  ///初始化标记开始坐标位置。
  _initStart(double sx, double sy) {
    if (sx != _startX || sy != _startY) {
      _startX = sx;
      _startY = sy;
      _cacheX = sx;
      _cacheY = sy;
    }
  }

  ///移动雨滴。
  ///[sx] 雨滴起始坐标
  ///[sy] 雨滴起始坐标
  ///[angle] 雨滴倾斜角度
  ///[region] 下雨范围
  Path move(double sx, double sy, double angle, Size region) {
    _initStart(sx, sy);
    if (angle == 90) {
      _cacheY = _cacheY + velocity;
      if (!region.contains(Offset(_cacheX, _cacheY))) {
        _reset();
      }
      var matrix = Matrix4.identity();
      matrix.translate(_cacheX, _cacheY);
      matrix.rotateZ(angle * math.pi / 180);
      return _path.transform(matrix.storage);
    } else if (angle > 90) {
      if (!region.contains(Offset(_cacheX, _cacheY))) {
        _reset();
      }
      var radians = angle * math.pi / 180;

      ///计算开始坐标到达 结束坐标的X或者Y的坐标点。
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
      matrix.rotateZ(radians);
      return _path.transform(matrix.storage);
    }
    return _path;
  }

  ///计算距离[start]最近的坐标位置。
  Offset _computeNear(Offset start, Offset p1, Offset p2) {
    var d1 = _distanceBetweenPoints(start, p1);
    var d2 = _distanceBetweenPoints(start, p2);
    return d1 < d2 ? p1 : p2;
  }

  ///计算两点之间距离
  double _distanceBetweenPoints(Offset p1, Offset p2) {
    double distance =
        math.sqrt(math.pow(p2.dx - p1.dx, 2) + math.pow(p2.dy - p1.dy, 2));
    return distance;
  }

  ///已知起始坐标和角度和结束坐标的X/Y,求结束坐标的X/Y
  ///就是知道结束x坐标，求在Y坐标上的Y坐标然后,然后组合x，y。
  ///相反知道结束Y坐标就是求X坐标。
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
  }
}
