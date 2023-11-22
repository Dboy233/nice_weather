import 'package:flutter/foundation.dart';

///数据排序，将数据排序成和它一样的顺序
void sortListLike<R>(List<R> like, List<R> checkList) {
  if (like.length != checkList.length) {
    return;
  }
  if (isSameOrder(like, checkList)) {
    return;
  }
  // 创建一个映射，将 A 中的元素映射到它们的索引
  Map<R, int> indexMap = {for (var i = 0; i < like.length; i++) like[i]: i};

  // 对 B 进行排序，使用映射中的索引作为比较依据
  checkList.sort((b1, b2) => indexMap[b1]!.compareTo(indexMap[b2]!));
}

///判断当前数据顺序是否和给定like一样。
bool isSameOrder<R>(List<R> like, List<R> checkList) {
  // 检查每个位置的元素是否相同
  for (int i = 0; i < like.length; i++) {
    if (like[i] != checkList[i]) {
      return false;
    }
  }
  return true;
}

///检查List是否存在相同数据
bool checkSameLayer(List list) {
  var newSet = list.toSet();
  if (newSet.length != list.length) {
    return true;
  }
  return false;
}
