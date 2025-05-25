import 'package:flutter/material.dart';

class ProgressChartWidget extends StatelessWidget {
  final List<double> painLevels;
  final List<int> adherenceRates;
  final List<String> dates;
  final String title;
  final double? maxPainLevel;
  final int? maxAdherenceRate;

  const ProgressChartWidget({
    super.key,
    required this.painLevels,
    required this.adherenceRates,
    required this.dates,
    this.title = 'Progress Over Time',
    this.maxPainLevel,
    this.maxAdherenceRate,
  });

  @override
  Widget build(BuildContext context) {
    if (painLevels.isEmpty || adherenceRates.isEmpty || dates.isEmpty) {
      return const Center(
        child: Text('No data available for chart'),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.7,
              child: CustomPaint(
                painter: ProgressChartPainter(
                  painLevels: painLevels,
                  adherenceRates: adherenceRates,
                  dates: dates,
                  maxPainLevel: maxPainLevel ?? 10,
                  maxAdherenceRate: maxAdherenceRate ?? 100,
                  painColor: Colors.red,
                  adherenceColor: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Pain Level', Colors.red),
                const SizedBox(width: 24),
                _buildLegendItem('Adherence', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class ProgressChartPainter extends CustomPainter {
  final List<double> painLevels;
  final List<int> adherenceRates;
  final List<String> dates;
  final double maxPainLevel;
  final int maxAdherenceRate;
  final Color painColor;
  final Color adherenceColor;

  ProgressChartPainter({
    required this.painLevels,
    required this.adherenceRates,
    required this.dates,
    required this.maxPainLevel,
    required this.maxAdherenceRate,
    required this.painColor,
    required this.adherenceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintBackground = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.fill;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paintBackground,
    );

    // Draw grid
    _drawGrid(canvas, size);

    // Draw axes
    _drawAxes(canvas, size);

    // Draw data points
    _drawPainLevels(canvas, size);
    _drawAdherenceRates(canvas, size);

    // Draw labels
    _drawLabels(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Horizontal grid lines
    final double verticalStep = size.height / 5;
    for (int i = 1; i < 5; i++) {
      final double y = verticalStep * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Vertical grid lines
    final double horizontalStep = size.width / (dates.length + 1);
    for (int i = 1; i <= dates.length; i++) {
      final double x = horizontalStep * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // X-axis
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      paint,
    );

    // Y-axis
    canvas.drawLine(
      Offset(0, 0),
      Offset(0, size.height),
      paint,
    );
  }

  void _drawPainLevels(Canvas canvas, Size size) {
    if (painLevels.isEmpty) return;

    final paint = Paint()
      ..color = painColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    final pointPaint = Paint()
      ..color = painColor
      ..style = PaintingStyle.fill;

    final double horizontalStep = size.width / (dates.length + 1);
    final double verticalUnit = size.height / maxPainLevel;

    // Start point
    double x = horizontalStep;
    double y = size.height - (painLevels[0] * verticalUnit);
    linePath.moveTo(x, y);

    // Draw points and line
    for (int i = 0; i < painLevels.length; i++) {
      x = horizontalStep * (i + 1);
      y = size.height - (painLevels[i] * verticalUnit);

      // Add point to line
      if (i > 0) {
        linePath.lineTo(x, y);
      }

      // Draw point
      canvas.drawCircle(Offset(x, y), 4.0, pointPaint);
    }

    // Draw line
    canvas.drawPath(linePath, paint);
  }

  void _drawAdherenceRates(Canvas canvas, Size size) {
    if (adherenceRates.isEmpty) return;

    final paint = Paint()
      ..color = adherenceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    final pointPaint = Paint()
      ..color = adherenceColor
      ..style = PaintingStyle.fill;

    final double horizontalStep = size.width / (dates.length + 1);
    final double verticalUnit = size.height / maxAdherenceRate;

    // Start point
    double x = horizontalStep;
    double y = size.height - (adherenceRates[0] * verticalUnit);
    linePath.moveTo(x, y);

    // Draw points and line
    for (int i = 0; i < adherenceRates.length; i++) {
      x = horizontalStep * (i + 1);
      y = size.height - (adherenceRates[i] * verticalUnit);

      // Add point to line
      if (i > 0) {
        linePath.lineTo(x, y);
      }

      // Draw point
      canvas.drawCircle(Offset(x, y), 4.0, pointPaint);
    }

    // Draw line
    canvas.drawPath(linePath, paint);
  }

  void _drawLabels(Canvas canvas, Size size) {
    // X-axis labels (dates)
    final double horizontalStep = size.width / (dates.length + 1);
    final textStyle = TextStyle(
      color: Colors.grey.shade700,
      fontSize: 10,
    );

    for (int i = 0; i < dates.length; i++) {
      final textSpan = TextSpan(
        text: dates[i],
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final double x = (horizontalStep * (i + 1)) - (textPainter.width / 2);
      final double y = size.height + 4;
      textPainter.paint(canvas, Offset(x, y));
    }

    // Y-axis labels for pain (left side)
    for (int i = 0; i <= maxPainLevel; i += 2) {
      if (i == 0) continue; // Skip 0 label

      final textSpan = TextSpan(
        text: i.toString(),
        style: textStyle.copyWith(color: painColor),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final double x = -textPainter.width - 4;
      final double y = size.height -
          (i * (size.height / maxPainLevel)) -
          (textPainter.height / 2);
      textPainter.paint(canvas, Offset(x, y));
    }

    // Y-axis labels for adherence (right side)
    for (int i = 0; i <= maxAdherenceRate; i += 20) {
      if (i == 0) continue; // Skip 0 label

      final textSpan = TextSpan(
        text: '$i%',
        style: textStyle.copyWith(color: adherenceColor),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final double x = size.width + 4;
      final double y = size.height -
          (i * (size.height / maxAdherenceRate)) -
          (textPainter.height / 2);
      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(ProgressChartPainter oldDelegate) {
    return oldDelegate.painLevels != painLevels ||
        oldDelegate.adherenceRates != adherenceRates ||
        oldDelegate.dates != dates;
  }
}

/// A simple widget for displaying single metric progress
class SimpleProgressChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String title;
  final Color color;
  final double maxValue;
  final String yAxisLabel;

  const SimpleProgressChart({
    super.key,
    required this.values,
    required this.labels,
    required this.title,
    this.color = Colors.blue,
    this.maxValue = 10,
    this.yAxisLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || labels.isEmpty) {
      return const Center(
        child: Text('No data available for chart'),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (yAxisLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  yAxisLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.7,
              child: CustomPaint(
                painter: SimpleChartPainter(
                  values: values,
                  labels: labels,
                  maxValue: maxValue,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SimpleChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double maxValue;
  final Color color;

  SimpleChartPainter({
    required this.values,
    required this.labels,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintBackground = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.fill;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paintBackground,
    );

    // Draw grid
    _drawGrid(canvas, size);

    // Draw axes
    _drawAxes(canvas, size);

    // Draw data points
    _drawValues(canvas, size);

    // Draw labels
    _drawLabels(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Horizontal grid lines
    final double verticalStep = size.height / 5;
    for (int i = 1; i < 5; i++) {
      final double y = verticalStep * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Vertical grid lines
    final double horizontalStep = size.width / (labels.length + 1);
    for (int i = 1; i <= labels.length; i++) {
      final double x = horizontalStep * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // X-axis
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      paint,
    );

    // Y-axis
    canvas.drawLine(
      Offset(0, 0),
      Offset(0, size.height),
      paint,
    );
  }

  void _drawValues(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double horizontalStep = size.width / (labels.length + 1);
    final double verticalUnit = size.height / maxValue;

    // Start point
    double x = horizontalStep;
    double y = size.height - (values[0] * verticalUnit);
    linePath.moveTo(x, y);

    // Draw points and line
    for (int i = 0; i < values.length; i++) {
      x = horizontalStep * (i + 1);
      y = size.height - (values[i] * verticalUnit);

      // Add point to line
      if (i > 0) {
        linePath.lineTo(x, y);
      }

      // Draw point
      canvas.drawCircle(Offset(x, y), 4.0, pointPaint);
    }

    // Draw line
    canvas.drawPath(linePath, paint);
  }

  void _drawLabels(Canvas canvas, Size size) {
    // X-axis labels
    final double horizontalStep = size.width / (labels.length + 1);
    final textStyle = TextStyle(
      color: Colors.grey.shade700,
      fontSize: 10,
    );

    for (int i = 0; i < labels.length; i++) {
      final textSpan = TextSpan(
        text: labels[i],
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final double x = (horizontalStep * (i + 1)) - (textPainter.width / 2);
      final double y = size.height + 4;
      textPainter.paint(canvas, Offset(x, y));
    }

    // Y-axis labels
    for (int i = 0; i <= maxValue; i += 2) {
      if (i == 0) continue; // Skip 0 label

      final textSpan = TextSpan(
        text: i.toString(),
        style: textStyle.copyWith(color: color),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final double x = -textPainter.width - 4;
      final double y = size.height -
          (i * (size.height / maxValue)) -
          (textPainter.height / 2);
      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(SimpleChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.color != color;
  }
}
