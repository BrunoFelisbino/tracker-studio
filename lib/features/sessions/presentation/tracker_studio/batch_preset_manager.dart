import 'package:flutter/material.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_radius.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/design/tracker_text_styles.dart';
import '../../../../core/widgets/tracker_card.dart';
import 'tracker_session_state.dart';

class CarrierPreset {
  final String name;
  final String apn;
  final String user;
  final String password;
  final String primaryServer;
  final String primaryPort;
  final String keepAlive;
  final String iconAsset;

  const CarrierPreset({
    required this.name,
    required this.apn,
    required this.user,
    required this.password,
    required this.primaryServer,
    required this.primaryPort,
    this.keepAlive = '10',
    this.iconAsset = '',
  });
}

const defaultPresets = [
  CarrierPreset(
    name: 'Vivo M2M',
    apn: 'm2m.vivo.com.br',
    user: 'vivo',
    password: 'vivo',
    primaryServer: '192.0.2.10',
    primaryPort: '5000',
    keepAlive: '10',
  ),
  CarrierPreset(
    name: 'Claro M2M',
    apn: 'claro.m2m.com.br',
    user: 'claro',
    password: 'claro',
    primaryServer: '192.0.2.10',
    primaryPort: '5000',
    keepAlive: '10',
  ),
  CarrierPreset(
    name: 'TIM M2M',
    apn: 'tim.m2m.com.br',
    user: 'tim',
    password: 'tim',
    primaryServer: '192.0.2.10',
    primaryPort: '5000',
    keepAlive: '10',
  ),
  CarrierPreset(
    name: 'Algar M2M',
    apn: 'algar.m2m.com.br',
    user: 'algar',
    password: 'algar',
    primaryServer: '192.0.2.10',
    primaryPort: '5000',
    keepAlive: '10',
  ),
];

class BatchPresetWidget extends StatefulWidget {
  final TrackerSessionState? session;
  final Function(CarrierPreset preset)? onApplyPreset;
  final VoidCallback? onFetchFromDevice;
  final bool isConnected;

  const BatchPresetWidget({
    super.key,
    this.session,
    this.onApplyPreset,
    this.onFetchFromDevice,
    this.isConnected = false,
  });

  @override
  State<BatchPresetWidget> createState() => _BatchPresetWidgetState();
}

class _BatchPresetWidgetState extends State<BatchPresetWidget> {
  late TextEditingController _apnController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  late TextEditingController _serverController;
  late TextEditingController _portController;
  late TextEditingController _keepAliveController;
  CarrierPreset _selected = defaultPresets.first;
  bool _isCustomEdited = false;

  @override
  void initState() {
    super.initState();
    _apnController = TextEditingController(text: _selected.apn);
    _userController = TextEditingController(text: _selected.user);
    _passController = TextEditingController(text: _selected.password);
    _serverController = TextEditingController(text: _selected.primaryServer);
    _portController = TextEditingController(text: _selected.primaryPort);
    _keepAliveController = TextEditingController(text: _selected.keepAlive);

    _populateFromSessionIfAvailable();
  }

  @override
  void didUpdateWidget(BatchPresetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session != oldWidget.session) {
      _populateFromSessionIfAvailable();
    }
  }

  void _populateFromSessionIfAvailable() {
    final original = widget.session?.configuration.original;
    if (original == null || original.isEmpty) return;

    final apn = original['APN'] ?? original['apn'] ?? '';
    final user = original['Usuário'] ?? original['Usuario'] ?? original['usuario'] ?? '';
    final pass = original['Senha'] ?? original['senha'] ?? '';
    final server = original['Servidor primário'] ?? original['Servidor primario'] ?? original['servidor'] ?? '';
    final port = original['Porta primária'] ?? original['Porta primaria'] ?? original['porta'] ?? '';
    final keepAlive = original['Keep-Alive'] ?? original['Intervalo'] ?? '';

    if (apn.isNotEmpty) _apnController.text = apn;
    if (user.isNotEmpty) _userController.text = user;
    if (pass.isNotEmpty) _passController.text = pass;
    if (server.isNotEmpty) _serverController.text = server;
    if (port.isNotEmpty) _portController.text = port;
    if (keepAlive.isNotEmpty) _keepAliveController.text = keepAlive;

    if (apn.isNotEmpty || server.isNotEmpty) {
      setState(() => _isCustomEdited = true);
    }
  }

  void _selectPreset(CarrierPreset preset) {
    setState(() {
      _selected = preset;
      _apnController.text = preset.apn;
      _userController.text = preset.user;
      _passController.text = preset.password;
      _serverController.text = preset.primaryServer;
      _portController.text = preset.primaryPort;
      _keepAliveController.text = preset.keepAlive;
      _isCustomEdited = false;
    });
  }

  CarrierPreset _buildCompiledPreset() {
    return CarrierPreset(
      name: _isCustomEdited ? 'Personalizado (Editado)' : _selected.name,
      apn: _apnController.text.trim(),
      user: _userController.text.trim(),
      password: _passController.text.trim(),
      primaryServer: _serverController.text.trim(),
      primaryPort: _portController.text.trim(),
      keepAlive: _keepAliveController.text.trim(),
    );
  }

  @override
  void dispose() {
    _apnController.dispose();
    _userController.dispose();
    _passController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _keepAliveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasReadData = widget.session != null && widget.session!.configuration.original.isNotEmpty;

    return TrackerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.layers_rounded,
                size: 18,
                color: TrackerColors.communicationBlue,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Perfis de Configuração em Lote & Edição de APN',
                  style: TrackerTextStyles.cardTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (hasReadData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TrackerColors.technicalGreen.withValues(alpha: 0.1),
                    borderRadius: TrackerRadius.pill,
                  ),
                  child: const Text(
                    'Dados Lidos do Rastreador',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: TrackerColors.technicalGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: TrackerSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: TrackerSpacing.md),

          // Seletor de operadora / preset + Botão Puxar Dados
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: TrackerSpacing.sm,
                  runSpacing: TrackerSpacing.xs,
                  children: defaultPresets.map((preset) {
                    final isSelected = !_isCustomEdited && preset.name == _selected.name;
                    return ChoiceChip(
                      label: Text(preset.name),
                      selected: isSelected,
                      selectedColor: TrackerColors.communicationBlue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : TrackerColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                      onSelected: (val) {
                        if (val) _selectPreset(preset);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.isConnected && widget.onFetchFromDevice != null
                    ? widget.onFetchFromDevice
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: TrackerColors.communicationBlue,
                  side: const BorderSide(color: TrackerColors.communicationBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: const RoundedRectangleBorder(borderRadius: TrackerRadius.small),
                ),
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text(
                  'Puxar PRESET / STATUS REQ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: TrackerSpacing.md),

          // Formulário com campos editáveis
          Container(
            padding: const EdgeInsets.all(TrackerSpacing.md),
            decoration: BoxDecoration(
              color: TrackerColors.background,
              borderRadius: TrackerRadius.medium,
              border: Border.all(color: TrackerColors.lineSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildFormField('APN (Endereço)', _apnController, 'm2m.vivo.com.br'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormField('Usuário APN', _userController, 'vivo'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormField('Senha APN', _passController, 'vivo'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildFormField('Servidor IP Primário', _serverController, '192.0.2.10'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormField('Porta Servidor', _portController, '5000'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormField('Tempo Envio / KeepAlive (min)', _keepAliveController, '10'),
                    ),
                  ],
                ),
                const SizedBox(height: TrackerSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isCustomEdited)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Text(
                          '* Parâmetros personalizados',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: TrackerColors.attentionAmber),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: widget.isConnected && widget.onApplyPreset != null
                          ? () => widget.onApplyPreset!(_buildCompiledPreset())
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TrackerColors.communicationBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: const RoundedRectangleBorder(
                          borderRadius: TrackerRadius.small,
                        ),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text(
                        'Gravar Configuração no Rastreador',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, String placeholder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TrackerTextStyles.label.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: (_) {
            if (!_isCustomEdited) setState(() => _isCustomEdited = true);
          },
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            isDense: true,
            hintText: placeholder,
            hintStyle: TextStyle(color: TrackerColors.textMuted.withValues(alpha: 0.5), fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: TrackerColors.surfaceMuted,
            border: OutlineInputBorder(
              borderRadius: TrackerRadius.small,
              borderSide: const BorderSide(color: TrackerColors.lineSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: TrackerRadius.small,
              borderSide: const BorderSide(color: TrackerColors.lineSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: TrackerRadius.small,
              borderSide: const BorderSide(color: TrackerColors.communicationBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
