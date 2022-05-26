
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';


class KlipAPi {
  String _requestKey = "";


  final prepareUri = Uri.parse('https://a2a-api.klipwallet.com/v2/a2a/prepare');
  Map<String, String> headers = <String, String>{
    'Content-Type': 'application/json'
  };


  // Prepare api
  // Get request key for klip App2App api
  Future<void> prepareRequestKey() async {
    String body = jsonEncode(<String, dynamic>{
      'bapp': {'name': 'ENFT'},
      'callback': {
        'success': 'mybapp://klipwallet/success',
        'fail': 'mybapp://klipwallet/fail'
      },
      'type': 'auth'
    });

    final http.Response response =
    await http.post(prepareUri, body: body, headers: headers);
    final responseBody = Map<String, dynamic>.from(json.decode(response.body));

    print(responseBody['request_key'].toString());
    _requestKey = responseBody['request_key'].toString();
  }


  // android verification api
  Future<void> createIntent() async {
    final AndroidIntent intent = AndroidIntent(
        action: 'action_view',
        data: Uri.encodeFull(
            'kakaotalk://klipwallet/open?url=https://klipwallet.com/?target=/a2a?request_key=$_requestKey#Intent;scheme=kakaotalk;package=com.kakao.talk;end'),
        package: 'com.kakao.talk');
    await intent.launch();
  }

  // iOS verification api
  Future<void> createDeepLink() async {
    String uri =
        "kakaotalk://klipwallet/open?url=https://klipwallet.com/?target=/a2a?request_key=$_requestKey";
    if (await canLaunchUrl(Uri.parse(uri))) {
      print("Deeplink can launch.");
      await launchUrl(Uri.parse(uri));
    } else {
      print("Error: Deeplink can't launch.");
    }
  }

  Future<void> createUriLaunch() async {
    if (Platform.isAndroid) {
      await createIntent();
    } else {
      await createDeepLink();
    }
  }

  Future getKlipAddress() async {
    Uri uri = Uri.parse(
        'https://a2a-api.klipwallet.com/v2/a2a/result?request_key=$_requestKey');

    final http.Response response = await http.get(uri, headers: headers);
    final body = Map<String, dynamic>.from(json.decode(response.body));

    if (body['status'].toString() == 'completed') {
      final result = Map<String, String>.from(body['result']);
      print('Get user klip address: ' + result['klaytn_address'].toString());
      return {
        'address': result['klaytn_address'].toString(),
        'status': 'success'
      };
    } else if (body['status'].toString() == 'canceled') {
      print('User cancel request');
      return {'result': true, 'status': 'canceled'};
    } else if (body['status'].toString() == 'error') {
      print('Error getting klip address');
      return {'result': true, 'status': 'error'};
    } else {
      print(body);
      print('Request in progress');
      return {'result': true, 'status': 'progress'};
    }
  }
}