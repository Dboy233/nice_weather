// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nice_weather/main.dart';

shortList(List list){
  //打乱list顺序
  for(int i=0;i<list.length;i++){
    int random = Random().nextInt(list.length);
    String temp = list[i];
    list[i] = list[random];
    list[random] = temp;
  }
}
void main() {


  test("测试", (){



      List<String> list = ["1","2","3"];

      shortList(list);

      print(list);

  });

}


class _EventSubscription {
  final Function listener;
  final Type eventType;

  _EventSubscription( this.eventType,this.listener);
}