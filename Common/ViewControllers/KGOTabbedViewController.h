#import <UIKit/UIKit.h>
#import "KGOTabbedControl.h"
#import "KGODetailPageHeaderView.h"

@protocol KGOTabbedViewDelegate <NSObject>

- (UIView *)tabbedControl:(KGOTabbedControl *)control containerViewAtIndex:(NSInteger)index;
- (NSArray *)itemsForTabbedControl:(KGOTabbedControl *)control;

@end

@interface KGOTabbedViewController : UIViewController <KGOTabbedControlDelegate, KGOTabbedViewDelegate, KGODetailPageHeaderDelegate> {
    
    IBOutlet KGOTabbedControl *_tabs;
    IBOutlet UIView *_tabViewContainer;
    
}

@property (nonatomic, retain) IBOutlet KGODetailPageHeaderView *headerView;
@property (nonatomic, assign) id<KGOTabbedViewDelegate> delegate;
@property (nonatomic, retain) UIView *tabViewContainer;
@property (nonatomic, retain) KGOTabbedControl *tabs;

- (void)reloadTabs;
- (void)reloadTabContent; // just reloads the current tab

@end
