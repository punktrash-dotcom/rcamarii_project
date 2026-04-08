# Fix RenderFlex Overflow in Market Price List Screen

## Problem Analysis

### Issue Summary
A `Row` widget at [`market_price_list_screen.dart:647`](../lib/screens/market_price_list_screen.dart:647) is overflowing by 10 pixels on the right side.

### Technical Details
- **Location**: Line 647 in [`market_price_list_screen.dart`](../lib/screens/market_price_list_screen.dart)
- **Widget Hierarchy**: 
  ```
  Row (line 637)
  └── Expanded (line 639)
      └── Column (line 640)
          └── Row (line 647) ← OVERFLOW HERE
              ├── Text (region)
              ├── Text (" • ") [conditional]
              └── Text (unit) [conditional]
  ```
- **Constraint**: The problematic Row has `BoxConstraints(0.0<=w<=196.7)`
- **Overflow Amount**: 10 pixels

### Root Cause
The Row at line 647 contains text widgets that are sized to their natural size without any flex constraints. When the combined width of:
- Region name (e.g., "Central Luzon", "Western Visayas")
- Bullet separator " • "
- Unit text (e.g., "per kilogram", "50 kg bag")

...exceeds 196.7 pixels, the overflow occurs.

## Solution Options

### Option 1: Wrap Inner Row with Flexible (RECOMMENDED ✅)

**Approach**: Wrap the entire Row at line 647 with a `Flexible` widget and add text overflow handling.

**Pros**:
- Maintains current visual design
- Simple, single-point fix
- Allows Row to adapt to available space
- Text will gracefully truncate with ellipsis

**Cons**:
- None significant

**Implementation**:
```dart
Flexible(  // Add this wrapper
  child: Row(
    children: [
      Flexible(  // Wrap the region text
        child: Text(
          _rowRegion(row),
          style: TextStyle(
            fontSize: 11,
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
          overflow: TextOverflow.ellipsis,  // Add overflow handling
          maxLines: 1,  // Ensure single line
        ),
      ),
      if (row['unit'] != null) ...[
        Text(
          ' • ',
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.3)
          ),
        ),
        Flexible(  // Wrap the unit text
          child: Text(
            row['unit'].toString(),
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,  // Add overflow handling
            maxLines: 1,  // Ensure single line
          ),
        ),
      ],
    ],
  ),
),
```

### Option 2: Use Expanded on Text Widgets

**Approach**: Wrap individual Text widgets with `Expanded` within the Row.

**Pros**:
- More control over how space is distributed
- Can assign flex values to prioritize certain elements

**Cons**:
- More complex than Option 1
- Requires careful flex value tuning
- May make the bullet separator position unpredictable

### Option 3: Add Text Overflow Only

**Approach**: Add `maxLines: 1` and `overflow: TextOverflow.ellipsis` to Text widgets without layout changes.

**Pros**:
- Minimal code change

**Cons**:
- May not fully prevent overflow if both texts are long
- Doesn't address the fundamental layout constraint issue

### Option 4: Vertical Layout

**Approach**: Stack region and unit vertically instead of horizontally.

**Pros**:
- Eliminates horizontal space constraints
- More space for text content

**Cons**:
- Changes the visual design significantly
- Takes more vertical space
- May not align with design intent

## Recommended Solution

**Option 1** is recommended because it:
1. Fixes the overflow issue completely
2. Maintains the current visual design
3. Provides graceful text truncation with ellipsis
4. Is a clean, maintainable solution
5. Follows Flutter best practices for constrained layouts

## Implementation Steps

1. Locate the Row widget at line 647
2. Wrap the entire Row with a `Flexible` widget
3. Wrap the region Text widget (line 649) with `Flexible`
4. Add `overflow: TextOverflow.ellipsis` and `maxLines: 1` to the region Text
5. Wrap the unit Text widget (line 664) with `Flexible`
6. Add `overflow: TextOverflow.ellipsis` and `maxLines: 1` to the unit Text
7. Test with various region names and units to ensure no overflow

## Testing Considerations

After implementing the fix, verify:
- ✅ No overflow errors in Flutter DevTools
- ✅ Text displays with ellipsis when content is too long
- ✅ Layout looks correct with short region/unit names
- ✅ Layout looks correct with long region/unit names
- ✅ Bullet separator displays correctly when unit is present
- ✅ Visual consistency across different data sources

## Similar Issues

Check if there are similar overflow issues elsewhere in the file:
- Line 559: Similar Row structure but different constraints
- Other price display sections that might have similar layouts

## Code Reference

The affected section displays market price data with the following structure:
- **Row Label** (line 644): Item name from [`_rowLabel()`](../lib/screens/market_price_list_screen.dart:955)
- **Row Region** (line 650): Region name from [`_rowRegion()`](../lib/screens/market_price_list_screen.dart:966)
- **Unit**: Optional unit text from `row['unit']`
- **Price** (line 680): Formatted price from [`_formatPeso()`](../lib/screens/market_price_list_screen.dart:940)

The parent Row (line 637) uses an `Expanded` column for the left side (item details) and an unconstrained Text on the right side (price), which is the correct pattern. The issue is purely within the inner metadata Row.
