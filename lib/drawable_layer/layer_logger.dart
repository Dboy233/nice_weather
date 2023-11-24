class LayerLogger {
  LayerLogger.create({String? tag, bool? enable})
      : _tag = tag ?? "LayerLogger",
        _enable = enable ?? true;
  ///全局开关
  static bool globeEnable = true;
  ///标签
  final String _tag;
  ///局部开关
  final bool _enable;

  void log(Object log) {
    if (globeEnable) {
      if (_enable) {
       print("$_tag::$log");
      }
    }
  }

}
