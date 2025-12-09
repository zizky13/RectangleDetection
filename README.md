# Expo Floor Plan Analyzer

An iOS application built with SwiftUI that uses Apple's Vision framework to detect and analyze booth layouts in expo floor plan images. The app can automatically identify rectangular booths, extract text content, and provide search functionality to locate specific booths by name.

## Features

### Rectangle Detection
- **Multi-strategy detection**: Uses three different detection algorithms (high sensitivity, standard, and small booth optimized) to maximize booth detection accuracy
- **Intelligent preprocessing**: Enhances images with contrast adjustment, edge sharpening, and grayscale conversion for better detection
- **Smart filtering**: Removes duplicate detections and composite boxes while preserving valid booth boundaries
- **Edge booth detection**: Specialized algorithms to detect booths at image boundaries that are often missed by standard detection

### Friendly UI
- **Image selection**: Easy photo library integration for selecting floor plan images
- **Interactive visualization**: Detected booths are outlined with confidence scores and booth names
- **Detailed results**: Shows detection statistics including booth count, confidence averages, and text recognition results

### Search
- **Text-based search**: Find booths by name or any detected text content
- **Visual highlighting**: Searched booths are highlighted in yellow with "FOUND" labels
- **Case-insensitive matching**: Flexible search that works with partial matches
- **Real-time feedback**: Instant visual confirmation when booths are found or not found

### Comprehensive Booth Details
- **Detailed view**: Expandable list showing all detected booths with full information
- **Booth metrics**: Area, dimensions, position coordinates, and confidence scores
- **Text extraction**: OCR-detected text content and cleaned booth names
- **Visual indicators**: Color-coded confidence levels and highlighting status

## Technical Architecture

### Core Components

#### `ExpoFloorPlanAnalyzer`
The main analysis engine that handles:
- Multi-strategy Vision framework rectangle detection
- Image preprocessing and enhancement
- Text recognition using VNRecognizeTextRequest
- Booth filtering and deduplication logic
- Search functionality and highlighting

#### `ExpoFloorPlanView`
The primary SwiftUI interface providing:
- Image selection and display
- Search bar with real-time filtering
- Analysis controls and progress indication
- Results summary and navigation to detailed views

#### `DetectedBooth` Model
Data structure containing:
- Geometric information (corners, bounding box, area)
- Detection metadata (confidence, unique ID)
- Text content (raw OCR results, cleaned booth names)
- UI state (highlighting status)

#### Supporting Views
- **`ImagePicker`**: UIKit integration for photo library access
- **`BoothDetailsView`**: Detailed list view of all detected booths
- **`ContentView`**: Main app entry point

## How to Use

### 1. Launch the App
Open the app to see the main Expo Floor Plan Analyzer interface.

### 2. Select a Floor Plan Image
1. Tap **"Select Image"** to open the photo picker
2. Choose a floor plan image from your photo library
3. The selected image will be displayed in the preview area

### 3. Analyze the Floor Plan
1. Tap **"Analyze Floor Plan"** to start the detection process
2. Wait for the analysis to complete (progress indicator will show)
3. View the processed image with detected booths outlined in red

### 4. Search for Specific Booths
1. Use the search bar to find specific booths by name
2. Type any part of a booth name or text content
3. Found booths will be highlighted in yellow with "FOUND" labels
4. Clear the search to return to normal view

### 5. View Detailed Results
1. Tap **"Show Details"** to see the complete booth list
2. Review individual booth information including:
   - Confidence scores and detection metrics
   - Detected text content and booth names
   - Physical measurements and coordinates
3. Tap **"Done"** to return to the main view

## Technical Requirements

- **iOS 15.0+** (for SwiftUI and modern Vision framework features)
- **Device with camera** (for photo library access)
- **Sufficient processing power** (Vision framework analysis is CPU intensive)

## Vision Framework Integration

The app leverages several Apple Vision framework capabilities:

### Rectangle Detection (`VNDetectRectanglesRequest`)
- Multiple detection passes with different sensitivity levels
- Configurable confidence thresholds and size constraints
- Aspect ratio filtering for booth-like rectangles

### Text Recognition (`VNRecognizeTextRequest`)
- OCR text extraction from detected booth areas
- Language correction and accurate recognition level
- Text-to-booth matching based on spatial overlap

### Image Processing
- Core Image filters for preprocessing
- Custom graphics rendering for result visualization
- Coordinate system transformation between Vision and UIKit

## Architecture Patterns

- **MVVM Pattern**: ObservableObject analyzer with SwiftUI views
- **Async Processing**: Background Vision framework operations
- **State Management**: Published properties for reactive UI updates
- **Modular Design**: Separated concerns across multiple Swift files

## Performance Optimizations

- **Multi-threading**: Vision requests run on background queues
- **Smart filtering**: Eliminates redundant detections early
- **Memory management**: Proper image handling and cleanup
- **Progressive enhancement**: Multiple detection strategies for accuracy

## Future Enhancement Opportunities

- **Export functionality**: Save analysis results as JSON or PDF
- **Batch processing**: Analyze multiple floor plans simultaneously
- **Machine learning**: Custom booth detection models
- **Integration**: Import from CAD files or web services
- **Collaboration**: Share and annotate floor plan analyses

## Troubleshooting

### Common Issues

**Low detection accuracy:**
- Ensure floor plan has clear booth boundaries
- Try images with higher contrast
- Use floor plans with minimal background noise

**Search not finding booths:**
- Check that text is clearly visible in the original image
- Try partial name matches
- Verify booth has detectable text content

**App performance issues:**
- Use smaller image sizes for faster processing
- Close other apps to free up memory
- Restart the app if analysis gets stuck

## Development Notes

Created by Zikar Nurizky on July 22, 2025.

- SwiftUI for modern declarative UI
- Vision framework for computer vision tasks
- Combine for reactive programming patterns
- UIKit integration within SwiftUI apps
- Core Image for advanced image processing

The codebase follows Apple's recommended practices for iOS development and showcases integration between multiple Apple frameworks for a cohesive user experience.
