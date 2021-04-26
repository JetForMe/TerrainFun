#  TerrainFun

## Building

Add a custom Xcode path (Preferences->Locations->Custom Paths) to your local directory containing test data, and call it `TerrainFunTestDataDirectory`.

### Prerequisites

Download the following test data:

```
$ curl "https://planetarymaps.usgs.gov/mosaic/Mars/HRSC_MOLA_Blend/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2.tif" -o "<Your TerrainFunTestDataDirectory from above>"
$ curl "https://astropedia.astrogeology.usgs.gov/download/Mars/Topography/HRSC_MOLA_Blend/thumbs/Mars_HRSC_MOLA_BlendDEM_Global_200mp_1024.jpg" -o "<Your TerrainFunTestDataDirectory from above>"
```

Install the following libraries:

```
$ brew install gdal
```
## Displaying a Scaled Image & Map Projections

To properly display a GeoTIFF image and reference the current mouse pointer to a geodetic
location, a number of transformations must occur:

* The source image is likely *very* large, and must be scaled down for display

	I’m not sure how to compute this SwiftUI. Normally it would handle displaying
	an existing image in a nicely-constrained frame while preserving aspect ratio.
	But we haven’t generated the image yet, and need to know how big to display it
	before generating it.
	
	Ideally we tile it.
	
	**For now:** Generate a working image that’s a couple-thousand pixels wide and
	let SwiftUI scale it. Then use `GeometryReader` to figure out what size
	we made it.
	
* Current image coordinates to full-size image coordinates
* Full-size image coordinates reverse-projected through the current map projection




### File Format Specifications

BIL: https://desktop.arcgis.com/en/arcmap/10.3/manage-data/raster-and-images/bil-bip-and-bsq-raster-files.htm
TIFF: https://www.adobe.io/content/dam/udp/en/open/standards/tiff/TIFF6.pdf
GeoTIFF: http://geotiff.maptools.org/spec/contents.html
SRTM: https://www.usgs.gov/centers/eros/science/usgs-eros-archive-digital-elevation-shuttle-radar-topography-mission-srtm-1-arc?qt-science_center_objects=0#qt-science_center_objects

### Misc

https://alastaira.wordpress.com/2013/11/12/importing-dem-terrain-heightmaps-for-unity-using-gdal/

## Notes

### SceneKit

* A basic scene puts the camera on the positive z-axis looking toward the origin, with the x-axis to the right, and the y-axis up.

---

The following is a draft of a blog post.

# Processing BigTIFF Images with Core Image

**Status:** Core Image can't handle signed 16-bit grayscale images, and so is useless for height maps.
For now we’re using GDAL wrapped in Swift.

Apple provides a number of image-manipulation and rendering APIs, and supports a number of
widely-used image formats, including TIFF. What you might not know is there’s a closely related
image format known colloquially as [BigTIFF](http://bigtiff.org), with the principal difference
being that it uses 8-byte offsets (and counts), whereas TIFF uses 4-byte offsets.

As you can imagine, 8-byte offsets means BigTIFF images can get very large. The Mars [MOLA](https://astrogeology.usgs.gov/search/map/Mars/Topography/HRSC_MOLA_Blend/Mars_HRSC_MOLA_BlendDEM_Global_200mp_v2)
digital elevation data is provided as an 11 GB TIFF file. macOS Preview won’t even open it, and if
an app does support BigTIFF (say, by using the aforereferenced open-source library), it has to be
very careful about how much of it is read into memory at once (particularly on iOS, where memory is
severely constrained).

The Apple APIs, particularly Core Image, make some effort to avoid loading a full image into memory.
But Core Image seems to be the only set of APIs that a third party (me and you, dear reader) to provide
data on demand, in chunks, directly from the source (probably a file).

## CIImageProvider

The key to this is `CIImageProvider`, a barely-documented and aggravatingly *informal* protocol. Were
it formal, it would look something like this:

```swift
@objc
protocol
CIImageProvider
{
    /**
        Comments taken from Objective-C header CoreImage/CIImageProvider.h:
        
        Callee should initialize the given bitmap with the subregion x,y
        width,height of the image. (this subregion is defined in the image's
        local coordinate space, i.e. the origin is the top left corner of
        the image).

        By default, this method will be called to requests the full image
        data regardless of what subregion is needed for the current render.
        All of the image is loaded or none of it is.

        If the `CIImage.providerTileSize` option is specified, then only the
        tiles that are needed are requested.

        Changing the virtual memory mapping of the supplied buffer (e.g. using
        vm_copy() to modify it) will give undefined behavior.
            
        - Parameters:
            - ioData: A pre-allocated buffer to contain the image data for the requested tile.
            - inRowbytes: Bytes per row of the supplied tile buffer.
            - inX: X-coordinate of the origin of the tile in image space.
            - inY: Y-coordinate of the origin of the tile in image space.
            - inWidth: Width of requested tile in image space.
            - inHeight: Height of requested tile in image space.
            - inInfo: Information supplied in CIImage constructor.
    */
    
    @objc
    func
    provideImageData(_ ioData: UnsafeMutableRawPointer,
                        bytesPerRow inRowbytes: Int,
                        origin inX: Int,
                             _ inY: Int,
                        size inWidth: Int,
                           _ inHeight: Int,
                        userInfo inInfo: Any?)
}
```

It’s used in conjunction with [`CIImage(imageProvider:size:_:format:colorSpace:options:)`](https://developer.apple.com/documentation/coreimage/ciimage/1437868-init):

```swift

```
