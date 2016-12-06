//
//  WSMessageManager.h
//  WellSign
//
//  Created by 骏秦 on 16/11/7.
//  Copyright © 2016年 Wellsign. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HomeViewController.h"
#import "PXAlertView.h"

@interface MessageManager : NSObject

@property(nonatomic,assign) BOOL Requesting;
/**
 * @june
 * 消息单例： 解析消息 通知显示消息 处理消息
 *
 *  @return 消息单例
 */
+(id)shareManager;
/**
 * @june
 *
 * 是否请求中
 *  @return 请求消费消息的状态
 */
+(BOOL)isRequesting;
/**
 * @june
 * 请求中
 */
+(void)nowRequesting:(BOOL)state;
/**
 *  @june
 *
 *  发送消息
 */
+ (void)uploadMNSWithFile:(NSString*)message
                  success:(void (^)(id responseObject))success
                  failure:(void (^)(NSError *error))failure;
/**
 *  @june
 *
 *  消费消息
 */
+(void)consumeMNSWith:(NSString*)queueName
              success:(void (^)(id responseObject))success
              failinf:(void (^)(id responseObject))fail
              failure:(void (^)(NSError *error))failure;

/**
 *  @june
 *
 *  删除消息
 */
+(void)deleteMessage:(NSString*)quque handler:(NSString*)handler
             success:(void (^)(id responseObject))success
             failinf:(void (^)(id responseObject))fail
             failure:(void (^)(NSError *error))failure;
/**
 *  @june
 *
 *  开启轮询服务
 */
+ (void)beginMNSCycle;


@end
