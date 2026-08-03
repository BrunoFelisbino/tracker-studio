import '../../core/equipment_lab_types.dart';

/// Campos padrão para equipamentos Teltonika (FMB140 etc.).
///
/// Define cada valor possível extraível de logs normais.
class TeltonikaFieldDefinitions {
  /// Campos GPS.
  static final List<EquipmentFieldDefinition> gps = [
    const EquipmentFieldDefinition(
      id: 'teltonika.gps.latitude',
      manufacturer: Manufacturer.teltonika,
      category: 'gps',
      name: 'Latitude',
      sourceTypes: ['GPS.API'],
      valueType: FieldValueType.coordinate,
      unit: '°',
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.gps.longitude',
      manufacturer: Manufacturer.teltonika,
      category: 'gps',
      name: 'Longitude',
      sourceTypes: ['GPS.API'],
      valueType: FieldValueType.coordinate,
      unit: '°',
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.gps.altitude',
      manufacturer: Manufacturer.teltonika,
      category: 'gps',
      name: 'Altitude',
      sourceTypes: ['GPS.API'],
      valueType: FieldValueType.number,
      unit: 'm',
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.gps.hdop',
      manufacturer: Manufacturer.teltonika,
      category: 'gps',
      name: 'HDOP',
      sourceTypes: ['GPS.API'],
      valueType: FieldValueType.number,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.gps.satellites',
      manufacturer: Manufacturer.teltonika,
      category: 'gps',
      name: 'Satélites',
      sourceTypes: ['GPS.API'],
      valueType: FieldValueType.number,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.gps.speed',
      manufacturer: Manufacturer.teltonika,
      category: 'gps',
      name: 'Velocidade',
      sourceTypes: ['GPS.API'],
      valueType: FieldValueType.number,
      unit: 'km/h',
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.gps.fix',
      manufacturer: Manufacturer.teltonika,
      category: 'gps',
      name: 'GPS Fix',
      sourceTypes: ['GPS.API'],
      valueType: FieldValueType.number,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
  ];

  /// Campos de energia e bateria.
  static final List<EquipmentFieldDefinition> power = [
    const EquipmentFieldDefinition(
      id: 'teltonika.power.external',
      manufacturer: Manufacturer.teltonika,
      category: 'power',
      name: 'Tensão externa',
      sourceTypes: ['LiPo'],
      valueType: FieldValueType.number,
      unit: 'V',
      minExpected: 9,
      maxExpected: 36,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.power.internal',
      manufacturer: Manufacturer.teltonika,
      category: 'power',
      name: 'Bateria interna',
      sourceTypes: ['LiPo'],
      valueType: FieldValueType.number,
      unit: 'V',
      minExpected: 3,
      maxExpected: 5,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.power.unplugged',
      manufacturer: Manufacturer.teltonika,
      category: 'power',
      name: 'Alimentação removida',
      sourceTypes: ['UNPLUG'],
      valueType: FieldValueType.boolean,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
  ];

  /// Ignição e estado do veículo.
  static final List<EquipmentFieldDefinition> vehicle = [
    const EquipmentFieldDefinition(
      id: 'teltonika.ignition',
      manufacturer: Manufacturer.teltonika,
      category: 'vehicle',
      name: 'Ignição',
      sourceTypes: ['ACC'],
      valueType: FieldValueType.boolean,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.movement.tracked',
      manufacturer: Manufacturer.teltonika,
      category: 'movement',
      name: 'Rastreamento ativo',
      sourceTypes: ['TRACK'],
      valueType: FieldValueType.boolean,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
  ];

  /// Rede e conectividade.
  static final List<EquipmentFieldDefinition> network = [
    const EquipmentFieldDefinition(
      id: 'teltonika.network.ip',
      manufacturer: Manufacturer.teltonika,
      category: 'network',
      name: 'IP',
      sourceTypes: ['NETWORK'],
      valueType: FieldValueType.string,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.network.domain',
      manufacturer: Manufacturer.teltonika,
      category: 'network',
      name: 'Domínio',
      sourceTypes: ['NETWORK'],
      valueType: FieldValueType.string,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.network.port',
      manufacturer: Manufacturer.teltonika,
      category: 'network',
      name: 'Porta',
      sourceTypes: ['NETWORK'],
      valueType: FieldValueType.number,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.network.connecting',
      manufacturer: Manufacturer.teltonika,
      category: 'network',
      name: 'Conectando',
      sourceTypes: ['NETWORK'],
      valueType: FieldValueType.boolean,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.network.socket_opened',
      manufacturer: Manufacturer.teltonika,
      category: 'network',
      name: 'Socket aberto',
      sourceTypes: ['NETWORK'],
      valueType: FieldValueType.boolean,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.avl.imei_sent',
      manufacturer: Manufacturer.teltonika,
      category: 'avl',
      name: 'IMEI enviado ao servidor',
      sourceTypes: ['REC.SEND.1', 'REC.SEND.2'],
      valueType: FieldValueType.boolean,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
    const EquipmentFieldDefinition(
      id: 'teltonika.avl.server_answer',
      manufacturer: Manufacturer.teltonika,
      category: 'avl',
      name: 'Resposta do servidor',
      sourceTypes: ['REC.SEND.1', 'REC.SEND.2'],
      valueType: FieldValueType.string,
      documentationStatus: DefinitionSource.confirmedTest,
    ),
  ];

  /// Todos os campos combinados.
  static List<EquipmentFieldDefinition> get all =>
      [...gps, ...power, ...vehicle, ...network];
}
