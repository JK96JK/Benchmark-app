import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const BenchmarkScreen(),
    );
  }
}

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => BenchmarkScreenState();
}

class TestResult {
  final String test;
  final String duration;

  TestResult(this.test, this.duration);
}

// Define the BenchmarkItem class to represent the structure of the mock data used in the memory test.
class BenchmarkItem {
  final int id;
  final String name;
  final int timestamp;
  final bool active;

  BenchmarkItem({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.active,
  });
}

class BenchmarkScreenState extends State<BenchmarkScreen> {
  final List<TestResult> result = [];
  bool isRunning = false;
  String statusText = 'Aja testi';
  bool isRenderTestActive = false;
  List<Color> colors = [];
  int renderCount = 0;
  DateTime? testStartTime;

  List<Color> getRandomColors(int amount) {
    final random = Random();
    return List.generate(
      amount,
      (_) => Color.fromARGB(
        255,
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      ),
    );
  }

  Future<void> runCpuTest() async {
    setState(() {
      isRunning = true;
      statusText = 'Suoritetaan CPU-testiä...';
    });
    await Future.delayed(const Duration(milliseconds: 100));

    final stopwatch = Stopwatch()..start();
    int primes = 0;
    for (int i = 2; i < 1000000; i++) {
      bool isPrime = true;
      for (int j = 2; j * j <= i; j++) {
        if (i % j == 0) {
          isPrime = false;
          break;
        }
      }
      if (isPrime) primes++;
    }
    stopwatch.stop();
    setState(() {
      isRunning = false;
      statusText = 'CPU-testi valmis!';
      result.add(
        TestResult('CPU Testi (1M)', '${stopwatch.elapsedMilliseconds} ms'),
      );
    });
  }

  void runRenderTest() {
    setState(() {
      isRunning = true;
      statusText = "Suoritetaan renderöintitestiä...";
      isRenderTestActive = true;
      renderCount = 0;
      testStartTime = DateTime.now();
      colors = getRandomColors(900);
    });

    scheduleNextFrame();
  }

  void scheduleNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isRenderTestActive || testStartTime == null) return;
      final elapsed = DateTime.now().difference(testStartTime!).inMilliseconds;
      if (elapsed < 5000) {
        setState(() {
          renderCount++;
          colors = getRandomColors(900);
        });
        scheduleNextFrame();
      } else {
        setState(() {
          isRenderTestActive = false;
          isRunning = false;
          statusText = "Renderöintitesti valmis!";
          result.add(
            TestResult(
              'Renderöintitesti (5s)',
              '$renderCount renderöintiä 5 sekunnissa',
            ),
          );
          colors = [];
        });
      }
    });
  }

  // 3. Memory test
  Future<void> runMemoryTest() async {
    setState(() {
      isRunning = true;
      statusText = "Suoritetaan muistintestausta...";
    });
    await Future.delayed(const Duration(milliseconds: 100));

    final startTime = DateTime.now().millisecondsSinceEpoch;
    const recordCount = 1000000;
    const baseTimestamp = 1700000000000;

    // 1. Reserve memory for 1 million objects
    List<BenchmarkItem>? list = List<BenchmarkItem>.generate(
      recordCount,
      (i) => BenchmarkItem(
        id: i,
        name: 'Käyttäjä $i',
        timestamp: baseTimestamp + i,
        active: i % 2 == 0,
      ),
      growable: true,
    );

    // 2. Data processing: Calculate checksum of active items
    int checksum = 0;
    for (final item in list) {
      if (item.active) checksum += item.id;
    }

    final endTime = DateTime.now().millisecondsSinceEpoch;
    final duration = endTime - startTime;

    // 3. Vapautus roskienkeruulle
    list.clear();
    list = null;

    setState(() {
      result.add(TestResult('Muistintestaus (1M oliota)', '$duration ms'));
      isRunning = false;
      statusText = 'Muistintestaus valmis';
    });
  }

  Future<void> exportResults() async {
    if (result.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ei tuloksia vietäväksi.')));
      return;
    }
    try {
      String csvContent = "Testi,Tulos\n";
      for (var r in result) {
        csvContent += "${r.test},${r.duration}\n";
      }
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/benchmark_results.csv');
      await file.writeAsString(csvContent);
      await Share.shareXFiles([XFile(file.path)], text: 'Benchmark tulokset');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Virhe viedessä tuloksia: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = MediaQuery.of(context).size.width * 0.8;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Suorituskykytesti",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Status Box
              Container(
                constraints: const BoxConstraints(minHeight: 80),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF555555),
                      ),
                    ),
                    if (isRunning && !isRenderTestActive) ...[
                      const SizedBox(height: 10),
                      const CircularProgressIndicator(color: Color(0xFF2196F3)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Render Grid (300x300, 1000 solua)
              if (isRenderTestActive)
                Container(
                  width: 300,
                  height: 300,
                  color: Colors.black,
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 30,
                    children: colors
                        .map((color) => Container(color: color))
                        .toList(),
                  ),
                ),

              // Painikkeet
              if (!isRunning) ...[
                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.all(15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: runCpuTest,
                    child: const Text(
                      "1. CPU Testi",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.all(15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: runRenderTest,
                    child: const Text(
                      "2. Renderöintitesti",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.all(15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: runMemoryTest,
                    child: const Text(
                      "3. Muistintestaus",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.all(15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: exportResults,
                    child: const Text(
                      "💾 Vie tulokset (CSV)",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // Tulokset
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tulokset:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (result.isEmpty)
                      const Text(
                        "Ei tuloksia",
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF555555),
                        ),
                      )
                    else
                      ...result.map(
                        (r) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFEEEEEE)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "${r.test}: ",
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                r.duration,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
