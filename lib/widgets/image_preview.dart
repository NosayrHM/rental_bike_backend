import 'package:flutter/material.dart';

Future<void> showImagePreview(
  BuildContext context,
  List<String> images,
  int initialIndex,
) {
  if (images.isEmpty) {
    return Future.value();
  }

  final clampedIndex = initialIndex.clamp(0, images.length - 1);
  final pageController = PageController(initialPage: clampedIndex);
  var currentIndex = clampedIndex;

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.9),
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: Container(color: Colors.black.withOpacity(0.9)),
                  ),
                ),
                Positioned.fill(
                  child: SafeArea(
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: images.length,
                      onPageChanged: (value) =>
                          setState(() => currentIndex = value),
                      itemBuilder: (context, index) {
                        final imagePath = images[index];
                        final imageWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: InteractiveViewer(
                            maxScale: 4,
                            child: Image.asset(imagePath, fit: BoxFit.contain),
                          ),
                        );

                        return Center(
                          child: Hero(tag: imagePath, child: imageWidget),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 32,
                  right: 24,
                  child: IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${currentIndex + 1} / ${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  ).whenComplete(pageController.dispose);
}
