import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/main_scaffold.dart';
import '../../models/detected_object.dart';
import '../../providers/scan_provider.dart';
import '../../services/firebase_app_service.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  String get _currentUserId {
    if (!FirebaseAppService.isReady) return '';
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Future<void> _analyze(BuildContext context) async {
    final scan = context.read<ScanProvider>();
    final success = await scan.analyze(_currentUserId);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Objects detected on image')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(scan.errorMessage ?? 'Cannot analyze image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scan = context.watch<ScanProvider>();
    final image = scan.selectedImage;
    final hasResult = scan.result != null;
    final userId = _currentUserId;

    return MainScaffold(
      currentIndex: 1,
      appBar: AppBar(title: const Text('Scan Object')),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: EdgeInsets.zero,
                  child: AspectRatio(
                    aspectRatio: 0.78,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [
                            colors.primary.withValues(alpha: 0.18),
                            colors.secondary.withValues(alpha: 0.12),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          image == null
                              ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt_rounded,
                                    size: 84,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Image preview',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Take a photo or pick from gallery',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              )
                              : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(image, fit: BoxFit.fill),
                                  if (scan.detections.isNotEmpty)
                                    CustomPaint(
                                      painter: _DetectionPainter(
                                        detections: scan.detections,
                                        selectedIndex:
                                            scan.selectedDetectionIndex,
                                        color: colors.primary,
                                      ),
                                    ),
                                ],
                              ),
                    ),
                  ),
                ),
                if (scan.detections.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Detected objects',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(scan.detections.length, (index) {
                      final object = scan.detections[index];
                      final selected = scan.selectedDetectionIndex == index;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(
                          '${index + 1}. ${object.word}'
                          '${object.meaningVi.isEmpty ? '' : ' • ${object.meaningVi}'}',
                        ),
                        onSelected:
                            (_) => context.read<ScanProvider>().selectDetection(
                              index,
                              userId: userId,
                            ),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 20),
                CustomButton(
                  label: 'Take Photo',
                  icon: Icons.camera_alt_rounded,
                  onPressed: context.read<ScanProvider>().takePhoto,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  label: 'Pick from Gallery',
                  icon: Icons.photo_library_rounded,
                  style: CustomButtonStyle.secondary,
                  onPressed: context.read<ScanProvider>().pickFromGallery,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  label: hasResult ? 'View Flashcard' : 'Analyze Image',
                  icon:
                      hasResult
                          ? Icons.style_rounded
                          : Icons.auto_awesome_rounded,
                  style: CustomButtonStyle.outline,
                  isLoading: scan.isAnalyzing,
                  onPressed:
                      image == null
                          ? null
                          : hasResult
                          ? () =>
                              Navigator.pushNamed(context, AppRoutes.aiResult)
                          : () => _analyze(context),
                ),
              ],
            ),
          ),
          if (scan.isAnalyzing)
            ColoredBox(
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: 0.76),
              child: const LoadingWidget(
                message: 'AI is recognizing the object...',
              ),
            ),
        ],
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  const _DetectionPainter({
    required this.detections,
    required this.selectedIndex,
    required this.color,
  });

  final List<DetectedObject> detections;
  final int selectedIndex;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
    final selectedPaint =
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
    final labelBackground =
        Paint()
          ..color = color.withValues(alpha: 0.92)
          ..style = PaintingStyle.fill;

    for (var index = 0; index < detections.length; index++) {
      final detection = detections[index];
      if (detection.box2d.length != 4) continue;
      final ymin = detection.box2d[0].clamp(0, 1000) / 1000 * size.height;
      final xmin = detection.box2d[1].clamp(0, 1000) / 1000 * size.width;
      final ymax = detection.box2d[2].clamp(0, 1000) / 1000 * size.height;
      final xmax = detection.box2d[3].clamp(0, 1000) / 1000 * size.width;
      final rect = Rect.fromLTRB(xmin, ymin, xmax, ymax);
      if (rect.width < 8 || rect.height < 8) continue;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        index == selectedIndex ? selectedPaint : boxPaint,
      );

      final label = '${index + 1}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelTop = rect.top.clamp(6.0, size.height - 28);
      final labelLeft = rect.left.clamp(6.0, size.width - 28);
      final labelRect = Rect.fromLTWH(labelLeft + 5, labelTop + 5, 24, 24);

      canvas.drawCircle(labelRect.center, 12, labelBackground);
      textPainter.paint(
        canvas,
        Offset(
          labelRect.center.dx - textPainter.width / 2,
          labelRect.center.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.color != color;
  }
}
