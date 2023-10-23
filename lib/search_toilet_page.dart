import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_place/google_place.dart';
import 'package:toilet_search/toilet.dart';
import 'package:url_launcher/url_launcher.dart';

import 'const.dart';

class SearchToiletPage extends StatefulWidget {
  const SearchToiletPage({Key? key}) : super(key: key);

  @override
  State<SearchToiletPage> createState() => _SearchToiletPageState();
}

class _SearchToiletPageState extends State<SearchToiletPage> {
  final apiKey = Const.apiKey;

  Toilet? toilet;
  Uri? mapUrl;
  bool? isExist;
  double? _deviceHeight;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    final currentPosition = await _determinePosition();
    final currentLatitude = currentPosition.latitude;
    final currentLongitude = currentPosition.longitude;

    //検索する
    final googlePlace = GooglePlace(apiKey); // ⬅︎GoogleMapと同じAPIキーを指定。

    final response = await googlePlace.search.getNearBySearch(
      Location(lat: currentLatitude, lng: currentLongitude),
      1000,
      language: 'ja',
      keyword: 'トイレ',
      rankby: RankBy.Distance,
    );
    final results = response?.results;
    final isExist = results?.isNotEmpty ?? false;
    setState(() {
      this.isExist = isExist;
    });

    if (!isExist) {
      return;
    }
    final firstResult = results?.first;
    final toiletLocation = firstResult?.geometry?.location;
    final toiletLatitude = toiletLocation?.lat;
    final toiletLongitude = toiletLocation?.lng;

    // GoogleMapへ飛ぶurlの作成
    String urlString = '';

    if (Platform.isAndroid) {
      urlString =
          'https://www.google.co.jp/maps/dir/$currentLatitude, $currentLongitude / $toiletLatitude, $toiletLongitude';
    } else if (Platform.isIOS) {
      urlString =
          'comgooglemaps://?saddr=$currentLatitude, $currentLongitude&daddr=$toiletLatitude, $toiletLongitude&directionsmode=walking';
    }
    mapUrl = Uri.parse(urlString);

    if (firstResult != null && mounted) {
      final photoReference = firstResult.photos?.first.photoReference;
      final String photoUrl;
      if (photoReference != null) {
        photoUrl =
            'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoReference&key=$apiKey';
      } else {
        photoUrl =
            'https://thumb.ac-illust.com/aa/aa9b42e907bef92abf8a36803af33da0_t.jpeg';
      }

      setState(() {
        toilet = Toilet(
          firstResult.name,
          photoUrl,
          toiletLocation,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _deviceHeight = MediaQuery.of(context).size.height;
    if (isExist == false) {
      return const Scaffold(
        body: Center(child: Text('近くにトイレがありません')),
      );
    }

    if (toilet == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple.shade200,
        title: const Text(
          '今一番近くのトイレはここ',
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: _deviceHeight! / 2,
              child: Image.network(
                toilet!.photo!,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              toilet!.name!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                if (mapUrl != null) {
                  await launchUrl(mapUrl!);
                }
              },
              child: const Text('Google Mapへ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('設定にて位置情報を許可してください');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('設定にて位置情報を許可してください');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error('設定にて位置情報を許可してください');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }
}
