#import "PhotosModule.h"
#import "AlbumListViewController.h"
#import "PhotoGridViewController.h"
#import "PhotoDetailViewController.h"
#import "PhotoDataManager.h"

@implementation PhotosModule

- (PhotoDataManager *)dataManager
{
    if (!_dataManager) {
        _dataManager = [[PhotoDataManager alloc] init];
        _dataManager.moduleTag = self.tag;
    }
    return _dataManager;
}

- (NSArray *)objectModelNames {
    return [NSArray arrayWithObject:@"Photos"];
}

- (UIViewController *)modulePage:(NSString *)pageName params:(NSDictionary *)params
{
    UIViewController *vc = nil;
    if ([pageName isEqualToString:LocalPathPageNameHome]) {
        AlbumListViewController *albumVC = [[[AlbumListViewController alloc] initWithNibName:@"AlbumListViewController"
                                                                                      bundle:nil] autorelease];
        albumVC.dataManager = [self dataManager];
        vc = albumVC;

    } else if ([pageName isEqualToString:LocalPathPageNameItemList]) {
        PhotoAlbum *album = [params objectForKey:@"album"];
        PhotoGridViewController *gridVC = [[[PhotoGridViewController alloc] initWithNibName:@"PhotoGridViewController"
                                                                                     bundle:nil] autorelease];
        gridVC.dataManager = [self dataManager];
        gridVC.album = album;
        vc = gridVC;
    
    } else if ([pageName isEqualToString:LocalPathPageNameDetail]) {
        Photo *photo = [params objectForKey:@"photo"];
        NSArray *photos = [params objectForKey:@"photos"];
        PhotoDetailViewController *detailVC = [[[PhotoDetailViewController alloc] initWithNibName:@"PhotoDetailViewController"
                                                                                           bundle:nil] autorelease];
        detailVC.photo = photo;
        detailVC.photos = photos;
        vc = detailVC;
    }
    return vc;
}

@end
