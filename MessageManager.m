//
//  WSMessageManager.m
//  WellSign
//
//  Created by 骏秦 on 16/11/7.
//  Copyright © 2016年 Wellsign. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MessageManager.h"
#import <mach/mach.h>
#import "CommonCrypto/CommonDigest.h"
#import "CommonCrypto/CommonHMAC.h"

#define kAccessKey               @"*************"
#define kSecretKey               @"*************"
#define kEndpoint @"http://***********.mns.cn-hangzhou.aliyuncs.com"
#define kSendQueue @"/queues/上传队列名称/messages"
#define kConsumeQueue @"/queues/上传队列名称/messages"


@implementation MessageManager
+(id)shareManager
{
    static MessageManager *sharedFileM = nil;
    static dispatch_once_t onetoekn;
    dispatch_once(&onetoekn, ^{
        sharedFileM = [[MessageManager alloc] init];
        sharedFileM.Requesting = NO;
    });
    return sharedFileM;
}

/**
 * @june
 *
 * 是否请求中
 *  @return 请求消费消息的状态
 */
+(BOOL)isRequesting
{
    MessageManager* shareM = [MessageManager shareManager];
    return shareM.Requesting;
    
}
/**
 * @june
 * 请求中
 */
+(void)nowRequesting:(BOOL)state
{
    MessageManager* shareM = [WSMessageManager shareManager];
    shareM.Requesting = state;
}
/**
 *  @june
 *
 *  发送消息
 */
+ (void)uploadMNSWithFile:(NSString*)message
                  success:(void (^)(id responseObject))success
                  failure:(void (^)(NSError *error))failure
{
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@",kEndpoint,kSendQueue];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:60];
    [request setValue:@"500" forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%@",[[NSDate oss_clockSkewFixedDate]oss_asStringValue]] forHTTPHeaderField:@"x-mns-date"];
     [request setValue:[NSString stringWithFormat:@"%@",[[NSDate oss_clockSkewFixedDate]oss_asStringValue]] forHTTPHeaderField:@"Date"];
    [request setValue:@"2015-06-06" forHTTPHeaderField:@"x-mns-version"];
 
    NSString *authorizationStr = [NSString stringWithFormat:@"MNS %@:%@",kAccessKey,[self configureAuthorizationofPOST]];
    [request setValue:authorizationStr forHTTPHeaderField:@"Authorization"];
    NSString* xml = @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>";
    NSString * body = [NSString stringWithFormat:@"%@<Message xmlns=\"http://mns.aliyuncs.com/doc/v1/\"><MessageBody>%@</MessageBody><Priority>1</Priority></Message>",xml,message];
    NSLog(@"%@",body);
    NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:data];
    [request setHTTPMethod:@"POST"];
    
    NSLog(@"请求队列消息：\n地址：%@\n请求header:%@",urlString,request.allHTTPHeaderFields);
    

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"请求转换队列失败:%@",error);
            failure(error);
        } else {
            NSLog(@"请求转换队列回调信息:%@",response);
            success(response);
        }
    }];
    
    [task resume];
}
/**
 *  @june
 *
 *  消费消息
 */
+(void)consumeMNSWith:(NSString*)queueName
                     success:(void (^)(id responseObject))success
                     failinf:(void (^)(id responseObject))fail
                     failure:(void (^)(NSError *error))failure
{
   NSString*resource =  [NSString stringWithFormat:@"/queues/%@/messages?waitseconds=30",queueName];
    NSString *urlString = [NSString stringWithFormat:@"%@%@",kEndpoint,resource];
  
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:60];
    [request setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%@",[[NSDate oss_clockSkewFixedDate]oss_asStringValue]] forHTTPHeaderField:@"x-mns-date"];
    [request setValue:[NSString stringWithFormat:@"%@",[[NSDate oss_clockSkewFixedDate]oss_asStringValue]] forHTTPHeaderField:@"Date"];
    [request setValue:@"2015-06-06" forHTTPHeaderField:@"x-mns-version"];
    NSString *authorizationStr = [NSString stringWithFormat:@"MNS %@:%@",kAccessKey,[self configureAuthorizationofGET:resource]];
    [request setValue:authorizationStr forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:@"GET"];
    WLog(@"消费队列消息\n请求地址：%@\n",urlString);
    WLog(@"请求header:%@",request.allHTTPHeaderFields);
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"请求转换队列失败:%@",error);
            failure(error);
        } else {
            NSLog(@"请求转换队列回调信息:%@",response);
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            NSLog(@" http response : %ld", (long)httpResponse.statusCode);
            if (httpResponse.statusCode == 200) {
                //在完成解析消息方法前快速测试删除消息
                NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSRange rangef = [result rangeOfString:@"<ReceiptHandle>"];
                NSRange rangel = [result rangeOfString:@"</ReceiptHandle>"];
                if (rangef.length > 0 && rangel.length > 0) {
                    NSInteger loc = rangef.location + rangef.length;
                    NSInteger length = rangel.location - loc;
                    NSRange Handlerange = NSMakeRange(loc, length);
                    if (length > 0) {
                        //存在消息 直接请求删除
                        NSString* handle = [result substringWithRange:Handlerange];
                        [WSMessageManager deleteMessage:queueName handler:handle success:^(id responseObject) {
                            NSLog(@"直接删除消息成功");
                            success(response);
                        } failinf:^(WSMesModel *message, id responseObject) {
                            NSLog(@"直接删除消息失败%@",message.MessageBody);
                            fail(response);
                        } failure:^(NSError *error) {
                            NSLog(@"直接删除消息请求失败");
                            fail(response);
                        }];
                        
                    }
                }
            }
            else
            {
                 fail(response);
            }
           
        }
    }];
    
    [task resume];

}
/**
 *  @june
 *
 *  删除消息
 */
+(void)deleteMessage:(NSString*)quque handler:(NSString*)handler
                       success:(void (^)(id responseObject))success
                       failinf:(void (^)(id responseObject))fail
                       failure:(void (^)(NSError *error))failure
{
    NSString*resource =  [NSString stringWithFormat:@"/queues/%@/messages?ReceiptHandle=%@",quque,handler];
    NSString *urlString = [NSString stringWithFormat:@"%@%@",kEndpoint,resource];
    WLog(@"请求地址：%@",urlString);
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:60];
    [request setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%@",[[NSDate oss_clockSkewFixedDate]oss_asStringValue]] forHTTPHeaderField:@"x-mns-date"];
    [request setValue:[NSString stringWithFormat:@"%@",[[NSDate oss_clockSkewFixedDate]oss_asStringValue]] forHTTPHeaderField:@"Date"];
    [request setValue:@"2015-06-06" forHTTPHeaderField:@"x-mns-version"];
    NSString *authorizationStr = [NSString stringWithFormat:@"MNS %@:%@",kAccessKey,[self configureAuthorizationofDELETE:resource]];
    [request setValue:authorizationStr forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:@"DELETE"];
    
    WLog(@"请求header:%@",request.allHTTPHeaderFields);
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"请求删除失败:%@",error);
            failure(error);
        } else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            NSLog(@" http response : %ld", (long)httpResponse.statusCode);
            if (httpResponse.statusCode == 204) {
                //删除成功
                success(response);
            }
            else
            {
                 fail(response);
            }
        }
    }];
    
    [task resume];
    
    
}

+ (NSString *)calBase64Sha1WithData:(NSString *)data withSecret:(NSString *)key {
    
    NSData *secretData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSData *clearTextData = [data dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t input[20];
    CCHmac(kCCHmacAlgSHA1, [secretData bytes], [secretData length], [clearTextData bytes], [clearTextData length], input);
    return [OSSUtil calBase64WithData:input];
}


+ (NSString *)configureAuthorizationofPOST{
    NSString * method = @"POST";
    NSString * contentMd5 = @"";
    NSString * contentType = @"text/xml";
    NSString * date = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
    NSString * xossHeader = [NSString stringWithFormat:@"%@\n%@\n",[NSString stringWithFormat:@"x-mns-date:%@",[[NSDate oss_clockSkewFixedDate] oss_asStringValue]],@"x-mns-version:2015-06-06"];
    NSString * resource = kSendQueue;
    NSString * stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@%@", method, contentMd5, contentType, date, xossHeader, resource];
    return [self calBase64Sha1WithData:stringToSign withSecret:kSecretKey];
}
+ (NSString *)configureAuthorizationofGET:(NSString*)resource
{
    NSString * method = @"GET";
    NSString * contentMd5 = @"";
    NSString * contentType = @"text/xml";
    NSString * date = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
    NSString * xossHeader = [NSString stringWithFormat:@"%@\n%@\n",[NSString stringWithFormat:@"x-mns-date:%@",[[NSDate oss_clockSkewFixedDate] oss_asStringValue]],@"x-mns-version:2015-06-06"];
    NSString * stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@%@", method, contentMd5, contentType, date, xossHeader, resource];
    WLog(@"授权签名：\n%@",stringToSign);
    return [self calBase64Sha1WithData:stringToSign withSecret:kSecretKey];
}
+ (NSString *)configureAuthorizationofDELETE:(NSString*)resource
{
    NSString * method = @"DELETE";
    NSString * contentMd5 = @"";
    NSString * contentType = @"text/xml";
    NSString * date = [[NSDate oss_clockSkewFixedDate] oss_asStringValue];
    NSString * xossHeader = [NSString stringWithFormat:@"%@\n%@\n",[NSString stringWithFormat:@"x-mns-date:%@",[[NSDate oss_clockSkewFixedDate] oss_asStringValue]],@"x-mns-version:2015-06-06"];
    NSString * stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@%@", method, contentMd5, contentType, date, xossHeader, resource];
    WLog(@"授权签名：\n%@",stringToSign);
    return [self calBase64Sha1WithData:stringToSign withSecret:kSecretKey];
}

/**
 *  @june
 *
 *  开启轮询服务
 */
+ (void)beginMNSCycle
{
        __block BOOL Converting = YES;
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_source_t _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,queue);
        dispatch_source_set_timer(_timer,dispatch_walltime(NULL, 0),5.0*NSEC_PER_SEC, 0); //每30秒执行
        dispatch_source_set_event_handler(_timer, ^{
            if(!Converting){ //倒计时结束，关闭
                dispatch_source_cancel(_timer);
            }else{
                //开启轮询请求
             
                if ([MessageManager isRequesting] == NO) {
                    [MessageManager nowRequesting: YES];
                    
                    [MessageManager consumeMNSWith:kConsumeQueue success:^( id responseObject) {
                        [MessageManager nowRequesting: NO];
                        NSLog(@"消费消息成功");
                    } failinf:^( id responseObject) {
                        [MessageManager nowRequesting: NO];
                        NSLog(@"消费消息失败");
            
                    } failure:^(NSError *error) {
                        [MessageManager nowRequesting: NO];
                        NSLog(@"获取消息失败");
                    }];
                    
//                    增加条件判断是否继续请求
//                    if (....) {
//                         Converting = NO;
//                    }
//                    else
//                    {
//                         Converting = YES;
//                    }
                    
                }
                
            }
        });
        dispatch_resume(_timer);
    
}
@end
