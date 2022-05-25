import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';


class KlipLoginButton extends StatelessWidget {
  final Function() onPressed;

  const KlipLoginButton({Key? key, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
        child: Container(
            height: 56.0,
            child: OutlinedButton(
                onPressed: onPressed,
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all(const Color(0xff216FEA)),
                  foregroundColor: MaterialStateProperty.all(
                    const Color(0xffffffff),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                        margin: const EdgeInsets.all(kDefaultPadding / 2),
                        child: SvgPicture.asset(
                          'assets/logos/klip_logo.svg',
                          height: 18.0,
                          fit: BoxFit.fitWidth,
                        )),
                    const Text(
                      "Klip으로 시작",
                      style: TextStyle(fontSize: 18),
                    )
                  ],
                ))));
  }
}
