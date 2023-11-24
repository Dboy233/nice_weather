

import 'dart:math';

final xRandom = Random();


class CatmullRomSpline {
  static List<Point<double>> calculateCatmullRomSpline(List<Point<double>> controlPoints, double t) {
    int numPoints = controlPoints.length;

    if (numPoints < 4) {
      throw ArgumentError('Catmull-Rom Spline requires at least 4 control points.');
    }

    List<Point<double>> result = [];

    for (int i = 0; i < numPoints - 3; i++) {
      Point<double> p0 = controlPoints[i];
      Point<double> p1 = controlPoints[i + 1];
      Point<double> p2 = controlPoints[i + 2];
      Point<double> p3 = controlPoints[i + 3];

      result.add(_calculateCatmullRomPoint(t, p0, p1, p2, p3));
    }

    return result;
  }

  static Point<double> _calculateCatmullRomPoint(double t, Point<double> p0, Point<double> p1, Point<double> p2, Point<double> p3) {
    double t2 = t * t;
    double t3 = t * t2;

    double x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3);
    double y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3);

    return Point<double>(x, y);
  }
}


class BSpline {
  static double calculateBSplineBasis(double t, int i, int p, List<double> knots) {
    if (p == 0) {
      return (knots[i] <= t && t < knots[i + 1]) ? 1.0 : 0.0;
    }

    double basis1 = (t - knots[i]) / (knots[i + p] - knots[i]);
    double basis2 = (knots[i + p + 1] - t) / (knots[i + p + 1] - knots[i + 1]);

    double recursive1 = calculateBSplineBasis(t, i, p - 1, knots);
    double recursive2 = calculateBSplineBasis(t, i + 1, p - 1, knots);

    return basis1 * recursive1 + basis2 * recursive2;
  }

  static Point<double> calculateBSplinePoint(double t, int degree, List<Point<double>> controlPoints, List<double> knots) {
    double x = 0.0;
    double y = 0.0;

    int n = controlPoints.length - 1;

    for (int i = 0; i <= n; i++) {
      double basis = calculateBSplineBasis(t, i, degree, knots);
      x += basis * controlPoints[i].x;
      y += basis * controlPoints[i].y;
    }

    return Point<double>(x, y);
  }
}