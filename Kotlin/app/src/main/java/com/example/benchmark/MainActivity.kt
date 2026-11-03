package com.example.benchmark

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import kotlin.math.sqrt
import kotlin.random.Random
import kotlin.time.Duration.Companion.milliseconds

data class TestResult(val testName: String, val result: String)

data class BenchmarkItem(
    val id: Int,
    val name: String,
    val timestamp: Long,
    val active: Boolean
)

class MainActivity : ComponentActivity(){
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                BenchmarkScreen()
            }
        }
    }
}
@Composable
fun BenchmarkScreen(){
    val context= LocalContext.current
    val coroutineScope= rememberCoroutineScope()
    var results by remember { mutableStateOf(listOf<TestResult>()) }
    var isRunning by remember { mutableStateOf(false) }
    var statusText by remember { mutableStateOf("Aja testi") }
    var isRenderTestActive by remember { mutableStateOf(false) }
    var colors by remember { mutableStateOf(listOf<Color>()) }
    var renderCount by remember { mutableIntStateOf(0) }

    // Function to get random colors
    fun getRandomColors(amount: Int): List<Color> {
        return List(amount) {
            Color(Random.nextInt(256), Random.nextInt(256), Random.nextInt(256))
        }
    }
    // Function to run CPU test
    fun runCpuTest(){
        isRunning=true
        statusText="Suoritetaan CPU testiä..."
        coroutineScope.launch(Dispatchers.Default){
            kotlinx.coroutines.delay(100.milliseconds)
            val startTime=System.currentTimeMillis()
            var primes=0
            for(i in 2 until 1000000){
                var isPrime=true
                val limit = sqrt(i.toDouble()).toInt()
                for (j in 2..limit) {
                    if (i % j == 0) {
                        isPrime = false
                        break
                    }
                }
                if (isPrime) primes++
            }
            val endTime=System.currentTimeMillis()
            val duration=endTime-startTime
            withContext(Dispatchers.Main) {
                results = results + TestResult("CPU Testi (1M)", "$duration ms")
                isRunning = false
                statusText = "CPU-testi valmis"
            }
        }
    }
    // Function to run Render test
    fun runRenderTest() {
        isRunning = true
        statusText = "Suoritetaan renderöintitestiä..."
        isRenderTestActive = true
        renderCount = 0
        colors = getRandomColors(900)

        coroutineScope.launch {
            val startTime = System.currentTimeMillis()
            while(System.currentTimeMillis() - startTime < 5000) {
                withFrameNanos {
                    renderCount++
                    colors=getRandomColors(900)
                }
            }
            isRenderTestActive = false
            isRunning = false
            results = results + TestResult(
                "Renderöintitesti (5s)",
                "$renderCount renderöintiä 5 sekunnissa"
            )
            statusText = "Renderöintitestaus valmis"
            colors=emptyList()
        }
    }

    //Function to run Memory test
    fun runMemoryTest() {
        isRunning = true
        statusText = "Suoritetaan muistintestausta..."
        coroutineScope.launch(Dispatchers.Default) {
            kotlinx.coroutines.delay(100.milliseconds)
            val startTime = System.currentTimeMillis()
            val recordCount = 1_000_000
            val baseTimestamp = 1_700_000_000_000L
            // 1. Reserve memory and create 1M objects.
            var list: MutableList<BenchmarkItem>? = ArrayList(recordCount)
            for (i in 0 until recordCount) {
                list?.add(
                    BenchmarkItem(
                        id = i,
                        name = "Käyttäjä $i",
                        timestamp = baseTimestamp + i,
                        active = i % 2 == 0
                    )
                )
            }

            // 2. Data handding
            var checksum = 0L
            list?.forEach { item ->
                if (item.active) checksum += item.id
            }

            val endTime = System.currentTimeMillis()
            val duration = endTime - startTime

            // 3. Release memory and garbage collection.
            list?.clear()
            list = null

            withContext(Dispatchers.Main) {
                results = results + TestResult("Muistintestaus (1M oliota)", "$duration ms")
                isRunning = false
                statusText = "Muistintestaus valmis"
            }


        }

    }

    // Function to export results
    fun exportResults(context: Context){
        if(results.isEmpty()){
            Toast.makeText(context,"Ei tuloksia vietäväksi",Toast.LENGTH_SHORT).show()
            return
        }
        try {
            val csvContent=StringBuilder("Testi,Tulos\n")
            results.forEach{r->
                csvContent.append("${r.testName}, ${r.result}\n")
            }
            val file=File(context.cacheDir,"benchmark_results.csv")
            file.writeText(csvContent.toString())
            val uri=FileProvider.getUriForFile(context,"com.example.benchmark.fileprovider",file)
            val intent=Intent(Intent.ACTION_SEND)
            intent.type="text/csv"
            intent.putExtra(Intent.EXTRA_STREAM,uri)
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            context.startActivity(Intent.createChooser(intent,"Vie tulokset"))
        }catch (e:Exception){
            Toast.makeText(context, "Vienti epäonnistui: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    // UI
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFFF5F5F5))
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(20.dp))
        Text(
            text = "Suorituskykytesti",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(20.dp))
        Box(
            modifier = Modifier
                .heightIn(min = 80.dp)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = statusText,
                    fontSize = 16.sp,
                    fontStyle = FontStyle.Italic,
                    color = Color(0xFF555555)
                )
                if (isRunning && !isRenderTestActive) {
                    Spacer(modifier = Modifier.height(10.dp))
                    CircularProgressIndicator(color = Color(0xFF2196F3))
                }
            }
        }
        Spacer(modifier = Modifier.height(20.dp))
        // Render Grid (300x300 dp, 30x30 = 900 squares)
        if (isRenderTestActive) {
            Box(
                modifier = Modifier
                    .size(300.dp)
                    .background(Color.Black)
                    .clipToBounds()
            ) {
                LazyVerticalGrid(
                    columns = GridCells.Fixed(30),
                    modifier = Modifier.fillMaxSize(),
                    userScrollEnabled = false
                ) {
                    items(colors.size) { index ->
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .background(colors[index])
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(20.dp))
        }

            // Buttons
            if (!isRunning) {
                Button(
                    onClick = { runCpuTest() },
                    modifier = Modifier
                        .fillMaxWidth(0.8f)
                        .height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2196F3)),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("1. CPU Testi", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.height(15.dp))

                Button(
                    onClick = { runRenderTest() },
                    modifier = Modifier
                        .fillMaxWidth(0.8f)
                        .height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2196F3)),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("2. Renderöintitesti", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.height(15.dp))

                Button(
                    onClick = { runMemoryTest() },
                    modifier = Modifier
                        .fillMaxWidth(0.8f)
                        .height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2196F3)),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("3. Muistintestaus", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.height(15.dp))

                Button(
                    onClick = { exportResults(context) },
                    modifier = Modifier
                        .fillMaxWidth(0.8f)
                        .height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4CAF50)),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("💾 Vie tulokset (CSV)", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.height(30.dp))
            }
            // Results Section
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.White, shape = RoundedCornerShape(8.dp))
                    .padding(15.dp)
            ) {
                Text(
                    text = "Tulokset:",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(10.dp))
                if (results.isEmpty()) {
                    Text(
                        text = "Ei tuloksia",
                        fontSize = 16.sp,
                        fontStyle = FontStyle.Italic,
                        color = Color(0xFF555555)
                    )
                } else {
                    results.forEach { r ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 5.dp)
                        ) {
                            Text(text = "${r.testName}: ", fontSize = 14.sp)
                            Text(
                                text = r.result,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                        HorizontalDivider(color = Color(0xFFEEEEEE))
                    }
                }
            }
        }
    }

