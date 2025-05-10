#!/bin/sh

# Detecta se é bash ou zsh e aplica compatibilidade
if [ -n "$ZSH_VERSION" ]; then
    SHELL_NAME="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_NAME="bash"
else
    SHELL_NAME="sh"
fi

# Vai para a raiz do script
cd "$(dirname "$0")" || exit 1

# Detectar cmake
if command -v cmake3 >/dev/null 2>&1; then
    B_CMAKE="cmake3"
else
    B_CMAKE="cmake"
fi

# Tipo de build (padrão: Debug)
B_BUILD_TYPE=${B_BUILD_TYPE:-Debug}
B_CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=$B_BUILD_TYPE"

# Ajustes específicos para macOS
if [ "$(uname)" = "Darwin" ]; then
    # Detecta Qt5 do Homebrew
    if [ -d /opt/homebrew/opt/qt@5 ]; then
        export PATH="/opt/homebrew/opt/qt@5/bin:$PATH"
        B_CMAKE_FLAGS="$B_CMAKE_FLAGS -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt@5"
    fi

    # SDK e compatibilidade com Xcode
    SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
    B_CMAKE_FLAGS="$B_CMAKE_FLAGS -DCMAKE_OSX_SYSROOT=$SDK_PATH -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0"
fi

# Incluir configurações locais se existirem
if [ -r ./build_env.sh ]; then
    case "$SHELL_NAME" in
        bash|zsh) . ./build_env.sh ;;
        *)        source ./build_env.sh ;;
    esac
fi

# Garantir submódulos do Git
git submodule update --init --recursive

# Limpa e cria build
rm -rf build
mkdir build || exit 1
cd build || exit 1

echo "🛠️  Iniciando build do Barrier ($B_BUILD_TYPE)..."
echo "🧰 Usando CMake: $B_CMAKE"
echo "⚙️  Flags: $B_CMAKE_FLAGS"

$B_CMAKE $B_CMAKE_FLAGS .. || exit 1
make -j"$(sysctl -n hw.ncpu)" || exit 1

echo "✅ Build concluído com sucesso."
