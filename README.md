# Traduora Localization Script

A Swift script to automatically download and update localization files from [Traduora](https://traduora.co) translation management platform.

## Overview

This script automates the process of downloading localization files from [Traduora](https://traduora.co) and updating your iOS project's `.strings` files. It supports multiple locales and handles authentication automatically.

## Features

- 🔐 **Automatic Authentication**: Handles OAuth2 authentication with Traduora
- 🌐 **Multiple Locales**: Downloads localization files for specified target locales
- 📁 **Directory Management**: Automatically creates `.lproj` directories
- ⚙️ **Environment Configuration**: Uses `.env` file for secure credential management
- 📊 **Progress Tracking**: Provides detailed console output during execution
- 🛡️ **Error Handling**: Comprehensive error handling with informative messages
- 📝 **Flexible Format**: Configurable export format (strings, json, etc.)

## Requirements

- macOS with Swift 5.0+
- Xcode (for iOS development)
- Traduora instance with API access
- Valid Traduora user credentials

## Script Workflow

1. **Environment Check**: Verifies `.env` file exists
2. **Configuration Loading**: Parses environment variables
3. **Authentication**: Obtains OAuth2 access token from Traduora
4. **Locale Discovery**: Fetches available locales from the project
5. **Filtering**: Matches target locales with available locales
6. **Download**: Downloads `.strings` files for each locale
7. **Processing**: Processes downloaded strings
8. **File Management**: Creates directories and saves files

## Output Structure

The script creates the following directory structure:

```
/path/to/localization/
├── en.lproj/
│   └── Localizable.strings
├── es.lproj/
│   └── Localizable.strings
├── fr.lproj/
│   └── Localizable.strings
└── de.lproj/
    └── Localizable.strings
```

## Security Considerations

- **Never commit `.env` files** to version control
- Add `.env` to your `.gitignore` file
- Regularly rotate Traduora credentials

## About Traduora

[Traduora](https://traduora.co) is a modern translation management platform that helps teams manage their localization workflow efficiently. 

- **Website**: https://traduora.co
- **GitHub Repository**: https://github.com/ever-co/ever-traduora
- **Documentation**: https://docs.traduora.co

## License

This project is licensed under the MIT License.
