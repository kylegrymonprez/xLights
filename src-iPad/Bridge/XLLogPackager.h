//
//  XLLogPackager.h
//  xLights-iPadLib
//
//  Builds a "Package Logs" zip suitable for sharing via
//  UIActivityViewController. Bundles xLights.log + rotated siblings,
//  MetricKit diagnostics JSON, the active show-folder XML, the
//  currently-loaded sequence, a threads dump, and a device-info
//  sidecar.
//

#pragma once

#import <Foundation/Foundation.h>

@class XLSequenceDocument;

NS_ASSUME_NONNULL_BEGIN

@interface XLLogPackager : NSObject

// Build the zip and return its file:// URL. `document` may be nil
// (no show folder loaded). The returned zip lives in NSTemporaryDirectory
// — the caller should delete it once the share sheet dismisses.
//
// Synchronous; safe to call from a background queue. Throws on
// unrecoverable failure (e.g. NSTemporaryDirectory write error).
+ (nullable NSURL*)packageLogsForDocument:(nullable XLSequenceDocument*)document
                                    error:(NSError* _Nullable* _Nullable)outError
    NS_SWIFT_NAME(packageLogs(for:));

@end

NS_ASSUME_NONNULL_END
