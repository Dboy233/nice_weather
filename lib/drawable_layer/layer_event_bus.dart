import 'package:flutter/rendering.dart';
import 'package:nice_weather/drawable_layer/layer_logger.dart';



///通用event数据封装
class LayerEventData {
  ///事件类型
  int type;
  ///事件数据
  dynamic data;

  LayerEventData(this.type, {this.data});

  @override
  String toString() {
    return 'LayerEventData{msg: $type, data: $data}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayerEventData &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          data == other.data;

  @override
  int get hashCode => type.hashCode ^ data.hashCode;
}

///图层事件封装类，用于记录事件类型和接收器。
class LayerEvent {
  ///订阅事件对象类型
  final Type type;

  ///事件接收器
  final Function listener;

  LayerEvent(this.type, this.listener);

  @override
  String toString() {
    return 'LayerEvent{type: $type, listener: $listener}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayerEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          listener == other.listener;

  @override
  int get hashCode => type.hashCode ^ listener.hashCode;
}

///图层事件管理接口定义
abstract class LayerEventBus {
  ///订阅事件
  LayerEvent subscribe<T>(Function(T event) listener);

  ///解约事件
  void unsubscribe(LayerEvent event);

  ///发布事件
  void publish<T>(T event);
}

///图层事件管理默认实现类。
class LayerEventManagerImp implements LayerEventBus {
  final Map<Type, Set<Function>> subscribers = {};
  final LayerLogger _logger = LayerLogger.create(tag: "Event");
  @override
  LayerEvent subscribe<T>(Function(T event) listener) {
    subscribers[T] ??= {};
    subscribers[T]!.add(listener);
    var layerEvent = LayerEvent(T, listener);
    _logger.log("订阅::$layerEvent");
    return layerEvent;
  }

  @override
  void unsubscribe(LayerEvent event) {
    var success = subscribers[event.type]?.remove(event.listener) ?? false;
    success ? _logger.log("解约成功::$event") : _logger.log("解约事件失败::$event");
  }

  @override
  void publish<T>(T event) {
    _logger.log("发布事件:$event");
    subscribers[T]?.forEach((listener) => listener(event));
  }
}
