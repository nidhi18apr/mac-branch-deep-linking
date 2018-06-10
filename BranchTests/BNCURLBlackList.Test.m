/**
 @file          BNCURLBlackList.Test.m
 @package       Branch-SDK-Tests
 @brief         BNCURLBlackList tests.

 @author        Edward Smith
 @date          February 14, 2018
 @copyright     Copyright © 2018 Branch. All rights reserved.
*/

#import "BNCTestCase.h"
#import "BNCURLBlackList.h"
#import "BranchMainClass.h"

@interface BNCURLBlackList ()
@property (readwrite) NSURL *blackListJSONURL;
@end

@interface BNCURLBlackListTest : BNCTestCase
@end

@implementation BNCURLBlackListTest

- (void) setUp {
//    [BNCPreferenceHelper preferenceHelper].URLBlackList = nil;
//    [BNCPreferenceHelper preferenceHelper].URLBlackListVersion = 0;
//    [BNCPreferenceHelper preferenceHelper].blacklistURLOpen = NO;
}

- (void) tearDown {
//    [BNCPreferenceHelper preferenceHelper].blacklistURLOpen = NO;
}

- (void)testListDownLoad {
    XCTestExpectation *expectation = [self expectationWithDescription:@"BlackList Download"];
    Branch*branch = [Branch new];
    BranchConfiguration*configuration = [BranchConfiguration configurationWithKey:@"key_live_foo"];
    [branch startWithConfiguration:configuration];
    BNCURLBlackList *blackList = [BNCURLBlackList new];
    [blackList refreshBlackListFromServerWithBranch:branch completion:
        ^(BNCURLBlackList * _Nonnull blackList, NSError * _Nullable error) {
            XCTAssertNil(error);
            XCTAssertTrue(blackList.blackList.count == 6);
            [expectation fulfill];
        }
    ];
    [self awaitExpectations];
}

- (NSArray*) badURLs {
    NSArray *kBadURLs = @[
        @"fb123456:login/464646",
        @"twitterkit-.4545:",
        @"shsh:oauth/login",
        @"https://myapp.app.link/oauth_token=fred",
        @"https://myapp.app.link/auth_token=fred",
        @"https://myapp.app.link/authtoken=fred",
        @"https://myapp.app.link/auth=fred",
        @"fb1234:",
        @"fb1234:/",
        @"fb1234:/this-is-some-extra-info/?whatever",
        @"fb1234:/this-is-some-extra-info/?whatever:andstuff",
        @"myscheme:path/to/resource?oauth=747474",
        @"myscheme:oauth=747474",
        @"myscheme:/oauth=747474",
        @"myscheme://oauth=747474",
        @"myscheme://path/oauth=747474",
        @"myscheme://path/:oauth=747474",
        @"https://google.com/userprofile/devonbanks=oauth?",
    ];
    return kBadURLs;
}

- (NSArray*) goodURLs {
    NSArray *kGoodURLs = @[
        @"shshs:/content/path",
        @"shshs:content/path",
        @"https://myapp.app.link/12345/link",
        @"fb123x:/",
        @"https://myapp.app.link?authentic=true&tokemonsta=false",
        @"myscheme://path/brauth=747474",
    ];
    return kGoodURLs;
}

- (void)testBadURLs {
    // Test default list.
    BNCURLBlackList *blackList = [BNCURLBlackList new];
    for (NSString *string in self.badURLs) {
        NSURL *URL = [NSURL URLWithString:string];
        XCTAssertTrue([blackList isBlackListedURL:URL], @"Checking '%@'.", URL);
    }
}

- (void) testDownloadBadURLs {
    // Test download list.
    XCTestExpectation *expectation = [self expectationWithDescription:@"BlackList Download"];

    Branch*branch = [Branch new];
    BranchConfiguration*configuration = [BranchConfiguration configurationWithKey:@"key_live_foo"];
    [branch startWithConfiguration:configuration];

    BNCURLBlackList *blackList = [BNCURLBlackList new];
    blackList.blackListJSONURL = [NSURL URLWithString:@"https://cdn.branch.io/sdk/uriskiplist_tv1.json"];
    [blackList refreshBlackListFromServerWithBranch:branch completion:
        ^(BNCURLBlackList * _Nonnull blackList, NSError * _Nullable error) {
            XCTAssertNil(error);
            XCTAssertTrue(blackList.blackList.count == 7);
            [expectation fulfill];
        }
    ];
    [self awaitExpectations];
    for (NSString *string in self.badURLs) {
        NSURL *URL = [NSURL URLWithString:string];
        XCTAssertTrue([blackList isBlackListedURL:URL], @"Checking '%@'.", URL);
    }
}

- (void)testGoodURLs {
    // Test default list.
    BNCURLBlackList *blackList = [BNCURLBlackList new];
    for (NSString *string in self.goodURLs) {
        NSURL *URL = [NSURL URLWithString:string];
        XCTAssertFalse([blackList isBlackListedURL:URL], @"Checking '%@'", URL);
    }
}

- (void) testDownloadGoodURLs {
    // Test download list.

    Branch*branch = [Branch new];
    BranchConfiguration*configuration = [BranchConfiguration configurationWithKey:@"key_live_foo"];
    [branch startWithConfiguration:configuration];

    XCTestExpectation *expectation = [self expectationWithDescription:@"BlackList Download"];
    BNCURLBlackList *blackList = [BNCURLBlackList new];
    blackList.blackListJSONURL = [NSURL URLWithString:@"https://cdn.branch.io/sdk/uriskiplist_tv1.json"];
    [blackList refreshBlackListFromServerWithBranch:branch completion:
        ^(BNCURLBlackList * _Nonnull blackList, NSError * _Nullable error) {
            XCTAssertNil(error);
            XCTAssertTrue(blackList.blackList.count == 7);
            [expectation fulfill];
        }
    ];
    [self awaitExpectations];
    for (NSString *string in self.goodURLs) {
        NSURL *URL = [NSURL URLWithString:string];
        XCTAssertFalse([blackList isBlackListedURL:URL], @"Checking '%@'.", URL);
    }
}

- (void) testStandardBlackList {
    Branch*branch = [Branch new];
    BranchConfiguration*configuration = [BranchConfiguration configurationWithKey:@"key_live_foo"];
    configuration.networkServiceClass = BNCTestNetworkService.class;
    [branch startWithConfiguration:configuration];

    XCTestExpectation *expectation = [self expectationWithDescription:@"OpenRequest Expectation"];
    BNCTestNetworkService.requestHandler =
        ^id<BNCNetworkOperationProtocol> _Nonnull(NSMutableURLRequest * _Nonnull request) {
            NSDictionary*dictionary = [BNCTestNetworkService mutableDictionaryFromRequest:request];
            NSLog(@"d: %@", dictionary);
            NSString* link = dictionary[@"external_intent_uri"];
            NSString *pattern =
                @"^(?i)((http|https):\\/\\/).*[\\/|?|#].*"
                 "\\b(password|o?auth|o?auth.?token|access|access.?token)\\b";
            NSLog(@"\n   Link: '%@'\nPattern: '%@'\n.", link, pattern);
            XCTAssert([link isEqualToString:pattern]);
            [expectation fulfill];
        };

    NSString *url = @"https://myapp.app.link/bob/link?oauth=true";
    #if TARGET_OS_OSX
    url = @"testbed-mac://open?link_click_id=348527481794276288&oauth=true";
    #endif

    [branch openURL:[NSURL URLWithString:url]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

/*
- (void) testStandardBlackList {
    Branch*branch = [Branch new];
    BranchConfiguration*configuration = [BranchConfiguration configurationWithKey:@"Key_live_foo"];
    [branch startWithConfiguration:configuration];

    Branch *branch = [Branch getInstance:@"key_live_foo"];
    id serverInterfaceMock = OCMPartialMock(branch.serverInterface);
    XCTestExpectation *expectation = [self expectationWithDescription:@"OpenRequest Expectation"];

    OCMStub(
        [serverInterfaceMock postRequest:[OCMArg any]
            url:[OCMArg any]
            key:[OCMArg any]
            callback:[OCMArg any]]
    ).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSDictionary *dictionary = nil;
        [invocation getArgument:&dictionary atIndex:2];

        NSLog(@"d: %@", dictionary);
        NSString* link = dictionary[@"external_intent_uri"];
        NSString *pattern = @"^(?i)((http|https):\\/\\/).*[\\/|?|#].*\\b(password|o?auth|o?auth.?token|access|access.?token)\\b";
        NSLog(@"\n   Link: '%@'\nPattern: '%@'\n.", link, pattern);
        if ([link isEqualToString:pattern]) {
            [expectation fulfill];
        }
    });

    [branch clearNetworkQueue];
    [branch handleDeepLinkWithNewSession:[NSURL URLWithString:@"https://myapp.app.link/bob/link?oauth=true"]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    [serverInterfaceMock stopMocking];
    [BNCPreferenceHelper preferenceHelper].referringURL = nil;
    [[BNCPreferenceHelper preferenceHelper] synchronize];
}
*/

/*
- (void) testUserBlackList {
    Branch *branch = [Branch getInstance:@"key_live_foo"];
    branch.blackListURLRegex = @[
        @"\\/bob\\/"
    ];
    id serverInterfaceMock = OCMPartialMock(branch.serverInterface);
    XCTestExpectation *expectation = [self expectationWithDescription:@"OpenRequest Expectation"];

    OCMStub(
        [serverInterfaceMock postRequest:[OCMArg any]
            url:[OCMArg any]
            key:[OCMArg any]
            callback:[OCMArg any]]
    ).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSDictionary *dictionary = nil;
        [invocation getArgument:&dictionary atIndex:2];

        NSString* link = dictionary[@"external_intent_uri"];
        NSString *pattern = @"\\/bob\\/";
        NSLog(@"\n   Link: '%@'\nPattern: '%@'\n.", link, pattern);

        if ([link isEqualToString:pattern]) {
            [expectation fulfill];
        }
    });

    [branch clearNetworkQueue];
    [branch handleDeepLinkWithNewSession:[NSURL URLWithString:@"https://myapp.app.link/bob/link"]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    [serverInterfaceMock stopMocking];
    [BNCPreferenceHelper preferenceHelper].referringURL = nil;
    [[BNCPreferenceHelper preferenceHelper] synchronize];
}
*/

@end
