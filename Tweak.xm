#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>

// YouTube and Instagram fix for iOS 10.3.3

// Hook into NSURLConnection to bypass certificate pinning
%hook NSURLConnection
- (void)setDelegate:(id)delegate {
    %orig;
}

+ (BOOL)canHandleRequest:(NSURLRequest *)request {
    return %orig;
}
%end

// Hook into NSURLSession for iOS 9+
%hook NSURLSession
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    // Accept all certificates - bypass pinning
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        return;
    }
    %orig;
}
%end

// Hook UIWebView to allow all content
%hook UIWebView
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSLog(@"YouTubeFix: Loading %@", request.URL);
    return %orig;
}
%end

// Hook into YouTube's video player
%hook YTPlayerView
- (void)loadWithVideoId:(NSString *)videoId {
    NSLog(@"YouTubeFix: Loading video %@", videoId);
    %orig;
}
%end

// Hook Instagram's NSURLSession for login
%hook NSURLSessionTask
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        return;
    }
    %orig;
}
%end

// Log when app launches
__attribute__((constructor))
static void init() {
    NSLog(@"YouTubeFix: Tweak loaded on iOS 10.3.3!");
}
