#import "TourStopDetailsViewController.h"
#import "KGOTabbedControl.h"
#import "UIKit+KGOAdditions.h"
#import "TourDataManager.h"
#import "TourLense.h"
#import "TourLenseItem.h"
#import "TourLensePhotoItem.h"
#import "TourLenseVideoItem.h"
#import "TourLenseSlideShowItem.h"
#import "TourSlide.h"
#import "TourLenseHtmlItem.h"
#import <MediaPlayer/MediaPlayer.h>

#define LenseItemPhotoImageTag 100
#define LenseItemPhotoCaptionTag 101
#define LenseItemVideoViewContainer 200
#define LenseItemVideoCaptionTag 201
#define LenseItemSlideShowScrollViewTag 300
#define LenseItemSlideShowPageControlTag 301

@interface TourStopDetailsViewController (Private)

- (void)deallocViews;
- (void)setupLenseTabs;
- (void)displayContentForTabIndex:(NSInteger)tabIndex;
- (void)displayLenseContent:(TourLense *)lense;
- (void)loadSlideAtIndex:(NSInteger)slideIndex;
- (void)pageChanged;

@end

@implementation TourStopDetailsViewController
@synthesize tabControl;
@synthesize tourStop;

@synthesize scrollView;
@synthesize lenseContentView;
@synthesize webView;
@synthesize html;
@synthesize lenseItemPhotoView;
@synthesize lenseItemVideoView;
@synthesize lenseItemSlideShowView;
@synthesize slideShowScrollView;
@synthesize slides;
@synthesize slidesPageControl;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        moviePlayers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    self.tourStop = nil;
    self.slides = nil;
    [moviePlayers release];
    [self deallocViews];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad]; 
    [[TourDataManager sharedManager] populateTourStopDetails:self.tourStop];
    [self setupLenseTabs];
    self.tabControl.selectedTabIndex = 0;
    [self displayContentForTabIndex:0];
    self.tabControl.delegate = self;
    
    //[self.tabControl setMinimumWidth:mininumTabWidth forTabAtIndex:3];
    // Do any additional setup after loading the view from its nib.
}

- (void)deallocViews {
    self.tabControl.delegate = nil;
    self.tabControl = nil;
    self.lenseContentView = nil;
    self.scrollView = nil;
    self.webView.delegate = nil;
    self.webView = nil;
    self.slideShowScrollView.delegate = nil;
    self.slideShowScrollView = nil;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [self deallocViews];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)setupLenseTabs {
    self.tabControl.tabPadding = 1.0;
    self.tabControl.tabSpacing = 0.0;
    NSInteger totalTabs = 5;
    CGFloat mininumTabWidth = self.tabControl.frame.size.width / totalTabs;
    for (NSInteger tabIndex = 0; tabIndex < [[self.tourStop orderedLenses] count]; tabIndex++) {
        [self.tabControl insertTabWithImage:[UIImage imageWithPathName:@"modules/map/map-button-location"] atIndex:0 animated:NO];
    }
    
    for (NSInteger tabIndex = 0; tabIndex < [[self.tourStop orderedLenses] count]; tabIndex++) {
        [self.tabControl setMinimumWidth:mininumTabWidth forTabAtIndex:tabIndex];
    }
}

- (void)tabbedControl:(KGOTabbedControl *)control didSwitchToTabAtIndex:(NSInteger)index {
    [self displayContentForTabIndex:index];
}

- (void)displayContentForTabIndex:(NSInteger)tabIndex {
    TourLense *lense = [[self.tourStop orderedLenses] objectAtIndex:tabIndex];
    [self displayLenseContent:lense];
}

- (void)displayLenseContent:(TourLense *)aLense; {
    CGFloat lenseContentHeight = 0;
    // remove old content
    self.webView.delegate = nil;
    self.webView = nil;
    self.html = @"";
    [moviePlayers removeAllObjects];
    for(UIView *subview in self.lenseContentView.subviews) {
        [subview removeFromSuperview];
    }
    
    for (TourLenseItem *lenseItem in [aLense orderedItems]) {
        if([lenseItem isKindOfClass:[TourLenseHtmlItem class]]) {
            TourLenseHtmlItem *lenseHtmlItem = (TourLenseHtmlItem *)lenseItem;
            self.html = [self.html stringByAppendingString:lenseHtmlItem.html];
        }
        else if([lenseItem isKindOfClass:[TourLensePhotoItem class]]) {
            TourLensePhotoItem *lensePhotoItem = (TourLensePhotoItem *)lenseItem;
            [[NSBundle mainBundle] loadNibNamed:@"TourLensePhotoView" owner:self options:nil];
            UIView *photoView = self.lenseItemPhotoView;
            self.lenseItemPhotoView = nil;
            CGRect photoViewFrame = photoView.frame;
            photoViewFrame.origin.y = lenseContentHeight;
            photoView.frame = photoViewFrame;
            lenseContentHeight += photoView.frame.size.height;
            
            UIImageView *imageView = (UIImageView *)[photoView viewWithTag:LenseItemPhotoImageTag];
            imageView.image = [lensePhotoItem.photo image];
            UILabel *captionLabel = (UILabel *)[photoView viewWithTag:LenseItemPhotoCaptionTag];
            captionLabel.text = lensePhotoItem.title;
            
            [self.lenseContentView addSubview:photoView];
        }
        else if([lenseItem isKindOfClass:[TourLenseVideoItem class]]) {
            TourLenseVideoItem *lenseVideoItem = (TourLenseVideoItem *)lenseItem;
            [[NSBundle mainBundle] loadNibNamed:@"TourLenseVideoView" owner:self options:nil];
            UIView *videoView = self.lenseItemVideoView;
            self.lenseItemVideoView = nil;
            CGRect videoViewFrame = videoView.frame;
            videoViewFrame.origin.y = lenseContentHeight;
            videoView.frame = videoViewFrame;
            lenseContentHeight += videoView.frame.size.height;
            
            UIView *videoContainerView = [videoView viewWithTag:LenseItemVideoViewContainer];
            NSURL *videoURL = [NSURL fileURLWithPath:[lenseVideoItem.video mediaFilePath]];
            MPMoviePlayerController *player = [[[MPMoviePlayerController alloc] initWithContentURL:videoURL] autorelease];
            player.shouldAutoplay = NO;
            [moviePlayers addObject:player];
            [player.view setFrame:videoContainerView.bounds];
            [player.view setAutoresizingMask:videoContainerView.autoresizingMask];
            [videoContainerView addSubview:player.view];
                               
            UILabel *captionLabel = (UILabel *)[videoView viewWithTag:LenseItemVideoCaptionTag];
            captionLabel.text = lenseVideoItem.title;
            
            [self.lenseContentView addSubview:videoView];
        }
        else if([lenseItem isKindOfClass:[TourLenseSlideShowItem class]]) {
            TourLenseSlideShowItem *lenseSlideShowItem = (TourLenseSlideShowItem *)lenseItem;
            [[NSBundle mainBundle] loadNibNamed:@"TourLenseSlideShowView" owner:self options:nil];
            UIView *slideShowView = self.lenseItemSlideShowView;
            self.lenseItemSlideShowView = nil;
            self.slideShowScrollView = (UIScrollView *)[slideShowView viewWithTag:LenseItemSlideShowScrollViewTag];
            self.slideShowScrollView.decelerationRate = 0;
            self.slideShowScrollView.bounces = NO;
            self.slideShowScrollView.delegate = self;
            self.slides = [lenseSlideShowItem orderedSlides];
            [self.lenseContentView addSubview:slideShowView];
            lenseContentHeight += slideShowView.frame.size.height;
            
            self.slidesPageControl = (UIPageControl *)[slideShowView viewWithTag:LenseItemSlideShowPageControlTag];
            self.slidesPageControl.numberOfPages = self.slides.count;
            [self.slidesPageControl addTarget:self action:@selector(pageChanged) forControlEvents:UIControlEventValueChanged];
            [self loadSlideAtIndex:0];
        }
    }
    
    if([self.html length]) {
        CGFloat dummyInitialHeight = 200;
        CGRect webviewFrame = CGRectMake(0, lenseContentHeight, self.lenseContentView.frame.size.width, dummyInitialHeight);
        lenseContentHeight += dummyInitialHeight;
        self.webView = [[[UIWebView alloc] initWithFrame:webviewFrame] autorelease];
        self.webView.delegate = self;
        [self.webView loadHTMLString:self.html baseURL:nil];
        [self.lenseContentView addSubview:self.webView]; 
    }
    
    
    CGRect contentViewFrame = self.lenseContentView.frame;
    contentViewFrame.size.height = lenseContentHeight;
    self.lenseContentView.frame = contentViewFrame;
    self.scrollView.contentSize = CGSizeMake(
        self.scrollView.frame.size.width,
        self.lenseContentView.frame.origin.y + lenseContentHeight);
}

- (void)loadSlideView:(TourSlide *)slide atOffset:(CGFloat)offset {
    [[NSBundle mainBundle] loadNibNamed:@"TourLensePhotoView" owner:self options:nil];
    UIView *slideView = self.lenseItemPhotoView;
    self.lenseItemPhotoView = nil;
    
    UIImageView *imageView = (UIImageView *)[slideView viewWithTag:LenseItemPhotoImageTag];
    imageView.image = [slide.photo image];
    UILabel *captionLabel = (UILabel *)[slideView viewWithTag:LenseItemPhotoCaptionTag];
    captionLabel.text = slide.title;
    
    CGRect slideViewFrame = slideView.frame;
    slideViewFrame.origin.x = offset;
    slideView.frame = slideViewFrame;
    [self.slideShowScrollView addSubview:slideView];
}

- (void)pageChanged {
    [self loadSlideAtIndex:self.slidesPageControl.currentPage];
}

- (void)loadSlideAtIndex:(NSInteger)slideIndex {
    // remove all old subviews
    for(UIView *subview in [self.slideShowScrollView subviews]) {
        [subview removeFromSuperview];
    }
    
    CGFloat scrollViewWidth = self.slideShowScrollView.frame.size.width;
    CGFloat currentSlideHorizontalOffset = 0;
    if (slideIndex > 0) {
        [self loadSlideView:[self.slides objectAtIndex:(slideIndex-1)] atOffset:currentSlideHorizontalOffset];
        currentSlideHorizontalOffset += scrollViewWidth;
    }
    
    [self loadSlideView:[self.slides objectAtIndex:slideIndex] atOffset:currentSlideHorizontalOffset];
    self.slideShowScrollView.contentOffset = CGPointMake(currentSlideHorizontalOffset, 0);
    currentSlideHorizontalOffset += scrollViewWidth;
    
    if (slideIndex + 1 < self.slides.count) {
        [self loadSlideView:[self.slides objectAtIndex:(slideIndex+1)] atOffset:currentSlideHorizontalOffset];
        currentSlideHorizontalOffset += scrollViewWidth;
    }
    
    self.slideShowScrollView.contentSize = CGSizeMake(currentSlideHorizontalOffset, self.slideShowScrollView.frame.size.height);
    self.slidesPageControl.currentPage = slideIndex;
}

- (void)snapToSlide {
    CGFloat pageWidth = self.slideShowScrollView.frame.size.width;
    int page = floor((self.slideShowScrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1; 
    CGFloat remainder = self.slideShowScrollView.contentOffset.x - page * pageWidth;
    CGFloat epsilon = 1.0; // if remainder is small do not animate the scroll
                           // animating small scroll is not gaurenteed to call scrollViewDidEndScrolling
                           // so simulate the animated scrolling instead
    if (-epsilon < remainder && remainder < epsilon) {
        [self scrollViewDidEndScrollingAnimation:self.slideShowScrollView];
    } else {
        [self.slideShowScrollView scrollRectToVisible:CGRectMake(pageWidth * page, 0, pageWidth, self.slideShowScrollView.frame.size.height) animated:YES]; 
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    CGFloat pageWidth = self.slideShowScrollView.frame.size.width;
    int page = floor((self.slideShowScrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1; 
    
    int deltaPage;
    if(self.slidesPageControl.currentPage == 0) {
        deltaPage = page;
    } else {
        deltaPage = page - 1;
    }
    [self loadSlideAtIndex:self.slidesPageControl.currentPage + deltaPage];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)aScrollView willDecelerate:(BOOL)decelerate {
    if(!decelerate) {
        [self snapToSlide];
    }    
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)aScrollView {
    [self snapToSlide];
}

#pragma mark UIWebView delegate
- (void)webViewDidFinishLoad:(UIWebView *)aWebView {
    if(aWebView.superview) {
        CGSize size = [aWebView sizeThatFits:CGSizeZero];
        CGRect frame = aWebView.frame;
        CGFloat addedHeight = size.height - frame.size.height;
        frame.size.height = size.height;
        aWebView.frame = frame;
    
        // change scrollview height by how much the webview height changed
        CGSize contentSize = self.scrollView.contentSize;
        contentSize.height = contentSize.height + addedHeight;
        self.scrollView.contentSize = contentSize;
        
        // change lense content view height
        CGRect contentFrame = self.lenseContentView.frame;
        contentFrame.size.height = contentFrame.size.height + addedHeight;
        self.lenseContentView.frame = contentFrame;
    }
}

@end