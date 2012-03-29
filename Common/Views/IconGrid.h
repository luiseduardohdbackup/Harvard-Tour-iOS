// from MIT-Mobile-for-iPhone v3.0
#import <UIKit/UIKit.h>

struct GridPadding {
    CGFloat top;
    CGFloat right;
    CGFloat bottom;
    CGFloat left;
};
typedef struct GridPadding GridPadding;
typedef CGSize GridSpacing;

GridPadding GridPaddingMake(CGFloat top, CGFloat left, CGFloat bottom, CGFloat right);
GridSpacing GridSpacingMake(CGFloat width, CGFloat height);

extern const GridPadding GridPaddingZero;
extern const GridSpacing GridSpacingZero;

typedef enum {
    GridIconAlignmentLeft,
    GridIconAlignmentCenter,
    GridIconAlignmentRight,
} GridIconAlignment;

@protocol IconGridDelegate;

@interface IconGrid : UIView {
    
	id<IconGridDelegate> delegate;

    // these determine where the next icon should be placed
    CGFloat _currentX;
    CGFloat _currentY;
}

- (void)addIcons:(NSArray *)icons;

@property (nonatomic, assign) id<IconGridDelegate> delegate;

@property GridPadding padding;
@property GridSpacing spacing;
@property NSInteger maxColumns; // specify 0 to fit as many columns as possible
@property GridIconAlignment alignment;
@property (nonatomic, retain) NSArray *icons;

@property CGFloat topPadding;
@property CGFloat rightPadding;
@property CGFloat bottomPadding;
@property CGFloat leftPadding;

@end

@protocol IconGridDelegate <NSObject>

- (void)iconGridFrameDidChange:(IconGrid *)iconGrid;

@end

