//
//  PlayerViewController.h
//  360PlayerDemo
//
//  Created by heyunpeng on 16/5/8.
//  Copyright © 2016年 heyunpeng. All rights reserved.
//

#ifndef PlayerViewController_h
#define PlayerViewController_h
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@class PlayerViewController;

@interface VideoPlayerViewController : GLKViewController<UIGestureRecognizerDelegate>

@property (strong, nonatomic, readwrite) PlayerViewController* videoPlayerController;

@end

#endif /* PlayerViewController_h */
