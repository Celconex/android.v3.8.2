#!/usr/bin/env bash
set -euo pipefail

# Script para generar keystore de Celconex
echo "🔐 Generador de Keystore para Celconex v2.2.1"
echo "=============================================="

# Configuración
KEYSTORE_DIR="android/keystores"
KEYSTORE_NAME="celconex-release.jks"
KEY_ALIAS="celconex"
VALIDITY_DAYS="10000"  # ~27 años

# Crear directorio si no existe
mkdir -p "$KEYSTORE_DIR"

# Información del certificado
echo "Por favor, ingresa la información para el certificado:"
read -p "Nombre completo: " FULL_NAME
read -p "Organización: " ORGANIZATION
read -p "Departamento: " DEPARTMENT
read -p "Ciudad: " CITY
read -p "Estado/Provincia: " STATE
read -p "Código de país (2 letras): " COUNTRY

# Generar contraseña segura o permitir que el usuario la ingrese
echo "Genera una contraseña segura para el keystore:"
read -s -p "Contraseña del keystore: " KEYSTORE_PASSWORD
echo
read -s -p "Confirma la contraseña: " KEYSTORE_PASSWORD_CONFIRM
echo

if [[ "$KEYSTORE_PASSWORD" != "$KEYSTORE_PASSWORD_CONFIRM" ]]; then
    echo "❌ Las contraseñas no coinciden"
    exit 1
fi

# Generar keystore
echo "🔨 Generando keystore..."
keytool -genkeypair \
    -v \
    -keystore "$KEYSTORE_DIR/$KEYSTORE_NAME" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity "$VALIDITY_DAYS" \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEYSTORE_PASSWORD" \
    -dname "CN=$FULL_NAME, OU=$DEPARTMENT, O=$ORGANIZATION, L=$CITY, ST=$STATE, C=$COUNTRY"

# Generar archivo de configuración
CONFIG_FILE="android/keystore.properties"
cat > "$CONFIG_FILE" <<EOF
# Configuración del keystore para Celconex
# ¡NO SUBIR ESTE ARCHIVO A GIT!
storeFile=$KEYSTORE_DIR/$KEYSTORE_NAME
storePassword=$KEYSTORE_PASSWORD
keyAlias=$KEY_ALIAS
keyPassword=$KEYSTORE_PASSWORD
EOF

# Actualizar .gitignore
echo "
# Keystore y configuración de firma
android/keystores/
android/keystore.properties
*.jks
*.p8
*.p12
" >> .gitignore

echo "✅ Keystore generado exitosamente:"
echo "   📁 Ubicación: $KEYSTORE_DIR/$KEYSTORE_NAME"
echo "   🔑 Alias: $KEY_ALIAS"
echo "   ⚙️  Configuración: $CONFIG_FILE"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - Guarda la contraseña en un lugar seguro"
echo "   - NO subas el keystore ni keystore.properties a Git"
echo "   - Haz una copia de seguridad del keystore"
echo ""
echo "🚀 Ahora puedes ejecutar: ./compilar-aab-v2.2.1.sh"