import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_fft/flutter_fft.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real-time Sound Analysis',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SoundAnalyzer(),
    );
  }
}

class SoundAnalyzer extends StatefulWidget {
  @override
  _SoundAnalyzerState createState() => _SoundAnalyzerState();
}

class _SoundAnalyzerState extends State<SoundAnalyzer> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterFft _flutterFft = FlutterFft();
  bool _isRecording = false;
  double _frequency = 0.0;
  double _amplitude = 0.0;
  double _decibel = 0.0;
  bool _isAmplitudeHigh = false; 
  bool _isAmplitudeLow = false; // Variabel untuk mendeteksi amplitudo rendah
  StreamSubscription? _subscription;
  Timer? _recordingTimer; // Timer untuk menghentikan dan memulai ulang rekaman
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(Duration(milliseconds: 1000));
  }

  Future<void> _startRecording() async {
    final directory = await getExternalStorageDirectory();
    _filePath = '${directory?.path}/audio.wav';
    print('Audio saved to: $_filePath');

    await _recorder.startRecorder(
      toFile: _filePath,
      codec: Codec.pcm16WAV,
    );

    await _flutterFft.startRecorder();

    _subscription = _flutterFft.onRecorderStateChanged.listen((data) {
      setState(() {
        _frequency = double.tryParse(data[1].toString()) ?? 0.0;
      });
    });

    _recorder.onProgress!.listen((event) {
      if (event.decibels != null) {
        setState(() {
          _amplitude = pow(10, (event.decibels! / 20)) as double;
          _decibel = event.decibels!;

          // Ubah status berdasarkan amplitude
          _isAmplitudeHigh = _amplitude > 1000;
          _isAmplitudeLow = _amplitude >= 50 && _amplitude <= 100;
        });
      }
    });

    setState(() {
      _isRecording = true;
    });

    // Timer untuk restart rekaman setiap 2 detik
    _recordingTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      await _restartRecording();
    });
  }

  Future<void> _restartRecording() async {
    // Stop the current recording
    await _recorder.stopRecorder();
    await _flutterFft.stopRecorder();
    _subscription?.cancel();

    // Optionally delete the previous file
    if (_filePath != null) {
      final file = File(_filePath!);
      if (await file.exists()) {
        await file.delete();
        print('Deleted old recording: $_filePath');
      }
    }

    // Restart the recording
    final directory = await getExternalStorageDirectory();
    _filePath = '${directory?.path}/audio.wav';
    print('Restarting recording, audio saved to: $_filePath');

    await _recorder.startRecorder(
      toFile: _filePath,
      codec: Codec.pcm16WAV,
    );

    await _flutterFft.startRecorder();

    // Re-subscribe to recorder events
    _subscription = _flutterFft.onRecorderStateChanged.listen((data) {
      setState(() {
        _frequency = double.tryParse(data[1].toString()) ?? 0.0;
      });
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel(); // Cancel the periodic timer
    await _recorder.stopRecorder();
    await _flutterFft.stopRecorder();
    _subscription?.cancel();

    setState(() {
      _isRecording = false;
      _isAmplitudeHigh = false;
      _isAmplitudeLow = false; // Reset status saat berhenti merekam
    });
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _recordingTimer?.cancel(); // Cancel the timer if it is still running
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Real-time Sound Analysis'),
      ),
      // Kondisi untuk mengubah warna latar belakang
      body: Container(
        color: _isAmplitudeHigh
            ? Colors.red // Jika amplitudo tinggi
            : _isAmplitudeLow
                ? Colors.blue // Jika amplitudo rendah
                : Colors.white, // Default warna latar belakang
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Frekuensi: ${_frequency.toStringAsFixed(2)} Hz',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            Text(
              'Amplitudo: ${_amplitude.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            Text(
              'Desibel: ${_decibel.toStringAsFixed(2)} dB',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            if (_isAmplitudeHigh)
              Text(
                'Peringatan: Suara terlalu tinggi!',
                style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            if (_isAmplitudeLow)
              Text(
                'Keterangan: Suara rendah',
                style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            SizedBox(height: 50),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
          ],
        ),
      ),
    );
  }
}