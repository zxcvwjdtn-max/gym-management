import 'package:flutter/material.dart';

class AdSenseBanner extends StatelessWidget {
  final String adClient;
  final String adSlot;
  final double height;

  const AdSenseBanner({
    super.key,
    required this.adClient,
    required this.adSlot,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
