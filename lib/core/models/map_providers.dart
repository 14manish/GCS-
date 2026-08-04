class MapProviderInfo {
  final String id;
  final String name;
  final String description;
  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;

  const MapProviderInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.urlTemplate,
    this.subdomains = const ['a', 'b', 'c'],
    required this.attribution,
  });
}

class MapProviders {
  static const Map<String, MapProviderInfo> providers = {
    'google_hybrid': MapProviderInfo(
      id: 'google_hybrid',
      name: 'Google Satellite Hybrid (Mission Planner)',
      description: 'High-res satellite imagery with roads and location labels',
      urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
      subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
      attribution: '© Google Maps',
    ),
    'google_sat': MapProviderInfo(
      id: 'google_sat',
      name: 'Google Satellite',
      description: 'Pure high-resolution Google satellite imagery',
      urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
      subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
      attribution: '© Google Maps',
    ),
    'google_terrain': MapProviderInfo(
      id: 'google_terrain',
      name: 'Google Maps / Terrain',
      description: 'Standard Google terrain and street map',
      urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
      subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
      attribution: '© Google Maps',
    ),
    'esri_sat': MapProviderInfo(
      id: 'esri_sat',
      name: 'Esri World Imagery',
      description: 'ArcGIS High-resolution satellite imagery',
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      subdomains: [],
      attribution: '© Esri, Maxar, Earthstar Geographics',
    ),
    'osm': MapProviderInfo(
      id: 'osm',
      name: 'OpenStreetMap Standard',
      description: 'Community-driven open street map',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c'],
      attribution: '© OpenStreetMap contributors',
    ),
    'carto_dark': MapProviderInfo(
      id: 'carto_dark',
      name: 'CartoDB Dark Vector',
      description: 'Sleek dark theme vector map',
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      subdomains: ['a', 'b', 'c'],
      attribution: '© CartoDB, © OpenStreetMap',
    ),
  };

  static MapProviderInfo get(String id) {
    return providers[id] ?? providers['google_hybrid']!;
  }
}
