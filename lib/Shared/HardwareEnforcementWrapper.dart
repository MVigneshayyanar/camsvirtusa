import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class HardwareEnforcementWrapper extends StatefulWidget {
  final Widget child;
  const HardwareEnforcementWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _HardwareEnforcementWrapperState createState() => _HardwareEnforcementWrapperState();
}

class _HardwareEnforcementWrapperState extends State<HardwareEnforcementWrapper> {
  bool _isBluetoothOn = true;
  
  StreamSubscription? _btSubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
    _listenToHardwareStates();
  }

  Future<void> _checkInitialState() async {
    // Check initial BT State
    bool btOn = await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;

    if (mounted) {
      setState(() {
        _isBluetoothOn = btOn;
      });
    }
  }

  void _listenToHardwareStates() {
    _btSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _isBluetoothOn = state == BluetoothAdapterState.on;
        });
      }
    });
  }

  @override
  void dispose() {
    _btSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isAllOn = _isBluetoothOn;

    return Stack(
      children: [
        // The main app (only accessible if hardware is on)
        widget.child,

        // Blocking UI if hardware is off
        if (!isAllOn)
          Positioned.fill(
            child: Container(
              color: Colors.white,
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.warningCircle,
                      color: Colors.redAccent,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Action Required',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'To mark attendance securely, you must keep Bluetooth turned ON at all times.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          height: 1.5,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildStatusRow('Bluetooth', _isBluetoothOn),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusRow(String label, bool isOn) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOn ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOn ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isOn ? Colors.green : Colors.red,
              decoration: TextDecoration.none,
            ),
          ),
          Icon(
            isOn ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.xCircle,
            color: isOn ? Colors.green : Colors.red,
            size: 28,
          ),
        ],
      ),
    );
  }
}
