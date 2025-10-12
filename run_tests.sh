#!/bin/bash
# Run Unit Tests for Parse SDK iOS/OSX
# This script should be run on macOS with Xcode installed

set -e  # Exit on error

echo "============================================"
echo "Parse SDK iOS/OSX - Unit Test Runner"
echo "============================================"
echo ""

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ Error: This script must be run on macOS"
    echo "Current OS: $(uname)"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode is not installed or xcodebuild is not in PATH"
    exit 1
fi

echo "✅ Running on macOS"
echo "Xcode version:"
xcodebuild -version
echo ""

# Check if submodules are initialized
if [ ! -f "Vendor/xctoolchain/Scripts/xctask/build_task.rb" ]; then
    echo "📦 Initializing submodules..."
    git submodule update --init --recursive
    echo ""
fi

# Check if bundler is installed
if ! command -v bundle &> /dev/null; then
    echo "📦 Installing bundler..."
    gem install bundler -v 2.5.22
    echo ""
fi

# Install Ruby dependencies
if [ ! -f "Gemfile.lock" ] || ! bundle check &> /dev/null; then
    echo "📦 Installing Ruby dependencies..."
    bundle install
    echo ""
fi

echo "============================================"
echo "Running Tests"
echo "============================================"
echo ""

# Array to track test results
declare -a test_results=()

# Function to run a test suite
run_test() {
    local test_name=$1
    local rake_task=$2
    
    echo "----------------------------------------"
    echo "Running: $test_name"
    echo "Command: bundle exec rake $rake_task"
    echo "----------------------------------------"
    
    if bundle exec rake "$rake_task"; then
        echo "✅ PASSED: $test_name"
        test_results+=("✅ PASSED: $test_name")
    else
        echo "❌ FAILED: $test_name"
        test_results+=("❌ FAILED: $test_name")
    fi
    echo ""
}

# Run Core Module Tests
run_test "Core Module - iOS" "test:ios"
run_test "Core Module - macOS" "test:macos"

# Ask if user wants to run LiveQuery tests
echo "Do you want to run LiveQuery tests? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    run_test "LiveQuery - iOS" "test:parse_live_query:ios"
    run_test "LiveQuery - macOS" "test:parse_live_query:osx"
    run_test "LiveQuery - tvOS" "test:parse_live_query:tvos"
    run_test "LiveQuery - watchOS" "test:parse_live_query:watchos"
fi

# Ask if user wants to build starters
echo "Do you want to build starter projects? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    run_test "Build Starters" "build:starters"
fi

# Print summary
echo "============================================"
echo "Test Summary"
echo "============================================"
for result in "${test_results[@]}"; do
    echo "$result"
done
echo ""

# Check if any tests failed
if [[ " ${test_results[@]} " =~ "❌" ]]; then
    echo "❌ Some tests failed"
    exit 1
else
    echo "✅ All tests passed"
    exit 0
fi
