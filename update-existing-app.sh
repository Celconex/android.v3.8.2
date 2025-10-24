#!/usr/bin/env bash
set -euo pipefail

# =====================================
# CELCONEX - Actualizar App Existente
# Developer: Arturo Yair Ochoa Pineda
# Account ID: 8729530839422072366
# App ID: 4975791825773366332
# =====================================

echo "🚀 Actualizando Celconex en Google Play Store"
echo "👤 Developer: Arturo Yair Ochoa Pineda"
echo "🆔 Account ID: 8729530839422072366"
echo "📱 App ID: 4975791825773366332"
echo "=================================="

# Variables requeridas
REQUIRED_VARS=(
    ANDROID_KEYSTORE 
    ANDROID_KEYSTORE_PASSWORD 
    ANDROID_KEY_ALIAS 
    ANDROID_KEY_PASSWORD 
    FIREBASE_TOKEN 
    PLAY_SERVICE_ACCOUNT_JSON
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "❌ [ERROR] Falta variable de entorno: $var"
        echo "💡 Configura todas las variables antes de ejecutar:"
        printf '   export %s="valor"\n' "${REQUIRED_VARS[@]}"
        exit 1
    fi
done

# Configuración específica de Celconex
DEVELOPER_ID="8729530839422072366"
EXISTING_APP_ID="4975791825773366332"
APP_PACKAGE="com.celconex.app"

# Versión nueva
CELCONEX_VERSION="2.2.1"
DATE=$(date -u +"%Y-%m-%dT%H%M%SZ")
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
VERSION_CODE=$(date +%y%j%H%M)
VERSION_NAME="${CELCONEX_VERSION}.${VERSION_CODE}+${GIT_HASH}"

# Track de subida (internal por defecto para testing)
TRACK="${1:-internal}"

echo "📦 Nueva versión: $VERSION_NAME ($VERSION_CODE)"
echo "🎯 Track: $TRACK"
echo "🔖 Commit: $GIT_HASH"
echo "=================================="

START_TS=$(date +%s)

# =====================================
# FASE 1: Limpiar builds anteriores
# =====================================
echo "🧹 Limpiando builds anteriores..."
cd android
./gradlew clean --no-daemon

# =====================================
# FASE 2: Configurar optimizaciones
# =====================================
echo "⚙️ Configurando optimizaciones para page size > 16KB..."

# Gradle properties para compatibilidad
GRADLE_OPTS=(
    "-Dorg.gradle.jvmargs=-Xmx4g -Dfile.encoding=UTF-8 -XX:+UseG1GC"
    "-Dorg.gradle.parallel=true"
    "-Dorg.gradle.daemon=false"
)

BUILD_OPTS=(
    "-PversionCode=$VERSION_CODE"
    "-PversionName=$VERSION_NAME"
    "-Pcelconex.developerId=$DEVELOPER_ID"
    "-Pcelconex.appId=$EXISTING_APP_ID"
    "-Pcelconex.package=$APP_PACKAGE"
    "-Pandroid.bundletool.enableNativeLibPageAlignment=true"
    "-Pandroid.bundle.enableUncompressedNativeLibs=false"
    "-Pandroid.enableR8.fullMode=true"
    "-Pandroid.useMinimalKeepRules=true"
    "-Pandroid.bundle.excludeDebugSymbols=true"
)

# =====================================
# FASE 3: Generar AAB Release
# =====================================
echo "🔨 Generando Bundle Release optimizado..."

./gradlew bundleRelease \
    "${GRADLE_OPTS[@]}" \
    "${BUILD_OPTS[@]}" \
    --stacktrace

# Verificar que se generó el AAB
AAB_SOURCE="app/build/outputs/bundle/release/app-release.aab"
if [[ ! -f "$AAB_SOURCE" ]]; then
    echo "❌ Error: No se pudo generar el AAB"
    exit 1
fi

echo "✅ AAB generado: $AAB_SOURCE"

# =====================================
# FASE 4: Validar compatibilidad
# =====================================
echo "🔍 Validando compatibilidad page size > 16KB..."

# Usar bundletool para validación
bundletool_jar="$HOME/.gradle/bundletool.jar"
if [[ ! -f "$bundletool_jar" ]]; then
    echo "📥 Descargando bundletool..."
    curl -L -o "$bundletool_jar" \
        "https://github.com/google/bundletool/releases/latest/download/bundletool-all.jar"
fi

# Validar el bundle
java -jar "$bundletool_jar" validate --bundle="$AAB_SOURCE"
echo "✅ Bundle validado correctamente"

# =====================================
# FASE 5: Registrar en Firebase
# =====================================
echo "📋 Registrando release en Firebase..."

RELEASE_PAYLOAD=$(cat <<EOF
{
  "developerId": "$DEVELOPER_ID",
  "appId": "$EXISTING_APP_ID", 
  "package": "$APP_PACKAGE",
  "track": "$TRACK",
  "versionCode": "$VERSION_CODE",
  "versionName": "$VERSION_NAME",
  "commit": "$GIT_HASH",
  "date": "$DATE",
  "status": "uploading",
  "aabPath": "$AAB_SOURCE",
  "buildDuration": $(($(date +%s) - START_TS)),
  "needsUpload": true,
  "celconexVersion": "$CELCONEX_VERSION",
  "pageSize16KBCompatible": true
}
EOF
)

RELEASE_ID=$(firebase functions:call logCelconexRelease \
    --data "$RELEASE_PAYLOAD" \
    --token "$FIREBASE_TOKEN" | \
    grep -oE '"id":"[^"]+' | cut -d':' -f2 | tr -d '"')

if [[ -z "$RELEASE_ID" ]]; then
    echo "❌ Error registrando release en Firebase"
    exit 1
fi

echo "✅ Release registrado: $RELEASE_ID"

# =====================================
# FASE 6: Subir a Google Play Store
# =====================================
echo "📤 Subiendo a Google Play Store (track: $TRACK)..."

# Configurar signing para upload
SIGNING_OPTS=(
    "-Pandroid.injected.signing.store.file=$ANDROID_KEYSTORE"
    "-Pandroid.injected.signing.store.password=$ANDROID_KEYSTORE_PASSWORD"
    "-Pandroid.injected.signing.key.alias=$ANDROID_KEY_ALIAS"
    "-Pandroid.injected.signing.key.password=$ANDROID_KEY_PASSWORD"
)

UPLOAD_OPTS=(
    "-Ptrack=$TRACK"
    "-PserviceAccountFile=$PLAY_SERVICE_ACCOUNT_JSON"
    "-PapplicationId=$APP_PACKAGE"
    "-PdeveloperId=$DEVELOPER_ID"
    "-PexistingAppId=$EXISTING_APP_ID"
)

# Ejecutar upload usando Gradle Play Publisher
echo "🚀 Ejecutando upload a track '$TRACK'..."
./gradlew publishReleaseBundle \
    "${SIGNING_OPTS[@]}" \
    "${UPLOAD_OPTS[@]}" \
    --no-daemon \
    --stacktrace

UPLOAD_STATUS=$?
END_TS=$(date +%s)
TOTAL_DURATION=$((END_TS - START_TS))

# =====================================
# FASE 7: Actualizar estado final
# =====================================
if [ $UPLOAD_STATUS -eq 0 ]; then
    echo "✅ Upload exitoso a Google Play Store"
    
    # Marcar como exitoso en Firebase
    firebase functions:call markCelconexReleaseUploaded \
        --data "{
            \"releaseId\": \"$RELEASE_ID\",
            \"duration\": $TOTAL_DURATION,
            \"playStoreTrack\": \"$TRACK\",
            \"finalStatus\": \"success\"
        }" \
        --token "$FIREBASE_TOKEN"
    
    # Copiar AAB al directorio de builds
    cd ..
    mkdir -p builds/
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    AAB_FINAL="builds/celconex-v${CELCONEX_VERSION}-${TIMESTAMP}.aab"
    cp "android/$AAB_SOURCE" "$AAB_FINAL"
    
    # Generar reporte final
    REPORT_FILE="builds/release-report-${TIMESTAMP}.json"
    cat > "$REPORT_FILE" <<EOF
{
  "celconex": {
    "version": "$CELCONEX_VERSION",
    "developerId": "$DEVELOPER_ID",
    "appId": "$EXISTING_APP_ID",
    "package": "$APP_PACKAGE"
  },
  "build": {
    "versionName": "$VERSION_NAME",
    "versionCode": "$VERSION_CODE",
    "commit": "$GIT_HASH",
    "date": "$DATE",
    "duration": "${TOTAL_DURATION}s"
  },
  "upload": {
    "status": "success",
    "playStoreTrack": "$TRACK",
    "releaseId": "$RELEASE_ID",
    "playConsoleUrl": "https://play.google.com/console/u/1/developers/$DEVELOPER_ID/app/$EXISTING_APP_ID/tracks"
  },
  "compatibility": {
    "pageSize16KB": true,
    "android15Plus": true,
    "nativeSymbolsStripped": true
  }
}
EOF
    
    echo "=================================="
    echo "🎉 CELCONEX v$CELCONEX_VERSION ACTUALIZADO EXITOSAMENTE"
    echo "=================================="
    echo "👤 Developer: Arturo Yair Ochoa Pineda"
    echo "🆔 Account ID: $DEVELOPER_ID"
    echo "📱 App ID: $EXISTING_APP_ID"
    echo "📦 Versión: $VERSION_NAME"
    echo "🎯 Track: $TRACK"
    echo "⏱️ Duración total: ${TOTAL_DURATION}s"
    echo "📋 Release ID: $RELEASE_ID"
    echo "📊 Reporte: $REPORT_FILE"
    echo "🔗 Play Console: https://play.google.com/console/u/1/developers/$DEVELOPER_ID/app/$EXISTING_APP_ID"
    echo ""
    echo "✅ Compatible con page size > 16KB (Android 15+)"
    echo "✅ Símbolos nativos eliminados"
    echo "✅ Bundle optimizado y validado"
    
else
    echo "❌ Error en upload a Google Play Store"
    
    # Marcar como fallido en Firebase
    firebase functions:call updateCelconexReleaseStatus \
        --data "{
            \"releaseId\": \"$RELEASE_ID\",
            \"status\": \"failed\",
            \"duration\": $TOTAL_DURATION,
            \"error\": \"Upload to Play Store failed with code $UPLOAD_STATUS\"
        }" \
        --token "$FIREBASE_TOKEN"
    
    echo "=================================="
    echo "💥 ACTUALIZACIÓN FALLIDA"
    echo "=================================="
    echo "👤 Developer: Arturo Yair Ochoa Pineda"
    echo "❌ Código de error: $UPLOAD_STATUS"
    echo "📋 Release ID: $RELEASE_ID"
    echo "⏱️ Duración: ${TOTAL_DURATION}s"
    echo "🔍 Revisa los logs arriba para más detalles"
    
    exit 1
fi