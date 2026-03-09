
import 'package:flutter/material.dart';

class BicyclePainter extends CustomPainter {
	@override
	void paint(Canvas canvas, Size size) {
		final double w = size.width;
		final double h = size.height;
		final wheelRadius = w * 0.32;
		final wheelStroke = w * 0.045;
		final frameStroke = w * 0.035;
		final accentStroke = w * 0.025;

		final wheelPaint = Paint()
			..color = Colors.black
			..strokeWidth = wheelStroke
			..style = PaintingStyle.stroke;
		final framePaint = Paint()
			..color = Colors.black
			..strokeWidth = frameStroke
			..style = PaintingStyle.stroke;
		final fillPaint = Paint()
			..color = Colors.black
			..style = PaintingStyle.fill;
		final accentPaint = Paint()
			..color = Colors.black
			..strokeWidth = accentStroke
			..style = PaintingStyle.stroke;

		// Ruedas
		final leftWheel = Offset(w * 0.23, h * 0.72);
		final rightWheel = Offset(w * 0.77, h * 0.72);
		canvas.drawCircle(leftWheel, wheelRadius, wheelPaint);
		canvas.drawCircle(rightWheel, wheelRadius, wheelPaint);

		// Cuadro principal
		final seatTubeTop = Offset(w * 0.60, h * 0.23);
		final seatTubeBottom = Offset(w * 0.50, h * 0.72);
		final headTubeTop = Offset(w * 0.80, h * 0.23);
		final headTubeBottom = Offset(w * 0.77, h * 0.40);


		// Triángulo principal
		canvas.drawLine(seatTubeBottom, seatTubeTop, framePaint); // tubo sillín
		canvas.drawLine(seatTubeTop, headTubeTop, framePaint); // tubo superior
		canvas.drawLine(headTubeTop, headTubeBottom, framePaint); // tubo dirección
		canvas.drawLine(headTubeBottom, seatTubeBottom, framePaint); // tubo diagonal
		canvas.drawLine(seatTubeBottom, leftWheel, framePaint); // vaina inferior izq
		canvas.drawLine(seatTubeBottom, rightWheel, framePaint); // vaina inferior der
		canvas.drawLine(leftWheel, seatTubeTop, framePaint); // tirante izq
		canvas.drawLine(rightWheel, headTubeTop, framePaint); // tirante der

		// Sillín
		final saddleBack = Offset(w * 0.52, h * 0.18);
		final saddleFront = Offset(w * 0.62, h * 0.21);
		canvas.drawLine(seatTubeTop, saddleBack, framePaint);
		canvas.drawLine(saddleBack, saddleFront, framePaint);

		// Manubrio
		final handleStart = Offset(w * 0.80, h * 0.23);
		final handleBend = Offset(w * 0.87, h * 0.18);
		final handleEnd = Offset(w * 0.87, h * 0.28);
		canvas.drawLine(handleStart, handleBend, framePaint);
		canvas.drawLine(handleBend, handleEnd, framePaint);

		// Pedalier (círculo central y pedal)
		final pedalier = seatTubeBottom;
		canvas.drawCircle(pedalier, w * 0.06, fillPaint);
		final pedalDown = Offset(pedalier.dx, pedalier.dy + w * 0.10);
		final pedalUp = Offset(pedalier.dx, pedalier.dy - w * 0.10);
		canvas.drawLine(pedalier, pedalDown, framePaint);
		canvas.drawLine(pedalier, pedalUp, framePaint);
		canvas.drawRect(Rect.fromCenter(center: pedalDown, width: w * 0.04, height: w * 0.015), fillPaint);
		canvas.drawRect(Rect.fromCenter(center: pedalUp, width: w * 0.04, height: w * 0.015), fillPaint);

		// Batería (rectángulo con rayo)
		final batteryRect = Rect.fromCenter(center: Offset(w * 0.44, h * 0.45), width: w * 0.13, height: h * 0.07);
		canvas.drawRRect(RRect.fromRectAndRadius(batteryRect, Radius.circular(8)), framePaint);
		// Rayo
		final boltPath = Path();
		boltPath.moveTo(batteryRect.left + w * 0.025, batteryRect.top + h * 0.015);
		boltPath.lineTo(batteryRect.center.dx, batteryRect.center.dy);
		boltPath.lineTo(batteryRect.left + w * 0.07, batteryRect.bottom - h * 0.015);
		boltPath.lineTo(batteryRect.right - w * 0.025, batteryRect.top + h * 0.025);
		canvas.drawPath(boltPath, accentPaint);
	}

	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
