import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'tracker_empty_state.dart';
import 'tracker_primary_button.dart';
import 'tracker_scaffold.dart';
import 'tracker_secondary_button.dart';

class InternalRouteErrorScreen extends StatelessWidget {
  final String requestedRoute;
  final Object? error;

  const InternalRouteErrorScreen({
    super.key,
    required this.requestedRoute,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return TrackerScaffold(
      title: 'Erro interno',
      subtitle: 'A rota solicitada não está disponível.',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TrackerEmptyState(
                icon: Icons.route_outlined,
                title: 'Rota indisponível',
                message: 'Rota solicitada: $requestedRoute',
              ),
              const SizedBox(height: 16),
              if (kDebugMode && error != null) ...[
                SelectableText('$error'),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  TrackerSecondaryButton(
                    label: 'Voltar',
                    icon: Icons.arrow_back,
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      context.go('/dashboard');
                    },
                  ),
                  TrackerPrimaryButton(
                    label: 'Início',
                    icon: Icons.home_outlined,
                    onPressed: () => context.go('/dashboard'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
