#!/usr/bin/env bash
set -euo pipefail

# =====================================
# CELCONEX - Deploy Rápido
# Para app existente en Play Store
# =====================================

echo "🚀 Celconex v2.2.1 - Deploy Rápido"
echo "👤 Developer: Arturo Yair Ochoa Pineda"
echo "=================================="

# Validar que tenemos las variables necesarias
if [[ -z "${ANDROID_KEYSTORE:-}" ]]; then
    echo "❌ Configura primero las variables de entorno:"
    echo ""
    echo "export ANDROID_KEYSTORE=\"path/to/keystore.jks\""
    echo "export ANDROID_KEYSTORE_PASSWORD=\"tu_password\""
    echo "export ANDROID_KEY_ALIAS=\"celconex\""  
    echo "export ANDROID_KEY_PASSWORD=\"tu_key_password\""
    echo "export FIREBASE_TOKEN=\"tu_firebase_token\""
    echo "export PLAY_SERVICE_ACCOUNT_JSON=\"path/to/service-account.json\""
    echo ""
    echo "Luego ejecuta: $0 [internal|alpha|beta|production]"
    exit 1
fi

# Track por defecto
TRACK="${1:-internal}"

echo "🎯 Track seleccionado: $TRACK"
echo ""

# Confirmar si es producción
if [[ "$TRACK" == "production" ]]; then
    echo "⚠️ ¿Estás seguro de desplegar a PRODUCCIÓN? (yes/no)"
    read -r confirmation
    if [[ "$confirmation" != "yes" ]]; then
        echo "❌ Despliegue cancelado"
        exit 1
    fi
fi

# Ejecutar el script principal
echo "🔄 Iniciando actualización..."
chmod +x update-existing-app.sh
./update-existing-app.sh "$TRACK"