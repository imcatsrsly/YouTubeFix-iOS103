#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// YouTubeFix v1.0.3 - InnerTube API Version Patcher
// Fix for "Error loading" on iOS 10.3.3

// Target API version - use a more recent one that's still compatible
#define INNER_TUBE_CLIENT_VERSION "19.14.03"
#define INNER_TUBE_API_KEY "AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc"

// Hook NSURLSession to patch InnerTube requests
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    
    NSString *urlString = request.URL.absoluteString;
    
    // Check if this is an InnerTube API request
    if ([urlString containsString:@"youtubei.googleapis.com"]) {
        NSLog(@"YouTubeFix: Caught InnerTube request: %@", urlString);
        
        // Clone the mutable request
        NSMutableURLRequest *mutableRequest = [request mutableCopy];
        
        // Get HTTP body
        NSData *bodyData = request.HTTPBody;
        if (bodyData) {
            NSError *jsonError = nil;
            NSMutableDictionary *bodyDict = [NSJSONSerialization JSONObjectWithData:bodyData options:NSJSONReadingMutableContainers error:&jsonError];
            
            if (bodyDict && !jsonError) {
                // Patch client version
                if ([bodyDict objectForKey:@"client"]) {
                    NSMutableDictionary *clientDict = [[bodyDict objectForKey:@"client"] mutableCopy];
                    NSString *oldVersion = [clientDict objectForKey:@"clientVersion"];
                    [clientDict setObject:INNER_TUBE_CLIENT_VERSION forKey:@"clientVersion"];
                    [clientDict setObject:@"ANDROID" forKey:@"clientName"];  // Force ANDROID client
                    [clientDict removeObjectForKey:@"deviceModel"];
                    [clientDict removeObjectForKey:@"osName"];
                    [clientDict removeObjectForKey:@"osVersion"];
                    [bodyDict setObject:clientDict forKey:@"client"];
                    
                    NSLog(@"YouTubeFix: Patched clientVersion from %@ to %@", oldVersion, INNER_TUBE_CLIENT_VERSION);
                    
                    // Re-encode the body
                    NSData *newBodyData = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
                    if (newBodyData) {
                        [mutableRequest setHTTPBody:newBodyData];
                        [mutableRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)newBodyData.length] forHTTPHeaderField:@"Content-Length"];
                    }
                }
            } else {
                NSLog(@"YouTubeFix: Could not parse JSON body: %@", jsonError.localizedDescription);
            }
        }
        
        // Use the patched request
        return %orig(mutableRequest, completionHandler);
    }
    
    return %orig;
}

%end

// Also hook NSURLConnection for completeness
%hook NSURLConnection

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    NSString *urlString = request.URL.absoluteString;
    
    if ([urlString containsString:@"youtubei.googleapis.com"]) {
        NSMutableURLRequest *mutableRequest = [request mutableCopy];
        NSData *bodyData = request.HTTPBody;
        
        if (bodyData) {
            NSError *jsonError = nil;
            NSMutableDictionary *bodyDict = [NSJSONSerialization JSONObjectWithData:bodyData options:NSJSONReadingMutableContainers error:&jsonError];
            
            if (bodyDict && !jsonError && [bodyDict objectForKey:@"client"]) {
                NSMutableDictionary *clientDict = [[bodyDict objectForKey:@"client"] mutableCopy];
                [clientDict setObject:INNER_TUBE_CLIENT_VERSION forKey:@"clientVersion"];
                [clientDict setObject:@"ANDROID" forKey:@"clientName"];
                [clientDict removeObjectForKey:@"deviceModel"];
                [bodyDict setObject:clientDict forKey:@"client"];
                
                NSData *newBody = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
                if (newBody) {
                    [mutableRequest setHTTPBody:newBody];
                }
                NSLog(@"YouTubeFix[NSURLConnection]: Patched InnerTube request");
            }
        }
        
        return %orig(mutableRequest, delegate);
    }
    
    return %orig;
}

%end

__attribute__((constructor))
static void init() {
    NSLog(@"YouTubeFix v1.0.3: InnerTube API Patcher loaded!");
    NSLog(@"YouTubeFix: Targeting API version %@", INNER_TUBE_CLIENT_VERSION);
}
