#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Uso: ./scripts/release-android.sh VERSION"
    echo "Ejemplo: ./scripts/release-android.sh 1.0.1"
    exit 2
fi

VERSION="$1"
TAG="v${VERSION}"
CMAKE_FILE="$ROOT_DIR/CMakeLists.txt"
BUILD_DIR="$ROOT_DIR/build/android-release"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$(find "$ANDROID_SDK_ROOT/ndk" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)}"
QT_ROOT="${DAWN_QT_ROOT:-$HOME/Qt/6.8.3}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
QT_CMAKE="$QT_ROOT/android_arm64_v8a/bin/qt-cmake"
HOST_QT="$QT_ROOT/gcc_64"
RELEASE_APK="$BUILD_DIR/android-build/build/outputs/apk/release/android-build-release.apk"
PUBLISHED_APK="$ROOT_DIR/android/Dawn-Studio-Android-arm64-v8a.apk"

fail() { echo "Error: $*" >&2; exit 1; }

[[ -x "$QT_CMAKE" ]] || fail "No encuentro Qt Android 6.8.3 en $QT_ROOT. Define DAWN_QT_ROOT."
[[ -d "$HOST_QT" ]] || fail "No encuentro el Qt de escritorio para herramientas host: $HOST_QT"
[[ -d "$ANDROID_SDK_ROOT" ]] || fail "No encuentro Android SDK: $ANDROID_SDK_ROOT"
[[ -d "$ANDROID_NDK_ROOT" ]] || fail "No encuentro Android NDK. Define ANDROID_NDK_ROOT."
[[ -x "$JAVA_HOME/bin/java" ]] || fail "Se requiere JDK 17; revisa JAVA_HOME."
command -v gh >/dev/null || fail "Instala GitHub CLI (gh) para publicar el Release."
command -v ninja >/dev/null || fail "Instala Ninja para compilar Qt Android."
command -v python3 >/dev/null || fail "Se requiere Python 3 para validar versiones."
gh auth status >/dev/null 2>&1 || fail "Inicia sesión una vez con: gh auth login"

CURRENT_VERSION="$(sed -nE 's/^project\(dawn-studio VERSION ([0-9]+\.[0-9]+\.[0-9]+) LANGUAGES CXX\)$/\1/p' "$CMAKE_FILE")"
[[ -n "$CURRENT_VERSION" ]] || fail "No pude leer VERSION en project() de CMakeLists.txt."
python3 - "$CURRENT_VERSION" "$VERSION" <<'PY'
import sys
current = tuple(map(int, sys.argv[1].split(".")))
requested = tuple(map(int, sys.argv[2].split(".")))
if any(part > 999 for part in requested):
    raise SystemExit("Cada parte de la versión debe ser menor o igual a 999.")
if requested < current:
    raise SystemExit(f"La versión {sys.argv[2]} es anterior a la actual {sys.argv[1]}.")
PY

if gh release view "$TAG" >/dev/null 2>&1; then
    fail "El Release $TAG ya existe. Elige una versión nueva."
fi

BRANCH="$(git branch --show-current)"
[[ -n "$BRANCH" ]] || fail "No hay una rama Git seleccionada."
UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
[[ -n "$UPSTREAM" ]] || fail "La rama $BRANCH no tiene upstream. Súbela a GitHub primero."
[[ -z "$(git status --porcelain)" ]] || fail "Hay cambios locales. Guarda y sube el trabajo antes de publicar."
git fetch origin --tags
read -r REMOTE_AHEAD LOCAL_AHEAD < <(git rev-list --left-right --count "$UPSTREAM...HEAD")
[[ "$REMOTE_AHEAD" == 0 && "$LOCAL_AHEAD" == 0 ]] || fail "La rama local no coincide con GitHub; sincronízala antes de publicar."
git var GIT_AUTHOR_IDENT >/dev/null 2>&1 || fail "Configura git user.name y user.email antes de publicar."

QT_ANDROID_KEYSTORE_PATH="${QT_ANDROID_KEYSTORE_PATH:-${DAWN_ANDROID_KEYSTORE_PATH:-$HOME/.local/share/dawn-studio/release-upload.jks}}"
QT_ANDROID_KEYSTORE_ALIAS="${QT_ANDROID_KEYSTORE_ALIAS:-${DAWN_ANDROID_KEY_ALIAS:-dawnstudio}}"
[[ -f "$QT_ANDROID_KEYSTORE_PATH" ]] || fail "Falta la llave de firma: $QT_ANDROID_KEYSTORE_PATH. Créala y conserva una copia segura fuera del equipo."
if [[ -z "${QT_ANDROID_KEYSTORE_STORE_PASS:-}" ]]; then
    read -r -s -p "Contraseña del keystore: " QT_ANDROID_KEYSTORE_STORE_PASS; echo
fi
if [[ -z "${QT_ANDROID_KEYSTORE_KEY_PASS:-}" ]]; then
    read -r -s -p "Contraseña de la llave (alias $QT_ANDROID_KEYSTORE_ALIAS): " QT_ANDROID_KEYSTORE_KEY_PASS; echo
fi
[[ -n "$QT_ANDROID_KEYSTORE_STORE_PASS" && -n "$QT_ANDROID_KEYSTORE_KEY_PASS" ]] || fail "Las contraseñas de firma no pueden estar vacías."
export QT_ANDROID_KEYSTORE_PATH QT_ANDROID_KEYSTORE_ALIAS
export QT_ANDROID_KEYSTORE_STORE_PASS QT_ANDROID_KEYSTORE_KEY_PASS

VERSION_COMMITTED=0
VERSION_CHANGED=0
restore_uncommitted_version() {
    if [[ "$VERSION_COMMITTED" == 0 && "$VERSION_CHANGED" == 1 ]]; then
        git restore --source=HEAD -- "$CMAKE_FILE"
        echo "Se restauró CMakeLists.txt desde Git." >&2
    fi
}
trap restore_uncommitted_version ERR
trap 'restore_uncommitted_version; exit 130' INT
trap 'restore_uncommitted_version; exit 143' TERM

if [[ "$VERSION" != "$CURRENT_VERSION" ]]; then
    VERSION_CHANGED=1
    python3 - "$CMAKE_FILE" "$VERSION" <<'PY'
from pathlib import Path
import re, sys
path = Path(sys.argv[1])
text = path.read_text()
updated, count = re.subn(
    r"(?m)^project\(dawn-studio VERSION [0-9]+\.[0-9]+\.[0-9]+ LANGUAGES CXX\)$",
    f"project(dawn-studio VERSION {sys.argv[2]} LANGUAGES CXX)", text, count=1)
if count != 1:
    raise SystemExit("No pude actualizar la versión del proyecto.")
path.write_text(updated)
PY
fi

export JAVA_HOME
export ANDROID_SDK_ROOT ANDROID_NDK_ROOT
export PATH="$JAVA_HOME/bin:$PATH"
"$QT_CMAKE" -S "$ROOT_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" \
    -DANDROID_NDK_ROOT="$ANDROID_NDK_ROOT" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-28 \
    -DQT_HOST_PATH="$HOST_QT" \
    -DQT_ANDROID_SIGN_APK:BOOL=ON
cmake --build "$BUILD_DIR" --parallel "$(nproc)"

[[ -f "$RELEASE_APK" ]] || fail "Qt no generó el APK Release esperado: $RELEASE_APK"
APKSIGNER="$(find "$ANDROID_SDK_ROOT/build-tools" -mindepth 2 -maxdepth 2 -type f -name apksigner | sort -V | tail -n 1)"
[[ -x "$APKSIGNER" ]] || fail "No encuentro apksigner en Android SDK Build Tools."
"$APKSIGNER" verify --verbose "$RELEASE_APK"

if [[ "$VERSION" != "$CURRENT_VERSION" ]]; then
    git add CMakeLists.txt
    git commit -m "Release $TAG"
    VERSION_COMMITTED=1
    git push origin "$BRANCH"
fi

mkdir -p "$(dirname "$PUBLISHED_APK")"
cp -p "$RELEASE_APK" "$PUBLISHED_APK"

gh release create "$TAG" "$PUBLISHED_APK" \
    --title "Dawn Studio $TAG" \
    --target "$BRANCH" \
    --generate-notes

echo "Release publicado: https://github.com/thelandy03-boop/Dawn-Creator-/releases/tag/$TAG"
echo "APK firmado: $PUBLISHED_APK"
