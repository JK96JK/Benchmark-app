#!/bin/bash
#64298ms
# ==============================================================================
# ASETUKSET
# ==============================================================================
PACKAGE="com.example.benchmark_kotlin" # com.example.benchmark_kotlin, com.jortsi.Benchmark_React_native, com.example.benchmark_flutter
FRAMEWORK="Kotlin" #Kotlin, React, Flutter
RUNS_PER_TEST=20

# Painikkeiden koordinaatit puhelimen näytöllä
CPU_X=540
CPU_Y=805

RENDER_X=540
RENDER_Y=1020

MEM_X=540
MEM_Y=1200

CPU_5M_X=540
CPU_5M_Y=1400

# ==============================================================================
# METODEJA TUKEVA APUFUNKTIO
# ==============================================================================
run_test_suite() {
    TEST_NAME=$1
    TAP_X=$2
    TAP_Y=$3
    DURATION_SEC=$4
    OUT_CSV="adb_metrics_${FRAMEWORK}_${TEST_NAME}.csv"

    # Lasketaan näytteiden määrä
    SAMPLES=$(( DURATION_SEC * 2 ))

    echo "timestamp_sec,ram_pss_mb,cpu_pct,jank_pct,p95_frame_ms,run_id,framework,test_name" > "$OUT_CSV"
    echo ""
    echo "======================================================================"
    echo " Aloitetaan testi: $TEST_NAME ($RUNS_PER_TEST ajoa, kesto ${DURATION_SEC}s) -> $OUT_CSV"
    echo "======================================================================"

    # Ajetaan i määrä runeja.
    for (( i=1; i<=$RUNS_PER_TEST; i++ ))
    do
        echo " -> $TEST_NAME | Ajo $i/$RUNS_PER_TEST..."

        PID=$(adb shell pidof "$PACKAGE" | tr -d '\r')
        if [ -z "$PID" ]; then
            echo "VIRHE: Sovellus $PACKAGE ei ole käynnissä puhelimessa!"
            exit 1
        fi

        # Nollataan GPU-renderöintitilastot ennen kutakin ajoa
        adb shell dumpsys gfxinfo "$PACKAGE" reset > /dev/null

        # Painetaan testipainiketta näytöltä
        adb shell input tap "$TAP_X" "$TAP_Y"

        START_TIME=$(date +%s%3N)

        # Otetaan näytteitä annetun keston ajan (0.5s välein)
        for (( sample=1; sample<=$SAMPLES; sample++ ))
        do
            NOW=$(date +%s%3N)
            ELAPSED=$(awk -v n="$NOW" -v s="$START_TIME" 'BEGIN {printf "%.2f", (n - s) / 1000}')

            # Haetaan PSS-muistilukema ja poistetaan \r-rivinvaihto
            RAM_KB=$(adb shell dumpsys meminfo "$PACKAGE" 2>/dev/null | grep -i "TOTAL PSS:" | awk '{print $3}' | tr -d '\r')

            # Jos TOTAL PSS: -riviä ei löydy, käytetään vaihtoehtoista TOTAL-riviä
            if [ -z "$RAM_KB" ] || ! [[ "$RAM_KB" =~ ^[0-9]+$ ]]; then
                RAM_KB=$(adb shell dumpsys meminfo "$PACKAGE" 2>/dev/null | grep -i "TOTAL:" | awk '{print $2}' | tr -d '\r')
            fi

            RAM_MB="0.00"
            if [ -n "$RAM_KB" ] && [ "$RAM_KB" -gt 0 ] 2>/dev/null; then
                RAM_MB=$(awk -v k="$RAM_KB" 'BEGIN {printf "%.2f", k / 1024}')
            fi

            # 2. CPU (%)
            RAW_CPU=$(adb shell "top -b -n 1 -p $PID" 2>/dev/null | tail -n 1 | awk '{print $9}')
            CPU_PCT=$(echo "$RAW_CPU" | tr -d '\r' | sed 's/,/./g')
            CPU_PCT=${CPU_PCT:-0.0}

            echo "$ELAPSED,$RAM_MB,$CPU_PCT,0,0,$i,$FRAMEWORK,$TEST_NAME" >> "$OUT_CSV"
            sleep 0.5
        done

        # 3. GPU / Renderöintitiedot ajon päätteeksi
        GFX_OUT=$(adb shell dumpsys gfxinfo "$PACKAGE")
        JANK_PCT=$(echo "$GFX_OUT" | grep "Janky frames:" | awk -F'(' '{print $2}' | tr -d '%) ')
        P95_TIME=$(echo "$GFX_OUT" | grep "95th percentile:" | awk '{print $3}' | tr -d 'ms')

        JANK_PCT=${JANK_PCT:-0}
        P95_TIME=${P95_TIME:-0}

        # Tallennetaan ajon lopputiivistelmä GPU-mittareilla
        echo "$ELAPSED,0,0,$JANK_PCT,$P95_TIME,$i,$FRAMEWORK,$TEST_NAME" >> "$OUT_CSV"

        # Jäähdytys- ja GC-tauko ennen seuraavaa suoritusta
        sleep 5
    done
}

# ==============================================================================
# SUORITUS: KAIKKI 4 TESTIÄ PERÄKKÄIN
# ==============================================================================
echo "=== ALOITETAAN AUTOMAATTINEN BENCHMARK-AJO ($FRAMEWORK) ==="

# Testi 1: CPU
run_test_suite "CPU" "$CPU_X" "$CPU_Y" 8
#10
# Testi 2: Renderöinti
run_test_suite "Render" "$RENDER_X" "$RENDER_Y" 8

# Testi 3: Muisti
run_test_suite "Memory" "$MEM_X" "$MEM_Y" 10

# Testi 4: CPU (5M)
run_test_suite "CPU_5M" "$CPU_5M_X" "$CPU_5M_Y" 8
#75
echo ""
echo "=== KAIKKI TESTIT SUORITETTU OSTAVALTAVASTI! ==="
echo "Luodut tiedostot:"
ls -l adb_metrics_${FRAMEWORK}_*.csv
