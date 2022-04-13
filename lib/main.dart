import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decode/jwt_decode.dart';


class User {
  int status;
  String accessToken;
  String address;
  String privateKey;
  String place;
  User(this.status, this.accessToken, this.address, this.privateKey, this.place);
}

Future<String> CheckInOut(User user, addrToken) async {
  Map<String, dynamic> jsonValue = jsonDecode(addrToken);
  Map<String, dynamic> payload = Jwt.parseJwt(jsonValue['nftToken']);
  print("jwt값 ");
  print(user.place);
  print(payload['place']);
  if(user.place != payload['place']) {
    return "사용하고자 하는 장소가 다릅니다.";
  }
  if(Jwt.isExpired(jsonValue['nftToken']) == true) {
    // 기간 만료
    return "기간 만료";
  }

  var checkUrl = Uri.parse('http://3.39.24.209/check');
  var response = await http.post(checkUrl, body: jsonValue, headers: {
    'Authorization': 'Bearer $user.accessToken',
  });
  Map<String, dynamic> body = jsonDecode(response.body);

  if(response.statusCode == 201) {
    print(body["status"]); // "checkin" or "checkout"
    print(body["place"]);
    return "[ " + body["place"] + " ] " + body["status"];
  }
  else {
    return "인증 실패";
  }
}

Future<User> Login(id, pw) async {
  var loginUrl = Uri.parse('http://3.39.24.209/auth/admin/login');
  var response = await http.post(loginUrl, body: {'email': id, 'password': pw});
  if(response.statusCode == 201) {
    final body = jsonDecode(response.body);
    return User(response.statusCode, body['access_token'], body['address'],body['privateKey'],body['place']);
  }
  return User(response.statusCode ,"", "", "", "");
}


void main() => runApp(const MaterialApp(home: LoginPage()));

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
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          children: <Widget>[
            SizedBox(height: 80.0),

            SizedBox(height: 120.0),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                filled: true,
                labelText: 'Username',
              ),
            ),
            SizedBox(height: 12.0),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                filled: true,
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            ButtonBar(
              children: <Widget>[
                RaisedButton(
                  child: Text('LOGIN'),
                  onPressed: () async {
                    print(_usernameController.text);
                    print( _passwordController.text);
                    final user = await Login(_usernameController.text, _passwordController.text);
                    if(user.status != 201)
                      FlutterDialog("안내","로그인 실패");
                    else {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => CheckInOutQRView(user: user)));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void FlutterDialog(title,content) {
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
  const CheckInOutQRView({Key ?key, required this.user}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewState();
}

class _QRViewState extends State<CheckInOutQRView> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

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
    final snackBar = SnackBar(
      content: Text(content),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          // Some code to undo the change.
        },
      ),
    );

    // Find the ScaffoldMessenger in the widget tree
    // and use it to show a SnackBar.
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  if (result != null)
                    Text(
                        'Barcode Type: ${describeEnum(result!.format)}   Data: ${result!.code}')
                  else
                    Text(widget.user.accessToken),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                            onPressed: () async {
                              await controller?.toggleFlash();
                              setState(() {});
                            },
                            child: FutureBuilder(
                              future: controller?.getFlashStatus(),
                              builder: (context, snapshot) {
                                return Text('Flash: ${snapshot.data}');
                              },
                            )),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                            onPressed: () async {
                              await controller?.flipCamera();
                              setState(() {});
                            },
                            child: FutureBuilder(
                              future: controller?.getCameraInfo(),
                              builder: (context, snapshot) {
                                if (snapshot.data != null) {
                                  return Text(
                                      'Camera facing ${describeEnum(snapshot.data!)}');
                                } else {
                                  return const Text('loading');
                                }
                              },
                            )),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                            onPressed: () async {
                              final result = await CheckInOut(widget.user.accessToken, '{"address":"0x5530580E722f5dDEeeFb34b45fA8c5cb382dD789","nftToken":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwbGFjZSI6IkVORlQg7Zes7Iqk7J6lIiwic3RhcnRfZGF0ZSI6IjIwMjItMDQtMTIiLCJlbmRfZGF0ZSI6IjIwMjItMDUtMTIiLCJpYXQiOjE2NDk3NTQxMzIsImV4cCI6MTY1MjM0NjEzMn0.KDMvs0EKAuTJX2K3WI_1hh6b5JSu_blSrFaYgfnzQo4"}');
                              Toast(result);
                            },
                            child: FutureBuilder(
                              builder: (context, snapshot) {
                                  return Text('TEST CHECKOUT');
                              },
                            )),
                      )
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
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
          cutOutSize: scanArea),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
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
