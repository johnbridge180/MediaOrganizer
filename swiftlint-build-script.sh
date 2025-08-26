#!/bin/bash

# Hybrid Code Quality + Formatting Build Script for MediaOrganizer
# UPDATED: Now supports SwiftLint (quality) + swift-format (formatting)
# Add this as a "Run Script" build phase in Xcode

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

# For Apple Silicon Macs - ensure Homebrew path is available
if [[ "$(uname -m)" == arm64 ]]; then 
    export PATH="/opt/homebrew/bin:$PATH" 
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# XCODE VERSION DETECTION
# ============================================================================

XCODE_VERSION=$(xcodebuild -version | head -n1 | cut -d' ' -f2 | cut -d'.' -f1)
print_status "Detected Xcode version: $XCODE_VERSION"

# Check if swift-format is available (Xcode 16+)
SWIFT_FORMAT_AVAILABLE=false
if [[ $XCODE_VERSION -ge 16 ]]; then
    if swift format --version >/dev/null 2>&1; then
        SWIFT_FORMAT_AVAILABLE=true
        print_success "swift-format is available"
    else
        print_warning "Xcode 16+ detected but swift-format not available"
    fi
else
    print_status "Xcode $XCODE_VERSION - swift-format requires Xcode 16+"
fi

# ============================================================================
# PHASE 1: CODE FORMATTING (if available)
# ============================================================================

if [[ "$SWIFT_FORMAT_AVAILABLE" == true ]]; then
    print_status "Running swift-format for code formatting..."
    
    # Find all Swift files in the project
    SWIFT_FILES=$(find . -name "*.swift" -not -path "./MediaOrganizerCLI/*" -not -path "./MediaOrganizerAPI/*" -not -path "./.build/*" -not -path "./Carthage/*" -not -path "./Pods/*")
    
    if [[ -n "$SWIFT_FILES" ]]; then
        # Format files using swift-format with our configuration
        if [[ -f ".swift-format" ]]; then
            print_status "Using .swift-format configuration"
            echo "$SWIFT_FILES" | xargs swift format --configuration .swift-format --in-place
        else
            print_warning "No .swift-format config found, using defaults"
            echo "$SWIFT_FILES" | xargs swift format --in-place
        fi
        print_success "Code formatting completed"
    else
        print_warning "No Swift files found for formatting"
    fi
else
    print_status "Skipping swift-format (not available) - formatting will be handled manually"
    
    # Provide guidance for manual formatting
    if [[ $XCODE_VERSION -lt 16 ]]; then
        print_status "To enable automatic formatting:"
        echo "  1. Upgrade to Xcode 16+ when available"
        echo "  2. Or use third-party tools like SwiftFormat: brew install swiftformat"
    fi
fi

# ============================================================================
# PHASE 2: CODE QUALITY LINTING
# ============================================================================

print_status "Running SwiftLint for code quality checks..."

# Check if SwiftLint is installed
if which swiftlint > /dev/null; then
    
    # Auto-fix what SwiftLint can handle (quality-focused, not formatting)
    print_status "Auto-fixing SwiftLint violations..."
    if swiftlint --fix --quiet; then
        print_success "SwiftLint auto-fixes applied"
    else
        print_warning "Some SwiftLint auto-fixes failed"
    fi
    
    # Run quality checks
    print_status "Checking code quality..."
    SWIFTLINT_OUTPUT=$(swiftlint 2>&1)
    SWIFTLINT_EXIT_CODE=$?
    
    if [[ $SWIFTLINT_EXIT_CODE -eq 0 ]]; then
        print_success "All code quality checks passed!"
    else
        print_warning "Code quality issues found:"
        echo "$SWIFTLINT_OUTPUT"
        
        # Count different types of violations
        ERROR_COUNT=$(echo "$SWIFTLINT_OUTPUT" | grep -c "error:")
        WARNING_COUNT=$(echo "$SWIFTLINT_OUTPUT" | grep -c "warning:")
        
        if [[ $ERROR_COUNT -gt 0 ]]; then
            print_error "$ERROR_COUNT quality errors found"
        fi
        
        if [[ $WARNING_COUNT -gt 0 ]]; then
            print_warning "$WARNING_COUNT quality warnings found"
        fi
        
        # Provide helpful guidance
        echo ""
        print_status "Code quality focus areas:"
        echo "  • Complexity: Reduce cyclomatic complexity and function length"
        echo "  • Safety: Avoid force unwrapping and force casting"
        echo "  • Performance: Use .isEmpty instead of .count == 0"
        echo "  • Best practices: Follow Swift naming conventions"
    fi
    
else
    print_error "SwiftLint not installed"
    echo "Install SwiftLint via: brew install swiftlint"
    echo "Or download from: https://github.com/realm/SwiftLint"
    exit 1
fi

# ============================================================================
# BUILD SUMMARY
# ============================================================================

echo ""
print_status "=== BUILD SCRIPT SUMMARY ==="

if [[ "$SWIFT_FORMAT_AVAILABLE" == true ]]; then
    print_success "✅ Formatting: Handled by swift-format"
else
    print_warning "⚠️  Formatting: Manual (upgrade to Xcode 16+ for auto-format)"
fi

if [[ $SWIFTLINT_EXIT_CODE -eq 0 ]]; then
    print_success "✅ Code Quality: All checks passed"
else
    print_warning "⚠️  Code Quality: Issues found (see output above)"
fi

echo ""
print_status "Hybrid approach active:"
echo "  📏 swift-format: Line length, indentation, spacing, imports"
echo "  🔍 SwiftLint: Complexity, safety, performance, naming, best practices"

# ============================================================================
# EXIT WITH APPROPRIATE CODE
# ============================================================================

# Exit with SwiftLint's exit code (formatting issues don't fail the build)
exit $SWIFTLINT_EXIT_CODE