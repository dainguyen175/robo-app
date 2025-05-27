import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'control_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BluetoothHomePage(),
    );
  }
}

class BluetoothHomePage extends StatefulWidget {
  const BluetoothHomePage({super.key});
  @override
  State<BluetoothHomePage> createState() => _BluetoothHomePageState();
}

class _BluetoothHomePageState extends State<BluetoothHomePage> {
  final List<ScanResult> devicesList = [];
  StreamSubscription<List<ScanResult>>? scanSubscription;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    print('Requesting permissions...');
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    print('Permissions requested');
  }

  void startScan() {
    print('Scan button pressed');
    setState(() {
      devicesList.clear();
      isScanning = true;
    });
    scanSubscription?.cancel();

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      print('Scan results received: ${results.length} devices');
      for (ScanResult result in results) {
        final device = result.device;
        if (device.name.isNotEmpty && !devicesList.any((d) => d.device.id == device.id)) {
          setState(() {
            devicesList.add(result);
          });
        }
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          isScanning = false;
        });
        FlutterBluePlus.stopScan();
        print('Scan completed after 10 seconds');
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ControlScreen(device: device),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to ${device.name}')),
        );
      }
    }
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Devices')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: isScanning ? null : startScan,
            child: Text(isScanning ? 'Scanning... (10s)' : 'Scan Devices'),
          ),
          Expanded(
            child: devicesList.isEmpty
                ? Center(
                    child: Text(
                      isScanning ? 'Scanning for devices...' : 'No devices found',
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: devicesList.length,
                    itemBuilder: (context, index) {
                      var result = devicesList[index];
                      var device = result.device;
                      return ListTile(
                        title: Text(device.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${device.id}'),
                            Text('RSSI: ${result.rssi} dBm'),
                            Text('Type: ${device.platformName}'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => connectToDevice(device),
                          child: const Text('Connect'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
