import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';

class _CacheStarLocation {
  final double xPercent;
  final double yPercent;

  _CacheStarLocation(this.xPercent, this.yPercent);
}

class Star extends DrawableLayer with AnimationAbilityMixin {
  Star() : super(label: "星星");

  ///随机创建对象
  final random = Random();

  ///星星画笔
  final _starPaint = Paint()..strokeCap = StrokeCap.round;

  ///透明度动画。
  late AnimationController _alphaController;
  late Animation<double> _alphaAnimation;

  ///缓存星星的坐标分布
  final _cacheSmallStarLocation = <_CacheStarLocation>[];
  final _cacheBigStarLocation = <_CacheStarLocation>[];

  ///闪烁画笔
  final _flashingPaint = Paint()
    ..color = Colors.yellow
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.0;

  ///星星闪烁动画。
  late AnimationController _flashingController;
  final List<Animation<double>> _flashingAnimations = [];

  ///固定显示的闪烁星星数量，数量最多3个了，如果增加就需要调整，动画的Interval间隔。
  ///当前是每隔0.2个时间百分比闪烁下一个星星。
  final _flashingSize = 3;

  ///缓存闪烁的星星的坐标分布，从[_cacheSmallStarLocation]和[_cacheBigStarLocation]中随机选取
  final _cacheFlashingStarLocation = <_CacheStarLocation>[];

  ///是否显示闪烁的星星
  bool _showFlashingStar = false;

  ///闪烁的开始延迟触发任务
  Timer? _delayFlashingTimer;

  @override
  void initAnim() {
    _alphaController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _alphaAnimation = Tween(begin: 0.0, end: 1.0).animate(_alphaController);
    _flashingController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    //循环为_flashingSize数量的星星设置闪烁数值动画。不要轻易的修改Interval的区间
    //因为其直接影响星星闪烁的效果。
    for (var i = 0; i < _flashingSize; i++) {
      _flashingAnimations.add(Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
              parent: _flashingController,
              curve:
                  Interval(0.2 * i, 0.6 + (0.2 * i), curve: Curves.linear))));
    }
    _flashingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _endFlashing();
      }
    });
  }

  @override
  void attachLayer() {
    super.attachLayer();
    _alphaController.forward();
    _createDelayTimer();
  }

  @override
  FutureOr<void> detachLayer() async {
    super.detachLayer();
    try {
      //等待星星隐藏，如果突然隐藏，画面会比较的突兀。
      await _alphaController.reverse().orCancel;
    } catch (e) {
      debugPrint("[$label]图层分离异常：${e.toString()}");
    }
  }

  @override
  void init() {
    super.init();
    _randomStarLocation();
  }

  @override
  void dispose() {
    _delayFlashingTimer?.cancel();
    super.dispose();
  }

  @override
  void draw(Canvas canvas, Size size) {
    var region = Size(size.width, size.height * 0.4);
    _drawStar(canvas, region);
    _createFlashingStarOnlyOnce();
    _drawFlashingStar(canvas, region);
  }

  //绘制星星
  void _drawStar(Canvas canvas, Size region) {
    _starPaint.color = Colors.yellow.withOpacity(_alphaAnimation.value);
    _starPaint.strokeWidth = 2.0;
    final smallStarOffsets = _cacheSmallStarLocation
        .map((e) =>
            Offset(region.width * e.xPercent, region.height * e.yPercent))
        .toList();
    canvas.drawPoints(PointMode.points, smallStarOffsets, _starPaint);
    _starPaint.strokeWidth = 5.0;
    final bigStarOffsets = _cacheBigStarLocation
        .map((e) =>
            Offset(region.width * e.xPercent, region.height * e.yPercent))
        .toList();
    canvas.drawPoints(PointMode.points, bigStarOffsets, _starPaint);
  }

  ///随机星星坐标所占的比例
  ///就是星星在空间坐标系中，X占画布的宽度百分比，Y占画布高度的半分比
  ///随机他们的xy坐标位置，这样就能让星星均匀的分散开。
  _randomStarLocation() {
    const allStarCount = 80;
    const minBigStarCount = 10;
    _cacheSmallStarLocation.clear();
    _cacheBigStarLocation.clear();

    _cacheSmallStarLocation.addAll(List.generate(allStarCount, (index) {
      final x = random.nextDouble();
      final y = random.nextDouble();
      return _CacheStarLocation(x, y);
    }));

    var randomBigStarSize = minBigStarCount + random.nextInt(minBigStarCount);
    for (int i = 0; i < randomBigStarSize; i++) {
      var removeIndex = random.nextInt(_cacheSmallStarLocation.length);
      var location = _cacheSmallStarLocation.removeAt(removeIndex);
      _cacheBigStarLocation.add(location);
    }
  }

  ///绘制闪烁的星星
  _drawFlashingStar(Canvas canvas, Size region) {
    if (!_showFlashingStar) return;
    if (_cacheFlashingStarLocation.isEmpty) {
      return;
    }
    var starOffsets = _cacheFlashingStarLocation
        .map((e) =>
            Offset(region.width * e.xPercent, region.height * e.yPercent))
        .toList();
    //在对应位位置绘制扩散阴影
    for (int i = 0; i < starOffsets.length; i++) {
      ///如果动画是0，说明还没轮到它闪烁，就没必要执行后面的操作了。
      if (_flashingAnimations[i].value == 0.0) continue;

      Offset offset = starOffsets[i];

      Path path = Path();
      //外角到中心点的长度
      var hornLong = 10;
      //内角到中心点的长度
      var shankLong = 1;
      path.moveTo(offset.dx, offset.dy - hornLong);
      path.lineTo(offset.dx - shankLong, offset.dy - shankLong);
      path.lineTo(offset.dx - hornLong, offset.dy);
      path.lineTo(offset.dx - shankLong, offset.dy + shankLong);
      path.lineTo(offset.dx, offset.dy + hornLong);
      path.lineTo(offset.dx + shankLong, offset.dy + shankLong);
      path.lineTo(offset.dx + hornLong, offset.dy);
      path.lineTo(offset.dx + shankLong, offset.dy - shankLong);
      path.close();

      // 获取路径的边界框
      final bounds = path.getBounds();
      // 计算路径的中心点
      final center = bounds.center;
      //获取动画执行进度
      var process = _flashingAnimations[i].value;
      // 旋转角度（以弧度为单位）
      final rotation = (360 * process) * pi / 180;
      //缩放计算，放大再缩小。
      var scale = 0.0;
      if (process <= 0.5) {
        //这里 * 几，就是放大几倍。
        scale = process * 3;
      } else {
        scale = (1 - process) * 3;
      }
      // 创建一个矩阵对象并设置旋转和缩放
      final matrix = Matrix4.identity();
      //对于在某个点上进行变换操作流程是 平移 ->[各种变换操作] -> 反向平移。
      //因为所有的变换操作都是在原点进行，所以需要先平移到中心点，然后操作，最后反向平移回去。
      matrix.translate(center.dx, center.dy);
      matrix.rotateZ(rotation);
      matrix.scale(scale);
      matrix.translate(-center.dx, -center.dy);

      // 对路径进行变换
      path = path.transform(matrix.storage);
      canvas.drawPath(path, _flashingPaint);
    }
  }

  ///创建要闪烁的星星坐标，从已有坐标系中选择
  _createFlashingStarOnlyOnce() {
    if (!_showFlashingStar) return;
    if (_cacheFlashingStarLocation.isNotEmpty) return;
    var mergedStar = <_CacheStarLocation>[];
    mergedStar.addAll(_cacheSmallStarLocation);
    mergedStar.addAll(_cacheBigStarLocation);

    for (int i = 0; i < _flashingSize; i++) {
      var index = random.nextInt(mergedStar.length);
      _cacheFlashingStarLocation.add(mergedStar.removeAt(index));
    }
  }

  ///结束闪烁
  _endFlashing() {
    _showFlashingStar = false;
    _cacheFlashingStarLocation.clear();
    _createDelayTimer();
  }

  ///开始闪烁
  _startFlashing() {
    if (_flashingController.isAnimating) return;
    _showFlashingStar = true;
    _flashingController.forward(from: 0.0);
  }

  ///创建延任务，延迟闪烁
  _createDelayTimer() {
    _delayFlashingTimer?.cancel();

    ///延迟任务一定是大于动画时长的。必须要等到下一个循环执行完成之后才可以进行下一次的延迟任务
    _delayFlashingTimer = Timer(const Duration(seconds: 3), () {
      _startFlashing();
    });
  }

  @override
  List<Listenable> get listenables => [_alphaController, _flashingController];
}
