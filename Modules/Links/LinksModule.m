#import "LinksModule.h"
#import "LinksTableViewController.h"


@implementation LinksModule


- (UIViewController *)modulePage:(NSString *)pageName params:(NSDictionary *)params {
    UIViewController *vc = nil;


    if ([pageName isEqualToString:LocalPathPageNameHome] || [pageName isEqualToString:LocalPathPageNameItemList]) {
        LinksTableViewController * linksVC = [[[LinksTableViewController alloc] initWithModuleTag:self.tag] autorelease];
        
        NSMutableDictionary *requestParams = [NSMutableDictionary dictionary];
        NSString *path = @"index";
        if([params objectForKey:@"group"]) {
            path = @"group";
            [requestParams setObject:[params objectForKey:@"group"] forKey:@"group"];
        }
        if([params objectForKey:@"title"]) {
            linksVC.title = [params objectForKey:@"title"];
        }
        
        KGORequest *feedRequest = [[KGORequestManager sharedManager] requestWithDelegate:linksVC                          
                                                                                  module:self.tag                            
                                                                                    path:path
                                                                                 version:1                         
                                                                                  params:requestParams];
        
        [feedRequest connect];
        feedRequest.expectedResponseType = [NSDictionary class];
        
        vc = linksVC;
    } 
    return vc;
}

@end
