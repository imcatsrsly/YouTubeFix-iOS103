#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// YouTube URL Logger for iOS 10.3.3

// Hook NSURLConnection to log requests
%hook NSURLConnection
- (void)start {
    NSLog(@"YouTubeFix[NSURLConnection-start]");
    %orig;
}

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    NSLog(@"YouTubeFix[NSURLConnection+]: %@ %@", request.HTTPMethod, request.URL.absoluteString);
    return %orig;
}
%end

// Hook NSURLSession for iOS 9+
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSLog(@"YouTubeFix[NSURLSession]: %@ %@", request.HTTPMethod, request.URL.absoluteString);
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSLog(@"YouTubeFix[NSURLSession+]: %@", url.absoluteString);
    return %orig;
}
%end

// Hook NSURLSessionTask to log when task starts
%hook NSURLSessionTask
- (void)resume {
    NSLog(@"YouTubeFix[Task resume]: %@", self.originalRequest.URL.absoluteString);
    %orig;
}
%end

// Hook NSMutableURLRequest 
%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    NSLog(@"YouTubeFix[MutableURL]: %@", url.absoluteString);
    %orig;
}
%end

__attribute__((constructor))
static void init() {
    NSLog(@"YouTubeFix: URL Logger loaded!");
}
