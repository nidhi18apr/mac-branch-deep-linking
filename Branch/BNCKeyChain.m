/**
 @file          BNCKeyChain.m
 @package       Branch
 @brief         Simple access routines for secure keychain storage.

 @author        Edward Smith
 @date          January 8, 2018
 @copyright     Copyright © 2018 Branch. All rights reserved.
*/

#import "BNCKeyChain.h"
#import "BNCLog.h"

// Apple Keychain Reference:
// https://developer.apple.com/library/content/documentation/Conceptual/
//      keychainServConcepts/02concepts/concepts.html#//apple_ref/doc/uid/TP30000897-CH204-SW1
//
// To translate security errors to text from the command line use: `security error -34018`

#pragma mark SecCopyErrorMessageString

//#pragma clang link undefined _SecCopyErrorMessageString // -Wl,-U,_SecCopyErrorMessageString
extern CFStringRef SecCopyErrorMessageString(OSStatus status, void *reserved)
    __attribute__((weak_import));

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
CFStringRef SecCopyErrorMessageString(OSStatus status, void *reserved) {
    return CFSTR("Sec OSStatus error.");
}
#pragma clang diagnostic pop

#pragma mark - BNCKeyChain

@implementation BNCKeyChain

- (instancetype) initWithSecurityAccessGroup:(NSString *)securityGroup {
    self = [super init];
    if (!self) return self;
    BNCLogAssert(securityGroup);
    if (securityGroup.length) {
        _securityAccessGroup = [securityGroup copy];
        return self;
    }
    return nil;
}

+ (NSError*) errorWithKey:(NSString*)key OSStatus:(OSStatus)status {
    // Security errors are defined in Security/SecBase.h
    if (status == errSecSuccess) return nil;
    NSString *reason = nil;
    NSString *description =
        [NSString stringWithFormat:@"Security error with key '%@': code %ld.", key, (long) status];

    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wtautological-compare"
    #pragma clang diagnostic ignored "-Wpartial-availability"
    if (SecCopyErrorMessageString != NULL)
        reason = (__bridge_transfer NSString*) SecCopyErrorMessageString(status, NULL);
    #pragma clang diagnostic pop

    if (!reason)
        reason = @"Sec OSStatus error.";

    NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:@{
        NSLocalizedDescriptionKey: description,
        NSLocalizedFailureReasonErrorKey: reason
    }];
    return error;
}

- (NSArray<NSString*>*_Nullable) retrieveKeysWithService:(NSString*)service
                                                   error:(NSError*_Nullable __autoreleasing *_Nullable)error {
    if (error) *error = nil;
    if (service == nil) {
        if (error) *error = [self.class errorWithKey:nil OSStatus:errSecParam];
        return nil;
    }
    NSDictionary* dictionary = @{
        (__bridge id)kSecClass:                 (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecReturnAttributes:      (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecAttrSynchronizable:    (__bridge id)kSecAttrSynchronizableAny,
        (__bridge id)kSecMatchLimit:            (__bridge id)kSecMatchLimitAll,
        (__bridge id)kSecAttrAccessGroup:       self->_securityAccessGroup,
        (__bridge id)kSecAttrService:           service,
    };
    CFTypeRef valueData = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)dictionary, &valueData);
    if (status == errSecItemNotFound) status = 0;
    if (status != errSecSuccess) {
        NSError *localError = [self.class errorWithKey:@"<all>" OSStatus:status];
        BNCLogDebugSDK(@"Can't retrieve key: %@.", localError);
        if (error) *error = localError;
        if (valueData) CFRelease(valueData);
        return nil;
    }
    NSMutableArray *array = [NSMutableArray new];
    if ([((__bridge NSArray*)valueData) isKindOfClass:[NSArray class]]) {
        NSArray *dataArray = (__bridge NSArray*) valueData;
        for (NSDictionary*dataDictionary in dataArray) {
            NSString*key = dataDictionary[(NSString*)kSecAttrAccount];
            if (key) [array addObject:key];
        }
    }
    if (valueData)
        CFRelease(valueData);
    return array;
}

- (id) retrieveValueForService:(NSString*)service key:(NSString*)key error:(NSError**)error {
    if (error) *error = nil;
    if (service == nil || key == nil) {
        NSError *localError = [self.class errorWithKey:key OSStatus:errSecParam];
        if (error) *error = localError;
        return nil;
    }

    NSDictionary* dictionary = @{
        (__bridge id)kSecClass:                 (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:           service,
        (__bridge id)kSecAttrAccount:           key,
        (__bridge id)kSecAttrAccessGroup:       self->_securityAccessGroup,
        (__bridge id)kSecReturnData:            (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit:            (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecAttrSynchronizable:    (__bridge id)kSecAttrSynchronizableAny
    };
    CFDataRef valueData = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)dictionary, (CFTypeRef *)&valueData);
    if (status) {
        NSError *localError = [self.class errorWithKey:key OSStatus:status];
        BNCLogDebugSDK(@"Can't retrieve key: %@.", localError);
        if (error) *error = localError;
        if (valueData) CFRelease(valueData);
        return nil;
    }
    id value = nil;
    if (valueData) {
        @try {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            value = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData*)valueData];
            #pragma clang diagnostic pop
        }
        @catch (id) {
            value = nil;
            NSError *localError = [self.class errorWithKey:key OSStatus:errSecDecode];
            if (error) *error = localError;
        }
        CFRelease(valueData);
    }
    return value;
}

- (NSError*) storeValue:(id)value
             forService:(NSString*)service
                    key:(NSString*)key {

    if (value == nil || service == nil || key == nil)
        return [self.class errorWithKey:key OSStatus:errSecParam];

    NSData* valueData = nil;
    @try {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        valueData = [NSKeyedArchiver archivedDataWithRootObject:value];
        #pragma clang diagnostic pop
    }
    @catch(id) {
        valueData = nil;
    }
    if (!valueData) {
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
            code:NSPropertyListWriteStreamError userInfo:nil];
        return error;
    }
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
        (__bridge id)kSecClass:                 (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:           service,
        (__bridge id)kSecAttrAccount:           key,
        (__bridge id)kSecAttrAccessGroup:       self->_securityAccessGroup,
        (__bridge id)kSecAttrSynchronizable:    (__bridge id)kSecAttrSynchronizableAny
    }];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)dictionary);
    if (status != errSecSuccess && status != errSecItemNotFound) {
        NSError *error = [self.class errorWithKey:key OSStatus:status];
        BNCLogDebugSDK(@"Can't clear to store key: %@.", error);
    }
    dictionary[(__bridge id)kSecValueData]          = valueData;
    dictionary[(__bridge id)kSecAttrIsInvisible]    = (__bridge id)kCFBooleanTrue;
    dictionary[(__bridge id)kSecAttrSynchronizable] = (__bridge id)kCFBooleanTrue;
    dictionary[(__bridge id)kSecAttrAccessible]     = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
    
    status = SecItemAdd((__bridge CFDictionaryRef)dictionary, NULL);
    if (status != errSecSuccess) {
        NSError *error = [self.class errorWithKey:key OSStatus:status];
        BNCLogDebugSDK(@"Can't store key: %@.", error);
        return error;
    }
    return nil;
}

- (NSError*) removeValuesForService:(NSString*)service key:(NSString*)key {
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
        (__bridge id)kSecClass:                 (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrSynchronizable:    (__bridge id)kSecAttrSynchronizableAny,
        (__bridge id)kSecAttrAccessGroup:       self->_securityAccessGroup,
    }];
    if (service) dictionary[(__bridge id)kSecAttrService] = service;
    if (key) dictionary[(__bridge id)kSecAttrAccount] = key;

    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)dictionary);
    if (status == errSecItemNotFound) status = errSecSuccess;
    if (status) {
        NSError *error = [self.class errorWithKey:key OSStatus:status];
        BNCLogDebugSDK(@"Can't remove key: %@.", error);
        return error;
    }
    return nil;
}

@end
