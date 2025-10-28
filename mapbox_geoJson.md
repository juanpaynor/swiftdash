GeoJsonSource class
A GeoJSON data source. @see The online documentation

Inheritance
Object Source GeoJsonSource
Constructors
GeoJsonSource({required String id, String? data = "", double? maxzoom, String? attribution, double? buffer, double? tolerance, bool? cluster, double? clusterRadius, double? clusterMaxZoom, double? clusterMinPoints, Map<String, dynamic>? clusterProperties, bool? lineMetrics, bool? generateId, bool? autoMaxZoom, double? prefetchZoomDelta, TileCacheBudget? tileCacheBudget})
Properties
attribution → Future<String?>
Contains an attribution to be displayed when the map is shown to a user.
no setter
autoMaxZoom → Future<bool?>
When set to true, the maxZoom property is ignored and is instead calculated automatically based on the largest bounding box from the geoJSON features. This resolves rendering artifacts for features that use wide blur (e.g. fill extrusion ground flood light or circle layer) and would bring performance improvement on lower zoom levels, especially for geoJSON sources that update data frequently. However, it can lead to flickering and precision loss on zoom levels above 19. Default value: false.
no setter
buffer → Future<double?>
Size of the tile buffer on each side. A value of 0 produces no buffer. A value of 512 produces a buffer as wide as the tile itself. Larger values produce fewer rendering artifacts near tile edges and slower performance. Default value: 128. Value range: 0, 512
no setter
cluster → Future<bool?>
If the data is a collection of point features, setting this to true clusters the points by radius into groups. Cluster groups become new Point features in the source with additional properties:
no setter
clusterMaxZoom → Future<double?>
Max zoom on which to cluster points if clustering is enabled. Defaults to one zoom less than maxzoom (so that last zoom features are not clustered). Clusters are re-evaluated at integer zoom levels so setting clusterMaxZoom to 14 means the clusters will be displayed until z15.
no setter
clusterMinPoints → Future<double?>
Minimum number of points necessary to form a cluster if clustering is enabled. Defaults to 2.
no setter
clusterProperties → Future<Map<String, dynamic>?>
An object defining custom properties on the generated clusters if clustering is enabled, aggregating values from clustered points. Has the form {"property_name": [operator, map_expression]}. operator is any expression function that accepts at least 2 operands (e.g. "+" or "max") — it accumulates the property value from clusters/points the cluster contains; map_expression produces the value of a single point.
no setter
clusterRadius → Future<double?>
Radius of each cluster if clustering is enabled. A value of 512 indicates a radius equal to the width of a tile. Default value: 50. Minimum value: 0.
no setter
data → Future<String?>
A URL to a GeoJSON file, or inline GeoJSON.
no setter
generateId → Future<bool?>
Whether to generate ids for the GeoJSON features. When enabled, the feature.id property will be auto assigned based on its index in the features array, over-writing any previous values. Default value: false.
no setter
hashCode → int
The hash code for this object.
no setterinherited
id ↔ String
The ID of the Source.
getter/setter pairinherited
lineMetrics → Future<bool?>
Whether to calculate line distance metrics. This is required for line layers that specify line-gradient values. Default value: false.
no setter
maxzoom → Future<double?>
Maximum zoom level at which to create vector tiles (higher means greater detail at high zoom levels). Default value: 18.
no setter
prefetchZoomDelta → Future<double?>
When loading a map, if PrefetchZoomDelta is set to any number greater than 0, the map will first request a tile at zoom level lower than zoom - delta, but so that the zoom level is multiple of delta, in an attempt to display a full map at lower resolution as quick as possible. It will get clamped at the tile source minimum zoom. Default value: 4.
no setter
runtimeType → Type
A representation of the runtime type of the object.
no setterinherited
tileCacheBudget → Future<TileCacheBudget?>
This property defines a source-specific resource budget, either in tile units or in megabytes. Whenever the tile cache goes over the defined limit, the least recently used tile will be evicted from the in-memory cache. Note that the current implementation does not take into account resources allocated by the visible tiles.
no setter
tolerance → Future<double?>
Douglas-Peucker simplification tolerance (higher means simpler geometries and faster performance). Default value: 0.375.
no setter
Methods
bind(StyleManager style) → void
inherited
getType() → String
Get the type of the current source as a String.
override
noSuchMethod(Invocation invocation) → dynamic
Invoked when a nonexistent method or property is accessed.
inherited
toString() → String
A string representation of this object.
inherited
updateGeoJSON(String geoJson) → Future<void>?
Update this GeojsonSource with a URL to a GeoJSON file, or inline GeoJSON.
Operators
operator ==(Object other) → bool
The equality operator.
inherited