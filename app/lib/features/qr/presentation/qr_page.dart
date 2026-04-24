import 'package:flutter/material.dart';

class QrPage extends StatelessWidget {
  const QrPage({super.key, required this.sensorId});

  final String sensorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QR 조회 #$sensorId')),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Card(
            child: ListTile(
              title: Text('현재 상태'),
              subtitle: Text('로그인 없이 조회 가능한 센서 상태 영역'),
            ),
          ),
        ),
      ),
    );
  }
}
