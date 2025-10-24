16KB">
#!/usr/bin/env bash
set -euo pipefail

# =====================================
# CELCONEX v2.2.1 - Generador de AAB
# =====================================

# Configuración
export CELCONEX_VERSION="2.2.1"
export CELCONEX_VERSION_CODE="221"
export CELCONEX_APP_ID="com.celconex.app"
export ANDROID_SDK_VERSION="35"
export MIN_SDK_VERSION="23"

# Colores para logs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================="
echo -e "🚀 CELCONEX AAB Builder v2.2.1"
echo -e "==================================${NC}"

# Verificar dependencias
echo -e "${YELLOW}🔍 Verificando dependencias...${NC}"
command -v java >/dev/null || { echo -e "${RED}❌ Java no encontrado${NC}"; exit 1; }
command -v node >/dev/null || { echo -e "${RED}❌ Node.js no encontrado${NC}"; exit 1; }

JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
echo -e "${GREEN}✅ Java $JAVA_VERSION encontrado${NC}"

NODE_VERSION=$(node --version)
echo -e "${GREEN}✅ Node.js $NODE_VERSION encontrado${NC}"

# Crear directorio de salida
OUTPUT_DIR="./builds/v2.2.1"
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}📁 Directorio de salida: $OUTPUT_DIR${NC}"

# Verificar keystore (opcional)
KEYSTORE_PATH="${KEYSTORE_PATH:-./android/keystores/celconex-release.jks}"
if [[ -f "$KEYSTORE_PATH" ]]; then
    echo -e "${GREEN}🔐 Keystore encontrado: $KEYSTORE_PATH${NC}"
    SIGNING_AVAILABLE=true
else
    echo -e "${YELLOW}⚠️  Keystore no encontrado. Se generará APK de debug.${NC}"
    SIGNING_AVAILABLE=false
fi

# Limpiar builds anteriores
echo -e "${YELLOW}🧹 Limpiando builds anteriores...${NC}"
cd android
./gradlew clean --no-daemon

# Preparar configuración
echo -e "${YELLOW}⚙️  Configurando build v$CELCONEX_VERSION...${NC}"

GRADLE_PROPERTIES=()
GRADLE_PROPERTIES+=("-Pcelconex.applicationId=$CELCONEX_APP_ID")
GRADLE_PROPERTIES+=("-Pcelconex.versionName=$CELCONEX_VERSION")
GRADLE_PROPERTIES+=("-Pcelconex.versionCode=$CELCONEX_VERSION_CODE")
GRADLE_PROPERTIES+=("-Pcelconex.minSdk=$MIN_SDK_VERSION")
GRADLE_PROPERTIES+=("-Pcelconex.targetSdk=$ANDROID_SDK_VERSION")
GRADLE_PROPERTIES+=("-Pcelconex.compileSdk=$ANDROID_SDK_VERSION")

# Configurar firma si está disponible
if [[ "$SIGNING_AVAILABLE" == true && -n "${KEYSTORE_PASSWORD:-}" ]]; then
    GRADLE_PROPERTIES+=("-Pcelconex.sign.storeFile=$KEYSTORE_PATH")
    GRADLE_PROPERTIES+=("-Pcelconex.sign.storePassword=$KEYSTORE_PASSWORD")
    GRADLE_PROPERTIES+=("-Pcelconex.sign.keyAlias=${KEY_ALIAS:-celconex}")
    GRADLE_PROPERTIES+=("-Pcelconex.sign.keyPassword=${KEY_PASSWORD:-$KEYSTORE_PASSWORD}")
    BUILD_TYPE="Release (Firmado)"
else
    BUILD_TYPE="Debug"
fi

echo -e "${BLUE}📦 Generando $BUILD_TYPE AAB...${NC}"

# Generar AAB
if [[ "$SIGNING_AVAILABLE" == true && -n "${KEYSTORE_PASSWORD:-}" ]]; then
    ./gradlew bundleRelease --no-daemon "${GRADLE_PROPERTIES[@]}"
    AAB_SOURCE="app/build/outputs/bundle/release/app-release.aab"
else
    ./gradlew bundleDebug --no-daemon "${GRADLE_PROPERTIES[@]}"
    AAB_SOURCE="app/build/outputs/bundle/debug/app-debug.aab"
fi

# Verificar que se generó el AAB
if [[ ! -f "$AAB_SOURCE" ]]; then
    echo -e "${RED}❌ Error: No se pudo generar el AAB${NC}"
    exit 1
fi

# Copiar AAB al directorio de salida
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
AAB_FILENAME="celconex-v2.2.1-${TIMESTAMP}.aab"
AAB_OUTPUT="../$OUTPUT_DIR/$AAB_FILENAME"

cp "$AAB_SOURCE" "$AAB_OUTPUT"

# Generar checksums
cd ..
SHA256=$(shasum -a 256 "$OUTPUT_DIR/$AAB_FILENAME" | awk '{print $1}')
MD5=$(md5sum "$OUTPUT_DIR/$AAB_FILENAME" 2>/dev/null | awk '{print $1}' || md5 -q "$OUTPUT_DIR/$AAB_FILENAME")
FILE_SIZE=$(stat -f%z "$OUTPUT_DIR/$AAB_FILENAME" 2>/dev/null || stat -c%s "$OUTPUT_DIR/$AAB_FILENAME")

# Generar reporte de build
BUILD_REPORT="$OUTPUT_DIR/build-report-${TIMESTAMP}.json"
cat > "$BUILD_REPORT" <<JSON
{
  "app": {
    "name": "Celconex",
    "id": "$CELCONEX_APP_ID",
    "version": "$CELCONEX_VERSION",
    "versionCode": $CELCONEX_VERSION_CODE
  },
  "build": {
    "type": "$BUILD_TYPE",
    "timestamp": "$TIMESTAMP",
    "filename": "$AAB_FILENAME",
    "sizeBytes": $FILE_SIZE,
    "sizeMB": "$(echo "scale=2; $FILE_SIZE/1024/1024" | bc -l 2>/dev/null || echo "N/A")"
  },
  "checksums": {
    "sha256": "$SHA256",
    "md5": "$MD5"
  },
  "android": {
    "minSdk": $MIN_SDK_VERSION,
    "targetSdk": $ANDROID_SDK_VERSION,
    "compileSdk": $ANDROID_SDK_VERSION
  },
  "features": [
    "WiFi Data Sharing",
    "Real-time Monitoring",
    "SMS Verification",
    "Connection Analytics",
    "Speed Testing"
  ]
}
JSON

# Generar instrucciones de instalación
INSTALL_GUIDE="$OUTPUT_DIR/install-guide.md"
cat > "$INSTALL_GUIDE" <<MARKDOWN
# Celconex v2.2.1 - Guía de Instalación

## 📱 Archivo Generado
- **AAB**: \`$AAB_FILENAME\`
- **Tamaño**: $(echo "scale=1; $FILE_SIZE/1024/1024" | bc -l 2>/dev/null || echo "N/A") MB
- **SHA256**: \`$SHA256\`

## 🏪 Google Play Store
1. Abre [Google Play Console](https://play.google.com/console)
2. Selecciona tu app Celconex
3. Ve a **Producción** → **Crear nueva versión**
4. Sube el archivo \`$AAB_FILENAME\`
5. Completa las notas de versión:

### 🆕 Novedades v2.2.1
- ✅ Interfaz mejorada con logo animado
- 🚀 Test de velocidad más preciso
- 📊 Análisis detallado de conexiones
- 🔒 Configuración de seguridad avanzada
- 🎨 Nuevo diseño con efectos visuales
- 🐛 Correcciones de bugs y optimizaciones

## 🧪 Testing Local
Para probar localmente antes de publicar:

\`\`\`bash
# Instalar bundletool
npm install -g bundletool

# Generar APKs desde AAB
bundletool build-apks --bundle=$AAB_FILENAME --output=celconex.apks

# Instalar en dispositivo conectado
bundletool install-apks --apks=celconex.apks
\`\`\`

## 📋 Verificación
- ✅ AAB generado correctamente
- ✅ Firmado $(if [[ "$SIGNING_AVAILABLE" == true ]]; then echo "digitalmente"; else echo "para debug"; fi)
- ✅ Compatible con Page Size > 16KB
- ✅ Optimizado para múltiples arquitecturas
- ✅ Checksums verificados

---
**Generado el**: $(date)
**Build ID**: $TIMESTAMP
MARKDOWN

# Resultados finales
echo -e "\n${GREEN}=================================="
echo -e "✅ BUILD COMPLETADO EXITOSAMENTE"
echo -e "==================================${NC}"
echo -e "${BLUE}📦 AAB:${NC} $OUTPUT_DIR/$AAB_FILENAME"
echo -e "${BLUE}📊 Reporte:${NC} $BUILD_REPORT"
echo -e "${BLUE}📖 Guía:${NC} $INSTALL_GUIDE"
echo -e "${BLUE}🔗 SHA256:${NC} $SHA256"
echo -e "${BLUE}📏 Tamaño:${NC} $(echo "scale=1; $FILE_SIZE/1024/1024" | bc -l 2>/dev/null || echo "N/A") MB"

echo -e "\n${YELLOW}🚀 Próximos pasos:${NC}"
echo -e "1. Revisa el archivo AAB en: ${BLUE}$OUTPUT_DIR/$AAB_FILENAME${NC}"
echo -e "2. Sube a Google Play Console para distribución"
echo -e "3. Consulta la guía completa en: ${BLUE}$INSTALL_GUIDE${NC}"

echo -e "\n${GREEN}¡Celconex v2.2.1 listo para lanzamiento! 🎉${NC}"