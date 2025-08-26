# PhotoGrid Component

A high-performance, manually-offset photo grid component for displaying media items with efficient viewport tracking and smooth animations.

## Overview

The PhotoGrid component provides a custom grid layout for displaying media thumbnails with advanced selection capabilities, drag-to-select functionality, and optimized viewport-based loading. Unlike standard SwiftUI grids, it uses manual offset calculations to enable efficient viewport tracking without performance degradation.

## Architecture

### Core Components

#### PhotoGridView.swift
The main view component that renders the photo grid interface.

**Key Features:**
- Manual offset-based positioning for optimal performance
- Multi-select with shift-click range selection
- Drag-to-select rectangle selection
- Context menu actions (download individual/multiple items)
- Smooth animations via SwiftUI transitions
- Horizontal and vertical scrolling modes

#### PhotoGridViewModel.swift  
Manages grid layout calculations and offset positioning.

**Responsibilities:**
- Calculate item positions using manual offsets
- Manage grid dimensions (columns, rows, item sizes)
- Handle incremental updates for growing datasets
- Rectangle-based selection calculations
- Viewport intersection detection

#### MediaItemsViewModel.swift
Handles data fetching, caching, and viewport-based loading optimization.

**Responsibilities:**
- Fetch media items from MongoDB
- Manage thumbnail loading states (tiny/full resolution)
- Viewport-based loading optimization
- Background processing queues
- Memory pressure management

## Key Performance Features

### Manual Offset System
Instead of relying on SwiftUI's automatic layout, the grid uses manually calculated CGSize offsets:

```swift
.offset(gridViewModel.offsets[object] ?? CGSize())
```

**Benefits:**
- Enables efficient viewport tracking without position monitoring
- Smooth animations with predictable positioning  
- Fast rectangle intersection calculations for drag selection
- No layout performance degradation with large datasets

### Incremental Updates
The grid optimizes for growing datasets by detecting when new items are added:

```swift
let canDoIncrementalUpdate = (width == lastWidth && 
                             idealGridItemSize == lastIdealSize && 
                             currentItemCount > lastItemCount &&
                             lastItemCount > 0)
```

Only calculates offsets for new items instead of recalculating the entire grid.

### Viewport-Based Loading
Media items load different thumbnail resolutions based on visibility:

- **Tiny thumbnails (100px)**: Items outside viewport
- **Full thumbnails**: Items within viewport + buffer zone
- **Background processing**: Thumbnail generation on separate queues

## Selection System

### Individual Selection
- Click to select/deselect individual items
- Visual feedback with checkmark overlay
- Selection state maintained in `selected: [BSONObjectID: Bool]`

### Range Selection (Shift+Click)
- Finds closest selected items in both directions
- Selects range to nearest selection boundary
- Handles edge cases (no existing selections, boundary items)

### Drag Selection
- Rectangle overlay during drag gesture
- Converts drag coordinates to grid positions
- Batch selects all items within rectangle
- Command+drag for additive selection

## Grid Calculations

### Column Count
```swift
func getNumColumns(width: CGFloat, idealGridItemSize: Double) -> Int {
    return Int(floor(width/idealGridItemSize))
}
```

### Item Positioning
```swift
func getOffset(for index: Int, width: CGFloat, numCols: Int, colWidth: CGFloat) -> CGSize {
    return CGSize(
        width: CGFloat(index % numCols) * colWidth, 
        height: CGFloat(index / numCols) * colWidth
    )
}
```

### Rectangle Selection
Converts screen coordinates to grid indices for drag selection:

```swift
func getPhotosInRectangle(_ rect: (x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)) -> [BSONObjectID]
```

## Usage

### Basic Grid
```swift
PhotoGridView(
    idealGridItemSize: $gridSize,
    minGridItemSize: 50.0,
    mongoHolder: mongoHolder,
    appDelegate: appDelegate,
    filter: [:],
    limit: 0
)
```

### With Multi-Select
```swift
PhotoGridView(
    idealGridItemSize: $gridSize,
    multiSelect: $multiSelectEnabled,
    minGridItemSize: 50.0,
    mongoHolder: mongoHolder,
    appDelegate: appDelegate,
    filter: searchFilter,
    limit: 100
)
```

### Horizontal Scrolling
```swift
PhotoGridView(
    idealGridItemSize: $gridSize,
    minGridItemSize: 50.0,
    mongoHolder: mongoHolder,
    appDelegate: appDelegate,
    filter: [:],
    horizontalScroll: true
)
```

## Configuration

### Constants
- `lowresTriggerWidth`: 100.0 - Threshold for high-res thumbnail loading
- `scrollUpdateDelay`: 0.2s - Debounce delay for scroll updates  
- `resizeUpdateDelay`: 0.5s - Debounce delay for resize updates
- `tinyThumbnailWidth`: 100.0 - Size for low-resolution thumbnails

### Grid Sizing
- `idealGridItemSize`: Target size for grid items (binding)
- `minGridItemSize`: Minimum allowed item size
- Responsive column calculation based on available width

## Performance Characteristics

### Memory Usage
- Viewport-based loading keeps memory usage constant
- Automatic cleanup of off-screen items
- Separate queues prevent UI blocking

### Scroll Performance  
- Manual offsets enable smooth scrolling at any dataset size
- Viewport tracking without per-item position monitoring
- Debounced updates prevent excessive calculations

### Animation Performance
- Predictable positioning enables smooth SwiftUI animations
- Offset changes animate automatically with `withAnimation`
- No layout recalculation during animations

## Integration Points

### Data Source
- Requires `MongoClientHolder` for database connectivity
- Supports BSON document filters for queries
- Handles MongoDB collection cursors efficiently

### Thumbnail System
- Integrates with `ThumbnailViewModel` for image loading
- Supports caching via Core Data `PreviewCache`
- Background image processing queues

### Download System
- Context menu integration with `DownloadManager`
- Supports single and batch downloads
- Selection-aware download actions

## Future Considerations

The viewport calculation currently assumes the ZStack starts at origin.y = 0. This assumption is documented and could be made more flexible if needed for complex layout scenarios.

The component uses NSOperationQueue comments suggest potential future optimization opportunities, though current DispatchQueue implementation performs well.