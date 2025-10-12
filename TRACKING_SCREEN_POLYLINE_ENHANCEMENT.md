# TRACKING SCREEN POLYLINE ENHANCEMENT PLAN

**Date:** October 11, 2025  
**Enhancement:** Dynamic Polyline Routing for Delivery Phases  

## OVERVIEW
Enhance the tracking screen to display dynamic polyline routes that change based on delivery status, providing Uber-style real-time routing visualization.

## POLYLINE PHASES

### Phase 1: Before Pickup (Driver → Pickup Location)
**Statuses:** `driver_assigned`, `going_to_pickup`
- **Route:** Driver's current location → Pickup point
- **Polyline Color:** Blue (#2196F3)
- **Display:** Driver marker + Pickup pin + Route
- **ETA:** Time to reach pickup location
- **Updates:** Real-time as driver moves toward pickup

### Phase 2: After Pickup (Pickup → Drop-off Location)  
**Statuses:** `package_collected`, `going_to_destination`, `in_transit`
- **Route:** Pickup location → Delivery destination
- **Polyline Color:** Purple (#9C27B0) 
- **Display:** Driver marker + Drop-off pin + Route
- **ETA:** Time to reach delivery destination
- **Updates:** Real-time as driver moves toward destination

### Phase 3: Driver Arrived
**Statuses:** `pickup_arrived`, `at_destination`
- **Route:** None (static markers only)
- **Display:** All markers with pulsing animations
- **ETA:** "Driver has arrived"

## TECHNICAL IMPLEMENTATION

### 1. Enhanced SharedDeliveryMap Widget
- Add `deliveryStatus` parameter
- Add `showPolylinePhase` method
- Add polyline phase management
- Add dynamic route calculation

### 2. Tracking Screen Updates
- Pass delivery status to map widget
- Update polyline when status changes
- Add ETA calculation based on route distance
- Add status-specific UI messaging

### 3. Route Management
- Clear previous polylines when phase changes
- Calculate new route based on current phase
- Update polyline color for visual clarity
- Handle route errors gracefully

## POLYLINE SPECIFICATIONS

### Color Coding:
- **Before Pickup:** Blue (#2196F3) - Driver heading to pickup
- **After Pickup:** Purple (#9C27B0) - Driver heading to delivery
- **Line Width:** 5.0dp for visibility
- **Animation:** Smooth transitions between phases

### Performance:
- Clear old polylines before drawing new ones
- Use Mapbox Directions API for accurate routes
- Cache route calculations when possible
- Optimize for real-time updates

## UI ENHANCEMENTS

### Status Messaging:
- "Driver is heading to pickup location" (Blue phase)
- "Driver has your package and is on the way" (Purple phase)
- "Driver has arrived at [location]" (Arrival phase)

### ETA Display:
- Calculate based on route distance and traffic
- Update dynamically as driver progresses
- Show different messaging for each phase

### Map Focus:
- Auto-adjust camera to show full route
- Focus on driver location during movement
- Zoom to show both driver and destination

## NEXT STEPS
1. Update SharedDeliveryMap with polyline phases
2. Modify TrackingScreen to pass delivery status
3. Add ETA calculation methods
4. Test with different delivery statuses
5. Optimize performance and error handling

---
**Status:** Ready for Implementation  
**Priority:** High - Core UX Enhancement
**Dependencies:** Existing Mapbox integration, delivery status updates