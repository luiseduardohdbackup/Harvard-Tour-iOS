#import "KGOScrollingTabstrip.h"
#import "KGOSearchBar.h"
#import "KGOSearchDisplayController.h"
#import "KGOTheme.h"
#import "KGOAppDelegate+ModuleAdditions.h"
#import "UIKit+KGOAdditions.h"

#define SCROLL_TAB_HORIZONTAL_MARGIN 5.0
#define SCROLL_TAB_HORIZONTAL_PADDING 5.0
#define MINIMUM_BUTTON_WIDTH 36.0

// if a tabstrip has more than this number of buttons they will probably
// have other problems before button index collision becomes an issue
NSInteger const kBookmarkButtonIndex = 8765913;

@interface KGOScrollingTabstrip (Private)

- (void)showHideScrollButtons;
- (void)sideButtonPressed:(id)sender;
- (void)buttonPressed:(id)sender;

@end


@implementation KGOScrollingTabstrip

@synthesize delegate, searchBar, searchController;

- (id)initWithFrame:(CGRect)frame delegate:(id<KGOScrollingTabstripDelegate>)delegate buttonTitles:(NSString *)title, ... {
    self = [super initWithFrame:frame];
    if (self) {
        _buttons = [[NSMutableArray alloc] init];
        
        va_list args;
        va_start(args, title);
        for (NSString *arg = title; arg != nil; arg = va_arg(args, NSString*)) {
            [self addButtonWithTitle:title];
        }
        va_end(args);
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _buttons = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _buttons = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setShowsSearchButton:(BOOL)shows {
    if (shows != (_searchButton != nil)) {
        if (shows) {
            [_searchButton release];
            _searchButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];

            UIImage *image = [UIImage imageWithPathName:@"common/search.png"];
            [_searchButton setImage:image forState:UIControlStateNormal];
            _searchButton.adjustsImageWhenHighlighted = NO;
            // ensure that button is wide enough to tap
            CGFloat buttonWidth = image.size.width;
            CGFloat insetWidth = 0;
            if (buttonWidth < MINIMUM_BUTTON_WIDTH) {
                insetWidth = floor((MINIMUM_BUTTON_WIDTH - buttonWidth) / 2);
                buttonWidth = MINIMUM_BUTTON_WIDTH;
            }
            _searchButton.imageEdgeInsets = UIEdgeInsetsMake(-1, insetWidth, 0, insetWidth);
            CGFloat yOrigin = floor((self.frame.size.height - image.size.height) / 2);
            _searchButton.frame = CGRectMake(0, yOrigin, buttonWidth, image.size.height);
            [_searchButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        } else {
            [_searchButton release];
            _searchButton = nil;
        }
    }
}

- (BOOL)showsSearchButton {
    return _searchButton != nil;
}

- (void)setShowsBookmarkButton:(BOOL)shows {
    if (shows != (_bookmarkButton != nil)) {
        
        if (shows) {
            [_bookmarkButton release];
            _bookmarkButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
            UIImage *image = [UIImage imageWithPathName:@"common/bookmark.png"];
            [_bookmarkButton setImage:image forState:UIControlStateNormal];
            // ensure that button is wide enough to tap
            CGFloat buttonWidth = image.size.width;
            CGFloat insetWidth = 0;
            if (buttonWidth < MINIMUM_BUTTON_WIDTH) {
                insetWidth = floor((MINIMUM_BUTTON_WIDTH - buttonWidth) / 2);
                buttonWidth = MINIMUM_BUTTON_WIDTH;
            }
            
            UIImage *stretchableButtonImage = [[UIImage imageWithPathName:@"common/scrolltabs-selected.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
            [_bookmarkButton setBackgroundImage:nil forState:UIControlStateNormal];
            [_bookmarkButton setBackgroundImage:stretchableButtonImage forState:UIControlStateHighlighted];

            _bookmarkButton.imageEdgeInsets = UIEdgeInsetsMake(0, insetWidth, 1, insetWidth); // center image vertically
            CGFloat yOrigin = floor((self.frame.size.height - stretchableButtonImage.size.height) / 2);
            _bookmarkButton.frame = CGRectMake(0, yOrigin, buttonWidth, stretchableButtonImage.size.height);
            [_bookmarkButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        } else {
            [_bookmarkButton release];
            _bookmarkButton = nil;
        }
    }
}

- (BOOL)showsBookmarkButton {
    return _bookmarkButton != nil;
}

- (void)addButtonWithTitle:(NSString *)title {
    UIButton *aButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
    [aButton setTitle:title forState:UIControlStateNormal];
    [aButton setTitleColor:[[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertyScrollTab]
                  forState:UIControlStateNormal];
    [aButton setTitleColor:[[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertyScrollTabSelected]
                  forState:UIControlStateHighlighted];
    
    aButton.titleLabel.font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyScrollTab];
    aButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 1.0, 0); // needed to center text vertically within button
    CGSize size = [aButton.titleLabel.text sizeWithFont:aButton.titleLabel.font];

	UIImage *stretchableButtonImage = [[UIImage imageWithPathName:@"common/scrolltabs-selected.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    [aButton setBackgroundImage:nil forState:UIControlStateNormal];
    [aButton setBackgroundImage:stretchableButtonImage forState:UIControlStateHighlighted];
    
    CGFloat yOrigin = floor((self.frame.size.height - stretchableButtonImage.size.height) / 2);
    aButton.frame = CGRectMake(0, yOrigin, size.width + 2 * SCROLL_TAB_HORIZONTAL_PADDING, stretchableButtonImage.size.height);
    [aButton addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    [_buttons addObject:aButton];
}

- (NSString *)buttonTitleAtIndex:(NSUInteger)index {
    UIButton *button = [_buttons objectAtIndex:index];
    if (button == _searchButton || button == _bookmarkButton) {
        return nil;
    }
    return [button titleForState:UIControlStateNormal];
}

- (NSUInteger)numberOfButtons {
    return [_buttons count];
}

- (void)removeAllRegularButtons
{
    _pressedButton = nil;
    for (UIButton *aButton in _buttons) {
        [aButton removeFromSuperview];
    }
    [_buttons release];
    _buttons = [[NSMutableArray alloc] init];
}

// TODO: get config values for tabstrip
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!_backgroundImageView) {
        UIImage *backgroundImage = [UIImage imageWithPathName:@"common/scrolltabs-background.png"];
        _backgroundImageView = [[[UIImageView alloc] initWithImage:[backgroundImage stretchableImageWithLeftCapWidth:0 topCapHeight:0]] autorelease];
        _backgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _backgroundImageView.frame = self.bounds;
        [self addSubview:_backgroundImageView];
    }

    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.delegate = self;
        _scrollView.scrollsToTop = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        _contentView = [[UIView alloc] initWithFrame:self.bounds];
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        
        [_scrollView addSubview:_contentView];
        [self addSubview:_scrollView];
    }
    
    CGFloat xOffset = SCROLL_TAB_HORIZONTAL_MARGIN;
    NSMutableArray *allButtons = [NSMutableArray array];
    if (_searchButton) {
        [allButtons addObject:_searchButton];
    }
    if (_bookmarkButton) {
        [allButtons addObject:_bookmarkButton];
    }
    [allButtons addObjectsFromArray:_buttons];
    
    NSArray *oldButtons = [_contentView subviews];
    UIView *oldButton = nil;
    for (oldButton in oldButtons) {
        [oldButton removeFromSuperview];
    }
    [_contentView setFrame:CGRectMake(0, 0, 320, 44)];
    
    for (UIButton *aButton in allButtons) {
        aButton.frame = CGRectMake(xOffset, aButton.frame.origin.y, aButton.frame.size.width, aButton.frame.size.height);
        xOffset += aButton.frame.size.width + SCROLL_TAB_HORIZONTAL_MARGIN;
        [_contentView addSubview:aButton];
        if (_contentView.frame.size.width < xOffset) {
            _contentView.frame = CGRectMake(_contentView.frame.origin.x, _contentView.frame.origin.y, xOffset, _contentView.frame.size.height);
            _scrollView.contentSize = _contentView.frame.size;
        }
    }
    
    // allow a few pixel overflow before we start adding scroll buttons
    // TODO: stop cheating
    if (_contentView.frame.size.width > self.frame.size.width + 10) {
        if (!_leftScrollButton) {
            UIImage *leftScrollImage = [UIImage imageWithPathName:@"common/scrolltabs-leftarrow.png"];
            CGRect imageFrame = CGRectMake(0, 0, leftScrollImage.size.width, leftScrollImage.size.height);
            _leftScrollButton = [UIButton buttonWithType:UIButtonTypeCustom];
            _leftScrollButton.frame = imageFrame;
            _leftScrollButton.hidden = YES;
            [_leftScrollButton setImage:leftScrollImage forState:UIControlStateNormal];
            [_leftScrollButton addTarget:self action:@selector(sideButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            [self addSubview:_leftScrollButton];
        }
        
        if (!_rightScrollButton) {
            UIImage *rightScrollImage = [UIImage imageWithPathName:@"common/scrolltabs-rightarrow.png"];
            CGRect imageFrame = CGRectMake(self.frame.size.width - rightScrollImage.size.width,0,rightScrollImage.size.width,rightScrollImage.size.height);
            _rightScrollButton = [UIButton buttonWithType:UIButtonTypeCustom];
            _rightScrollButton.frame = imageFrame;
            if (_scrollView.contentSize.width > _scrollView.frame.size.width) {
                _rightScrollButton.hidden = NO;
            } else {
                _rightScrollButton.hidden = YES;
            }
            _rightScrollButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            [_rightScrollButton setImage:rightScrollImage forState:UIControlStateNormal];
            [_rightScrollButton addTarget:self action:@selector(sideButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            [self addSubview:_rightScrollButton];
        }
        
        // only do this if we start the scroller in a different position
        //[self showHideScrollButtons];
    } else {
        if (_leftScrollButton) {
            _leftScrollButton.hidden = YES;
        }
        if (_rightScrollButton) {
            _rightScrollButton.hidden = YES;
        }
    }
    
    if (self.searchBar) {
        [self bringSubviewToFront:self.searchBar];
    }
}

- (void)selectButtonAtIndex:(NSUInteger)index {
    if (index == [self bookmarkButtonIndex]) {
        [self buttonPressed:_bookmarkButton];
    } else if (index < _buttons.count) {
        UIButton *button = [_buttons objectAtIndex:index];
        [self buttonPressed:button];
    }
}

- (NSInteger)indexOfSelectedButton
{
    NSInteger index = NSNotFound;
    if (_buttons && _pressedButton) {
        index = [_buttons indexOfObject:_pressedButton];
    }
    return index;
}

- (NSInteger)bookmarkButtonIndex
{
    return kBookmarkButtonIndex;
}

- (void)buttonPressed:(id)sender {
    UIButton *pressedButton = (UIButton *)sender;
    
    if (pressedButton == _searchButton) {
        if ([self.delegate respondsToSelector:@selector(tabstripSearchButtonPressed:)]) {
            [self.delegate tabstripSearchButtonPressed:self];
        } else {
            [self showSearchBarAnimated:YES]; // default action
        }

    } else {
        if (pressedButton != _pressedButton) {
            
            [_pressedButton setTitleColor:[UIColor colorWithHexString:@"#E0E0E0"] forState:UIControlStateNormal];
            [_pressedButton setBackgroundImage:nil forState:UIControlStateNormal];
            
            UIImage *buttonImage = [UIImage imageWithPathName:@"common/scrolltabs-selected.png"];
            UIImage *stretchableButtonImage = [buttonImage stretchableImageWithLeftCapWidth:15 topCapHeight:0];
            
            [pressedButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [pressedButton setBackgroundImage:stretchableButtonImage forState:UIControlStateNormal];
            
            _pressedButton = pressedButton;
        }
        
        if (_pressedButton == _bookmarkButton) {
            if ([self.delegate respondsToSelector:@selector(tabstripBookmarkButtonPressed:)]) {
                [self.delegate tabstripBookmarkButtonPressed:self];
            }
            
        } else {
            NSUInteger index = [_buttons indexOfObject:_pressedButton];
            if (index != NSNotFound)
                [self.delegate tabstrip:self clickedButtonAtIndex:index];
        }
    }
}

- (void)showSearchBarAnimated:(BOOL)animated
{
    if ([self.delegate conformsToProtocol:@protocol(KGOScrollingTabstripSearchDelegate)]) {
        id<KGOScrollingTabstripSearchDelegate> strictDelegate = (id<KGOScrollingTabstripSearchDelegate>)self.delegate;
        if ([strictDelegate tabstripShouldShowSearchDisplayController:self]) {
            if (!self.searchBar) {
                UIViewController *vc = [strictDelegate viewControllerForTabstrip:self];
                
                self.searchBar = [[[KGOSearchBar alloc] initWithFrame:self.frame] autorelease];
                self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                self.searchBar.alpha = 0.0;
                if (!self.searchController) {
                    self.searchController = [[[KGOSearchDisplayController alloc] initWithSearchBar:self.searchBar
                                                                                          delegate:strictDelegate
                                                                                contentsController:vc] autorelease];
                    
                    if ([KGO_SHARED_APP_DELEGATE() navigationStyle] == KGONavigationStyleTabletSidebar) {
                        self.searchController.showsSearchOverlay = NO;
                    }
                }
                [self addSubview:self.searchBar];
            }
            
            [self bringSubviewToFront:self.searchBar];
            
            if (animated) {
                __block KGOScrollingTabstrip *blockSelf = self;
                [UIView animateWithDuration:0.4 animations:^{
                    blockSelf.searchBar.alpha = 1.0;
                }];
            } else {
                self.searchBar.alpha = 1.0;
            }

            [self.searchController setActive:YES animated:animated];
        }
    }
}

- (void)hideSearchBarAnimated:(BOOL)animated
{
	if (self.searchBar) {
        if (animated) {
            __block KGOScrollingTabstrip *blockSelf = self;
            [UIView animateWithDuration:0.4 animations:^{
                blockSelf.searchBar.alpha = 0;
            } completion:^(BOOL finished) {
                [blockSelf.searchBar removeFromSuperview];
                blockSelf.searchBar = nil;
                blockSelf.searchController = nil;
            }];
        } else {
            [self.searchBar removeFromSuperview];
            self.searchBar = nil;
            self.searchController = nil;
        }
	}
}

- (void)sideButtonPressed:(id)sender {
	// This is a slight cheat. The bumpers scroll the next text button so it fits completely into view, 
	// but if all of the buttons in navbuttons are already in view, this scrolls by default to the far
	// left, where the search and bookmark buttons sit.
    CGPoint offset = _scrollView.contentOffset;
	CGRect tabRect = CGRectMake(0, 0, 1, 1); // Because CGRectZero is ignored by -scrollRectToVisible:
	
    if (sender == _leftScrollButton) {
        NSInteger i, count = [_buttons count];
        for (i = count - 1; i >= 0; i--) {
            UIButton *tab = [_buttons objectAtIndex:i];
            if (CGRectGetMinX(tab.frame) - offset.x < 0) {
                tabRect = tab.frame;
                tabRect.origin.x -= _leftScrollButton.frame.size.width - 8.0;
                break;
            }
        }
    } else if (sender == _rightScrollButton) {
        for (UIButton *tab in _buttons) {
            if (CGRectGetMaxX(tab.frame) - (offset.x + _scrollView.frame.size.width) > 0) {
                tabRect = tab.frame;
                tabRect.origin.x += _rightScrollButton.frame.size.width - 8.0;
                break;
            }
        }
    }
	[_scrollView scrollRectToVisible:tabRect animated:YES];
}

- (void)showHideScrollButtons
{
    CGPoint offset = _scrollView.contentOffset;
    if (offset.x <= 0) {
        _leftScrollButton.hidden = YES;
    } else {
        _leftScrollButton.hidden = NO;
    }
    if (offset.x >= _scrollView.contentSize.width - _scrollView.frame.size.width) {
        _rightScrollButton.hidden = YES;
    } else {
        _rightScrollButton.hidden = NO;
    }
}

// scroll view delegation
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (scrollView == _scrollView) {
        [self showHideScrollButtons];
	}
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    if(_scrollView) {
        [self scrollViewDidScroll:_scrollView];
    }
}

- (void)dealloc {
    self.searchBar = nil;
    [_contentView release];
    [_scrollView release];
    [_buttons release];
    [super dealloc];
}

@end

