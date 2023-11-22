import 'package:flutter/material.dart';
import 'package:nice_weather/drawable_layer/drawable_layer.dart';
import 'package:nice_weather/weathers/meteor.dart';
import 'package:nice_weather/weathers/rain.dart';
import 'package:nice_weather/weathers/snow.dart';
import 'package:nice_weather/weathers/star.dart';

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

  List<DrawableLayer> currentLayers = [];

  WeatherLayerData? currentWeather;

  bool smallRegion = false;

  @override
  void initState() {
    super.initState();

    weatherData = [
      WeatherLayerData(
        description: "白天",
        layers: () => [Sky(), Sun()],
      ),
      WeatherLayerData(
        description: "夜晚",
        layers: () => [Sky(color: const Color(0xff272b2e)), Star(), Meteor()],
      ),
      WeatherLayerData(
        description: "雨雪",
        layers: () => [
          Sky(color: const Color(0xff032c52)),
          CloudFullSky(
              cloudHeight: 50, floatingTime: const Duration(seconds: 3)),
          Rain(30,25),
          Snow(45,5),
          CloudFullSky(
              cloudHeight: 20,
              cloudColor: const Color(0xff28669a),
              floatingTime: const Duration(seconds: 2)),
        ],
      ),
      WeatherLayerData(
        description: "下雪",
        layers: () => [
          Sky(color: const Color(0xff032c52)),
          Snow(),
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
              child: SizedBox(
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
