LineLayer class
A stroked line.

Inheritance
Object Layer LineLayer
Constructors
LineLayer({required String id, Visibility? visibility, List<Object>? visibilityExpression, List<Object>? filter, double? minZoom, double? maxZoom, String? slot, required String sourceId, String? sourceLayer, LineCap? lineCap, List<Object>? lineCapExpression, double? lineCrossSlope, List<Object>? lineCrossSlopeExpression, double? lineCutoutFadeWidth, List<Object>? lineCutoutFadeWidthExpression, double? lineCutoutOpacity, List<Object>? lineCutoutOpacityExpression, double? lineCutoutWidth, List<Object>? lineCutoutWidthExpression, LineElevationReference? lineElevationReference, List<Object>? lineElevationReferenceExpression, LineJoin? lineJoin, List<Object>? lineJoinExpression, double? lineMiterLimit, List<Object>? lineMiterLimitExpression, double? lineRoundLimit, List<Object>? lineRoundLimitExpression, double? lineSortKey, List<Object>? lineSortKeyExpression, LineWidthUnit? lineWidthUnit, List<Object>? lineWidthUnitExpression, double? lineZOffset, List<Object>? lineZOffsetExpression, double? lineBlur, List<Object>? lineBlurExpression, int? lineBorderColor, List<Object>? lineBorderColorExpression, double? lineBorderWidth, List<Object>? lineBorderWidthExpression, int? lineColor, List<Object>? lineColorExpression, List<double?>? lineDasharray, List<Object>? lineDasharrayExpression, double? lineDepthOcclusionFactor, List<Object>? lineDepthOcclusionFactorExpression, double? lineEmissiveStrength, List<Object>? lineEmissiveStrengthExpression, double? lineGapWidth, List<Object>? lineGapWidthExpression, int? lineGradient, List<Object>? lineGradientExpression, double? lineOcclusionOpacity, List<Object>? lineOcclusionOpacityExpression, double? lineOffset, List<Object>? lineOffsetExpression, double? lineOpacity, List<Object>? lineOpacityExpression, String? linePattern, List<Object>? linePatternExpression, double? linePatternCrossFade, List<Object>? linePatternCrossFadeExpression, List<double?>? lineTranslate, List<Object>? lineTranslateExpression, LineTranslateAnchor? lineTranslateAnchor, List<Object>? lineTranslateAnchorExpression, int? lineTrimColor, List<Object>? lineTrimColorExpression, List<double?>? lineTrimFadeRange, List<Object>? lineTrimFadeRangeExpression, List<double?>? lineTrimOffset, List<Object>? lineTrimOffsetExpression, double? lineWidth, List<Object>? lineWidthExpression})
Properties
filter ↔ List<Object>?
An expression specifying conditions on source features. Only features that match the filter are displayed.
getter/setter pairinherited
hashCode → int
The hash code for this object.
no setterinherited
id ↔ String
The ID of the Layer.
getter/setter pairinherited
lineBlur ↔ double?
Blur applied to the line, in pixels. Default value: 0. Minimum value: 0. The unit of lineBlur is in pixels.
getter/setter pair
lineBlurExpression ↔ List<Object>?
Blur applied to the line, in pixels. Default value: 0. Minimum value: 0. The unit of lineBlur is in pixels.
getter/setter pair
lineBorderColor ↔ int?
The color of the line border. If line-border-width is greater than zero and the alpha value of this color is 0 (default), the color for the border will be selected automatically based on the line color. Default value: "rgba(0, 0, 0, 0)".
getter/setter pair
lineBorderColorExpression ↔ List<Object>?
The color of the line border. If line-border-width is greater than zero and the alpha value of this color is 0 (default), the color for the border will be selected automatically based on the line color. Default value: "rgba(0, 0, 0, 0)".
getter/setter pair
lineBorderWidth ↔ double?
The width of the line border. A value of zero means no border. Default value: 0. Minimum value: 0.
getter/setter pair
lineBorderWidthExpression ↔ List<Object>?
The width of the line border. A value of zero means no border. Default value: 0. Minimum value: 0.
getter/setter pair
lineCap ↔ LineCap?
The display of line endings. Default value: "butt".
getter/setter pair
lineCapExpression ↔ List<Object>?
The display of line endings. Default value: "butt".
getter/setter pair
lineColor ↔ int?
The color with which the line will be drawn. Default value: "#000000".
getter/setter pair
lineColorExpression ↔ List<Object>?
The color with which the line will be drawn. Default value: "#000000".
getter/setter pair
lineCrossSlope ↔ double?
Defines the slope of an elevated line. A value of 0 creates a horizontal line. A value of 1 creates a vertical line. Other values are currently not supported. If undefined, the line follows the terrain slope. This is an experimental property with some known issues:
getter/setter pair
lineCrossSlopeExpression ↔ List<Object>?
Defines the slope of an elevated line. A value of 0 creates a horizontal line. A value of 1 creates a vertical line. Other values are currently not supported. If undefined, the line follows the terrain slope. This is an experimental property with some known issues:
getter/setter pair
lineCutoutFadeWidth ↔ double?
The width of the cutout fade effect Default value: 0.4. Value range: 0, 1
getter/setter pair
lineCutoutFadeWidthExpression ↔ List<Object>?
The width of the cutout fade effect Default value: 0.4. Value range: 0, 1
getter/setter pair
lineCutoutOpacity ↔ double?
The opacity of the aboveground objects affected by the line cutout. Cutout for tunnels isn't affected by this property, If set to 0, the cutout is fully transparent. Cutout opacity should have the same value for all layers that specify it. If all layers don't have the same value, it is not specified which value is used. Default value: 0.3. Value range: 0, 1
getter/setter pair
lineCutoutOpacityExpression ↔ List<Object>?
The opacity of the aboveground objects affected by the line cutout. Cutout for tunnels isn't affected by this property, If set to 0, the cutout is fully transparent. Cutout opacity should have the same value for all layers that specify it. If all layers don't have the same value, it is not specified which value is used. Default value: 0.3. Value range: 0, 1
getter/setter pair
lineCutoutWidth ↔ double?
The width of the line cutout in meters. If set to 0, the cutout is disabled. The cutout does not apply to location-indicator type layers. Default value: 0. Value range: 0, 50
getter/setter pair
lineCutoutWidthExpression ↔ List<Object>?
The width of the line cutout in meters. If set to 0, the cutout is disabled. The cutout does not apply to location-indicator type layers. Default value: 0. Value range: 0, 50
getter/setter pair
lineDasharray ↔ List<double?>?
Specifies the lengths of the alternating dashes and gaps that form the dash pattern. The lengths are later scaled by the line width. To convert a dash length to pixels, multiply the length by the current line width. Note that GeoJSON sources with lineMetrics: true specified won't render dashed lines to the expected scale. Also note that zoom-dependent expressions will be evaluated only at integer zoom levels. Minimum value: 0. The unit of lineDasharray is in line widths.
getter/setter pair
lineDasharrayExpression ↔ List<Object>?
Specifies the lengths of the alternating dashes and gaps that form the dash pattern. The lengths are later scaled by the line width. To convert a dash length to pixels, multiply the length by the current line width. Note that GeoJSON sources with lineMetrics: true specified won't render dashed lines to the expected scale. Also note that zoom-dependent expressions will be evaluated only at integer zoom levels. Minimum value: 0. The unit of lineDasharray is in line widths.
getter/setter pair
lineDepthOcclusionFactor ↔ double?
Decrease line layer opacity based on occlusion from 3D objects. Value 0 disables occlusion, value 1 means fully occluded. Default value: 1. Value range: 0, 1
getter/setter pair
lineDepthOcclusionFactorExpression ↔ List<Object>?
Decrease line layer opacity based on occlusion from 3D objects. Value 0 disables occlusion, value 1 means fully occluded. Default value: 1. Value range: 0, 1
getter/setter pair
lineElevationReference ↔ LineElevationReference?
Selects the base of line-elevation. Some modes might require precomputed elevation data in the tileset. Default value: "none".
getter/setter pair
lineElevationReferenceExpression ↔ List<Object>?
Selects the base of line-elevation. Some modes might require precomputed elevation data in the tileset. Default value: "none".
getter/setter pair
lineEmissiveStrength ↔ double?
Controls the intensity of light emitted on the source features. Default value: 0. Minimum value: 0. The unit of lineEmissiveStrength is in intensity.
getter/setter pair
lineEmissiveStrengthExpression ↔ List<Object>?
Controls the intensity of light emitted on the source features. Default value: 0. Minimum value: 0. The unit of lineEmissiveStrength is in intensity.
getter/setter pair
lineGapWidth ↔ double?
Draws a line casing outside of a line's actual path. Value indicates the width of the inner gap. Default value: 0. Minimum value: 0. The unit of lineGapWidth is in pixels.
getter/setter pair
lineGapWidthExpression ↔ List<Object>?
Draws a line casing outside of a line's actual path. Value indicates the width of the inner gap. Default value: 0. Minimum value: 0. The unit of lineGapWidth is in pixels.
getter/setter pair
lineGradient ↔ int?
A gradient used to color a line feature at various distances along its length. Defined using a step or interpolate expression which outputs a color for each corresponding line-progress input value. line-progress is a percentage of the line feature's total length as measured on the webmercator projected coordinate plane (a number between 0 and 1). Can only be used with GeoJSON sources that specify "lineMetrics": true.
getter/setter pair
lineGradientExpression ↔ List<Object>?
A gradient used to color a line feature at various distances along its length. Defined using a step or interpolate expression which outputs a color for each corresponding line-progress input value. line-progress is a percentage of the line feature's total length as measured on the webmercator projected coordinate plane (a number between 0 and 1). Can only be used with GeoJSON sources that specify "lineMetrics": true.
getter/setter pair
lineJoin ↔ LineJoin?
The display of lines when joining. Default value: "miter".
getter/setter pair
lineJoinExpression ↔ List<Object>?
The display of lines when joining. Default value: "miter".
getter/setter pair
lineMiterLimit ↔ double?
Used to automatically convert miter joins to bevel joins for sharp angles. Default value: 2.
getter/setter pair
lineMiterLimitExpression ↔ List<Object>?
Used to automatically convert miter joins to bevel joins for sharp angles. Default value: 2.
getter/setter pair
lineOcclusionOpacity ↔ double?
Opacity multiplier (multiplies line-opacity value) of the line part that is occluded by 3D objects. Value 0 hides occluded part, value 1 means the same opacity as non-occluded part. The property is not supported when line-opacity has data-driven styling. Default value: 0. Value range: 0, 1
getter/setter pair
lineOcclusionOpacityExpression ↔ List<Object>?
Opacity multiplier (multiplies line-opacity value) of the line part that is occluded by 3D objects. Value 0 hides occluded part, value 1 means the same opacity as non-occluded part. The property is not supported when line-opacity has data-driven styling. Default value: 0. Value range: 0, 1
getter/setter pair
lineOffset ↔ double?
The line's offset. For linear features, a positive value offsets the line to the right, relative to the direction of the line, and a negative value to the left. For polygon features, a positive value results in an inset, and a negative value results in an outset. Default value: 0. The unit of lineOffset is in pixels.
getter/setter pair
lineOffsetExpression ↔ List<Object>?
The line's offset. For linear features, a positive value offsets the line to the right, relative to the direction of the line, and a negative value to the left. For polygon features, a positive value results in an inset, and a negative value results in an outset. Default value: 0. The unit of lineOffset is in pixels.
getter/setter pair
lineOpacity ↔ double?
The opacity at which the line will be drawn. Default value: 1. Value range: 0, 1
getter/setter pair
lineOpacityExpression ↔ List<Object>?
The opacity at which the line will be drawn. Default value: 1. Value range: 0, 1
getter/setter pair
linePattern ↔ String?
Name of image in sprite to use for drawing image lines. For seamless patterns, image width must be a factor of two (2, 4, 8, ..., 512). Note that zoom-dependent expressions will be evaluated only at integer zoom levels.
getter/setter pair
linePatternCrossFade ↔ double?
Controls the transition progress between the image variants of line-pattern. Zero means the first variant is used, one is the second, and in between they are blended together. Both images should be the same size and have the same type (either raster or vector). Default value: 0. Value range: 0, 1
getter/setter pair
linePatternCrossFadeExpression ↔ List<Object>?
Controls the transition progress between the image variants of line-pattern. Zero means the first variant is used, one is the second, and in between they are blended together. Both images should be the same size and have the same type (either raster or vector). Default value: 0. Value range: 0, 1
getter/setter pair
linePatternExpression ↔ List<Object>?
Name of image in sprite to use for drawing image lines. For seamless patterns, image width must be a factor of two (2, 4, 8, ..., 512). Note that zoom-dependent expressions will be evaluated only at integer zoom levels.
getter/setter pair
lineRoundLimit ↔ double?
Used to automatically convert round joins to miter joins for shallow angles. Default value: 1.05.
getter/setter pair
lineRoundLimitExpression ↔ List<Object>?
Used to automatically convert round joins to miter joins for shallow angles. Default value: 1.05.
getter/setter pair
lineSortKey ↔ double?
Sorts features in ascending order based on this value. Features with a higher sort key will appear above features with a lower sort key.
getter/setter pair
lineSortKeyExpression ↔ List<Object>?
Sorts features in ascending order based on this value. Features with a higher sort key will appear above features with a lower sort key.
getter/setter pair
lineTranslate ↔ List<double?>?
The geometry's offset. Values are x, y where negatives indicate left and up, respectively. Default value: 0,0. The unit of lineTranslate is in pixels.
getter/setter pair
lineTranslateAnchor ↔ LineTranslateAnchor?
Controls the frame of reference for line-translate. Default value: "map".
getter/setter pair
lineTranslateAnchorExpression ↔ List<Object>?
Controls the frame of reference for line-translate. Default value: "map".
getter/setter pair
lineTranslateExpression ↔ List<Object>?
The geometry's offset. Values are x, y where negatives indicate left and up, respectively. Default value: 0,0. The unit of lineTranslate is in pixels.
getter/setter pair
lineTrimColor ↔ int?
The color to be used for rendering the trimmed line section that is defined by the line-trim-offset property. Default value: "transparent".
getter/setter pair
lineTrimColorExpression ↔ List<Object>?
The color to be used for rendering the trimmed line section that is defined by the line-trim-offset property. Default value: "transparent".
getter/setter pair
lineTrimFadeRange ↔ List<double?>?
The fade range for the trim-start and trim-end points is defined by the line-trim-offset property. The first element of the array represents the fade range from the trim-start point toward the end of the line, while the second element defines the fade range from the trim-end point toward the beginning of the line. The fade result is achieved by interpolating between line-trim-color and the color specified by the line-color or the line-gradient property. Default value: 0,0. Minimum value: 0,0. Maximum value: 1,1.
getter/setter pair
lineTrimFadeRangeExpression ↔ List<Object>?
The fade range for the trim-start and trim-end points is defined by the line-trim-offset property. The first element of the array represents the fade range from the trim-start point toward the end of the line, while the second element defines the fade range from the trim-end point toward the beginning of the line. The fade result is achieved by interpolating between line-trim-color and the color specified by the line-color or the line-gradient property. Default value: 0,0. Minimum value: 0,0. Maximum value: 1,1.
getter/setter pair
lineTrimOffset ↔ List<double?>?
The line part between trim-start, trim-end will be painted using line-trim-color, which is transparent by default to produce a route vanishing effect. The line trim-off offset is based on the whole line range 0.0, 1.0. Default value: 0,0. Minimum value: 0,0. Maximum value: 1,1.
getter/setter pair
lineTrimOffsetExpression ↔ List<Object>?
The line part between trim-start, trim-end will be painted using line-trim-color, which is transparent by default to produce a route vanishing effect. The line trim-off offset is based on the whole line range 0.0, 1.0. Default value: 0,0. Minimum value: 0,0. Maximum value: 1,1.
getter/setter pair
lineWidth ↔ double?
Stroke thickness. Default value: 1. Minimum value: 0. The unit of lineWidth is in pixels.
getter/setter pair
lineWidthExpression ↔ List<Object>?
Stroke thickness. Default value: 1. Minimum value: 0. The unit of lineWidth is in pixels.
getter/setter pair
lineWidthUnit ↔ LineWidthUnit?
Selects the unit of line-width. The same unit is automatically used for line-blur and line-offset. Note: This is an experimental property and might be removed in a future release. Default value: "pixels".
getter/setter pair
lineWidthUnitExpression ↔ List<Object>?
Selects the unit of line-width. The same unit is automatically used for line-blur and line-offset. Note: This is an experimental property and might be removed in a future release. Default value: "pixels".
getter/setter pair
lineZOffset ↔ double?
Vertical offset from ground, in meters. Defaults to 0. This is an experimental property with some known issues:
getter/setter pair
lineZOffsetExpression ↔ List<Object>?
Vertical offset from ground, in meters. Defaults to 0. This is an experimental property with some known issues:
getter/setter pair
maxZoom ↔ double?
The maximum zoom level for the layer. At zoom levels equal to or greater than the maxzoom, the layer will be hidden.
getter/setter pairinherited
minZoom ↔ double?
The minimum zoom level for the layer. At zoom levels less than the minzoom, the layer will be hidden.
getter/setter pairinherited
runtimeType → Type
A representation of the runtime type of the object.
no setterinherited
slot ↔ String?
The slot this layer is assigned to. If specified, and a slot with that name exists, it will be placed at that position in the layer order.
getter/setter pairinherited
sourceId ↔ String
The id of the source.
getter/setter pair
sourceLayer ↔ String?
A source layer is an individual layer of data within a vector source. A vector source can have multiple source layers.
getter/setter pair
visibility ↔ Visibility?
The visibility of the layer.
getter/setter pairinherited
visibilityExpression ↔ List<Object>?
The visibility of the layer.
getter/setter pairinherited
Methods
getType() → String
Get the type of current layer as a String.
override
noSuchMethod(Invocation invocation) → dynamic
Invoked when a nonexistent method or property is accessed.
inherited
toString() → String
A string representation of this object.
inherited
Operators
operator ==(Object other) → bool
The equality operator.
inherited
Static Methods
decode(String properties) → LineLayer