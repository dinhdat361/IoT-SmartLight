#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <WiFiManager.h>
#include <WebServer.h>
#include <ElegantOTA.h>
#include <Preferences.h>
#include <time.h>

// ==========================================
// CONFIGURATION STORAGE
// ==========================================
Preferences preferences;

struct DeviceConfig {
  String deviceId;
  String deviceType;  // "all_in_one", "relay_only", "rgb_only"
  String backend;     // "mqtt" or "firebase"
  
  // MQTT Config
  String mqttBroker;
  int mqttPort;
  String mqttUser;
  String mqttPass;
  
  // Firebase Config (future implementation)
  String firebaseApiKey;
  String firebaseDatabaseUrl;
  String firebaseAuthToken;
};

DeviceConfig config;

// ==========================================
// HARDWARE GPIO CONFIGURATION
// ==========================================
// 4 Relay Outputs
const int RELAY_LIGHT1 = 32;
const int RELAY_FAN1 = 33;
const int RELAY_LIGHT2 = 14;
const int RELAY_FAN2 = 12;

// RGB LED PWM Pins
const int LED_R_PIN = 25;
const int LED_G_PIN = 26;
const int LED_B_PIN = 27;

// PWM Configuration
const int PWM_FREQ = 5000;
const int PWM_RESOLUTION = 8; // 0-255

// Reset Button
const int TRIGGER_PIN = 0;

// ==========================================
// MQTT CLIENT
// ==========================================
WiFiClientSecure espClient;
PubSubClient mqttClient(espClient);
WebServer server(80);

// Dynamic MQTT Topics (generated based on deviceId)
String topicLight1;
String topicFan1;
String topicLight2;
String topicFan2;
String topicRgb;
String topicStatus;

// Device States
bool light1_state = false;
bool fan1_state = false;
bool light2_state = false;
bool fan2_state = false;
int rgb_r = 0;
int rgb_g = 0;
int rgb_b = 0;

// Device Capabilities (set based on deviceType)
bool hasRelays = false;
bool hasRGB = false;

// ==========================================
// NTP CONFIGURATION
// ==========================================
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 7 * 3600; // GMT+7 Vietnam
const int daylightOffset_sec = 0;

// ==========================================
// CONFIGURATION MANAGEMENT
// ==========================================
void loadConfig() {
  preferences.begin("device-config", false);
  
  config.deviceId = preferences.getString("deviceId", "");
  config.deviceType = preferences.getString("deviceType", "all_in_one");
  config.backend = preferences.getString("backend", "mqtt");
  
  // MQTT Config with defaults
  config.mqttBroker = preferences.getString("mqttBroker", 
    "5b05f6b9b4c24961b29b4d85e8d5af4b.s1.eu.hivemq.cloud");
  config.mqttPort = preferences.getInt("mqttPort", 8883);
  config.mqttUser = preferences.getString("mqttUser", "home123");
  config.mqttPass = preferences.getString("mqttPass", "Chuyenhalong123@");
  
  // Firebase Config
  config.firebaseApiKey = preferences.getString("fbApiKey", "");
  config.firebaseDatabaseUrl = preferences.getString("fbDbUrl", "");
  config.firebaseAuthToken = preferences.getString("fbToken", "");
  
  preferences.end();
  
  // Set device capabilities
  if (config.deviceType == "all_in_one") {
    hasRelays = true;
    hasRGB = true;
  } else if (config.deviceType == "relay_only") {
    hasRelays = true;
    hasRGB = false;
  } else if (config.deviceType == "rgb_only") {
    hasRelays = false;
    hasRGB = true;
  }
  
  // Generate dynamic MQTT topics
  if (!config.deviceId.isEmpty()) {
    // Validate Device ID (must be alphanumeric)
    bool isValid = true;
    for (char c : config.deviceId) {
      if (!isalnum(c) && c != '_' && c != '-') {
        isValid = false;
        break;
      }
    }
    
    if (!isValid) {
      Serial.println("Invalid Device ID detected (garbage?), resetting config...");
      config.deviceId = ""; // Force reset
      preferences.clear();
    } else {
      if (hasRelays) {
        topicLight1 = "home/" + config.deviceId + "/light1/control";
        topicFan1 = "home/" + config.deviceId + "/fan1/control";
        topicLight2 = "home/" + config.deviceId + "/light2/control";
        topicFan2 = "home/" + config.deviceId + "/fan2/control";
      }
      
      if (hasRGB) {
        topicRgb = "home/" + config.deviceId + "/rgb/control";
      }
      
      topicStatus = "home/" + config.deviceId + "/status";
    }
  }
  
  Serial.println("=== Configuration Loaded ===");
  Serial.println("Device ID: " + config.deviceId);
  Serial.println("Device Type: " + config.deviceType);
  // Serial.println("Backend: " + con0.........fig.backend);
  Serial.println("Backend: " + config.backend);
  Serial.println("Has Relays: " + String(hasRelays));
  Serial.println("Has RGB: " + String(hasRGB));
}

void saveConfig() {
  preferences.begin("device-config", false);
  
  preferences.putString("deviceId", config.deviceId);
  preferences.putString("deviceType", config.deviceType);
  preferences.putString("backend", config.backend);
  
  preferences.putString("mqttBroker", config.mqttBroker);
  preferences.putInt("mqttPort", config.mqttPort);
  preferences.putString("mqttUser", config.mqttUser);
  preferences.putString("mqttPass", config.mqttPass);
  
  preferences.putString("fbApiKey", config.firebaseApiKey);
  preferences.putString("fbDbUrl", config.firebaseDatabaseUrl);
  preferences.putString("fbToken", config.firebaseAuthToken);
  
  preferences.end();
  
  Serial.println("Configuration saved to flash");
}

// ==========================================
// WIFI CONFIGURATION PORTAL
// ==========================================
void configWiFiManagerCallbacks(WiFiManager* wm) {
  // Feedback: Turn ON LED when in AP Mode
  wm->setAPCallback([](WiFiManager *myWiFiManager) {
    Serial.println("Entered config mode");
    Serial.println(WiFi.softAPIP());
    digitalWrite(2, HIGH); 
  });

  wm->setSaveConfigCallback([]() {
    Serial.println("Should save config callback triggered");
    digitalWrite(2, LOW);
  });
}

void setupConfigPortal() {
  WiFiManager wifiManager;
  configWiFiManagerCallbacks(&wifiManager);
  
  // Custom HTML header
  const char* customHtml = 
    "<h2>ESP32 Smart Home Configuration</h2>"
    "<p>Configure your device settings below</p>";
  WiFiManagerParameter customHeader(customHtml);
  wifiManager.addParameter(&customHeader);
  
  // Device ID
  WiFiManagerParameter paramDeviceId(
    "deviceId",
    "Device ID (unique, lowercase)",
    config.deviceId.c_str(),
    50,
    "placeholder='living_room_hub'"
  );
  wifiManager.addParameter(&paramDeviceId);
  
  // Device Type (radio buttons would be better, but using text for simplicity)
  WiFiManagerParameter paramDeviceType(
    "deviceType",
    "Device Type (all_in_one/relay_only/rgb_only)",
    config.deviceType.c_str(),
    20
  );
  wifiManager.addParameter(&paramDeviceType);
  
  // Backend selection
  const char* backendHtml = "<br><h3>Backend Configuration</h3>";
  WiFiManagerParameter backendHeader(backendHtml);
  wifiManager.addParameter(&backendHeader);
  
  // ... (rest of parameters) ...
  // Note: To save tokens, I'm abbreviating the parameter re-declarations since they are unchanged.
  // BUT wait, I need to include them to compile. 
  // Let's just include the critical parts and the connection logic.
  
  WiFiManagerParameter paramBackend("backend", "Backend (mqtt/firebase)", config.backend.c_str(), 10);
  wifiManager.addParameter(&paramBackend);
  
  WiFiManagerParameter paramMqttBroker("mqttBroker", "MQTT Broker URL", config.mqttBroker.c_str(), 100);
  wifiManager.addParameter(&paramMqttBroker);
  
  char portStr[10]; itoa(config.mqttPort, portStr, 10);
  WiFiManagerParameter paramMqttPort("mqttPort", "MQTT Port", portStr, 5);
  wifiManager.addParameter(&paramMqttPort);
  
  WiFiManagerParameter paramMqttUser("mqttUser", "MQTT Username", config.mqttUser.c_str(), 50);
  wifiManager.addParameter(&paramMqttUser);
  
  WiFiManagerParameter paramMqttPass("mqttPass", "MQTT Password", config.mqttPass.c_str(), 50, "type='password'");
  wifiManager.addParameter(&paramMqttPass);
  
  WiFiManagerParameter paramFbApiKey("fbApiKey", "Firebase API Key", config.firebaseApiKey.c_str(), 100);
  wifiManager.addParameter(&paramFbApiKey);
  
  WiFiManagerParameter paramFbDbUrl("fbDbUrl", "Firebase Database URL", config.firebaseDatabaseUrl.c_str(), 100);
  wifiManager.addParameter(&paramFbDbUrl);
  
  // Portal settings
  wifiManager.setConfigPortalTimeout(300); // 5 minutes
  
  // Start config portal
  String apName = "ESP32_SmartHome";
  if (!config.deviceId.isEmpty()) {
    apName += "_" + config.deviceId;
  }
  
  Serial.println("Starting config portal: " + apName);
  
  if (wifiManager.autoConnect(apName.c_str(), "12345678")) {
    // Save all parameters
    config.deviceId = paramDeviceId.getValue();
    config.deviceType = paramDeviceType.getValue();
    config.backend = paramBackend.getValue();
    
    config.mqttBroker = paramMqttBroker.getValue();
    config.mqttPort = atoi(paramMqttPort.getValue());
    config.mqttUser = paramMqttUser.getValue();
    config.mqttPass = paramMqttPass.getValue();
    
    config.firebaseApiKey = paramFbApiKey.getValue();
    config.firebaseDatabaseUrl = paramFbDbUrl.getValue();
    
    saveConfig();
    loadConfig(); // Reload to update topics and capabilities
    
    Serial.println("WiFi connected!");
    Serial.println("IP address: " + WiFi.localIP().toString());
    
    // Turn off LED after successful connection
    digitalWrite(2, LOW);
  } else {
    Serial.println("Failed to connect, restarting...");
    delay(3000);
    ESP.restart();
  }
}


// ==========================================
// HARDWARE CONTROL FUNCTIONS
// ==========================================
void setRGBColor(int r, int g, int b) {
  if (!hasRGB) return;

  r = constrain(r, 0, 255);
  g = constrain(g, 0, 255);
  b = constrain(b, 0, 255);

  ledcWrite(0, r);
  ledcWrite(1, g);
  ledcWrite(2, b);

  rgb_r = r;
  rgb_g = g;
  rgb_b = b;

  Serial.printf("RGB set to: (%d, %d, %d)\n", r, g, b);
}


void setRelay(int pin, bool state, const char* name) {
  if (!hasRelays) return;
  
  digitalWrite(pin, state ? HIGH : LOW);
  Serial.printf("%s: %s\n", name, state ? "ON" : "OFF");
}

// ==========================================
// MQTT FUNCTIONS
// ==========================================
void publishStatus(); // Forward declaration

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.println("MQTT received [" + String(topic) + "]: " + message);
  
  // Parse JSON
  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.println("JSON parse error: " + String(error.c_str()));
    return;
  }
  
  // Handle topics
  String topicStr = String(topic);
  
  if (hasRelays) {
    if (topicStr == topicLight1) {
      String state = doc["state"] | "off";
      light1_state = (state == "on");
      setRelay(RELAY_LIGHT1, light1_state, "Light1");
    }
    else if (topicStr == topicFan1) {
      String state = doc["state"] | "off";
      fan1_state = (state == "on");
      setRelay(RELAY_FAN1, fan1_state, "Fan1");
    }
    else if (topicStr == topicLight2) {
      String state = doc["state"] | "off";
      light2_state = (state == "on");
      setRelay(RELAY_LIGHT2, light2_state, "Light2");
    }
    else if (topicStr == topicFan2) {
      String state = doc["state"] | "off";
      fan2_state = (state == "on");
      setRelay(RELAY_FAN2, fan2_state, "Fan2");
    }
  }
  
  if (hasRGB && topicStr == topicRgb) {
    int r = doc["r"] | 0;
    int g = doc["g"] | 0;
    int b = doc["b"] | 0;
    setRGBColor(r, g, b);
  }
}

void publishStatus() {
  if (!mqttClient.connected()) return;
  
  StaticJsonDocument<400> doc;
  
  doc["deviceId"] = config.deviceId;
  doc["deviceType"] = config.deviceType;
  doc["backend"] = config.backend;
  doc["uptime"] = millis() / 1000;
  
  if (hasRelays) {
    doc["light1"] = light1_state ? "on" : "off";
    doc["fan1"] = fan1_state ? "on" : "off";
    doc["light2"] = light2_state ? "on" : "off";
    doc["fan2"] = fan2_state ? "on" : "off";
  }
  
  if (hasRGB) {
    JsonObject rgb = doc.createNestedObject("rgb");
    rgb["r"] = rgb_r;
    rgb["g"] = rgb_g;
    rgb["b"] = rgb_b;
  }
  
  char buffer[400];
  serializeJson(doc, buffer);
  
  mqttClient.publish(topicStatus.c_str(), buffer);
  Serial.println("Status published: " + String(buffer));
}

void mqttReconnect() {
  while (!mqttClient.connected()) {
    Serial.print("Connecting to MQTT...");
    
    String clientId = "ESP32_" + config.deviceId + "_" + String(random(0xffff), HEX);
    
    if (mqttClient.connect(clientId.c_str(), 
                           config.mqttUser.c_str(), 
                           config.mqttPass.c_str())) {
      Serial.println("Connected!");
      
      // Subscribe to topics
      if (hasRelays) {
        mqttClient.subscribe(topicLight1.c_str());
        mqttClient.subscribe(topicFan1.c_str());
        mqttClient.subscribe(topicLight2.c_str());
        mqttClient.subscribe(topicFan2.c_str());
        Serial.println("Subscribed to relay topics");
      }
      
      if (hasRGB) {
        mqttClient.subscribe(topicRgb.c_str());
        Serial.println("Subscribed to RGB topic");
      }
      
      publishStatus();
    } else {
      Serial.println("Failed, rc=" + String(mqttClient.state()));
      Serial.println("Retrying in 5 seconds...");
      delay(5000);
    }
  }
}

void setupMQTT() {
  espClient.setInsecure(); // For HiveMQ Cloud SSL
  mqttClient.setServer(config.mqttBroker.c_str(), config.mqttPort);
  mqttClient.setCallback(mqttCallback);
  Serial.println("MQTT client initialized");
}

// ==========================================
// WEB SERVER
// ==========================================
void setupWebServer() {
  server.on("/", HTTP_GET, []() {
    String html = "<!DOCTYPE html><html><head>";
    html += "<meta name='viewport' content='width=device-width, initial-scale=1'>";
    html += "<style>";
    html += "body { font-family: Arial; margin: 20px; }";
    html += "h1 { color: #333; }";
    html += ".info { background: #f0f0f0; padding: 10px; margin: 10px 0; border-radius: 5px; }";
    html += ".status { display: inline-block; padding: 5px 10px; border-radius: 3px; }";
    html += ".on { background: #4CAF50; color: white; }";
    html += ".off { background: #f44336; color: white; }";
    html += "</style></head><body>";
    
    html += "<h1>ESP32 Smart Home</h1>";
    
    html += "<div class='info'>";
    html += "<h2>Device Info</h2>";
    html += "<p><b>Device ID:</b> " + config.deviceId + "</p>";
    html += "<p><b>Type:</b> " + config.deviceType + "</p>";
    html += "<p><b>Backend:</b> " + config.backend + "</p>";
    html += "<p><b>IP:</b> " + WiFi.localIP().toString() + "</p>";
    html += "<p><b>Uptime:</b> " + String(millis() / 1000) + "s</p>";
    html += "</div>";
    
    if (hasRelays) {
      html += "<div class='info'>";
      html += "<h2>Relays</h2>";
      html += "<p>Light1: <span class='status " + String(light1_state ? "on" : "off") + "'>" + String(light1_state ? "ON" : "OFF") + "</span></p>";
      html += "<p>Fan1: <span class='status " + String(fan1_state ? "on" : "off") + "'>" + String(fan1_state ? "ON" : "OFF") + "</span></p>";
      html += "<p>Light2: <span class='status " + String(light2_state ? "on" : "off") + "'>" + String(light2_state ? "ON" : "OFF") + "</span></p>";
      html += "<p>Fan2: <span class='status " + String(fan2_state ? "on" : "off") + "'>" + String(fan2_state ? "ON" : "OFF") + "</span></p>";
      html += "</div>";
    }
    
    if (hasRGB) {
      html += "<div class='info'>";
      html += "<h2>RGB LED</h2>";
      html += "<p>Color: RGB(" + String(rgb_r) + ", " + String(rgb_g) + ", " + String(rgb_b) + ")</p>";
      html += "<div style='width: 100px; height: 50px; background: rgb(" + String(rgb_r) + "," + String(rgb_g) + "," + String(rgb_b) + "); border: 1px solid #ccc;'></div>";
      html += "</div>";
    }
    
    html += "<div class='info'>";
    html += "<p><a href='/update'>OTA Update</a></p>";
    html += "</div>";
    
    html += "</body></html>";
    server.send(200, "text/html", html);
  });
  
  ElegantOTA.begin(&server);
  server.begin();
  Serial.println("Web server started");
}

// ==========================================
// RESET BUTTON CHECK
// ==========================================
void checkResetButton() {
  if (digitalRead(TRIGGER_PIN) == LOW) {
    Serial.println("BOOT button pressed, waiting 3s...");
    delay(3000);
    
    if (digitalRead(TRIGGER_PIN) == LOW) {
      Serial.println("Resetting WiFi and configuration...");
      
      WiFiManager wifiManager;
      wifiManager.resetSettings();
      
      preferences.begin("device-config", false);
      preferences.clear();
      preferences.end();
      
      Serial.println("Reset complete, restarting...");
      delay(1000);
      ESP.restart();
    }
  }
}


// ==========================================
// SETUP
// ==========================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n\n=== ESP32 Smart Home v4 ===");
  
  // Initialize LED pin explicitly
  pinMode(2, OUTPUT);
  digitalWrite(2, LOW); // Start OFF
  
  // Check reset button
  pinMode(TRIGGER_PIN, INPUT_PULLUP);
  checkResetButton();
  
  // Load configuration
  loadConfig();
  
  // First time setup or reconfiguration needed
  if (config.deviceId.isEmpty()) {
    Serial.println("No configuration found, starting setup portal...");
    setupConfigPortal();
  }
  
  // Initialize hardware based on capabilities
  if (hasRelays) {
    pinMode(RELAY_LIGHT1, OUTPUT);
    pinMode(RELAY_FAN1, OUTPUT);
    pinMode(RELAY_LIGHT2, OUTPUT);
    pinMode(RELAY_FAN2, OUTPUT);
    
    digitalWrite(RELAY_LIGHT1, LOW);
    digitalWrite(RELAY_FAN1, LOW);
    digitalWrite(RELAY_LIGHT2, LOW);
    digitalWrite(RELAY_FAN2, LOW);
    
    Serial.println("Relays initialized");
  }
  
  if (hasRGB) {
      // Setup 3 PWM channels
      ledcSetup(0, PWM_FREQ, PWM_RESOLUTION);
      ledcSetup(1, PWM_FREQ, PWM_RESOLUTION);
      ledcSetup(2, PWM_FREQ, PWM_RESOLUTION);

      // Attach pins
      ledcAttachPin(LED_R_PIN, 0);
      ledcAttachPin(LED_G_PIN, 1);
      ledcAttachPin(LED_B_PIN, 2);

      setRGBColor(0, 0, 0);

      Serial.println("RGB LED initialized");
  }

  
  // Connect to WiFi if not connected
  if (WiFi.status() != WL_CONNECTED) {
    WiFiManager wifiManager;
    configWiFiManagerCallbacks(&wifiManager); // Attach LED callbacks here too!
    
    String apName = "ESP32_SmartHome_" + config.deviceId;
    // Set a shorter timeout for this auto-reconnect attempt
    wifiManager.setConfigPortalTimeout(180); 
    
    if (!wifiManager.autoConnect(apName.c_str())) {
      Serial.println("Failed to connect, restarting...");
      delay(3000);
      ESP.restart();
    }
  }
  
  Serial.println("WiFi connected: " + WiFi.localIP().toString());
  
  // Initialize NTP
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  Serial.println("NTP time configured");
  
  // Initialize backend
  if (config.backend == "mqtt") {
    setupMQTT();
  } else if (config.backend == "firebase") {
    // TODO: Implement Firebase Realtime DB
    Serial.println("Firebase backend not yet implemented, falling back to MQTT");
    config.backend = "mqtt";
    setupMQTT();
  }
  
  // Setup web server
  setupWebServer();
  
  Serial.println("=== Setup Complete ===");
  Serial.println("Device ID: " + config.deviceId);
  Serial.println("Backend: " + config.backend);
  Serial.println("Web Dashboard: http://" + WiFi.localIP().toString());
}

// ==========================================
// LOOP
// ==========================================
unsigned long lastStatusPublish = 0;
const unsigned long STATUS_INTERVAL = 30000; // 30 seconds

void loop() {
  // Check for Serial commands
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd == "reset") {
      Serial.println("Command received: RESET");
      Serial.println("Clearing WiFi and Preferences...");
      WiFiManager wm;
      wm.resetSettings();
      preferences.begin("device-config", false);
      preferences.clear();
      preferences.end();
      Serial.println("Done. Restarting...");
      delay(1000);
      ESP.restart();
    }
  }

  // Handle backend
  if (config.backend == "mqtt") {
    if (!mqttClient.connected()) {
      mqttReconnect();
    }
    mqttClient.loop();
    
    // Publish status periodically
    unsigned long now = millis();
    if (now - lastStatusPublish > STATUS_INTERVAL) {
      publishStatus();
      lastStatusPublish = now;
    }
  }
  // TODO: Handle Firebase backend
  
  // Web server
  server.handleClient();
}




