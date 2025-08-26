# Swift Formatter Migration Guide

## Overview

This project uses a hybrid approach for code quality and formatting:
- **SwiftLint**: Code quality, best practices, and naming conventions
- **swift-format**: Code formatting (when available in Xcode 16+)

## Current Status (Xcode 15.2)

### What We're Using Now
- SwiftLint with quality-focused rules (31 violations → focus on meaningful issues)
- Manual formatting following swift-format configuration preview
- Automated build script that detects available tools

### What's Ready for Xcode 16+
- `.swift-format` configuration file already created
- Build script automatically detects and uses swift-format when available
- SwiftLint configuration updated to avoid conflicts with swift-format

## Migration Timeline

### Phase 1: Preparation (Current - Completed)
- ✅ Created `.swift-format` configuration
- ✅ Updated SwiftLint to focus on code quality only
- ✅ Updated build script for hybrid approach
- ✅ Reduced violations from 120+ to 31 meaningful issues

### Phase 2: Xcode 16+ Upgrade (Future)
When upgrading to Xcode 16+:

1. **Automatic Detection**: Build script will automatically detect swift-format availability
2. **Formatting Handoff**: swift-format will handle:
   - Line length and wrapping
   - Indentation and spacing
   - Import ordering
   - Brace placement
   - Whitespace cleanup

3. **Quality Focus**: SwiftLint will continue handling:
   - Cyclomatic complexity
   - Function length and parameter count
   - Naming conventions
   - Safety and performance patterns
   - Code organization

## Usage Instructions

### Running the Build Script
```bash
./swiftlint-build-script.sh
```

The script automatically:
- Detects Xcode version
- Uses swift-format if available (Xcode 16+)
- Falls back to SwiftLint-only mode for older versions
- Provides clear status and guidance

### Manual Formatting (Xcode 15.2)
Until Xcode 16+, follow these formatting guidelines:
- Line length: 150 characters
- Indentation: 4 spaces
- Lower camelCase for variables and functions
- Upper CamelCase for types
- No semicolons
- Ordered imports

### Code Quality Issues to Address

Current SwiftLint findings (31 total):
- **Complexity**: Functions with high cyclomatic complexity
- **Length**: Long functions or parameter lists  
- **Organization**: File length and structure
- **Performance**: Force unwrapping and type inference
- **Safety**: Implicitly unwrapped optionals

## Configuration Files

### .swiftlint.yml
- Focuses on code quality rules only
- Disables formatting rules that conflict with swift-format
- Customized for project patterns and SwiftUI usage

### .swift-format
- 150 character line length for modern displays
- 4-space indentation
- Enforces Swift naming conventions
- Orders imports alphabetically

## Benefits of Hybrid Approach

### Immediate (Xcode 15.2)
- Reduced noise: 31 meaningful violations vs 120+ mixed issues
- Clear separation of concerns
- Future-ready configuration
- Consistent team standards

### Future (Xcode 16+)
- Automatic formatting on save/build
- Zero formatting violations
- Focus on code quality improvements
- Seamless tool integration
- Reduced development friction

## Team Workflow

### Current Workflow
1. Write code following naming conventions
2. Run `./swiftlint-build-script.sh` before commits
3. Address SwiftLint quality issues
4. Manual formatting cleanup as needed

### Future Workflow (Xcode 16+)
1. Write code (formatting handled automatically)
2. Run build script (swift-format + SwiftLint)
3. Address only code quality issues
4. Commit with confidence

## Troubleshooting

### Common Issues
- **"Command not found: swiftlint"**: Install via `brew install swiftlint`
- **Wrong directory errors**: Run from project root directory
- **Xcode version detection**: Script shows current version and capabilities

### Getting Help
- SwiftLint rules: https://realm.github.io/SwiftLint/rule-directory.html
- swift-format config: https://github.com/apple/swift-format/blob/main/Documentation/Configuration.md

## Summary

This hybrid approach provides:
- ✅ **Immediate value**: Quality-focused linting with 74% fewer violations
- ✅ **Future compatibility**: Ready for automatic formatting in Xcode 16+
- ✅ **Team efficiency**: Clear separation of formatting vs quality concerns
- ✅ **Smooth migration**: Automatic detection and graceful fallback