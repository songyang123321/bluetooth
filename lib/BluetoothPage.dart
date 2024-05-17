import 'dart:async';
import 'dart:io';

import 'package:bluetooth/DeviceScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  ///当前已经连接的蓝牙设备
  List<BluetoothDevice> _systemDevices = [];

  ///扫描到的蓝牙设备
  List<ScanResult> _scanResults = [];

  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      if (mounted) {
        setState(() {});
      }
    }, onError: (error) {
      print('Scan Error:$error');
    });
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("蓝牙"),
      ),
      body: ListView(
        children: [
          ..._buildSystemDeviceTiles(),
          ..._buildScanResultTiles(),
        ],
      ),
      floatingActionButton: FlutterBluePlus.isScanningNow
          ? FloatingActionButton(
              onPressed: () {
                FlutterBluePlus.stopScan();
              },
              backgroundColor: Colors.red,
              child: const Text("Stop"),
            )
          : FloatingActionButton(
              onPressed: () async {
                try {
                  _systemDevices = FlutterBluePlus.connectedDevices;
                  print('dc-----_systemDevices$_systemDevices');
                } catch (e) {
                  print("Stop Scan Error:$e");
                }
                try {
                  // android is slow when asking for all advertisements,
                  // so instead we only ask for 1/8 of them
                  int divisor = Platform.isAndroid ? 8 : 1;
                  await FlutterBluePlus.startScan();
                } catch (e) {
                  print("Stop Scan Error:$e");
                }
                if (mounted) {
                  setState(() {});
                }
              },
              child: const Text("SCAN"),
            ),
    );
  }

  List<Widget> _buildSystemDeviceTiles() {
    return _systemDevices.map((device) {
      return ListTile(
        title: Text(device.platformName),
        subtitle: Text(device.remoteId.toString()),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => DeviceScreen(device: device)));
          },
          child: const Text('CONNECT'),
        ),
      );
    }).toList();
  }

  List<Widget> _buildScanResultTiles() {
    return _scanResults
        .map(
          (scanResult) => ListTile(
            title: Text(
              scanResult.device.platformName,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              scanResult.device.remoteId.toString(),
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => DeviceScreen(device: scanResult.device)));
              },
              child: const Text('CONNECT'),
            ),
          ),
        )
        .toList();
  }
}
