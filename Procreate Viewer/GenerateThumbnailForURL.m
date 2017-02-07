#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include <Foundation/Foundation.h>
#include <Cocoa/Cocoa.h>

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */


CGPoint getSwatchPosition(int index) {
    int column = index % 10;
    int row = (int)floor(index / 10);
    CGPoint position = CGPointMake((column * 22), 44 - (row * 22));
    return position;
}

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    
//    CFBundleRef bundle = QLThumbnailRequestGetGeneratorBundle(thumbnail);
//    CFURLRef logoURL = CFBundleCopyResourceURL(bundle, CFSTR("procreatelogo"), CFSTR("png"), NULL);
//    NSURL *logoNSURL = (__bridge NSURL *)logoURL;
//    NSImage *logo = [[NSImage alloc] initWithContentsOfURL:logoNSURL];
//    CGImageSourceRef source;
//    source = CGImageSourceCreateWithData((CFDataRef)[logo TIFFRepresentation], NULL);
//    CGImageRef logoRef = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    
    NSURL *URL = (__bridge NSURL *)url;
    NSString *filename = [[URL absoluteString] lastPathComponent];
    NSArray *filename_array = [filename componentsSeparatedByString:@"."];
    NSString *file_extension = [filename_array lastObject];

    NSData *thumbdata = nil;
    
    const CFStringRef kQLThumbnailPropertyIconFlavorKey = CFSTR("IconFlavor");
    typedef NS_ENUM(NSInteger, QLThumbnailIconFlavor)
    
    {
        kQLThumbnailIconPlainFlavor		= 0,
        kQLThumbnailIconShadowFlavor	= 1,
        kQLThumbnailIconBookFlavor		= 2,
        kQLThumbnailIconMovieFlavor		= 3,
        kQLThumbnailIconAddressFlavor	= 4,
        kQLThumbnailIconImageFlavor		= 5,
        kQLThumbnailIconGlossFlavor		= 6,
        kQLThumbnailIconSlideFlavor		= 7,
        kQLThumbnailIconSquareFlavor	= 8,
        kQLThumbnailIconBorderFlavor	= 9,
        // = 10,
        kQLThumbnailIconCalendarFlavor	= 11,
        kQLThumbnailIconPatternFlavor	= 12,
    };
    
    if ([file_extension isEqual: @"procreate"] || [file_extension isEqual: @"brush"]) {
        
        NSTask *unzipTask = [NSTask new];
        [unzipTask setLaunchPath:@"/usr/bin/unzip"];
        [unzipTask setStandardOutput:[NSPipe pipe]];
        [unzipTask setArguments:@[@"-p", [URL path], @"QuickLook/Thumbnail.png"]];
        [unzipTask launch];
        
        thumbdata = [[[unzipTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        NSBitmapImageRep * image = [NSBitmapImageRep imageRepWithData:thumbdata];

        NSDictionary *properties;
        
        if ([file_extension isEqual: @"procreate"]) {
            NSData *plistData = nil;
            
            NSTask *unzipPlist = [NSTask new];
            [unzipPlist setLaunchPath:@"/usr/bin/unzip"];
            [unzipPlist setStandardOutput:[NSPipe pipe]];
            [unzipPlist setArguments:@[@"-p", [URL path], @"Document.archive"]];
            [unzipPlist launch];
            
            plistData = [[[unzipPlist standardOutput] fileHandleForReading] readDataToEndOfFile];
            NSError *error;
            NSPropertyListFormat format;
            NSDictionary  *plist = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:&format error:&error];
            if(!plist){
                NSLog(@"Error: %@",error);
            }
            NSInteger flippedHorizontally = [[[plist objectForKey: @"$objects"][1] objectForKey: @"flippedHorizontally"] integerValue];
            NSInteger flippedVertically = [[[plist objectForKey: @"$objects"][1] objectForKey: @"flippedVertically"] integerValue];
            NSInteger orientation = [[[plist objectForKey: @"$objects"][1] objectForKey: @"orientation"] integerValue];
            
            properties = @{(__bridge NSString *) kQLThumbnailPropertyIconFlavorKey: @(kQLThumbnailIconImageFlavor) };
            CGImageRef imageref = image.CGImage;
            CGSize size = CGSizeMake(image.size.width, image.size.height);
            CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, size, true, (__bridge CFDictionaryRef)(properties));
            if (orientation == 1 || orientation == 2) {
                if (flippedHorizontally == 1 && flippedVertically == 0) {
                    CGContextTranslateCTM(ctxt, image.size.width, 0);
                    CGContextScaleCTM(ctxt, -1.0, 1.0);
                }
                if (flippedVertically == 1 && flippedHorizontally == 0) {
                    CGContextTranslateCTM(ctxt, 0.0, image.size.height);
                    CGContextScaleCTM(ctxt, 1.0, -1.0);
                }
                if (flippedHorizontally == 1 && flippedVertically == 1) {
                    CGContextTranslateCTM(ctxt, image.size.width, image.size.height);
                    CGContextScaleCTM(ctxt, -1.0, -1.0);
                }
            } else if (orientation == 3 || orientation == 4) {
                if (flippedHorizontally == 1 && flippedVertically == 0) {
                    CGContextTranslateCTM(ctxt, 0.0, image.size.height);
                    CGContextScaleCTM(ctxt, 1.0, -1.0);
                }
                if (flippedVertically == 1 && flippedHorizontally == 0) {
                    CGContextTranslateCTM(ctxt, image.size.width, 0);
                    CGContextScaleCTM(ctxt, -1.0, 1.0);
                }
                if (flippedHorizontally == 1 && flippedVertically == 1) {
                    CGContextTranslateCTM(ctxt, image.size.width, image.size.height);
                    CGContextScaleCTM(ctxt, -1.0, -1.0);
                }
            }
            CGContextDrawImage(ctxt, CGRectMake(0, 0, image.size.width, image.size.height), imageref);
            QLThumbnailRequestFlushContext(thumbnail, ctxt);
            CGContextRelease(ctxt);
        }
        
        if ([file_extension isEqual: @"brush"]) {
            properties = @{(__bridge NSString *) kQLThumbnailPropertyIconFlavorKey: @(kQLThumbnailIconGlossFlavor) };
        
            CGImageRef imageref = image.CGImage;
            
//            CGRect rect = CGRectMake(0, 0, image.size.width, image.size.width);
            CGSize size = CGSizeMake(image.size.width, image.size.height);
            
            CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, size, true, (__bridge CFDictionaryRef)(properties));
//            CGContextAddEllipseInRect(ctxt, rect);
//            CGContextClip(ctxt);
            CGContextSetRGBFillColor(ctxt, 0, 0, 0, 1);
            CGContextFillRect(ctxt, (CGRect){CGPointZero, size});
            CGContextDrawImage(ctxt, CGRectMake(20, 35, image.size.width - 40, image.size.height - 40), imageref);
//            CGContextDrawImage(ctxt, CGRectMake(size.width - 170, 20, 140, 140), logoRef);
//            CGContextDrawImage(ctxt, rect, logoRef);
            QLThumbnailRequestFlushContext(thumbnail, ctxt);
            CGContextRelease(ctxt);
        }
    }
    
    if ([file_extension isEqual: @"swatches"]) {
        NSTask *unzipTask = [NSTask new];
        [unzipTask setLaunchPath:@"/usr/bin/unzip"];
        [unzipTask setStandardOutput:[NSPipe pipe]];
        [unzipTask setArguments:@[@"-p", [URL path], @"Swatches.json"]];
        [unzipTask launch];
        
        thumbdata = [[[unzipTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        
        NSDictionary *properties;
        properties = @{(__bridge NSString *) kQLThumbnailPropertyIconFlavorKey: @(kQLThumbnailIconGlossFlavor) };
        
        NSError *jsonError;
        
        NSMutableArray *swatches_array = [[NSMutableArray alloc] init];
        swatches_array = [NSJSONSerialization JSONObjectWithData:thumbdata options:NSJSONReadingMutableLeaves error:&jsonError];
        if(jsonError) {
            // check the error description
            NSLog(@"json error : %@", [jsonError localizedDescription]);
        } else {
            // use the jsonDictionaryOrArray
            NSDictionary *swatch_dict = swatches_array[0];
            NSMutableArray *colors_list = [swatch_dict objectForKey:@"swatches"];
            
            CGSize swatch_thumb_size = CGSizeMake(218, 64);
            CGSize swatch_size = CGSizeMake(20, 20);
            CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, swatch_thumb_size, true, (__bridge CFDictionaryRef)(properties));
            CGContextAddRect(ctxt, CGRectMake(0,0,swatch_size.width,swatch_size.height));
            
            CGContextSetRGBFillColor(ctxt, 0.1, 0.1, 0.1, 1);
            
            CGContextFillRect(ctxt, (CGRect){CGPointZero, swatch_thumb_size});

            int index = 0;
            while (index < 30) {
                // Create NSColor from HSB values
                NSDictionary *color;
                if (index < [colors_list count]) {
                    color = colors_list[index];
                }
                if (![color isEqual:[NSNull null]]) {
                    CGFloat hue = [[color objectForKey:@"hue"] floatValue];
                    CGFloat saturation = [[color objectForKey:@"saturation"] floatValue];
                    CGFloat brightness = [[color objectForKey:@"brightness"] floatValue];
                    NSColor *swatch_color = [NSColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1.0];
                    CGContextSetRGBFillColor(ctxt, [swatch_color redComponent], [swatch_color greenComponent], [swatch_color blueComponent], 1.0);
                    
                    CGPoint position = getSwatchPosition(index);
                    CGContextFillRect(ctxt, (CGRect){position, swatch_size});
                } else {
                    CGContextSetRGBFillColor(ctxt, 0.05, 0.05, 0.05, 1);
                    CGPoint position = getSwatchPosition(index);
                    CGContextFillRect(ctxt, (CGRect){position, swatch_size});
                }
                index++;
            }
            
            QLThumbnailRequestFlushContext(thumbnail, ctxt);
            CGContextRelease(ctxt);
        }
    }

    
    return noErr;
    
}


void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail) { }
