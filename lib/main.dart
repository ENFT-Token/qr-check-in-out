import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_checkinout/constant.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decode/jwt_decode.dart';
import 'package:lottie/lottie.dart';

import 'KlipApi.dart';
import 'KlipLoginButton.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class User {
  int status;
  String accessToken;
  String address;
  String place;

  User(this.status, this.accessToken, this.address, this.place);
}

AudioCache audioPlayer = AudioCache();

Future<String> CheckInOut(User user, addrToken) async {
  try {
    print(addrToken);
    if (Jwt.isExpired(addrToken) == true) {
      // 기간 만료
      throw "30초가 지난 티켓입니다.";
    }
    Map<String, dynamic> jsonValue = Jwt.parseJwt(addrToken);
    print(jsonValue);
    if (!jsonValue.containsKey('address') ||
        !jsonValue.containsKey('nftToken')) {
      throw "올바르지 않은 QR 형식입니다.";
    }

    print("hh ${jsonValue['nftToken']}");
    Map<String, dynamic> payload = Jwt.parseJwt(jsonValue['nftToken']);

    print(user.place);
    print(payload['place']);
    if (user.place != payload['place']) {
      throw "이용권의 위치와 사용하려는 위치가 일치하지 않습니다.";
    }
    if (Jwt.isExpired(jsonValue['nftToken']) == true) {
      // 기간 만료
      throw "기간이 만료된 토큰입니다";
    }
    var checkUrl = Uri.parse('http://13.209.200.101:3000/check');
    var response = await http.post(checkUrl, body: {
      'address': jsonValue['address'],
      'nftToken': jsonValue['nftToken'],
    }, headers: {
      'Authorization': 'Bearer ' + user.accessToken,
    });
    Map<String, dynamic> body = jsonDecode(response.body);
    if (response.statusCode == 201) {
      audioPlayer.play(body["status"] + ".mp3");
      print(body["status"]); // "checkin" or "checkout"
      print(body["place"]);
      return "[ " + body["place"] + " ] " + body["status"];
    } else {
      print(body);
      throw "유효하지 않은 티켓입니다.";
    }
  } catch (e) {
    print(e);
    return e.toString();
  }
}

Future<User> Login(address) async {
  var loginUrl = Uri.parse('http://13.209.200.101:3000/auth/admin/login');
  var response = await http.post(loginUrl, body: {'address': address});
  print(response.body);
  if (response.statusCode == 201) {
    final body = jsonDecode(response.body);
    return User(response.statusCode, body['access_token'], body['address'],
        body['place']);
  }
  return User(response.statusCode, "", "", "");
}

void main() async {
  await dotenv.load(fileName: '.env');
  runApp(const MaterialApp(home: LoginPage()));
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(kDefaultPadding * 2),
        child: Column(
          children: <Widget>[
            Lottie.asset('assets/logo/running.json'),
            Expanded(
                child: Center(
                    child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "ENFT 관리자 어플리케이션",
                  style: TextStyle(fontSize: 24),
                ),
                Text(
                  "\nQR 코드로 출입을 관리하세요!",
                  style: TextStyle(fontSize: 24),
                ),
              ],
            ))),
            KlipLoginButton(
              onPressed: () async {
                final klipApi = KlipAPi();
                await klipApi.prepareRequestKey();
                await klipApi.createUriLaunch();
                int i = 0;
                String address = "";
                await Future.doWhile(() async {
                  i++;
                  await Future.delayed(const Duration(seconds: 3));
                  final result = await klipApi.getKlipAddress();
                  if (result['status'] == "success") {
                    address = result['address'];
                    return false;
                  }
                  if (i == 10) {
                    return false;
                  }
                  return true;
                });
                if (address != "") {
                  print(address);
                  final user = await Login(address);
                  if (user.status != 201)
                    FlutterDialog("안내", "로그인 실패");
                  else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                CheckInOutQRView(user: user)));
                  }
                } else {
                  FlutterDialog("안내", "클립 연결 실패");
                }
              },
            ),
          ],
        ),
      )),
    );
  }

  void FlutterDialog(title, content) {
    showDialog(
        context: context,
        //barrierDismissible - Dialog를 제외한 다른 화면 터치 x
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            // RoundedRectangleBorder - Dialog 화면 모서리 둥글게 조절
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0)),
            //Dialog Main Title
            title: Column(
              children: <Widget>[
                new Text(title),
              ],
            ),
            //
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  content,
                ),
              ],
            ),
            actions: <Widget>[
              new FlatButton(
                child: new Text("확인"),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
  }
}

class CheckInOutQRView extends StatefulWidget {
  final User user;

  const CheckInOutQRView({Key? key, required this.user}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewState();
}

class _QRViewState extends State<CheckInOutQRView> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool scanAllow = true;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    }
    controller!.resumeCamera();
  }

  void Toast(content) {
    print(content);
    bool isError = (content.contains("checkin") || content.contains("checkout"))
        ? true
        : false;
    print(isError);
    final snackBar = SnackBar(
      content: Container(
          height: 100,
          child: Center(
            child: RichText(
                text: TextSpan(
                    text: content,
                    style: TextStyle(
                        color: isError ? Colors.white : Colors.red,
                        fontSize: 20))),
          )),
    );

    // Find the ScaffoldMessenger in the widget tree
    // and use it to show a SnackBar.
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
        body: Stack(alignment: Alignment.bottomCenter, children: <Widget>[
      _buildQrView(context),
      Positioned(
          bottom: size.height * 0.1,
          child: FutureBuilder(
            future: controller?.getCameraInfo(),
            builder: (context, snapshot) {
              if (snapshot.data != null) {
                return IconButton(
                    icon: Icon(
                      Icons.cameraswitch_rounded,
                      size: 66,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      await controller?.flipCamera();
                      setState(() {});
                    });
              } else {
                print(snapshot.error);
                return const Text('loading');
              }
            },
          ))
    ]));
  }

  Widget _buildQrView(BuildContext context) {
    // For this example we check how width or tall the device is and change the scanArea and overlay accordingly.
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    // To ensure the Scanner view is properly sizes after rotation
    // we need to listen for Flutter SizeChanged notification and update controller
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: Colors.red,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 500),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) async {
      if (scanAllow == true && scanData.code != null) {
        scanAllow = false;
        Timer(Duration(seconds: 5), () {
          scanAllow = true;
        });
        print(scanData.code);
        final checkResult = await CheckInOut(widget.user, scanData.code);
        Toast(checkResult);
      }
      setState(() {
        result = scanData;
      });
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('no Permission')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
