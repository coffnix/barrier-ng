#!/bin/bash

# Detecta se é bash ou zsh e aplica compatibilidade
if [ -n "$ZSH_VERSION" ]; then
    SHELL_NAME="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_NAME="bash"
else
    SHELL_NAME="sh"
fi

B_BUILD_TYPE=Release

cd "$(dirname "$0")" || exit 1

if command -v cmake3 >/dev/null 2>&1; then
    B_CMAKE="cmake3"
else
    B_CMAKE="cmake"
fi

B_BUILD_TYPE=${B_BUILD_TYPE:-Debug}
B_CMAKE_FLAGS="-DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=$B_BUILD_TYPE"

# macOS ajustes
if [ "$(uname)" = "Darwin" ]; then
    # Qt5 detectado via brew
    if [ -d /opt/homebrew/opt/qt@5 ]; then
        export PATH="/opt/homebrew/opt/qt@5/bin:$PATH"
        B_CMAKE_FLAGS="$B_CMAKE_FLAGS -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt@5"
    fi

    # SDK correto
    SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
    B_CMAKE_FLAGS="$B_CMAKE_FLAGS -DCMAKE_OSX_SYSROOT=$SDK_PATH -DCMAKE_OSX_DEPLOYMENT_TARGET=$(xcrun --show-sdk-version)"

    # Usa Clang certo
    export CC=$(xcrun --find clang)
    export CXX=$(xcrun --find clang++)
    
    # Flags seguras
    export CFLAGS="-O2 -pipe -mcpu=apple-m4 -ftree-vectorize -fomit-frame-pointer -moutline-atomics -falign-functions=32 -falign-loops=32"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-L/opt/homebrew/lib -Wl,-O2 -L/opt/homebrew/opt/libffi/lib"
    export CPPFLAGS="-I/opt/homebrew/opt/libffi/include -I/opt/homebrew/opt/libomp/include"
fi

# Configuração local
if [ -r ./build_env.sh ]; then
    case "$SHELL_NAME" in
        bash|zsh) . ./build_env.sh ;;
        *)        source ./build_env.sh ;;
    esac
fi

git submodule update --init --recursive

rm -rf build
mkdir build || exit 1
cd build || exit 1

echo "🛠️  Iniciando build do Barrier ($B_BUILD_TYPE)..."
echo "🧰 Usando CMake: $B_CMAKE"
echo "⚙️  Flags: $B_CMAKE_FLAGS"

$B_CMAKE $B_CMAKE_FLAGS .. || exit 1
make -j"$(sysctl -n hw.logicalcpu)" || exit 1

APP_PATH="./bundle/Barrier.app"
DMG_PATH="./bundle/Barrier-2.4.0-release.dmg"

echo "🔐 Assinando app: $APP_PATH"
codesign --deep --force --verbose --sign - "$APP_PATH" || exit 1

echo "✅ Validando assinatura..."
codesign --verify --deep --strict --verbose=4 "$APP_PATH" || exit 1

echo "🧹 Removendo DMG antigo..."
rm -f "$DMG_PATH"

echo "📦 Gerando DMG novamente..."
make Barrier_MacOS || exit 1

echo "✅ DMG gerado com app assinado"

echo "✅ Build concluído com sucesso."


