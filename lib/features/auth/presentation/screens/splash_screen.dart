import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bootstrap/bootstrap_controller.dart';
import '../../../../core/bootstrap/bootstrap_models.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final AnimationController _routeController;

  bool _hasTapped = false;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _routeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(bootstrapProvider.notifier).start());
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  double _realProgress(BootstrapState state) {
    if (state.status == BootstrapStatus.ready) return 1;

    final total = BootstrapStep.values.length.toDouble();
    if (total == 0) return 0;

    final finished = state.steps.where((result) {
      return result.status == BootstrapStepStatus.success ||
          result.status == BootstrapStepStatus.skipped ||
          result.status == BootstrapStepStatus.failed ||
          result.status == BootstrapStepStatus.timedOut;
    }).length;

    var progress = finished / total;

    if (state.status == BootstrapStatus.running && state.currentStep != null) {
      progress += 0.35 / total;
    }

    if (state.status == BootstrapStatus.degraded && state.limitedModeAccepted) {
      return 1;
    }

    return progress.clamp(0.02, 0.98);
  }

  String _statusText(BootstrapState state) {
    if (state.status == BootstrapStatus.ready) return 'Pronto para iniciar';
    if (state.status == BootstrapStatus.degraded) {
      return state.limitedModeAccepted
          ? 'Modo limitado preparado'
          : 'Atenção necessária';
    }
    if (state.status == BootstrapStatus.failed) {
      return 'Não foi possível concluir a inicialização';
    }
    return state.currentStep?.loadingMessage ?? 'Inicializando serviços...';
  }

  void _enterApp(BootstrapState state) {
    setState(() => _hasTapped = true);
    if (state.canEnterApp) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(bootstrapProvider).state;
    final failed = bootstrap.isTerminalFailure;
    final progress = _realProgress(bootstrap);

    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _enterApp(bootstrap),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SplashArtwork(),
            AnimatedBuilder(
              animation: _routeController,
              builder: (context, _) => CustomPaint(
                painter: _TelemetryRoutePainter(
                  progress: _routeController.value,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _ambientController,
              builder: (context, _) => CustomPaint(
                painter: _AntennaSignalPainter(
                  pulse: _ambientController.value,
                ),
              ),
            ),
            const _ReadabilityOverlay(),
            SafeArea(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _introController,
                  curve: Curves.easeOut,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .04),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _introController,
                    curve: Curves.easeOutCubic,
                  )),
                  child: Column(
                    children: [
                      const Spacer(),
                      _BottomPanel(
                        state: bootstrap,
                        progress: progress,
                        statusText: _statusText(bootstrap),
                        hasTapped: _hasTapped,
                        onRetry: () => unawaited(
                          ref.read(bootstrapProvider.notifier).retry(),
                        ),
                        onContinueLimited: ref
                            .read(bootstrapProvider.notifier)
                            .continueLimited,
                        onEnter: () => _enterApp(bootstrap),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (failed)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 16,
                right: 16,
                child: IconButton.filledTonal(
                  tooltip: 'Abrir diagnóstico',
                  onPressed: () => context.push('/bootstrap-diagnostics'),
                  icon: const Icon(Icons.troubleshoot_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        return Container(
          color: const Color(0xFF020817),
          alignment: Alignment.center,
          child: Image.asset(
            'assets/tracker_studio_splash.png',
            width: isWide ? math.min(constraints.maxWidth, 1000) : null,
            height: constraints.maxHeight,
            fit: isWide ? BoxFit.contain : BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const _ArtworkFallback(),
          ),
        );
      },
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.25),
          radius: 1.2,
          colors: [Color(0xFF102A61), Color(0xFF020817)],
        ),
      ),
      child: Center(
        child: Text(
          'TRACKER STUDIO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

class _ReadabilityOverlay extends StatelessWidget {
  const _ReadabilityOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, .5, .72, 1],
          colors: [
            Color(0x12000000),
            Color(0x08000000),
            Color(0x9A020817),
            Color(0xFF020817),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final BootstrapState state;
  final double progress;
  final String statusText;
  final bool hasTapped;
  final VoidCallback onRetry;
  final VoidCallback onContinueLimited;
  final VoidCallback onEnter;

  const _BottomPanel({
    required this.state,
    required this.progress,
    required this.statusText,
    required this.hasTapped,
    required this.onRetry,
    required this.onContinueLimited,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final canEnter = state.canEnterApp;
    final isFailure = state.isTerminalFailure;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ConnectionSlogan(),
            const SizedBox(height: 18),
            _RealProgressBar(progress: progress),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Text(
                statusText,
                key: ValueKey(statusText),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isFailure
                      ? const Color(0xFFFFA7A7)
                      : const Color(0xFFE6EEFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .15,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (isFailure) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  ),
                  if (state.status == BootstrapStatus.degraded) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: onContinueLimited,
                        child: const Text('Modo limitado'),
                      ),
                    ),
                  ],
                ],
              ),
            ] else
              AnimatedOpacity(
                opacity: canEnter ? 1 : .72,
                duration: const Duration(milliseconds: 300),
                child: TextButton.icon(
                  onPressed: canEnter ? onEnter : null,
                  icon: Icon(
                    canEnter
                        ? Icons.arrow_forward_rounded
                        : Icons.touch_app_rounded,
                  ),
                  label: Text(
                    canEnter
                        ? 'Toque para entrar'
                        : hasTapped
                            ? 'Aguarde a inicialização'
                            : 'Carregando o Tracker Studio',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8FC5FF),
                  ),
                ),
              ),
            const SizedBox(height: 2),
            const Text(
              'LOCALITEL',
              style: TextStyle(
                color: Color(0xFF8A9AB8),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionSlogan extends StatelessWidget {
  const _ConnectionSlogan();

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      color: Colors.white,
      fontSize: 24,
      height: 1.08,
      fontWeight: FontWeight.w900,
      letterSpacing: -.4,
      shadows: [Shadow(color: Color(0xA80060FF), blurRadius: 18)],
    );

    Widget line(String suffix) => Text.rich(
          TextSpan(
            style: base,
            children: [
              const TextSpan(text: 'Conecta '),
              TextSpan(
                text: suffix,
                style: const TextStyle(color: Color(0xFF2D8CFF)),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        );

    return Column(
      children: [
        line('dados.'),
        line('pessoas.'),
        line('dispositivos.'),
      ],
    );
  }
}

class _RealProgressBar extends StatelessWidget {
  final double progress;

  const _RealProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Column(
          children: [
            Container(
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFF071630),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x663C8DFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x442D8CFF),
                    blurRadius: 16,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0, 1),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF28D7FF), Color(0xFF306BFF)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0xFF20C8FF), blurRadius: 14),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFF8FC5FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TelemetryRoutePainter extends CustomPainter {
  final double progress;

  _TelemetryRoutePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x4025A7FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xAA32B7FF);

    final path = Path()
      ..moveTo(size.width * .06, size.height * .80)
      ..cubicTo(
        size.width * .25,
        size.height * .72,
        size.width * .36,
        size.height * .91,
        size.width * .52,
        size.height * .78,
      )
      ..cubicTo(
        size.width * .68,
        size.height * .65,
        size.width * .82,
        size.height * .84,
        size.width * .96,
        size.height * .70,
      );

    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;

    for (var i = 0; i < 7; i++) {
      final t = (progress + i / 7) % 1.0;
      final tangent = metric.getTangentForOffset(metric.length * t);
      if (tangent == null) continue;

      final pointPaint = Paint()
        ..color = const Color(0xFF63E6FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawCircle(tangent.position, 4.5, pointPaint);
      canvas.drawCircle(
        tangent.position,
        2,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TelemetryRoutePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AntennaSignalPainter extends CustomPainter {
  final double pulse;

  _AntennaSignalPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .13, size.height * .60);
    final base = math.min(size.width, size.height) * .035;

    for (var i = 0; i < 3; i++) {
      final radius = base * (1.1 + i * .62 + pulse * .35);
      final opacity = (0.55 - i * .12) * (1 - pulse * .25);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color(0xFF33B9FF).withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi * .78,
        math.pi * .56,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AntennaSignalPainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}
