import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';
import 'package:nice_weather/weathers/fogger.dart';
import 'package:nice_weather/weathers/meteor.dart';
import 'package:nice_weather/weathers/moon_simple.dart';
import 'package:nice_weather/weathers/rain.dart';
import 'package:nice_weather/weathers/snow.dart';
import 'package:nice_weather/weathers/star.dart';
import 'package:nice_weather/weathers/sun_simple.dart';

import 'weathers/cloud_full_sky.dart';
import 'weathers/sky.dart';
import 'weathers/sun.dart';

class ReviewWeatherAnim extends StatefulWidget {
  const ReviewWeatherAnim({super.key});

  @override
  State<ReviewWeatherAnim> createState() => _ReviewWeatherAnimState();
}

class WeatherLayerData {
  String description;
  List<DrawableLayer> Function() layers;

  WeatherLayerData({
    required this.description,
    required this.layers,
  });
}

class _ReviewWeatherAnimState extends State<ReviewWeatherAnim>
    with TickerProviderStateMixin {
  late List<WeatherLayerData> weatherData;

  ///当前天气图层列表
  List<DrawableLayer> currentLayers = [];

  ///当前展示的天气数据
  WeatherLayerData? currentWeather;

  ///是否使用小区域显示，用来Debug调试动画用的。
  bool smallRegion = false;

  @override
  void initState() {
    super.initState();

    ///创建需要展示的天气数据
    weatherData = [
      WeatherLayerData(
        description: "晴朗的天空",
        layers: () => [Sky(), Sun()],
      ),
      WeatherLayerData(
        description: "晴朗无月的夜晚",
        layers: () => [Sky(color: const Color(0xff272b2e)), Star(), Meteor()],
      ),
      WeatherLayerData(
        description: "雨加雪",
        layers: () => [
          Sky(color: const Color(0xff032c52)),
          CloudFullSky(
            cloudHeight: 50,
            floatingTime: const Duration(seconds: 3),
          ),
          //让雨雪夹在两个云层中间绘制，这样能更好的显示雨雪是从乌云中出现的。
          Rain(30, 25),
          Snow(45, 5),
          CloudFullSky(
            cloudColor: const Color(0xff28669a),
            floatingTime: const Duration(seconds: 2),
          ),
        ],
      ),
      WeatherLayerData(
        description: "暴雪",
        layers: () => [
          Sky(color: const Color(0xff032c52)),
          CloudFullSky(
            cloudHeight: 50,
            cloudColor: const Color(0xff28669a),
            floatingTime: const Duration(seconds: 2),
          ),
          Snow(25, 15),
          CloudFullSky(
            cloudColor: const Color(0xff28669a),
            floatingTime: const Duration(seconds: 2),
          ),
        ],
      ),
      WeatherLayerData(
        description: "有雾-白天",
        layers: () => [
          Sky(color: const Color(0xffb9a26d)),
          SunSimple(),
          Foggy(peakHeight: 30,peakDensity: 6),
        ],
      ),
      WeatherLayerData(
        description: "有雾-夜晚",
        layers: () => [
          Sky(color: const Color(0xff302520)),
          MoonSimple(),
          Foggy(color: const Color(0xff302520),peakHeight: 30,peakDensity: 6),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        shadowColor: Colors.cyan,
        elevation: 4,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 24),
          Builder(builder: (context) {
            return IconButton(
                onPressed: () => _showMenu(context),
                icon: const Icon(Icons.more_vert));
          }),
          const SizedBox(width: 24),
        ],
      ),
      body: smallRegion
          ? Center(
              child: Container(
                decoration:
                    BoxDecoration(border: Border.all(color: Colors.black)),
                width: 200,
                height: 200,
                child: DrawableLayerWidget(
                  drawableLayers: currentLayers,
                  tickerProvider: this,
                ),
              ),
            )
          : DrawableLayerWidget(
              drawableLayers: currentLayers,
              tickerProvider: this,
            ),
    );
  }

  _refresh() {
    setState(() {
      currentLayers = currentWeather?.layers() ?? [];
    });
  }

  void _showMenu(context) async {
    showModalBottomSheet(
      context: context,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) {
        return SizedBox(
          width: double.infinity,
          height: 400,
          child: ListView.builder(
            itemBuilder: (context, index) {
              var data = weatherData[index];
              return ListTile(
                title: Text(data.description),
                onTap: () {
                  Navigator.pop(context);
                  currentWeather = data;
                  _refresh();
                },
              );
            },
            itemCount: weatherData.length,
          ),
        );
      },
    );
  }
}
