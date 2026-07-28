import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/work_order_route.dart';

void main() {
  test('empty work order route does not invent destination', () {
    const route = WorkOrderRoute(destinationAddress: '');

    expect(route.directLink, isNull);
    expect(route.routeLink(), isNull);
  });

  test('address creates Google Maps destination and driving route', () {
    const route = WorkOrderRoute(
      destinationAddress: 'Rua 10, 100 - Goiânia - GO',
    );

    expect(route.directLink?.host, 'www.google.com');
    expect(route.directLink?.queryParameters['query'],
        'Rua 10, 100 - Goiânia - GO');
    expect(route.routeLink()?.queryParameters['destination'],
        'Rua 10, 100 - Goiânia - GO');
    expect(route.routeLink()?.queryParameters['travelmode'], 'driving');
  });

  test('coordinates take priority over typed address', () {
    const route = WorkOrderRoute(
      destinationAddress: 'Endereço informado',
      destinationLatitude: -16.6869,
      destinationLongitude: -49.2648,
    );

    expect(route.routeLink()?.queryParameters['destination'],
        '-16.6869,-49.2648');
  });

  test('provided Google Maps link is accepted', () {
    const route = WorkOrderRoute(
      destinationAddress: '',
      providedGoogleMapsUrl: 'https://maps.google.com/?q=-16.6,-49.2',
    );

    expect(route.directLink?.host, 'maps.google.com');
  });

  test('untrusted external link is rejected', () {
    const route = WorkOrderRoute(
      destinationAddress: '',
      providedGoogleMapsUrl: 'https://example.com/fake-route',
    );

    expect(route.directLink, isNull);
  });
}
