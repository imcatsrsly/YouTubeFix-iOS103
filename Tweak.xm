#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// YouTubeFix v1.0.5 - Deep InnerTube body inspection and binary patching
// Fix for "Error loading" on iOS 10.3.3

static NSString * const kInnerTubeClientVersion = @"19.14.03";

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    
    NSString *urlString = request.URL.absoluteString;
    
    if ([urlString containsString:@"youtubei.googleapis.com"]) {
        
        NSMutableURLRequest *mutableRequest = [request mutableCopy];
        NSData *bodyData = request.HTTPBody;
        
        if (bodyData && bodyData.length > 0) {
            
            const uint8_t *bytes = (const uint8_t *)bodyData.bytes;
            BOOL isBinaryPlist = (bodyData.length > 8 && 
                                   bytes[0] == 0x62 && bytes[1] == 0x70 && 
                                   bytes[2] == 0x6C && bytes[3] == 0x69 && 
                                   bytes[4] == 0x73 && bytes[5] == 0x74);
            
            NSLog(@"YouTubeFix: InnerTube body: %lu bytes, binary=%d, first_bytes=%02X%02X%02X%02X", 
                  (unsigned long)bodyData.length, isBinaryPlist, bytes[0], bytes[1], bytes[2], bytes[3]);
            
            // Try binary plist first
            if (isBinaryPlist) {
                CFErrorRef error = NULL;
                CFPropertyListRef plist = CFPropertyListCreateWithData(kCFAllocatorDefault,
                                                                       (__bridge CFDataRef)bodyData,
                                                                       kCFPropertyListImmutable,
                                                                       NULL,
                                                                       &error);
                if (plist && CFGetTypeID(plist) == CFDictionaryGetTypeID()) {
                    CFMutableDictionaryRef mutDict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, (CFDictionaryRef)plist);
                    
                    // Get client dict
                    CFPropertyListRef clientRef = CFDictionaryGetValue(mutDict, CFSTR("client"));
                    if (clientRef && CFGetTypeID(clientRef) == CFDictionaryGetTypeID()) {
                        CFMutableDictionaryRef clientDict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, (CFDictionaryRef)clientRef);
                        
                        // Patch version
                        CFDictionarySetValue(clientDict, CFSTR("clientVersion"), (__bridge CFTypeRef)([kInnerTubeClientVersion copy]));
                        CFDictionarySetValue(clientDict, CFSTR("clientName"), CFSTR("ANDROID"));
                        
                        // Remove problematic keys
                        CFDictionaryRemoveValue(clientDict, CFSTR("deviceModel"));
                        CFDictionaryRemoveValue(clientDict, CFSTR("osName"));
                        CFDictionaryRemoveValue(clientDict, CFSTR("osVersion"));
                        
                        // Put back
                        CFDictionarySetValue(mutDict, CFSTR("client"), clientDict);
                        
                        // Serialize back to binary plist
                        CFDataRef newData = CFPropertyListCreateData(kCFAllocatorDefault,
                                                                      mutDict,
                                                                      kCFPropertyListBinaryFormat_v1_0,
                                                                      0,
                                                                      &error);
                        if (newData) {
                            [mutableRequest setHTTPBody:(__bridge NSData *)newData];
                            [mutableRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)CFDataGetLength(newData)] forHTTPHeaderField:@"Content-Length"];
                            [mutableRequest setValue:@"application/x-binary-plist" forHTTPHeaderField:@"Content-Type"];
                            NSLog(@"YouTubeFix: Successfully patched binary plist body!");
                            CFRelease(newData);
                        } else {
                            NSLog(@"YouTubeFix: Failed to serialize patched plist: %@", (__bridge NSError *)error);
                        }
                        CFRelease(clientDict);
                    }
                    CFRelease(mutDict);
                } else {
                    NSLog(@"YouTubeFix: Binary plist parse failed: %@", (__bridge NSError *)error);
                }
                if (plist) CFRelease(plist);
                if (error) CFRelease(error);
            } else {
                // Try JSON
                NSError *jsonError = nil;
                id bodyObj = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:&jsonError];
                if (bodyObj && [bodyObj isKindOfClass:[NSDictionary class]]) {
                    NSMutableDictionary *bodyDict = [bodyObj mutableCopy];
                    if (bodyDict[@"client"]) {
                        NSMutableDictionary *clientDict = [bodyDict[@"client"] mutableCopy];
                        clientDict[@"clientVersion"] = kInnerTubeClientVersion;
                        clientDict[@"clientName"] = @"ANDROID";
                        [clientDict removeObjectForKey:@"deviceModel"];
                        [clientDict removeObjectForKey:@"osVersion"];
                        bodyDict[@"client"] = clientDict;
                        
                        NSData *newBody = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
                        if (newBody) {
                            [mutableRequest setHTTPBody:newBody];
                            [mutableRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)newBody.length] forHTTPHeaderField:@"Content-Length"];
                            [mutableRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                            NSLog(@"YouTubeFix: Patched JSON body");
                        }
                    }
                } else {
                    NSLog(@"YouTubeFix: Body format unrecognized, first bytes: %02X %02X %02X %02X", bytes[0], bytes[1], bytes[2], bytes[3]);
                }
            }
        }
        
        return %orig(mutableRequest, completionHandler);
    }
    
    return %orig;
}

%end

__attribute__((constructor))
static void init() {
    NSLog(@"YouTubeFix v1.0.5: Deep InnerTube patcher loaded!");
}
