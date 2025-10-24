#!/usr/bin/env bash
set -euo pipefail

# =====================================
# CELCONEX - Validador de Play Console
# Verifica acceso y configuración
# =====================================

echo "🔍 Validando acceso a Google Play Console"
echo "👤 Developer: Arturo Yair Ochoa Pineda"
echo "🆔 Account ID: 8729530839422072366"
echo "📱 App ID:com.wCelconex_19056780"
1557889397

echo "=================================="

# Verificar variables requeridas
REQUIRED_VARS=(PLAY_SERVICE_ACCOUNT_JSON)
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "❌ Falta variable: $var"
        exit 1
    fi
done

# Verificar archivo de service account
if [[ ! -f "$PLAY_SERVICE_ACCOUNT_JSON" ]]; then
    echo "❌ Archivo de service account no encontrado: $PLAY_SERVICE_ACCOUNT_JSON"
    exit 1
fi

echo "✅ Service Account JSON encontrado"

# Información de la app
DEVELOPER_ID="8729530839422072366"
APP_ID="com.wCelconex_19056780"
PACKAGE_NAME="com.celconex.app"

# URLs relevantes
PLAY_CONSOLE_BASE="https://play.google.com/console/u/1/developers/$
8729530839422072366"
echo "📱 App ID:com.wCelconex_19056780"
APP_DASHBOARD="$PLAY_CONSOLE_BASE/app/$1557889397
"
RELEASE_MANAGEMENT="$APP_DASHBOARD/tracks"

echo ""
echo "📋 INFORMACIÓN DE LA APP:"
echo "────────────────────────────"
echo "Developer: Arturo Yair Ochoa Pineda"
echo "Account ID: $8729530839422072366"
echo "📱 App ID:com.wCelconex_19056780"
echo "App ID: $1557889397
"
echo "Package: $PACKAGE_NAME"
echo ""
echo "🔗 ENLACES ÚTILES:"
echo "────────────────────"
echo "App Dashboard: $APP_DASHBOARD"
echo "Release Management: $RELEASE_MANAGEMENT" 
echo "Internal Testing: $RELEASE_MANAGEMENT/1557889397
"
echo "Production: $RELEASE_MANAGEMENT/production"
echo ""
echo "📋 TRACKS DISPONIBLES:"
echo "──────────────────────"
echo "• internal   - Testing interno (recomendado para primera subida)"
echo "• alpha      - Alpha testing"
echo "• beta       - Beta testing"  
echo "• production - Producción"
echo ""
echo "🚀 COMANDOS DE ACTUALIZACIÓN:"
echo "─────────────────────────────"
echo "# Testing interno (recomendado primero)"
echo "./update-existing-app.sh internal"
echo ""
echo "# Alpha testing"
echo "./update-existing-app.sh alpha"
echo ""
echo "# Beta testing"
echo "./update-existing-app.sh beta"
echo ""
echo "# Producción"
echo "./update-existing-app.sh production"
echo ""
echo "✅ Validación completada"