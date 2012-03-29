// this class represents a request made to the configured Kurogo server.

#import <Foundation/Foundation.h>

@class KGORequest;

// blocks to operate on objects created from JSON in the background
// e.g. create core data objects
typedef NSInteger (^JSONObjectHandler)(id);

@protocol KGORequestDelegate <NSObject>

/* notifies the receiver that this request is no longer self-retained.
 * because requests are self-retaining, delegates' dealloc methods must
 * ensure that all requests' delegates are set to nil, preferably
 * by calling -cancel to terminate the associated url connection.
 */
- (void)requestWillTerminate:(KGORequest *)request;

@optional

- (void)request:(KGORequest *)request didFailWithError:(NSError *)error;

// generally delegates implement exactly one of the following per request
- (void)request:(KGORequest *)request didHandleResult:(NSInteger)returnValue; // retValue could be number of records updated
- (void)request:(KGORequest *)request didReceiveResult:(id)result; // no need to check result type since this is checked via expectedResponseType

// for showing determinate loading indicators. progress is between 0 and 1
- (void)request:(KGORequest *)request didMakeProgress:(CGFloat)progress;
- (void)requestDidReceiveResponse:(KGORequest *)request;

- (void)requestResponseUnchanged:(KGORequest *)request;

@end


extern NSString * const KGORequestErrorDomain;
// wrapper for most common kCFURLError constants, plus custom states
// TODO: coordinate with server-side error messages and 
// HTTP status codes
typedef enum {
	KGORequestErrorBadRequest,
	KGORequestErrorForbidden,
	KGORequestErrorUnreachable,
	KGORequestErrorDeviceOffline,
	KGORequestErrorTimeout,
	KGORequestErrorBadResponse,
    KGORequestErrorResponseTypeMismatch,
	KGORequestErrorVersionMismatch,
	KGORequestErrorInterrupted,
	KGORequestErrorServerMessage,
	KGORequestErrorOther
} KGORequestErrorCode;

@interface KGORequest : NSObject {
	
	NSMutableData *_data;
	NSURLConnection *_connection;
    long long _contentLength;
    
	NSThread *_thread;
}

@property(nonatomic, retain) NSString *module;
@property(nonatomic, retain) NSString *path;
@property(nonatomic, retain) NSDictionary *getParams;
@property(nonatomic, retain) NSDictionary *postParams;
@property(nonatomic, retain) NSDate *ifModifiedSince; // If-Modified-Since header

// maximum and minimum supported API versions. if either of them is
// different from the preferred version, set them manually after
// the request object is created.
@property(nonatomic) NSInteger apiMaxVersion;
@property(nonatomic) NSInteger apiMinVersion;

@property(nonatomic) NSTimeInterval minimumDuration;

@property(nonatomic, retain) NSString *format; // default is json
@property(nonatomic) NSURLRequestCachePolicy cachePolicy; // default is NSURLRequestReloadIgnoringLocalAndRemoteCacheData
@property(nonatomic) NSTimeInterval timeout; // default is 30 seconds

@property(nonatomic, assign) Class expectedResponseType; // default is NSDictionary
@property(nonatomic, copy) JSONObjectHandler handler;

@property(nonatomic, retain) id result;

// urls are of the form
// https://<kurogo-server>/<apipath>/<module>/<path>?<key>=<value>
// https://kurogo.hq.modolabs.com/rest/people/search?q=Some+Guy
// https://kurogo.hq.modolabs.com/rest/hello? (special case)
@property(nonatomic, retain) NSURL *url;
@property(nonatomic, assign) id<KGORequestDelegate> delegate;

- (BOOL)connect;
- (BOOL)connectWithResponseType:(Class)responseType callback:(JSONObjectHandler)callback;
- (BOOL)connectWithCallback:(JSONObjectHandler)callback;
- (void)cancel;  // call to stop receiving messages

- (void)removeFromCache; // for requests that have minumumDuration set and failed after passing all sanity checks

+ (KGORequestErrorCode)internalCodeForNSError:(NSError *)error;
+ (NSString *)userAgentString;

@end
