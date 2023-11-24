import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';

///有雾
///fixme 当前的绘制内容中存在性能问题，导致帧数上不去。
class Foggy extends DrawableLayer with AnimationAbilityMixin {
  Foggy(
      {double offsetY = 120,
      int peakDensity = 8,
      double peakHeight = 50,
      Color color = const Color(0xffb9a26d)})
      : _offsetY = offsetY,
        _peakDensity = peakDensity,
        _peakHeight = peakHeight,
        _color = color,
        super(label: "雾");

  ///Y轴的平移量
  final double _offsetY;

  ///曲线密度，越高波峰越多。
  final int _peakDensity;

  ///波峰的高度，值越大，曲线越拧巴。
  final double _peakHeight;

  final Color _color;

  ///前景雾点列表
  late List<Offset> _foregroundPoints;

  ///背景雾点列表
  late List<Offset> _backgroundPoints;

  late AnimationController _foregroundController;
  late AnimationController _backgroundController;
  late AnimationController _alphaController;

  final Paint _paintForeground = Paint()..style = PaintingStyle.fill;
  final Paint _paintBackground = Paint()..style = PaintingStyle.fill;

  late LinearGradient _gradientForeground;
  late LinearGradient _gradientBackground;

  ///背景雾层路径
  Path bPath = Path();

  ///前景雾层路径
  Path fPath = Path();

  ///判断是否更改了渐变属性。
  bool _isChangeGradient = false;

  ///缓存画布大小
  Size _cacheSize = Size.zero;

  @override
  List<Listenable> get listenables =>
      [_backgroundController, _foregroundController, _alphaController];

  @override
  void initAnim() {
    _alphaController =
        AnimationController(vsync: this, duration: Durations.extralong4);
    _backgroundController =
        AnimationController(vsync: this, duration: const Duration(seconds: 15));
    _foregroundController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10));

    _alphaController.addListener(() {
      _changeLinearGradient(_alphaController.value);
    });
  }

  @override
  void init() {
    super.init();
    _foregroundPoints = _createControlPoint(_peakDensity, true);
    _backgroundPoints = _createControlPoint(_peakDensity, true);
    _changeLinearGradient(0);
  }

  @override
  void attachLayer() {
    super.attachLayer();
    _alphaController.forward();
    _foregroundController.repeat();
    _backgroundController.repeat();
  }

  @override
  FutureOr<void> detachLayer() async {
    super.detachLayer();
    try {
      await _alphaController.reverse().orCancel;
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void draw(Canvas canvas, Size size) {
    //对画布大小进行缓存，并判断画布是否改变，如果改变就重置Path等数据
    bool reset = false;
    if (size != _cacheSize) {
      _cacheSize = size;
      reset = true;
    }

    //设置画笔着色器
    _setPaintShader(size);

    if (reset) {
      bPath.reset();

      //宽度/密度 = 均分宽度
      var dx = size.width / _peakDensity;
      var backgroundList = _backgroundPoints.map((e) {
        //根据随机的点位置，转换为坐标位置，Y轴进行平移达到合适的地方,这里加10，是为了让前后背景有一定的交错距离
        return Offset(e.dx * dx, _peakHeight * e.dy + _offsetY + 10);
      }).toList();
      _convertPoints2Path(bPath, backgroundList);
      //将路径闭合
      bPath.lineTo(size.width, size.height);
      bPath.lineTo(-size.width, size.height);
      bPath.close();
    }

    ///fixme 反复的矩阵操作也会增加绘制的耗时
    var matrix42 = Matrix4.identity();
    matrix42.translate(size.width * _backgroundController.value);
    canvas.drawPath(bPath.transform(matrix42.storage), _paintBackground);

    if (reset) {
      fPath.reset();

      //宽度/密度 = 均分宽度
      var dx = size.width / _peakDensity;
      var foregroundList = _foregroundPoints.map((e) {
        return Offset(e.dx * dx, _peakHeight * e.dy + _offsetY);
      }).toList();
      _convertPoints2Path(fPath, foregroundList);
      //将路径闭合
      fPath.lineTo(size.width, size.height);
      fPath.lineTo(-size.width, size.height);
      fPath.close();
    }

    ///fixme 反复的矩阵操作也会增加绘制的耗时
    var matrix4 = Matrix4.identity();
    matrix4.translate(size.width * _foregroundController.value);
    canvas.drawPath(fPath.transform(matrix4.storage), _paintForeground);
  }

  ///使用 catmull rom spline 将控制点转换成平滑的路径。
  _convertPoints2Path(Path path, List<Offset> controlPoints) {
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

  ///随机创建控制点
  ///[size] 控制点个数
  ///[previous] 是否在前面，这里之前做了雾的两个方向运动才设置的
  ///从逻辑中就能看出，控制点创建完成后，会复制一份点坐标，然后平移到前面。让路径看上去像是两个一摸一样的路径拼接在一起
  List<Offset> _createControlPoint(int size, bool previous) {
    var random = Random();
    var list = List.generate(size, (index) {
      double dx;
      double dy;
      if (index == 0) {
        dx = 0;
        dy = 0.5;
      } else if (index == size - 1) {
        dx = size * 1.0;
        dy = 0.5;
      } else {
        dx = (index + random.nextDouble());
        if (index % 2 == 0) {
          dy = (0.5 * random.nextDouble());
        } else {
          dy = (0.5 + 0.5 * random.nextDouble());
        }
      }
      return Offset(dx, dy);
    });
    var list2 = List.generate(size, (index) {
      var r = list[index];
      if (previous) {
        return Offset(r.dx - size, r.dy);
      } else {
        return Offset(r.dx + size, r.dy);
      }
    }).toList();

    if (previous) {
      list2.removeLast();
    } else {
      list2.removeAt(0);
    }

    return [
      if (previous) ...list2,
      ...list,
      if (!previous) ...list2,
    ];
  }

  ///改变渐变色
  _changeLinearGradient(double alpha) {
    _gradientForeground = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _color.withOpacity(alpha), // 渐变开始颜色
        _color.withOpacity(0), // 渐变结束颜色
        Colors.transparent, // 渐变结束颜色
      ],
    );
    _gradientBackground = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _color.withOpacity(0.5 * alpha), // 渐变开始颜色
        _color.withOpacity(0), // 渐变结束颜色
        Colors.transparent, // 渐变结束颜色
      ],
    );
    //标记渐变发生改变，让下次绘制的时候进行重新着色
    _isChangeGradient = true;
  }

  ///设置画笔着色器
  _setPaintShader(Size size) {
    ///仅当渐变数据改变的时候再更改着色器，一直反复创建着色器很耗时
    if (_isChangeGradient) {
      _paintForeground.shader = _gradientForeground
          .createShader(Rect.fromLTRB(0, _offsetY, size.width, size.height));
      _paintBackground.shader = _gradientBackground
          .createShader(Rect.fromLTRB(0, _offsetY, size.width, size.height));
      _isChangeGradient = false;
    }
  }
}
