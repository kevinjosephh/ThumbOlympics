# ThumbOlympics

Compete in the ultimate thumb Olympics! Track your scroll distance and compare it to real-world landmarks. Turn doom scrolling into a playful competition!

**Version:** 1.0.0  
**Status:** Production Ready ✅

## Features

- **Scroll Distance Tracking**: Measures how far you've scrolled in real-world distances
- **Playful Comparisons**: See how your scrolling compares to famous landmarks like Mount Everest, Eiffel Tower, and marathons
- **Guilt Trip Gamification**: Get "playful guilt trips" that make you aware of your scrolling habits in a fun way
- **Real-time Updates**: Watch your scroll journey progress in real-time
- **Data Persistence**: Your scroll data is saved between app sessions
- **Scroll Advice**: Get friendly reminders to take breaks based on your scrolling level
- **Accessibility Service Integration**: Uses Android's accessibility service to monitor scroll events across all apps
- **Modern UI**: Clean Material Design 3 interface with engaging visual feedback
- **Responsive Layout**: Works on all screen sizes with proper overflow handling

## How it Works

1. **Install the app** on your Android device
2. **Enable Accessibility Service**: Tap "Open Accessibility Settings" and enable ThumbOlympics
3. **Start Scrolling**: The app will track your scroll distance as you use your phone
4. **Discover Your Journey**: See how far you've scrolled compared to famous landmarks
5. **Get Playful Reminders**: Receive fun comparisons and advice that make you think about your scrolling habits
6. **Track Progress**: Your data persists between app sessions so you can see your long-term scrolling patterns

## Real-World Comparisons

The app compares your scroll distance to famous landmarks and distances:

- **Mount Everest** (8,848m) - The world's highest peak
- **Eiffel Tower** (324m) - Paris's iconic landmark
- **Marathon** (42,195m) - A full marathon distance
- **Empire State Building** (443m) - New York's famous skyscraper
- **Golden Gate Bridge** (1,280m) - San Francisco's iconic bridge
- **Burj Khalifa** (828m) - The world's tallest building
- **Statue of Liberty** (93m) - New York's famous statue
- **London Eye** (135m) - London's giant Ferris wheel
- **Sydney Opera House** (65m) - Australia's iconic building
- **Taj Mahal** (73m) - India's beautiful monument

## Playful Messages & Advice

The app provides engaging messages and advice based on your scrolling:

### Messages:
- "Just getting started! 🚀" (0-100m)
- "You're building up some momentum! 📈" (100-500m)
- "That's some serious scrolling! 😅" (500-1000m)
- "You could've climbed a mountain by now! 🏔️" (1000-5000m)
- "Marathon-level scrolling detected! 🏃‍♂️" (5000-10000m)
- "You're a scrolling legend! 👑" (10000m+)

### Advice:
- "Keep it up! You're doing great! 🌟" (0-100m)
- "Maybe take a short break? ☕" (100-500m)
- "Consider doing something else for a bit! 🎨" (500-1000m)
- "Time for a real break! Go outside! 🌳" (1000-5000m)
- "Seriously, put the phone down! 😅" (5000m+)

## Technical Details

- Built with Flutter for cross-platform compatibility
- Uses Android Accessibility Service API for accurate scroll detection
- Implements method channels for Flutter-Native communication
- Material Design 3 for modern UI
- Real-time distance calculations and comparisons
- Data persistence using SharedPreferences
- Responsive design with proper overflow handling
- Enhanced accessibility service configuration for better scroll detection
- Production-optimized build configuration

## Permissions Required

- **Accessibility Service**: Required to monitor scroll events across apps

## Development

### Prerequisites
- Flutter SDK 3.8.0 or higher
- Android Studio / VS Code
- Android device or emulator

### Setup
```bash
flutter pub get
flutter run
```

### Building

#### Debug Build
```bash
flutter build apk --debug
```

#### Production Build
```bash
flutter build apk --release
```

The production build creates an optimized APK ready for distribution.

## Privacy

ThumbOlympics only tracks scroll distance and events. No personal data is collected, stored, or transmitted. All data stays on your device and can be reset at any time.

## The Goal

This app aims to make users more aware of their scrolling habits through playful comparisons rather than judgment. By showing how far you've scrolled in terms of real-world distances, it helps you visualize the extent of your screen time in a memorable and engaging way. The app encourages healthy digital habits through gentle reminders and fun achievements.

## Production Features

- ✅ **Production Build**: Optimized APK with proper versioning
- ✅ **Clean Code**: Removed all debug statements and logging
- ✅ **Error Handling**: Silent error handling for production
- ✅ **App Metadata**: Professional app name and descriptions
- ✅ **Build Configuration**: Optimized for release with proper SDK versions
- ✅ **Resource Management**: Proper string resources and configurations
- ✅ **Accessibility**: Enhanced service configuration for better detection
- ✅ **Data Persistence**: Reliable data storage between sessions
- ✅ **Responsive UI**: Works on all screen sizes without overflow
- ✅ **Modern Design**: Material Design 3 with engaging visuals

## Recent Improvements

- ✅ Fixed bottom overflow issues with responsive layout
- ✅ Added data persistence between app sessions
- ✅ Improved accessibility service configuration
- ✅ Added scroll advice based on usage levels
- ✅ Enhanced error handling and fallback mechanisms
- ✅ Better UI with Material Design 3 components
- ✅ Production-ready build configuration
- ✅ Removed debug elements and optimized for release
- ✅ Professional app metadata and descriptions

## Contributing

Feel free to submit issues and enhancement requests! Ideas for new landmarks, playful messages, or features are always welcome.
