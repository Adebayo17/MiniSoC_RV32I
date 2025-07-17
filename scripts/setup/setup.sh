#!/bin/bash

# script/setup.sh - Toolchain Setup Validator
# 🔍 ❌ ✅ 🔁 📚 ⚠️ 📦

REQUIRED_TOOLS=(
    iverilog
    vvp
    gtkwave
    yosys
    riscv64-unknown-elf-gcc
    riscv64-unknown-elf-objcopy
)

APT_PACKAGES=(
    iverilog
    gtkwave
    yosys
    build-essential
    gcc-riscv64-unknown-elf
    binutils-riscv64-unknown-elf
)

echo "🔍 Checking required toolchain components..."
MISSING_TOOLS=()
ALL_OK=true

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "❌ $tool not found"
        MISSING_TOOLS+=("$tool")
        ALL_OK=false
    else
        echo "✅ $tool found: $(command -v $tool)"
    fi
done

# If everything is okay
if [ "$ALL_OK" == true ]; then
    echo ""
    echo "✅ All required tools are installed."
    echo ""
    exit 0
fi

# If missing tools
echo ""
echo "⚠️ The following tools are missing: "
for tool in "${MISSING_TOOLS[@]}"; do
    echo "      - $tool "
done

# Ask user to install
read -p "Would you like to install the missing tools now using apt? [Y/n] " confirm
confirm=${confirm,,}  # to lowercase
confirm=${confirm:-y} # default to yes


if [[ "$confirm" == "y" || "$confirm" == "yes"  ]]; then
    echo ""
    echo "📦 Installing required packages via apt..."
    sudo apt update
    sudo apt install -y "${APT_PACKAGES[@]}"

    echo ""
    echo "🔁 Rechecking tools after installation..."
    echo ""
    exec "$0"   # re-run the script
else
    echo ""
    echo "❌ Installation skipped. Please install the missing tools manually:"
    echo "      sudo apt update "
    echo "      sudo apt install ${APT_PACKAGES[*]}"
    echo ""
    exit 1
fi

