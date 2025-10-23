import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Pokémon Go Map',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MapPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final EncounterController controller = Get.put(EncounterController());

  @override
  void initState() {
    super.initState();
    controller.initLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final center = controller.center.value ?? const LatLng(19.4326, -99.1332);
      return Scaffold(
        appBar: AppBar(title: const Text('Pokémon Map')),
        body: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                onTap: (tapPos, latLng) => controller.handleTap(latLng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'pokimon_go',
                ),
                MarkerLayer(markers: controller.markers),
              ],
            ),
            if (controller.selectedPokemon.value != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: _PokemonInfo(pokemon: controller.selectedPokemon.value!),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await controller.initLocation();
          },
          child: const Icon(Icons.my_location),
        ),
      );
    });
  }
}

class _PokemonInfo extends StatelessWidget {
  final Map<String, dynamic> pokemon;
  const _PokemonInfo({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final types = (pokemon['types'] as List).join(', ');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pokemon['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Tipos: $types'),
            ],
          ),
        ),
        if (pokemon['sprite'] != null)
          Image.network(
            pokemon['sprite'],
            height: 64,
            width: 64,
            errorBuilder: (ctx, err, stack) => const Icon(Icons.catching_pokemon, size: 48),
          ),
      ],
    );
  }
}

enum BiomeType { water, fire, forest, rock, ground, ice, urban, other }

class EncounterController extends GetxController {
  final Rx<LatLng?> center = Rx<LatLng?>(null);
  final RxList<Marker> markers = <Marker>[].obs;
  final Rx<Map<String, dynamic>?> selectedPokemon = Rx<Map<String, dynamic>?>(null);

  Future<void> initLocation() async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied || status == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      center.value = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      center.value = const LatLng(19.4326, -99.1332); // fallback: CDMX
    }
  }

  Future<void> handleTap(LatLng latLng) async {
    // Marker básico del punto seleccionado
    _setSelectionMarker(latLng);

    // Detectar bioma y elegir tipo Pokémon
    final biome = await _detectBiome(latLng);
    final type = _mapBiomeToType(biome);

    // Consultar PokeAPI
    final pokemon = await _fetchRandomPokemonByType(type);
    if (pokemon != null) {
      selectedPokemon.value = pokemon;
      // Reemplazar marcador con sprite
      _setPokemonMarker(latLng, pokemon['sprite']);
      // Registrar encuentro en Supabase
      await _insertEncounter(latLng, pokemon);
      // Guardar localmente (opcional)
      await _cacheEncounter(pokemon, latLng);
    }
  }

  void _setSelectionMarker(LatLng latLng) {
    markers
      ..clear()
      ..add(Marker(
        point: latLng,
        width: 40,
        height: 40,
        child: const Icon(Icons.place, color: Colors.red, size: 36),
      ));
  }

  void _setPokemonMarker(LatLng latLng, String? spriteUrl) {
    markers
      ..clear()
      ..add(Marker(
        point: latLng,
        width: 60,
        height: 60,
        child: spriteUrl != null
            ? Image.network(spriteUrl, errorBuilder: (c, e, s) => const Icon(Icons.catching_pokemon, size: 48))
            : const Icon(Icons.catching_pokemon, size: 48, color: Colors.deepPurple),
      ));
  }

  Future<BiomeType> _detectBiome(LatLng pos) async {
    try {
      final q = _overpassQuery(pos.latitude, pos.longitude);
      final res = await http.post(Uri.parse('https://overpass-api.de/api/interpreter'), body: q);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final elements = (data['elements'] as List?) ?? [];
        final tagsList = elements.map((e) => (e['tags'] ?? {}) as Map).toList();
        return _classifyBiome(tagsList);
      }
    } catch (_) {}
    return BiomeType.other;
  }

  String _overpassQuery(double lat, double lon) {
    return '''
[out:json][timeout:25];
(
  node(around:800, $lat, $lon)["natural"="coastline"];
  way(around:800, $lat, $lon)["natural"="coastline"];
  node(around:800, $lat, $lon)["natural"="water"];
  way(around:800, $lat, $lon)["natural"="water"];
  node(around:800, $lat, $lon)["waterway"];
  way(around:800, $lat, $lon)["waterway"];
  node(around:1500, $lat, $lon)["natural"="volcano"];
  way(around:1500, $lat, $lon)["natural"="volcano"];
  way(around:800, $lat, $lon)["natural"="wood"];
  way(around:800, $lat, $lon)["landuse"="forest"];
  way(around:800, $lat, $lon)["landuse"="park"];
  way(around:800, $lat, $lon)["natural"="rock"];
  way(around:800, $lat, $lon)["natural"="sand"];
  way(around:800, $lat, $lon)["natural"="heath"];
  way(around:800, $lat, $lon)["natural"="wetland"];
  way(around:800, $lat, $lon)["landuse"="residential"];
  way(around:800, $lat, $lon)["landuse"="industrial"];
  way(around:800, $lat, $lon)["landuse"="commercial"];
);
out tags center 40;
''';
  }

  BiomeType _classifyBiome(List<Map> tagsList) {
    bool hasAnyTag(bool Function(Map) predicate) => tagsList.any(predicate);

    if (hasAnyTag((t) =>
        t['natural'] == 'coastline' ||
        t['natural'] == 'water' ||
        t['waterway'] != null ||
        t['natural'] == 'wetland')) {
      return BiomeType.water;
    }
    if (hasAnyTag((t) => t['natural'] == 'volcano' || t['geological'] == 'volcanic')) {
      return BiomeType.fire;
    }
    if (hasAnyTag((t) => t['natural'] == 'wood' || t['landuse'] == 'forest' || t['landuse'] == 'park' || t['natural'] == 'heath')) {
      return BiomeType.forest;
    }
    if (hasAnyTag((t) => t['natural'] == 'rock')) {
      return BiomeType.rock;
    }
    if (hasAnyTag((t) => t['natural'] == 'sand')) {
      return BiomeType.ground;
    }
    if (hasAnyTag((t) => t['natural'] == 'glacier' || t['natural'] == 'ice' || t['natural'] == 'snow')) {
      return BiomeType.ice;
    }
    if (hasAnyTag((t) => t['landuse'] == 'residential' || t['landuse'] == 'industrial' || t['landuse'] == 'commercial')) {
      return BiomeType.urban;
    }
    return BiomeType.other;
  }

  String _mapBiomeToType(BiomeType biome) {
    switch (biome) {
      case BiomeType.water:
        return 'water';
      case BiomeType.fire:
        return 'fire';
      case BiomeType.forest:
        return 'grass';
      case BiomeType.rock:
        return 'rock';
      case BiomeType.ground:
        return 'ground';
      case BiomeType.ice:
        return 'ice';
      case BiomeType.urban:
        return 'normal';
      case BiomeType.other:
        return 'flying';
    }
  }

  Future<Map<String, dynamic>?> _fetchRandomPokemonByType(String type) async {
    try {
      final listRes = await http.get(Uri.parse('https://pokeapi.co/api/v2/type/$type'));
      if (listRes.statusCode != 200) return null;
      final listJson = json.decode(listRes.body);
      final pokes = (listJson['pokemon'] as List).map((e) => e['pokemon']).toList();
      if (pokes.isEmpty) return null;
      final rnd = Random();
      final pick = pokes[rnd.nextInt(pokes.length)];
      final name = pick['name'];
      final detRes = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$name'));
      if (detRes.statusCode != 200) return null;
      final det = json.decode(detRes.body);
      final types = (det['types'] as List).map((t) => t['type']['name']).cast<String>().toList();
      return {
        'id': det['id'],
        'name': det['name'],
        'types': types,
        'sprite': det['sprites']?['front_default'],
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _insertEncounter(LatLng pos, Map<String, dynamic> poke) async {
    try {
      await Supabase.instance.client.from('pokemon_encounters').insert({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'pokemon_id': poke['id'],
        'pokemon_name': poke['name'],
        'pokemon_types': poke['types'],
      });
    } catch (e) {
      // ignore errors in demo
    }
  }

  Future<void> _cacheEncounter(Map<String, dynamic> poke, LatLng pos) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/encounters.json');
      final now = DateTime.now().toIso8601String();
      final entry = {
        'time': now,
        'lat': pos.latitude,
        'lon': pos.longitude,
        'pokemon': poke,
      };
      List list = [];
      if (await f.exists()) {
        final txt = await f.readAsString();
        list = (txt.isNotEmpty) ? (json.decode(txt) as List) : [];
      }
      list.add(entry);
      await f.writeAsString(json.encode(list));
    } catch (_) {}
  }
}
