#!/bin/bash
# Basic code validation for PR 1863
# This script performs static analysis that can be done on Linux

echo "============================================"
echo "Parse SDK - Static Code Validation"
echo "============================================"
echo ""

cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success_count=0
warning_count=0
error_count=0

# Function to print status
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "PASS")
            echo -e "${GREEN}✓${NC} $message"
            ((success_count++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $message"
            ((warning_count++))
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $message"
            ((error_count++))
            ;;
    esac
}

echo "Checking modified file: PFDecoder.m"
echo "----------------------------------------"

# Check if file exists
if [ -f "Parse/Parse/Source/PFDecoder.m" ]; then
    print_status "PASS" "PFDecoder.m exists"
else
    print_status "FAIL" "PFDecoder.m not found"
    exit 1
fi

# Check for basic Objective-C syntax issues
echo ""
echo "Basic Syntax Checks:"
echo "----------------------------------------"

# Check for matching braces
DECODER_FILE="Parse/Parse/Source/PFDecoder.m"

OPEN_BRACES=$(grep -o '{' "$DECODER_FILE" | wc -l)
CLOSE_BRACES=$(grep -o '}' "$DECODER_FILE" | wc -l)

if [ "$OPEN_BRACES" -eq "$CLOSE_BRACES" ]; then
    print_status "PASS" "Matching braces: $OPEN_BRACES opening, $CLOSE_BRACES closing"
else
    print_status "FAIL" "Mismatched braces: $OPEN_BRACES opening, $CLOSE_BRACES closing"
fi

# Check for matching parentheses  
OPEN_PARENS=$(grep -o '(' "$DECODER_FILE" | wc -l)
CLOSE_PARENS=$(grep -o ')' "$DECODER_FILE" | wc -l)

if [ "$OPEN_PARENS" -eq "$CLOSE_PARENS" ]; then
    print_status "PASS" "Matching parentheses: $OPEN_PARENS opening, $CLOSE_PARENS closing"
else
    print_status "FAIL" "Mismatched parentheses: $OPEN_PARENS opening, $CLOSE_PARENS closing"
fi

# Check for matching square brackets
OPEN_BRACKETS=$(grep -o '\[' "$DECODER_FILE" | wc -l)
CLOSE_BRACKETS=$(grep -o '\]' "$DECODER_FILE" | wc -l)

if [ "$OPEN_BRACKETS" -eq "$CLOSE_BRACKETS" ]; then
    print_status "PASS" "Matching square brackets: $OPEN_BRACKETS opening, $CLOSE_BRACKETS closing"
else
    print_status "FAIL" "Mismatched square brackets: $OPEN_BRACKETS opening, $CLOSE_BRACKETS closing"
fi

# Check for the new code addition
echo ""
echo "PR-Specific Changes:"
echo "----------------------------------------"

if grep -q "Inject __type = @\"Object\"" "$DECODER_FILE"; then
    print_status "PASS" "Found PR comment about __type injection"
else
    print_status "FAIL" "PR comment not found"
fi

if grep -q 'mutable\[@"__type"\] = @"Object"' "$DECODER_FILE"; then
    print_status "PASS" "Found __type injection code"
else
    print_status "FAIL" "__type injection code not found"
fi

if grep -q 'pointerKeys = \[NSSet setWithObjects:@"className", @"objectId", @"localId", nil\]' "$DECODER_FILE"; then
    print_status "PASS" "Found pointer keys set initialization"
else
    print_status "FAIL" "Pointer keys set initialization not found"
fi

if grep -q 'dispatch_once(&onceToken' "$DECODER_FILE"; then
    print_status "PASS" "Found dispatch_once for optimization"
else
    print_status "WARN" "dispatch_once optimization might be missing"
fi

# Check test files exist
echo ""
echo "Test File Verification:"
echo "----------------------------------------"

test_files=(
    "Parse/Tests/Unit/DecoderTests.m"
    "Parse/Tests/Unit/ObjectFileCoderTests.m"
    "Parse/Tests/Unit/FieldOperationDecoderTests.m"
)

for test_file in "${test_files[@]}"; do
    if [ -f "$test_file" ]; then
        print_status "PASS" "Found test file: $(basename "$test_file")"
    else
        print_status "WARN" "Test file not found: $(basename "$test_file")"
    fi
done

# Check for potential issues
echo ""
echo "Code Quality Checks:"
echo "----------------------------------------"

# Check for TODO or FIXME comments in the modified section
if grep -n "TODO\|FIXME" "$DECODER_FILE" | grep -q "50\|51\|52\|53\|54\|55\|56\|57\|58\|59\|60\|61\|62\|63\|64\|65\|66\|67\|68\|69\|70\|71"; then
    print_status "WARN" "TODO/FIXME comments found in modified code"
else
    print_status "PASS" "No TODO/FIXME comments in modified code"
fi

# Check for common memory issues (though ARC should handle this)
if grep -n "retain\|release\|autorelease" "$DECODER_FILE" | grep -q "50\|51\|52\|53\|54\|55\|56\|57\|58\|59\|60\|61\|62\|63\|64\|65\|66\|67\|68\|69\|70\|71"; then
    print_status "WARN" "Manual memory management found in modified code (check if ARC is enabled)"
else
    print_status "PASS" "No manual memory management in modified code"
fi

# Check for NSLog (should use proper logging)
if grep -n "NSLog" "$DECODER_FILE" | grep -q "50\|51\|52\|53\|54\|55\|56\|57\|58\|59\|60\|61\|62\|63\|64\|65\|66\|67\|68\|69\|70\|71"; then
    print_status "WARN" "NSLog found in modified code"
else
    print_status "PASS" "No debug logging in modified code"
fi

# Summary
echo ""
echo "============================================"
echo "Validation Summary"
echo "============================================"
echo -e "${GREEN}Passed: $success_count${NC}"
echo -e "${YELLOW}Warnings: $warning_count${NC}"
echo -e "${RED}Failed: $error_count${NC}"
echo ""

if [ $error_count -eq 0 ]; then
    echo -e "${GREEN}✓ Static validation completed successfully${NC}"
    echo ""
    echo "Note: This is basic static analysis only."
    echo "Full compilation and unit tests require macOS with Xcode."
    echo "Run './run_tests.sh' on macOS for complete testing."
    exit 0
else
    echo -e "${RED}✗ Static validation found issues${NC}"
    echo ""
    echo "Please review the errors above."
    echo "Full validation requires macOS with Xcode."
    exit 1
fi
