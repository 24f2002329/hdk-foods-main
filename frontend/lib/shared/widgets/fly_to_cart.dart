import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A "fly-to-cart" micro-animation: a small rounded thumbnail of the tapped
/// product floats along an arc from the source widget into the cart affordance,
/// shrinking and fading as it arrives.
///
/// Usage:
///  1. Attach [FlyToCart.targetKey] to the screen's cart icon / capsule:
///       Container(key: FlyToCart.targetKey, ...)
///  2. On "add to cart", call:
///       FlyToCart.run(sourceContext: context, imageUrl: product.image);
///
/// If no valid target is mounted, the thumbnail flies to the bottom-center of
/// the screen instead, so it never crashes or no-ops unexpectedly.
class FlyToCart {
  FlyToCart._();

  /// Attach this to the active screen's primary cart affordance.
  static final GlobalKey targetKey = GlobalKey();

  static Rect? _rectFor(BuildContext? context) {
    final obj = context?.findRenderObject();
    if (obj is! RenderBox || !obj.attached) return null;
    final offset = obj.localToGlobal(Offset.zero);
    return offset & obj.size;
  }

  static void run({
    required BuildContext sourceContext,
    required String imageUrl,
  }) {
    if (imageUrl.isEmpty) return;
    final overlay = Overlay.maybeOf(sourceContext, rootOverlay: true);
    if (overlay == null) return;

    final sourceRect = _rectFor(sourceContext);
    if (sourceRect == null) return;

    final screen = MediaQuery.of(sourceContext).size;
    // Prefer the registered cart target; fall back to bottom-center.
    final targetRect = _rectFor(targetKey.currentContext) ??
        Rect.fromCenter(
          center: Offset(screen.width / 2, screen.height - 48),
          width: 48,
          height: 48,
        );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlyingThumb(
        imageUrl: imageUrl,
        sourceRect: sourceRect,
        targetRect: targetRect,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _FlyingThumb extends StatefulWidget {
  final String imageUrl;
  final Rect sourceRect;
  final Rect targetRect;
  final VoidCallback onDone;

  const _FlyingThumb({
    required this.imageUrl,
    required this.sourceRect,
    required this.targetRect,
    required this.onDone,
  });

  @override
  State<_FlyingThumb> createState() => _FlyingThumbState();
}

class _FlyingThumbState extends State<_FlyingThumb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  // Start the thumbnail capped at ~72px so a full card doesn't fly across.
  static const double _startSize = 72;
  static const double _endSize = 28;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startCenter = widget.sourceRect.center;
    final endCenter = widget.targetRect.center;

    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final t = _t.value;
        // Horizontal eases linearly; vertical lifts up first then drops into the
        // target, producing a gentle arc.
        final dx = startCenter.dx + (endCenter.dx - startCenter.dx) * t;
        final arc = -60.0 * (4 * t * (1 - t)); // peak lift at t=0.5
        final dy = startCenter.dy + (endCenter.dy - startCenter.dy) * t + arc;
        final size = _startSize + (_endSize - _startSize) * t;
        final opacity = t < 0.85 ? 1.0 : (1.0 - (t - 0.85) / 0.15);

        return Positioned(
          left: dx - size / 2,
          top: dy - size / 2,
          width: size,
          height: size,
          child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => const ColoredBox(
            color: Color(0xFF1E1E1E),
            child: Icon(Icons.restaurant_rounded, color: Color(0xFFFF1E1E)),
          ),
        ),
      ),
    );
  }
}
