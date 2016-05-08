//
//  ViewController.h
//  360PlayerDemo
//
//  Created by heyunpeng on 16/5/8.
//  Copyright © 2016年 heyunpeng. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface PlayerViewController : UIViewController <AVPlayerItemOutputPullDelegate>

- (CVPixelBufferRef)getPixelBuffer;

@end

