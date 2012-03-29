/* KGOTabbedControl is a successor to TabViewControl from MIT
 * whose inteface basically clones UISegmentedControl but uses
 * title/image as foreground elements and has highlighted states
 */

#import <UIKit/UIKit.h>

@class KGOTabbedControl;

@protocol KGOTabbedControlDelegate <NSObject>

- (void)tabbedControl:(KGOTabbedControl *)contol didSwitchToTabAtIndex:(NSInteger)index;

@end

typedef enum {
    KGOTabStateInactive,
    KGOTabStateActive,
    KGOTabStatePressed,
    KGOTabStateDisabled
} KGOTabState;

@interface KGOTabbedControl : UIView { // UIControl {
    
    NSMutableArray *_tabs;
    NSMutableArray *_tabContents;
    CGFloat *_tabMinWidths;
    KGOTabState *_tabStates;

    NSInteger _selectedTabIndex;

}

- (id)initWithItems:(NSArray *)items;

@property(nonatomic) CGFloat tabSpacing;
@property(nonatomic) CGFloat tabPadding;
@property(nonatomic, retain) UIFont *tabFont;

@property(nonatomic, readonly) NSUInteger numberOfTabs;
@property(nonatomic) NSInteger selectedTabIndex;
@property(nonatomic, assign) id<KGOTabbedControlDelegate> delegate;

- (void)insertTabWithImage:(UIImage *)image atIndex:(NSUInteger)index animated:(BOOL)animated;
- (void)insertTabWithTitle:(NSString *)title atIndex:(NSUInteger)index animated:(BOOL)animated;
- (BOOL)isEnabledForTabAtIndex:(NSUInteger)index;
- (void)removeAllTabs;
- (void)removeTabAtIndex:(NSUInteger)index animated:(BOOL)animated;
- (void)setEnabled:(BOOL)enabled forTabAtIndex:(NSUInteger)index;
- (void)setImage:(UIImage *)image forTabAtIndex:(NSUInteger)index;
- (void)setTitle:(NSString *)title forTabAtIndex:(NSUInteger)index;
- (void)setMinimumWidth:(CGFloat)width forTabAtIndex:(NSUInteger)index;
- (NSString *)titleForTabAtIndex:(NSUInteger)index;
- (UIImage *)imageForTabAtIndex:(NSUInteger)index;
- (CGFloat)minimumWidthForTabAtIndex:(NSUInteger)index;

// for subclasses (e.g. KGOSegmentedControl)

- (UIImage *)backgroundImageForState:(KGOTabState)state atIndex:(NSUInteger)index;

@end


