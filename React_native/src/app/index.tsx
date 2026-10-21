import {
  Alert,
  Share,
  StyleSheet,
  Text,
  View,
  ScrollView,
  ActivityIndicator,
  TouchableOpacity,
} from "react-native";
import React, { useEffect, useRef, useState } from "react";
import * as FileSystem from "expo-file-system/legacy";
import * as Sharing from "expo-sharing";

// This is the main entry point of the React Native application. It sets up the initial state and renders the main view of the app.
export default function App() {
  // State variables for managing the test results, running status, and status text
  const [result, setResult] = useState<{ test: string; duration: string }[]>(
    [],
  );
  const [isRunning, setIsRunning] = useState(false);
  const [statusText, setStatusText] = useState("Aja testi");
  // States for render test
  const [isRenderTestActive, setIsRenderTestActive] = useState(false);
  const [colors, setColors] = useState<any[]>([]);
  const renderCount = useRef(0);
  const renderStartTime = useRef(0);

  // Helper function to generate a random color
  const getRandomColors = (amount: any) => {
    return Array.from(
      { length: amount },
      () =>
        `rgb(${Math.floor(Math.random() * 255)},${Math.floor(Math.random() * 255)},${Math.floor(Math.random() * 255)})`,
    );
  };
  // 1. CPU Test: This function runs a CPU-intensive test by performing a large number of calculations.
  // It measures the time taken to complete the calculations and updates the result state with the duration.
  // We calculate the number of prime numbers up to 1,000,000 and measure how long it takes to complete this calculation.
  const runCPUTest = () => {
    setIsRunning(true);
    setStatusText("Suoritetaan CPU-testiä...");
    setTimeout(() => {
      const startTime = performance.now();
      let primes = 0;
      for (let i = 2; i < 1000000; i++) {
        let isPrime = true;
        for (let j = 2; j <= Math.sqrt(i); j++) {
          if (i % j === 0) {
            isPrime = false;
            break;
          }
        }
        if (isPrime) primes++;
      }
      const endTime = performance.now();
      const duration = Math.round(endTime - startTime);
      setResult((prev) => [
        ...prev,
        { test: "CPU Testi (1M)", duration: `${duration} ms` },
      ]);
      setIsRunning(false);
      setStatusText("CPU-testi valmis");
    }, 100);
  };

  // 2. Render Test: This function runs a render performance test by generating a large number of random colors and rendering them in the UI.
  // It measures the time taken to render the colors and updates the result state with the duration.
  const runRenderTest = () => {
    setIsRunning(true);
    setStatusText("Suoritetaan renderöintitestiä...");
    setIsRenderTestActive(true);
    renderCount.current = 0;
    renderStartTime.current = performance.now();
    setColors(getRandomColors(1000));
  };

  // useEffect hook to handle the render test logic.
  // It checks if the render test is active and updates the colors state every time the colors state changes.
  useEffect(() => {
    if (isRenderTestActive) {
      const animationFrameId = requestAnimationFrame(() => {
        const now = performance.now();
        if (now - renderStartTime.current < 5000) {
          renderCount.current++; // Increment the render count
          setColors(getRandomColors(1000)); // Generate new colors to trigger re-rendering
        } else {
          // After 5 seconds, stop the render test and update the result state with the number of renders completed.
          setIsRenderTestActive(false);
          setIsRunning(false);
          setResult((prev) => [
            ...prev,
            {
              test: "Renderöintitesti (5s)",
              duration: `${renderCount.current} renderöintiä 5 sekunnissa`,
            },
          ]);
          setStatusText("Renderöintitesti valmis");
          // Clear the colors state to stop rendering
          setColors([]);
        }
      });
      return () => cancelAnimationFrame(animationFrameId); // Cleanup the animation frame on component unmount or when the effect re-runs
    }
  }, [colors, isRenderTestActive]);

  // 3. Memory Test: This function runs a memory-intensive test by creating a large number of mock data objects and converting them to JSON.
  // It measures the time taken to create and parse the JSON data and updates the result state with the duration.
  const runMemoryTest = () => {
    setIsRunning(true);
    setStatusText("Suoritetaan muistintestausta...");
    setTimeout(() => {
      const startTime = performance.now();
      let mockData: any[] | null = [];
      for (let i = 0; i < 1000000; i++) {
        mockData.push({
          id: i,
          name: `Käyttäjä ${i}`,
          timestamp: Date.now(),
          isActive: i % 2 === 0,
        });
      }
      // Convert the mock data to a JSON string and then parse it back to an object to simulate memory usage.
      let jsonString: string | null = JSON.stringify(mockData);
      let parsedData: any = JSON.parse(jsonString);
      const endTime = performance.now();
      const timeMs = Math.round(endTime - startTime);
      // Clean references for Garbage Collection
      mockData = null;
      jsonString = null;
      parsedData = null;
      setResult((prev) => [
        ...prev,
        {
          test: "Muistintestaus (1M JSON objektia)",
          duration: `${timeMs} ms`,
        },
      ]);
      setIsRunning(false);
      setStatusText("Muistintestaus valmis");
    }, 100);
  };

  // Function to export the test results to a CSV file and share it using the device's sharing options.
  const exportResults = async () => {
    if (result.length === 0) {
      alert("Ei tuloksia vietäväksi.");
      return;
    }
    try {
      let csvContent = "Testi,Tulos\n";
      result.forEach((r) => {
        csvContent += `${r.test},${r.duration}\n`;
      });
      // Create a new file in the document directory and write the CSV content to it.
      const fileUri = `${FileSystem.documentDirectory}benchmark_results.csv`;
      await FileSystem.writeAsStringAsync(fileUri, csvContent);
      await Sharing.shareAsync(fileUri, {
        mimeType: "text/csv",
        dialogTitle: "Jaa tulokset",
      });
    } catch (error) {
      Alert.alert("Virhe", "Tiedoston vienti epäonnistui.");
    }
  };
  return (
    // Main ScrollView container for the app's UI
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.header}>Suorituskykytesti</Text>
      <View style={styles.statusBox}>
        <Text style={styles.statusText}>{statusText}</Text>
        {/* Show an activity indicator while a test is running and the render test is not active. */}
        {isRunning && !isRenderTestActive && (
          <ActivityIndicator
            size="large"
            color="#2196F3"
            style={{ marginTop: 10 }}
          />
        )}
      </View>
      {/* Render the grid of colored cells during the render test. */}
      {isRenderTestActive && (
        <View style={styles.grid}>
          {colors.map((color, index) => (
            <View
              key={index}
              style={[styles.cell, { backgroundColor: color }]}
            />
          ))}
        </View>
      )}
      {/* Show the test buttons when not running any test. */}
      {!isRunning && (
        <View style={styles.buttonContainer}>
          <TouchableOpacity style={styles.button} onPress={runCPUTest}>
            <Text style={styles.buttonText}>1. CPU Testi</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.button} onPress={runRenderTest}>
            <Text style={styles.buttonText}>2. Renderöintitesti</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.button} onPress={runMemoryTest}>
            <Text style={styles.buttonText}>3. Muistintestaus</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.exportButton]}
            onPress={exportResults}
          >
            <Text style={styles.buttonText}>💾 Vie tulokset (CSV)</Text>
          </TouchableOpacity>
        </View>
      )}
      {/* Show the results container. */}
      <View style={styles.resultsContainer}>
        <Text style={styles.resultsHeader}>Tulokset:</Text>
        {result.length === 0 ? (
          <Text style={styles.statusText}>Ei tuloksia</Text>
        ) : (
          result.map((r, index) => (
            <Text key={index} style={styles.resultItem}>
              {r.test}: {r.duration}
            </Text>
          ))
        )}
      </View>
    </ScrollView>
  );
}

// Styles for the app's UI components and ignore for TypeScript errors related to the StyleSheet.create method.
//@ts-ignore
const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    padding: 20,
    backgroundColor: "#f5f5f5",
    alignItems: "center",
  },
  header: { fontSize: 24, fontWeight: "bold", marginTop: 40, marginBottom: 20 },
  statusBox: {
    minHeight: 80,
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 20,
  },
  statusText: { fontSize: 16, fontStyle: "italic", color: "#555" },
  buttonContainer: { width: "100%", alignItems: "center" },
  button: {
    backgroundColor: "#2196F3",
    width: "80%",
    padding: 15,
    borderRadius: 8,
    marginBottom: 15,
    alignItems: "center",
  },
  exportButton: { backgroundColor: "#4CAF50", marginTop: 20 },
  buttonText: { color: "white", fontSize: 16, fontWeight: "bold" },
  resultsContainer: {
    width: "100%",
    marginTop: 30,
    padding: 15,
    backgroundColor: "white",
    borderRadius: 8,
  },
  resultsHeader: { fontSize: 18, fontWeight: "bold", marginBottom: 10 },
  resultItem: {
    fontSize: 14,
    marginBottom: 5,
    borderBottomWidth: 1,
    borderBottomColor: "#eee",
    paddingBottom: 5,
  },
  grid: {
    flexDirection: "row",
    flexWrap: "wrap",
    width: 300,
    height: 300,
    backgroundColor: "black",
  },
  cell: { width: 15, height: 15 },
});
