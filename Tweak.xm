#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// YouTubeFix v1.0.4 - InnerTube API Version Patcher
// Fix for "Error loading" on iOS 10.3.3

// Target API version - use a more recent one that's still compatible
static NSString * const kInnerTubeClientVersion = @"19.14.03";
static NSString * const kInnerTubeApiKey = @"";

// Hook NSURLSession to patch InnerTube requests
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    
    NSString *urlString = request.URL.absoluteString;
    
    // Check if this is an InnerTube API request
    if ([urlString containsString:@"youtubei.googleapis.com"]) {
        
        NSMutableURLRequest *mutableRequest = [request mutableCopy];
        NSData *bodyData = request.HTTPBody;
        
        if (bodyData && bodyData.length > 0) {
            // Try to parse as JSON first
            NSError *jsonError = nil;
            NSMutableDictionary *bodyDict = [NSJSONSerialization JSONObjectWithData:bodyData options:NSJSONReadingMutableContainers error:&jsonError];
            
            if (bodyDict && !jsonError && [bodyDict isKindOfClass:[NSDictionary class]]) {
                // Successfully parsed as JSON
                BOOL patched = NO;
                
                if ([bodyDict objectForKey:@"client"]) {
                    id clientObj = [bodyDict objectForKey:@"client"];
                    if ([clientObj isKindOfClass:[NSDictionary class]]) {
                        NSMutableDictionary *clientDict = [clientObj mutableCopy];
                        NSString *oldVersion = [clientDict objectForKey:@"clientVersion"];
                        [clientDict setObject:kInnerTubeClientVersion forKey:@"clientVersion"];
                        [clientDict setObject:@"ANDROID" forKey:@"clientName"];
                        // Remove fields that might cause issues
                        [clientDict removeObjectForKey:@"deviceModel"];
                        [clientDict removeObjectForKey:@"osName"];
                        [clientDict removeObjectForKey:@"osVersion"];
                        [clientDict removeObjectForKey:@"platform"];
                        [clientDict removeObjectForKey:@"hl"];
                        [bodyDict setObject:clientDict forKey:@"client"];
                        patched = YES;
                        
                        NSLog(@"YouTubeFix: Patched JSON body (clientVersion: %@ -> %@)", oldVersion, kInnerTubeClientVersion);
                    }
                }
                
                if (patched) {
                    NSData *newBody = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
                    if (newBody) {
                        [mutableRequest setHTTPBody:newBody];
                        [mutableRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)newBody.length] forHTTPHeaderField:@"Content-Length"];
                        [mutableRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                    }
                }
            } else {
                // Not JSON - might be protobuf or binary format
                // Try as property list
                NSError *plistError = nil;
                NSMutableDictionary *plistDict = [NSPropertyListSerialization propertyListWithData:bodyData options:NSPropertyListMutableContainers format:NULL error:&plistError];
                
                if (plistDict && !plistError && [plistDict isKindOfClass:[NSDictionary class]]) {
                    if ([plistDict objectForKey:@"client"]) {
                        NSMutableDictionary *clientDict = [[plistDict objectForKey:@"client"] mutableCopy];
                        NSString *oldVersion = [clientDict objectForKey:@"clientVersion"];
                        [clientDict setObject:kInnerTubeClientVersion forKey:@"clientVersion"];
                        [clientDict setObject:@"ANDROID" forKey:@"clientName"];
                        [plistDict setObject:clientDict forKey:@"client"];
                        
                        NSData *newBody = [NSPropertyListSerialization dataWithPropertyList:plistDict format:NSPropertyListXMLFormat_v1_0 options:0 error:&plistError];
                        if (newBody) {
                            [mutableRequest setHTTPBody:newBody];
                            [mutableRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)newBody.length] forHTTPHeaderField:@"Content-Length"];
                        }
                        NSLog(@"YouTubeFix: Patched plist body (clientVersion: %@)", oldVersion);
                    }
                } else {
                    // Binary format - can't easily patch
                    // Just log the raw data info
                    NSLog(@"YouTubeFix: InnerTube body is binary (%lu bytes), skipping patch", (unsigned long)bodyData.length);
                }
            }
        }
        
        return %orig(mutableRequest, completionHandler);
    }
    
    return %orig;
}

%end

// Hook NSURLConnection for completeness
%hook NSURLConnection

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    NSString *urlString = request.URL.absoluteString;
    
    if ([urlString containsString:@"youtubei.googleapis.com"]) {
        NSMutableURLRequest *mutableRequest = [request mutableCopy];
        NSData *bodyData = request.HTTPBody;
        
        if (bodyData && bodyData.length > 0) {
            NSError *jsonError = nil;
            NSMutableDictionary *bodyDict = [NSJSONSerialization JSONObjectWithData:bodyData options:NSJSONReadingMutableContainers error:&jsonError];
            
            if (bodyDict && !jsonError && [bodyDict objectForKey:@"client"]) {
                NSMutableDictionary *clientDict = [[bodyDict objectForKey:@"client"] mutableCopy];
                NSString *oldVersion = [clientDict objectForKey:@"clientVersion"];
                [clientDict setObject:kInnerTubeClientVersion forKey:@"clientVersion"];
                [clientDict setObject:@"ANDROID" forKey:@"clientName"];
                [bodyDict setObject:clientDict forKey:@"client"];
                
                NSData *newBody = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
                if (newBody) {
                    [mutableRequest setHTTPBody:newBody];
                }
                NSLog(@"YouTubeFix[NSURLConnection]: Patched plist body (clientVersion: %@ -> %@)", oldVersion, kInnerTubeClientVersion);
            }
        }
        
        return %orig(mutableRequest, delegate);
    }
    
    return %orig;
}

%end

__attribute__((constructor))
static void init() {
    NSLog(@"YouTubeFix v1.0.4: InnerTube API Patcher loaded!");
    NSLog(@"YouTubeFix: Targeting API version %@", kInnerTubeClientVersion);
}
