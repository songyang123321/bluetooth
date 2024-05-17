///
/// @author Created by SongYang
/// @email: 2419499843@qq.com
/// @Date: 2024/5/16
/// @Description:
///
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;
  const DeviceScreen({
    super.key,
    required this.device,
  });

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  List<BluetoothService> _services = [];
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  late StreamSubscription<BluetoothConnectionState>
  _connectionStateSubscription;

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
          _connectionState = state;
          if (state == BluetoothConnectionState.connected) {
            _services = []; // must rediscover services
          }
          if (mounted) {
            setState(() {});
          }
        });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.device.platformName,
        ),
        actions: [
          TextButton(
            onPressed: isConnected
                ? () async {
              await widget.device.disconnect();
            }
                : () async {
              await widget.device.connect();
              print("Connect: Success");
            },
            child: Text(
              isConnected ? "DISCONNECT" : "CONNECT",
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: Text(
              'Device is ${_connectionState.toString().split('.')[1]}.',
            ),
            trailing: TextButton(
              onPressed: () async {
                if (!isConnected) {
                  print('请先连接蓝牙设备');
                  return;
                }
                /// 连接蓝牙
                _services = await widget.device.discoverServices();

                setState(() {});
              },
              child: const Text("Get Services"),
            ),
          ),
          ..._buildServiceTiles(),
        ],
      ),
    );
  }

  List<Widget> _buildServiceTiles() {
    return _services.map(
          (service) {
        return ExpansionTile(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Service', style: TextStyle(color: Colors.blue)),
              Text(
                '0x${service.uuid.str.toUpperCase()}',
              ),
            ],
          ),
          children: service.characteristics.map((c) {
            return CharacteristicTile(
              characteristic: c,
              descriptorTiles: c.descriptors
                  .map((d) => DescriptorTile(descriptor: d))
                  .toList(),
            );
          }).toList(),
        );
      },
    ).toList();
  }
}


class CharacteristicTile extends StatefulWidget {
  final BluetoothCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;

  const CharacteristicTile(
      {Key? key, required this.characteristic, required this.descriptorTiles})
      : super(key: key);

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  List<int> _value = [];

  late StreamSubscription<List<int>> _lastValueSubscription;

  @override
  void initState() {
    super.initState();
    _lastValueSubscription =
        widget.characteristic.lastValueStream.listen((value) {
          _value = value;
          if (mounted) {
            setState(() {});
          }
        });
  }

  @override
  void dispose() {
    _lastValueSubscription.cancel();
    super.dispose();
  }

  BluetoothCharacteristic get c => widget.characteristic;

  List<int> _getRandomBytes() {
    // 将字符串转换为字节数组
    String data = 'Hello, Bluetooth!';
    List<int> bytes = utf8.encode(data);
    return bytes;
  }

  Future onReadPressed() async {
    try {
      await c.read();
      print("Read: Success");
    } catch (e) {
      print("Read Error:");
    }
  }

  Future onWritePressed() async {
    try {
      await c.write(_getRandomBytes(),
          withoutResponse: c.properties.writeWithoutResponse);
      print("Write: Success");
      if (c.properties.read) {
        await c.read();
      }
    } catch (e) {
      print("Write Error:");
    }
  }

  Future onSubscribePressed() async {
    try {
      String op = c.isNotifying == false ? "Subscribe" : "Unubscribe";
      await c.setNotifyValue(c.isNotifying == false);
      print("$op : Success");
      if (c.properties.read) {
        await c.read();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Subscribe Error:");
    }
  }

  Widget buildUuid(BuildContext context) {
    String uuid = '0x${widget.characteristic.uuid.str.toUpperCase()}';
    return Text(uuid);
  }

  Widget buildValue(BuildContext context) {
    String data = _value.toString();
    return Text(
      data,
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget buildReadButton(BuildContext context) {
    return TextButton(
        child: const Text(
          "Read",
          style: TextStyle(fontSize: 13),
        ),
        onPressed: () async {
          await onReadPressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildWriteButton(BuildContext context) {
    bool withoutResp = widget.characteristic.properties.writeWithoutResponse;
    return TextButton(
        child: Text(withoutResp ? "WriteNoResp" : "Write",
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        onPressed: () async {
          await onWritePressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildSubscribeButton(BuildContext context) {
    bool isNotifying = widget.characteristic.isNotifying;
    return TextButton(
        child: Text(isNotifying ? "Unsubscribe" : "Subscribe"),
        onPressed: () async {
          await onSubscribePressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildButtonRow(BuildContext context) {
    bool read = widget.characteristic.properties.read;
    bool write = widget.characteristic.properties.write;
    bool notify = widget.characteristic.properties.notify;
    bool indicate = widget.characteristic.properties.indicate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (read) buildReadButton(context),
        if (write) buildWriteButton(context),
        if (notify || indicate) buildSubscribeButton(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: ListTile(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Characteristic',
              style: TextStyle(fontSize: 13),
            ),
            buildUuid(context),
            buildValue(context),
          ],
        ),
        subtitle: buildButtonRow(context),
        contentPadding: const EdgeInsets.all(0.0),
      ),
      children: widget.descriptorTiles,
    );
  }
}

class DescriptorTile extends StatefulWidget {
  final BluetoothDescriptor descriptor;

  const DescriptorTile({Key? key, required this.descriptor}) : super(key: key);

  @override
  State<DescriptorTile> createState() => _DescriptorTileState();
}

class _DescriptorTileState extends State<DescriptorTile> {
  List<int> _value = [];

  late StreamSubscription<List<int>> _lastValueSubscription;

  @override
  void initState() {
    super.initState();
    _lastValueSubscription = widget.descriptor.lastValueStream.listen((value) {
      _value = value;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _lastValueSubscription.cancel();
    super.dispose();
  }

  BluetoothDescriptor get d => widget.descriptor;

  List<int> _getRandomBytes() {
    // 将字符串转换为字节数组
    String data = 'Hello, Bluetooth!';
    return utf8.encode(data);
  }

  Future onReadPressed() async {
    try {
      await d.read();
      print("Descriptor Read : Success");
    } catch (e) {
      print("Descriptor Read Error:");
    }
  }

  Future onWritePressed() async {
    try {
      await d.write(_getRandomBytes());
      print("Descriptor Write : Success");
    } catch (e) {
      print("Descriptor Write Error:");
    }
  }

  Widget buildUuid(BuildContext context) {
    String uuid = '0x${widget.descriptor.uuid.str.toUpperCase()}';
    return Text(
      uuid,
      style: TextStyle(fontSize: 13),
    );
  }

  Widget buildValue(BuildContext context) {
    String data = _value.toString();
    return Text(
      data,
      style: TextStyle(fontSize: 13),
    );
  }

  Widget buildReadButton(BuildContext context) {
    return TextButton(
      child: Text("Read"),
      onPressed: onReadPressed,
    );
  }

  Widget buildWriteButton(BuildContext context) {
    return TextButton(
      child: Text("Write"),
      onPressed: onWritePressed,
    );
  }

  Widget buildButtonRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        buildReadButton(context),
        buildWriteButton(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Descriptor',
            style: TextStyle(fontSize: 13),
          ),
          buildUuid(context),
          buildValue(context),
        ],
      ),
      subtitle: buildButtonRow(context),
    );
  }
}

