import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nice_weather/drawable_layer/layer_logger.dart';

import '_utils.dart';
import 'layer_event_bus.dart';

///默认能力管理器创建辅助方法
List<AbilityManager> createDefAbilityManagers({
  TickerProvider? tickerProvider,
  LayerEventBus? eventBus,
}) {
  return [
    if (eventBus != null) EventBusAbilityManager(eventBus: eventBus),
    if (tickerProvider != null) AnimationAbilityManager(tickerProvider),
    LayerExistAbilityManager(),
  ];
}

///可绘制图层。
///每个图层独立绘制，拥有自己的生命周期 init->attachLayer->draw->detachLayer->dispose
///如果需要动画能力查看[AnimationAbilityMixin]。
///如果需要EventBus能力查看[EventBusAbilityMixin]。
abstract class DrawableLayer {
  DrawableLayer({this.label});

  final LayerLogger _logger = LayerLogger.create(tag: "Layer");

  ///label用于debug测试打印，可填写图层用途或者别名。
  String? label;

  ///所有可以让[CustomPainter]重绘的[Listenable]对象合集。
  ///因为每个图层进行了独立的封装，所以所有UI可见元素的数据都应该是被动更新由Listenable控制。
  List<Listenable> get listenables;

  ///初始化，用于初始化AnimationController和Animation资源
  void init() {
    _logger.log("Layer - ${toString()} init");
  }

  ///当图层添加到画布的时候触发。
  void attachLayer() {
    _logger.log("${toString()} attachLayer");
  }

  ///绘制
  void draw(Canvas canvas, Size size);

  ///当图层将要从画布移除的时候触发。
  ///如果要执行消失动画，可以使用await AnimationController.forward().orCancel，
  ///并用try catch包裹。
  ///当detachLayer执行完成后自动触发dispose方法。
  FutureOr<void> detachLayer() {
    _logger.log("${toString()} detachLayer");
  }

  ///用于销毁AnimationController和Animation资源
  void dispose() {
    _logger.log("${toString()} dispose");
  }

  @override
  String toString() {
    return 'DrawableLayer{label: $label,hashCode:$hashCode}';
  }
}

///使得图层的扩展能力得到绑定或卸载。
///每个能力管理者对应一个混入类。两者存在强依赖和一一对应的关系。
///例如[AnimationAbilityMixin]和 [AnimationAbilityManager]
///因为[DrawableLayer]是抽象类需要子类继承，为了可以打造通用的扩展功能封装，则需要使用
///混入类的加入，但是混入类无法让子类提供统一的依赖注入，所以需要使用[AbilityManager]来管理。
///其实这样就是多个实现能力混入的图层都由一个管理者管理，这样就实现了图层的扩展能力的统一管理。
///扩展能力需要的外部依赖可以由[AbilityManager]来提供。
///
/// [AbilityManager]无法感知[DrawableLayer]的生命周期。
/// 但是可以知道何时添加和移除图层。并且在图层添加的时候为其注入能力所需的依赖。
///
abstract class AbilityManager {
  ///此方法会在[DrawableLayer]的init方法之前执行。
  void onAddDrawableLayer(CompositeDrawableLayer compositeDrawableLayer,
      DrawableLayer drawableLayer);

  ///此方法会在[DrawableLayer]的生命周期的dispose方法之后并且图层列表彻底remove后执行。
  void onRemoveDrawableLayer(CompositeDrawableLayer compositeDrawableLayer,
      DrawableLayer drawableLayer);
}

///组合可绘制图层。
abstract class CompositeDrawableLayer {
  ///所有可以让CustomPainter重绘的[Listenable]对象合集
  List<Listenable> get listenables;

  ///所有图层列表
  List<DrawableLayer> get drawableLayers;

  ///能力管理者列表
  List<AbilityManager> get abilityManagers;

  ///添加图层
  void addLayer(DrawableLayer drawable, {int index = -1});

  ///移除图层
  void removeLayer(DrawableLayer drawable);

  ///绘制。
  void draw(Canvas canvas, Size size);
}

///绘制图层组件。将实现[DrawableLayer]的对象进行管理和绘制。
///内部实现逻辑比较的简单，如果需要定制也是完全没有难度的。
class DrawableLayerWidget extends StatefulWidget {
  ///图层列表
  final List<DrawableLayer> drawableLayers;

  ///动画控制器，如果你的图层中需要对动画操作，一定要提供。
  final TickerProvider? tickerProvider;

  ///EventBus,一般来说不需要自己提供，但是如果你有更高效的EventBus实现方案，可以自己进行封装。
  final LayerEventBus? eventBus;

  const DrawableLayerWidget(
      {super.key,
      required this.drawableLayers,
      this.tickerProvider,
      this.eventBus});

  @override
  State<DrawableLayerWidget> createState() => _DrawableLayerWidgetState();
}

class _DrawableLayerWidgetState extends State<DrawableLayerWidget> {
  late CompositeDrawableLayerManager _composite;

  @override
  void initState() {
    super.initState();
    _composite = CompositeDrawableLayerManager.ability(
        abilityManagers: createDefAbilityManagers(
      tickerProvider: widget.tickerProvider,
      eventBus: widget.eventBus ?? LayerEventManagerImp(),
    ));

    ///初始化数据列表，之后的数据外部可以通过setState改变数据列表来提供。
    _composite.addNewLayers(widget.drawableLayers);
  }

  @override
  void didUpdateWidget(covariant DrawableLayerWidget oldWidget) {
    ///因为数据由外部提供，当外部调用setState重新给图层列表的时候，就要动态的为其进行添加和移除。
    ///所以updateLayers封装的内容就是数据对比，然后进行add和remove
    _composite.updateLayers(widget.drawableLayers);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void reassemble() {
    ///热重载的时候移除所有数据。
    _composite.removeAllLayer();
    super.reassemble();
  }

  @override
  void dispose() {
    _composite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: DrawableLayerPainter(composite: _composite),
      ),
    );
  }
}

///图层绘制
class DrawableLayerPainter extends CustomPainter {
  final CompositeDrawableLayer composite;

  DrawableLayerPainter({
    required this.composite,
  }) : super(repaint: Listenable.merge(composite.listenables));

  @override
  void paint(Canvas canvas, Size size) {
    composite.draw(canvas, size);
  }

  ///因为是否绘制已经全部交由repaint控制，所以这里返回false。
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

///组合绘制图层混入类，用于管理图层。
class CompositeDrawableLayerManager extends CompositeDrawableLayer {
  ///图层合集
  final List<DrawableLayer> _drawableLayers = [];

  final LayerLogger _logger = LayerLogger.create(tag: "composite");

  ///需要移除的图层合集，如果图层在移除的时候需要异步，就将需要移除的图层先添加到待移除队列。
  final Map<int, Set<DrawableLayer>> _futureRemoveCacheMap = {};

  ///能力管理者
  final List<AbilityManager> _abilityManagers;

  ///辅助刷新，主动通知绘制。
  final ValueNotifier<int> _assistedRefreshDraw = ValueNotifier(0);

  CompositeDrawableLayerManager.ability({List<AbilityManager>? abilityManagers})
      : _abilityManagers = abilityManagers ?? [];

  CompositeDrawableLayerManager.create({
    TickerProvider? tickerProvider,
    LayerEventBus? eventBus,
  }) : this.ability(
            abilityManagers: createDefAbilityManagers(
          tickerProvider: tickerProvider,
          eventBus: eventBus ?? LayerEventManagerImp(),
        ));

  @override
  List<AbilityManager> get abilityManagers => _abilityManagers;

  ///获取所有图层，其中包含了正在移除的图层。
  @override
  List<DrawableLayer> get drawableLayers {
    return [
      ..._drawableLayers,
      ..._futureRemoveCacheMap.values.expand((e) => e)
    ];
  }

  ///图层初始化.
  ///建议在initState方法中添加图层。
  void addNewLayers(List<DrawableLayer> layers) {
    if (checkSameLayer(layers)) {
      throw "存在相同实例的图层，请检查图层列表: $layers";
    }
    for (var drawableLayer in layers) {
      addLayer(drawableLayer);
    }
  }

  ///更新图层。
  ///更新并不是替换，而是将新图层和旧图层进行合并，删除，添加，排序。
  ///将新列表和旧列表进行对比，找出需要删除的图层，新增的图层。
  ///如果新图层列表中包含了旧的图层列表，并且两者是同一个实例，则此图层将不会刷新。
  ///其实这部分的代码逻辑，应该由外部调用者进行操作，而不是封装到内部。
  void updateLayers(List<DrawableLayer> newLayers) async {
    //浅拷贝旧对象，不能对同一个List做查询和移除操作，
    var oldLayers = [..._drawableLayers];

    ///这里去重，指的是同一个对象，如果是不同对象示例的同一个图层没事。
    ///当然这里的去重还是需要看你是否需要重写DrawableLayer的 == 操作符。
    ///如果你重写了，那么即使是不同对象但是同一个类型的图层也会被去重。
    if (checkSameLayer(newLayers)) {
      _logger.log("存在相同实例的图层，新图层将会被去重: $newLayers");
      newLayers = newLayers.toSet().toList();
      _logger.log("去重后的图层: $newLayers");
    }
    _logger.log("旧图层：$oldLayers");
    _logger.log("新图层：$newLayers");
    //先找出是否减少了绘制图层，并将旧的移除。旧列表中在新列表中消失的就是删除的。
    oldLayers
        .where((element) => !newLayers.contains(element))
        .forEach((element) {
      _logger.log("删除图层：$element");
      removeLayer(element);
    });

    //找到新增的绘制图层并添加，新列表在旧列表中没有的就是新增的。
    newLayers
        .where((element) => !oldLayers.contains(element))
        .forEach((element) {
      _logger.log("添加图层: $element");
      var indexOf = newLayers.indexOf(element);
      addLayer(element, index: indexOf);
    });

    //已经完成了添加和删除操作，如果其中有数据位置交换的，那么对数据进行排序。
    sortListLike(newLayers, _drawableLayers);
  }

  ///清理资源
  void dispose() {
    _assistedRefreshDraw.dispose();
    removeAllLayer();
  }

  ///当图层添加时，检查图层的其他能力
  void _onAddLayerCheckAbilityManager(DrawableLayer drawableLayer) {
    for (var manager in abilityManagers) {
      manager.onAddDrawableLayer(this, drawableLayer);
    }
  }

  ///当图层移除时，检查图层的其他能力
  void _onRemoveLayerCheckAbilityManager(DrawableLayer drawableLayer) {
    for (var manager in abilityManagers) {
      manager.onRemoveDrawableLayer(this, drawableLayer);
    }
  }

  ///添加图层。
  @override
  void addLayer(DrawableLayer drawableLayer, {int? index}) {
    if (_drawableLayers.contains(drawableLayer)) {
      _logger.log("图层:$drawableLayer 已经添加了");
      return;
    }
    if (index != null && index < 0) {
      _logger.log("图层$drawableLayer 添加越界，将添加到最底层 index = 0 ");
    }
    if (index != null && index > _drawableLayers.length) {
      _logger.log(
          "图层$drawableLayer 添加越界，将添加到顶层 index = ${_drawableLayers.length}");
      index = _drawableLayers.length;
    }
    _onAddLayerCheckAbilityManager(drawableLayer);
    drawableLayer.init();
    if (index != null) {
      _drawableLayers.insert(index, drawableLayer);
    } else {
      _drawableLayers.add(drawableLayer);
    }
    drawableLayer.attachLayer();
    _assistedRefreshDraw.value += 1;
  }

  ///移除图层。
  @override
  void removeLayer(DrawableLayer drawableLayer) {
    if (!_drawableLayers.contains(drawableLayer)) {
      _logger.log("图层:$drawableLayer,没有在绘制合集中");
      return;
    }
    try {
      var futureOr = drawableLayer.detachLayer();
      if (futureOr is Future) {
        _futureRemoveLayer(futureOr, drawableLayer);
      } else {
        _removeLayer(drawableLayer);
      }
    } catch (e) {
      _logger.log(e.toString());
    }
  }

  ///直接移除图层
  _removeLayer(DrawableLayer drawableLayer) {
    drawableLayer.dispose();
    _drawableLayers.remove(drawableLayer);
    _onRemoveLayerCheckAbilityManager(drawableLayer);

    //刷新绘制，当移除图层后，需要刷新绘制。因为最后一帧可能会残留在Canvas上。
    _assistedRefreshDraw.value += 1;
  }

  ///由于DrawableLayer的detachLayer是Future类型，需要未来移除它，将其添加到缓存队列中。
  _futureRemoveLayer(Future future, DrawableLayer drawableLayer) {
    _logger.log("缓存到将要删除队列，$drawableLayer");
    var index = _drawableLayers.indexOf(drawableLayer);
    _drawableLayers.remove(drawableLayer);
    _futureRemoveCacheMap[index] ??= {};
    _futureRemoveCacheMap[index]!.add(drawableLayer);
    future.then((value) {
      drawableLayer.dispose();
      var remove = _futureRemoveCacheMap[index]!.remove(drawableLayer);
      if (remove) {
        _logger.log("成功移除$drawableLayer");
      }
      if (_futureRemoveCacheMap[index]!.isEmpty) {
        _futureRemoveCacheMap.remove(index);
      }
      _onRemoveLayerCheckAbilityManager(drawableLayer);

      //刷新绘制，当移除图层后，需要刷新绘制。因为最后一帧可能会残留在Canvas上。
      _assistedRefreshDraw.value += 1;
    });
  }

  ///绘制。
  @override
  void draw(Canvas canvas, Size size) {
    var dlLength = _drawableLayers.length;
    var dlRemoveLength = _futureRemoveCacheMap.length;

    //需要删除的图层，以前所在的下标位置，取最大下标位置。
    final maxDlRemoveIndex = dlRemoveLength == 0
        ? 0
        : _futureRemoveCacheMap.keys.reduce((value, element) {
            return value > element ? value : element;
          });

    //循环下标，取正常绘制图层的位置和需要移除图层的下表最大值，
    //确保查询的时候能正确渲染两种类型图层。
    final loopIndex = max(dlLength, maxDlRemoveIndex);
    for (var i = 0; i < loopIndex; i++) {
      //先在当前位置绘制需要移除的图层，因为它被移除之前在这个位置。
      var futureRemoveList = _futureRemoveCacheMap[i];
      if (futureRemoveList != null) {
        //这里拷贝列表是因为可能在循环的时候，会对此列表进行remove操作，防止并发删除错误
        final copyList = [...futureRemoveList];
        for (var dl in copyList) {
          dl.draw(canvas, size);
        }
      }

      //绘制正常图层列表
      if (i < dlLength) {
        _drawableLayers[i].draw(canvas, size);
      }
    }
  }

  ///所有可绘制图层的Listenable集合。
  @override
  List<Listenable> get listenables {
    return [
      _assistedRefreshDraw,
      for (var dl in drawableLayers) ...dl.listenables,
    ];
  }

  ///丢弃所有图层，并释放资源。
  ///所有图层都会被调用 dispose 方法。
  void removeAllLayer() {
    try {
      if (_drawableLayers.isEmpty) return;
      for (var dl in _drawableLayers) {
        dl.dispose();
      }
      _drawableLayers.clear();

      _futureRemoveCacheMap.forEach((key, dlSet) {
        for (var dl in dlSet) {
          dl.dispose();
        }
      });
      _futureRemoveCacheMap.clear();
    } catch (e) {
      _logger.log(e.toString());
    }
  }
}

///动画能力管理。
///对应[AnimationAbilityMixin]
class AnimationAbilityManager implements AbilityManager {
  ///为动画提供
  final TickerProvider _tickerProvider;

  AnimationAbilityManager(TickerProvider tickerProvider)
      : assert(tickerProvider is TickerProviderStateMixin,
            "当使用图层的动画能力时，请使用TickerProviderStateMixin"),
        _tickerProvider = tickerProvider;

  @override
  void onAddDrawableLayer(CompositeDrawableLayer compositeDrawableLayer,
      DrawableLayer drawableLayer) {
    if (drawableLayer is AnimationAbilityMixin) {
      drawableLayer._initTickerProvider(_tickerProvider);
      drawableLayer.initAnim();
    }
  }

  @override
  void onRemoveDrawableLayer(CompositeDrawableLayer compositeDrawableLayer,
      DrawableLayer drawableLayer) {}
}

///EventBus能力管理
///对应[EventBusAbilityMixin]
class EventBusAbilityManager implements AbilityManager {
  ///事件管理
  final LayerEventBus _layerEventBus;

  EventBusAbilityManager({LayerEventBus? eventBus})
      : _layerEventBus = eventBus ?? LayerEventManagerImp();

  @override
  void onAddDrawableLayer(CompositeDrawableLayer compositeDrawableLayer,
      DrawableLayer drawableLayer) {
    if (drawableLayer is EventBusAbilityMixin) {
      drawableLayer._initEventBus(_layerEventBus);
      drawableLayer.subscribeEvent();
    }
  }

  @override
  void onRemoveDrawableLayer(CompositeDrawableLayer compositeDrawableLayer,
      DrawableLayer drawableLayer) {}
}

///图层感知存在管理器类。
///对应[LayerExistAbilityMixin]
class LayerExistAbilityManager implements AbilityManager {
  @override
  void onAddDrawableLayer(CompositeDrawableLayer compositeDrawableLayer,
      DrawableLayer drawableLayer) {
    //会通知所有图层包括还没有被删除的图层，但是不会通知当前被添加的图层。
    var drawableLayers = compositeDrawableLayer.drawableLayers;
    for (var dl in drawableLayers) {
      if (dl != drawableLayer && dl is LayerExistAbilityMixin) {
        dl.onDrawableLayerAdd(drawableLayer);
      }
    }
  }

  @override
  void onRemoveDrawableLayer(CompositeDrawableLayer compositeDrawableLayer,
      DrawableLayer drawableLayer) {
    //会通知所有图层包括还没有被删除的图层，但是不会通知当前被删除的图层。
    var drawableLayers = compositeDrawableLayer.drawableLayers;
    for (var dl in drawableLayers) {
      if (dl != drawableLayer && dl is LayerExistAbilityMixin) {
        dl.onDrawableLayerRemove(drawableLayer);
      }
    }
  }
}

///为绘制图层提供动画能力，并自动销毁所有动画资源。
///对应[AnimationAbilityManager]
mixin AnimationAbilityMixin on DrawableLayer implements TickerProvider {
  TickerProvider? _tickerProvider;

  ///初始化TickerProvider，此方法由[AnimationAbilityManager]调用。
  void _initTickerProvider(TickerProvider tickerProvider) {
    _tickerProvider = tickerProvider;
  }

  ///初始化动画，子类图层所有的动画资源的创建都应在当前方法中执行。
  ///此方法由[AnimationAbilityManager]调用。
  void initAnim();

  @override
  Ticker createTicker(TickerCallback onTick) {
    assert(
        _tickerProvider != null,
        "为图层添加了Animation能力，"
        "但是与之对应的AnimationAbilityManager并未添加到CompositeDrawableLayerManager");
    return _tickerProvider!.createTicker(onTick);
  }

  @override
  void dispose() {
    //在当前图层销毁的时候回收所有动画资源。
    for (var listenable in listenables) {
      if (listenable is AnimationController) {
        try {
          listenable.dispose();
        } catch (e) {
          _logger.log(e.toString());
        }
      }
    }
    super.dispose();
  }
}

///图层事件混入类，为绘制图层对象提供EventBus能力,并且自动根据生命周期解除event订阅。
///对应 [EventBusAbilityManager]
mixin EventBusAbilityMixin on DrawableLayer implements LayerEventBus {
  ///事件管理。每个图层都可以使用此事件管理对象。
  LayerEventBus? _layerEventBus;

  final List<LayerEvent> _autoUnsubscribeList = [];

  ///初始化event对象
  void _initEventBus(LayerEventBus layerEventBus) {
    _layerEventBus = layerEventBus;
  }

  ///注册事件，绘制图层的所有事件的订阅代码都应在该方法中实现。
  void subscribeEvent();

  @override
  LayerEvent subscribe<T>(Function(T event) listener) {
    assert(
        _layerEventBus != null,
        "为图层添加了EventBus能力，"
        "但是与之对应的EventBusAbilityManager并未添加到CompositeDrawableLayerManager");
    var layerEvent = _layerEventBus!.subscribe(listener);
    _autoUnsubscribeList.add(layerEvent);
    return layerEvent;
  }

  @override
  void unsubscribe(LayerEvent event) {
    assert(
        _layerEventBus != null,
        "为图层添加了EventBus能力，"
        "但是与之对应的EventBusAbilityManager并未添加到CompositeDrawableLayerManager");
    _layerEventBus?.unsubscribe(event);
    _autoUnsubscribeList.remove(event);
  }

  @override
  void publish<T>(T event) {
    assert(
        _layerEventBus != null,
        "为图层添加了EventBus能力，"
        "但是与之对应的EventBusAbilityManager并未添加到CompositeDrawableLayerManager");
    _layerEventBus?.publish(event);
  }

  @override
  void dispose() {
    assert(
        _layerEventBus != null,
        "为图层添加了EventBus能力，"
        "但是与之对应的EventBusAbilityManager并未添加到CompositeDrawableLayerManager");
    for (var layerEvent in _autoUnsubscribeList) {
      _layerEventBus!.unsubscribe(layerEvent);
    }
    _autoUnsubscribeList.clear();
    super.dispose();
  }
}

///感知其他图层的存在，图层可以接收到其他图层被添加和被移除的通知。
///对应 [LayerExistAbilityManager]
mixin LayerExistAbilityMixin on DrawableLayer {
  ///当新的图层被添加的时候，会调用此方法。
  ///[drawableLayer] - 被添加的图层。
  void onDrawableLayerAdd(DrawableLayer drawableLayer) {}

  ///当图层被移除的时候，会调用此方法。
  ///[drawableLayer] - 被移除的图层。
  void onDrawableLayerRemove(DrawableLayer drawableLayer) {}
}

///图层生命周期扩展，混入类
///子类的draw方法需要在第一行调用super.draw()
/// void draw(Canvas canvas, Size size) {
///     super.draw(canvas, size);
///     。。。
///}
mixin LayerLifeCycleExtendMixin on DrawableLayer {
  ///缓存画布大小
  Size _cacheSize = Size.zero;

  @override
  @mustCallSuper
  void draw(Canvas canvas, Size size) {
    if (_cacheSize != size) {
      onSizeChange(canvas, _cacheSize, size);
      _cacheSize = size;
    }
  }

  ///画布大小改变。
  ///每当画布大小发生改变时通知此方法。并且此方法只会在[draw]之前通知，
  ///并且在画布大小确定之后，此方法只会通知一次。
  ///可以在此方法中做一些会之前的初始化操作，因为其他生命周期中无法拿到画布大小，对于一些坐标定位，
  ///可重复利用资源的创建和初始化都有很大的帮助。
  ///[preSize] 前一个尺寸
  ///[size] 改变后的尺寸
  void onSizeChange(Canvas canvas, Size preSize, Size size) {}
}
