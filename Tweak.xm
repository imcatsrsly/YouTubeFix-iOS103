#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// YouTube URL Logger for iOS 10.3.3
// Logs all network requests made by YouTube

// Hook NSURLConnection to log requests
%hook NSURLConnection
- (void)start {
    NSURLRequest *req = self;
    if (req) {
        NSLog(@"YouTubeFix[NSURLConnection]: %@ %@", req.HTTPMethod, req.URL.absoluteString);
    }
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
    NSLog(@"YouTubeFix[Task]: %@ %@", self.taskDescription, self.originalRequest.URL.absoluteString);
    %orig;
}
%end

// Hook NSMutableURLRequest to see modifications
%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    NSLog(@"YouTubeFix[MutableURL]: setting URL to %@", url.absoluteString);
    %orig;
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    NSLog(@"YouTubeFix[Header]: %@ = %@", field, value);
    %orig;
}
%end

// Hook CFNetwork to catch lower-level stuff
%hook NSURLResponse
- (NSString *)URL {
    NSString *url = %orig;
    if (url) {
        NSLog(@"YouTubeFix[Response URL]: %@", url);
    }
    return url;
}
%end

__attribute__((constructor))
static void init() {
    NSLog(@"YouTubeFix: URL Logger loaded on iOS 10.3.3!");
}
