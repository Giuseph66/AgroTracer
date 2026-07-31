import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/tokens.dart';

/// Assinatura visual do produto: a identidade do animal desenhada como um
/// brinco de gado — placa amarela com número estampado e furo de fixação.
class EarTag extends StatelessWidget {
  const EarTag({
    super.key,
    required this.number,
    this.rfid,
    this.size = EarTagSize.medium,
  });

  final String number;
  final String? rfid;
  final EarTagSize size;

  @override
  Widget build(BuildContext context) {
    final s = size._spec;
    return CustomPaint(
      painter: _EarTagPainter(),
      child: SizedBox(
        width: s.width,
        height: s.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              number,
              style: GoogleFonts.archivoBlack(
                fontSize: s.numberSize,
                color: TaColors.stamp,
                height: 1,
              ),
            ),
            if (rfid != null) ...[
              const SizedBox(height: 2),
              Text(
                rfid!,
                style: GoogleFonts.splineSansMono(
                  fontSize: s.rfidSize,
                  color: TaColors.stamp.withValues(alpha: .65),
                  height: 1,
                ),
              ),
            ],
            SizedBox(height: s.height * .14),
          ],
        ),
      ),
    );
  }
}

enum EarTagSize {
  small(_TagSpec(64, 72, 22, 0)),
  medium(_TagSpec(96, 108, 32, 8)),
  large(_TagSpec(148, 166, 52, 11));

  const EarTagSize(this._spec);
  final _TagSpec _spec;
}

class _TagSpec {
  const _TagSpec(this.width, this.height, this.numberSize, this.rfidSize);
  final double width;
  final double height;
  final double numberSize;
  final double rfidSize;
}

class _EarTagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Placa: topo estreito (pescoço do pino), corpo largo arredondado.
    final neckW = w * .34;
    final neckH = h * .18;
    final r = w * .16;

    final plate = Path()
      ..moveTo((w - neckW) / 2, neckH)
      ..lineTo((w - neckW) / 2, r * .4)
      ..quadraticBezierTo((w - neckW) / 2, 0, (w - neckW) / 2 + r * .5, 0)
      ..lineTo((w + neckW) / 2 - r * .5, 0)
      ..quadraticBezierTo((w + neckW) / 2, 0, (w + neckW) / 2, r * .4)
      ..lineTo((w + neckW) / 2, neckH)
      // ombro direito
      ..quadraticBezierTo(w, neckH, w, neckH + r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, neckH + r)
      ..quadraticBezierTo(0, neckH, (w - neckW) / 2, neckH)
      ..close();

    canvas.drawShadow(plate, TaColors.stamp, 3, false);
    canvas.drawPath(plate, Paint()..color = TaColors.tagYellow);
    canvas.drawPath(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TaColors.tagYellowDeep,
    );

    // Furo do pino.
    final hole = Offset(w / 2, neckH * .62);
    canvas.drawCircle(hole, w * .045, Paint()..color = TaColors.paperDim);
    canvas.drawCircle(
      hole,
      w * .045,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = TaColors.tagYellowDeep,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
