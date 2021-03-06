/**
 @file          BNCLog.Test.m
 @package       BranchTests
 @brief         Tests for BNCLog.

 @author        Edward Smith
 @date          October 2016
 @copyright     Copyright © 2016 Branch. All rights reserved.
*/

#import <XCTest/XCTest.h>
#import "BNCLog.h"
#import "NSString+Branch.h"
#import "BNCTestCase.h"

@interface BNCLogTest : BNCTestCase
@end

static NSString* globalTestLogString_ = nil;

void TestLogProcedure(NSDate*timestamp, BNCLogLevel level, NSString* message) {
    @synchronized (BNCLogTest.class) {
        globalTestLogString_ = [message copy];
    }
}

NSString* globalTestLogString(void) {
    @synchronized (BNCLogTest.class) {
        return globalTestLogString_;
    }
}

@implementation BNCLogTest

- (void) dealloc {
    globalTestLogString_ = nil;
}

extern void BNCLogInternalErrorFunction(int linenumber, NSString*format, ...);

- (void) testInternalError {
    int e = 9;
    BNCLogInternalErrorFunction(__LINE__, @"Test error success (%d): %s.", e, strerror(e));
}

- (void) testLogLineNumbers {

    BNCLogSetOutputFunction(TestLogProcedure);
    XCTAssertTrue(BNCLogOutputFunction() == TestLogProcedure);

    // Set SynchronizeMessages so that messages don't lag for testing.
    // Alternate synchronization of log messages has been removed.
    // BNCLogSetSynchronizeMessages(NO);

    //  Test the log message facility --
    //  Warning!  If these line numbers change the tests will fail!

    //  Extra line
    //  Extra line
    //  Extra line

    BNCLog(@"Debug message with no parameters.");
    BNCLogFlushMessages();
    XCTAssertEqualObjects(globalTestLogString(),
        @"[branch.io] BNCLog.Test.m(62) Log: Debug message with no parameters.");
}

- (void) testLog {
    BNCLogSetDisplayLevel(BNCLogLevelLog);
    XCTAssertTrue(BNCLogDisplayLevel() == BNCLogLevelLog);
    BNCLogSetDisplayLevel(BNCLogLevelAll);

    BNCLogSetOutputFunction(TestLogProcedure);
    XCTAssertTrue(BNCLogOutputFunction() == TestLogProcedure);

    //  Test the log message facility --

    BNCLog(@"Debug message with no parameters.");
    BNCLogFlushMessages();
    XCTAssert([globalTestLogString() bnc_isEqualToMaskedString:
        @"[branch.io] BNCLog.Test.m(**) Log: Debug message with no parameters."]);

    BNCLog(@"Debug message with one parameter: %d.", 1);
    BNCLogFlushMessages();
    XCTAssert([globalTestLogString() bnc_isEqualToMaskedString:
        @"[branch.io] BNCLog.Test.m(**) Log: Debug message with one parameter: 1."]);

    BNCLogMethodName();
    BNCLogFlushMessages();
    XCTAssert([globalTestLogString() bnc_isEqualToMaskedString:
        @"[branch.io] BNCLog.Test.m(**) DebugSDK: Method 'testLog'."]);

    BNCLogAssert(1 == 2);
    XCTAssert([globalTestLogString() bnc_isEqualToMaskedString:
        @"[branch.io] BNCLog.Test.m(**) Assert: (1 == 2) !!! "]);

    BNCLogAssertWithMessage(1 == 2, @"Assert message! Parameter: %d.", 2);
    XCTAssert([globalTestLogString() bnc_isEqualToMaskedString:
        @"[branch.io] BNCLog.Test.m(**) Assert: (1 == 2) !!! Assert message! Parameter: 2."]);
}

- (void) testOutputFunctions {
    BNCLogOutputFunctionPtr origPtr = BNCLogOutputFunction();

    NSError *error = nil;
    NSURL *URL =
        [[NSFileManager defaultManager]
            URLForDirectory:NSCachesDirectory
            inDomain:NSUserDomainMask
            appropriateForURL:nil
            create:YES
            error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"io.branch.BranchSDK-Test"];
    [[NSFileManager defaultManager]
        createDirectoryAtURL:URL
        withIntermediateDirectories:YES
        attributes:nil
        error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"Test.log"];
    [[NSFileManager defaultManager]
        removeItemAtURL:URL
        error:&error];

    BNCLogSetOutputToURL(URL);
    BNCLog(@"Hi to file1.");
    BNCLogCloseLogFile();

    NSString *string =
        [[NSString stringWithContentsOfURL:URL
            encoding:NSNEXTSTEPStringEncoding
            error:&error]
                bnc_stringTruncatedAtNull];
    NSString *test = @"[branch.io] BNCLog.Test.m(***) Log: Hi to file1. \n";
    XCTAssert([string bnc_isEqualToMaskedString:test]);

    BNCLogCloseLogFile();
    BNCLogSetOutputFunction(NULL);
    BNCLog(@"Hi to null.");

    // Re-open log file and append to it --
    BNCLogSetOutputToURL(URL);
    BNCLog(@"Hi to file2.");
    BNCLog(@"Hi to file3.");
    BNCLogCloseLogFile();

    NSData * data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    test =
        @"[branch.io] BNCLog.Test.m(***) Log: Hi to file1. \n"
        @"[branch.io] BNCLog.Test.m(***) Log: Hi to file2. \n"
        @"[branch.io] BNCLog.Test.m(***) Log: Hi to file3. \n";
    XCTAssert([string bnc_isEqualToMaskedString:test]);


    BNCLogSetOutputFunction(origPtr);
}

- (void) testEvenLengthLogMessages {
    BNCLogOutputFunctionPtr origPtr = BNCLogOutputFunction();

    NSError *error = nil;
    NSURL *URL =
        [[NSFileManager defaultManager]
            URLForDirectory:NSCachesDirectory
            inDomain:NSUserDomainMask
            appropriateForURL:nil
            create:YES
            error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"io.branch.BranchSDK-Test"];
    [[NSFileManager defaultManager]
        createDirectoryAtURL:URL
        withIntermediateDirectories:YES
        attributes:nil
        error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"Test.log"];
    [[NSFileManager defaultManager]
        removeItemAtURL:URL
        error:&error];
    error = nil;

    // Check that we only write even length messages.

    BNCLogSetOutputToURL(URL);
    BNCLog(@"Hi to file01.");
    BNCLogCloseLogFile();

    NSString *string =
        [[NSString stringWithContentsOfURL:URL
            encoding:NSNEXTSTEPStringEncoding
            error:&error]
                bnc_stringTruncatedAtNull];
    NSString *test = @"[branch.io] BNCLog.Test.m(***) Log: Hi to file01.\n";
    XCTAssert([string bnc_isEqualToMaskedString:test]);

    // Re-open log file and append to it --
    BNCLogSetOutputToURL(URL);
    BNCLog(@"Hi to file02.");
    BNCLog(@"Hi to file03.");
    BNCLogCloseLogFile();

    NSData * data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    test =
        @"[branch.io] BNCLog.Test.m(***) Log: Hi to file01.\n"
        @"[branch.io] BNCLog.Test.m(***) Log: Hi to file02.\n"
        @"[branch.io] BNCLog.Test.m(***) Log: Hi to file03.\n";
    XCTAssert([string bnc_isEqualToMaskedString:test]);

    BNCLogSetOutputFunction(origPtr);
}

- (void) testTripleLengthLogMessages {
    BNCLogOutputFunctionPtr origPtr = BNCLogOutputFunction();

    NSError *error = nil;
    NSURL *URL =
        [[NSFileManager defaultManager]
            URLForDirectory:NSCachesDirectory
            inDomain:NSUserDomainMask
            appropriateForURL:nil
            create:YES
            error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"io.branch.BranchSDK-Test"];
    [[NSFileManager defaultManager]
        createDirectoryAtURL:URL
        withIntermediateDirectories:YES
        attributes:nil
        error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"Test.log"];
    [[NSFileManager defaultManager]
        removeItemAtURL:URL
        error:&error];
    error = nil;

    BNCLogSetOutputToURL(URL);
    BNCLog(@"Hi to file001.");
    BNCLogCloseLogFile();

    NSString *string =
        [[NSString stringWithContentsOfURL:URL
            encoding:NSUTF8StringEncoding
            error:&error]
                bnc_stringTruncatedAtNull];
    NSString *test = @"[branch.io] BNCLog.Test.m(***) Log: Hi to file001. \n";
    XCTAssert([string bnc_isEqualToMaskedString:test]);

    // Re-open log file and append to it --
    BNCLogSetOutputToURL(URL);
    BNCLog(@"Hi to file002.");
    BNCLog(@"Hi to file003.");
    BNCLogCloseLogFile();

    NSData * data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    test =
        @"[branch.io] BNCLog.Test.m(***) Log: Hi to file001. \n"
        @"[branch.io] BNCLog.Test.m(***) Log: Hi to file002. \n"
        @"[branch.io] BNCLog.Test.m(***) Log: Hi to file003. \n";
    XCTAssert([string bnc_isEqualToMaskedString:test]);

    BNCLogSetOutputFunction(origPtr);
}

- (void) testLogObject {
    BNCLogSetOutputFunction(TestLogProcedure);
    NSData *data = [@"Test string." dataUsingEncoding:NSUTF8StringEncoding];
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wformat-security"
    BNCLog((id)data);
    #pragma clang diagnostic pop
    BNCLogFlushMessages();
    XCTAssert([globalTestLogString() bnc_isEqualToMaskedString:
        @"[branch.io] BNCLog.Test.m(***) Log: "
         "0x**************** <NSConcreteMutableData> "
         "{length = 12, bytes = 0x5465737420737472696e672e}"]);
}

#pragma mark - Test BNCLogSetOutputToURLByteWrap

- (void) testLogFunctionOutputToURLByteWrap {

    BNCLogSetDisplayLevel(BNCLogLevelAll);

    // Remove the current file if it exists.

    NSError *error = nil;
    NSURL *URL =
        [[NSFileManager defaultManager]
            URLForDirectory:NSCachesDirectory
            inDomain:NSUserDomainMask
            appropriateForURL:nil
            create:YES
            error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"io.branch.BranchSDK-Test"];
    [[NSFileManager defaultManager]
        createDirectoryAtURL:URL
        withIntermediateDirectories:YES
        attributes:nil
        error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"TestWrap.log"];
    [[NSFileManager defaultManager]
        removeItemAtURL:URL
        error:&error];
    if (error) {
        NSLog(@"Error removing file: %@.", error);
        error = nil;
    }

    NSInteger const kLogSize = 78*5;

    // Extra line 1

    // Open the file, write 3 records.

    BNCLogSetOutputToURLByteWrap(URL, kLogSize);
    BNCLog(@"Log 01.");
    BNCLog(@"Log 02.");
    BNCLog(@"Log 03.");
    BNCLogCloseLogFile();

    // Check the file.

    NSData *data;
    NSString *string, *truth;
    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    truth  =
        @"****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 01.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 02.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 03.\n";
    XCTAssert([string bnc_isEqualToMaskedString:truth]);

    // Re-open the file, write 1 record.

    BNCLogSetOutputToURLByteWrap(URL, kLogSize);
    BNCLog(@"Log 04.");
    BNCLogCloseLogFile();

    // Check the file again.

    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    truth  =
        @"****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 01.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 02.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 03.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 04.\n";
    XCTAssert([string bnc_isEqualToMaskedString:truth]);

    // Re-open the file, write 3 records.

    BNCLogSetOutputToURLByteWrap(URL, kLogSize);
    BNCLog(@"Log 05.");
    BNCLog(@"Log 06.");
    BNCLog(@"Log 07.");
    BNCLogCloseLogFile();

    // Check the file: make sure it wrapped in the right place.

    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    truth  =
        @"****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 06.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 07.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 03.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 04.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 05.\n";
    XCTAssert([string bnc_isEqualToMaskedString:truth]);

    // Write 1 and check again.

    BNCLogSetOutputToURLByteWrap(URL, kLogSize);
    BNCLog(@"Log 08.");
    BNCLogCloseLogFile();

    // Check the file: make sure it wrapped in the right place.

    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    truth  =
        @"****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 06.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 07.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 08.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 04.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 05.\n";
    XCTAssert([string bnc_isEqualToMaskedString:truth]);

    // Write 23 records.  Make sure it wraps correctly.

    BNCLogSetOutputToURLByteWrap(URL, kLogSize);
    for (long i = 1; i <= 23; i++)
        BNCLog(@"Log %ld.", i);
    BNCLogCloseLogFile();

    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    truth  =
        @"****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 23.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 19.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 20.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 21.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 22.\n";
    XCTAssert([string bnc_isEqualToMaskedString:truth]);
    //NSLog(@"Result string:\n%@\ntruth:\n%@.", string, truth);
}

// This test sometimes fails due to timing issues so it sometimes fails.
//- (void) testStressByteWrap {
//    for (int i = 0; i < 1000; i++)
//        [self testLogFunctionOutputToURLByteWrap];
//}

- (void) testLogByteWrapPerformanceTesting {

    NSError *error = nil;
    NSURL *URL =
        [[NSFileManager defaultManager]
            URLForDirectory:NSCachesDirectory
            inDomain:NSUserDomainMask
            appropriateForURL:nil
            create:YES
            error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"io.branch.BranchSDK-Test"];
    [[NSFileManager defaultManager]
        createDirectoryAtURL:URL
        withIntermediateDirectories:YES
        attributes:nil
        error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"TestWrapSync.log"];
    [[NSFileManager defaultManager]
        removeItemAtURL:URL
        error:&error];
    error = nil;
    NSLog(@"Log is %@.", URL);

    NSInteger const kLogSize = 64;

    //  Test sychronized first --

    BNCLogSetOutputToURLByteWrap(URL, kLogSize);

    NSDate *startTime = [NSDate date];
    dispatch_group_t waitGroup = dispatch_group_create();

    dispatch_group_async(waitGroup,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        for (long i = 0; i < 2000; i++)
            BNCLog(@"Message 1 1x%ld.", i);
    });

    dispatch_group_async(waitGroup,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        for (long i = 0; i < 2000; i++)
            BNCLog(@"Message 1 2x%ld.", i);
    });

    dispatch_group_async(waitGroup,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        for (long i = 0; i < 2000; i++)
            BNCLog(@"Message 1 3x%ld.", i);
    });

    dispatch_group_wait(waitGroup, DISPATCH_TIME_FOREVER);
    BNCLogCloseLogFile();
    NSLog(@"%@: Synchronized time: %1.5f.",
        BNCSStringForCurrentMethod(), - startTime.timeIntervalSinceNow);

    // Test open and closed synchronization & threading --

    startTime = [NSDate date];
    waitGroup = dispatch_group_create();
    BNCLogSetDisplayLevel(BNCLogLevelAll);

    dispatch_group_async(waitGroup,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        for (long i = 0; i < 2000; i++) {
            BNCLog(@"Message 2 1x%ld.", i);
            if (i % 100 == 0) {
                BNCLogCloseLogFile();
                BNCLogSetOutputToURLByteWrap(URL, kLogSize);
            }
        }
    });

    dispatch_group_async(waitGroup,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        for (long i = 0; i < 2000; i++) {
            BNCLog(@"Message 2 2x%ld.", i);
            if (i % 25 == 0) {
                BNCLogCloseLogFile();
                BNCLogSetOutputToURLByteWrap(URL, kLogSize);
            }
        }
    });

    dispatch_group_async(waitGroup,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        for (long i = 0; i < 2000; i++) {
            BNCLog(@"Message 2 3x%ld.", i);
            if (i % 10 == 0) {
                BNCLogCloseLogFile();
                BNCLogSetOutputToURLByteWrap(URL, kLogSize);
            }
        }
    });

    dispatch_group_wait(waitGroup, DISPATCH_TIME_FOREVER);
    BNCLogCloseLogFile();
    NSLog(@"%@: Synchronized time: %1.5f.",
        BNCSStringForCurrentMethod(), - startTime.timeIntervalSinceNow);
}

- (void) testByteWrapTruncate {
    //  Create a larger log file then re-open and write smaller file to make sure it truncates.

    NSError *error = nil;
    NSURL *URL =
        [[NSFileManager defaultManager]
            URLForDirectory:NSCachesDirectory
            inDomain:NSUserDomainMask
            appropriateForURL:nil
            create:YES
            error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"io.branch.BranchSDK-Test"];
    [[NSFileManager defaultManager]
        createDirectoryAtURL:URL
        withIntermediateDirectories:YES
        attributes:nil
        error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"TestWrapSync.log"];
    [[NSFileManager defaultManager]
        removeItemAtURL:URL
        error:&error];
    NSLog(@"Remove error is '%@'.\nLog is %@.", error, URL);
    error = nil;

    BNCLogSetOutputToURLByteWrap(URL, 1024);
    for (long i = 0; i < 100; i++) {
        BNCLog(@"Log %ld.", i);
    }
    BNCLogCloseLogFile();

    NSData *data;
    NSString *string;
    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssert(string.length > 512 && string.length <= 1024);

    BNCLogSetOutputToURLByteWrap(URL, 512);
    for (long i = 0; i < 100; i++) {
        BNCLog(@"Log %ld.", i);
    }
    BNCLogCloseLogFile();

    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssert(string.length <= 512);
}

- (void) testByteWrapUnevenRecordReopen {
    // Make sure the re-open works at the right place when records aren't even:

    NSError *error = nil;
    NSURL *URL =
        [[NSFileManager defaultManager]
            URLForDirectory:NSCachesDirectory
            inDomain:NSUserDomainMask
            appropriateForURL:nil
            create:YES
            error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"io.branch.BranchSDK-Test"];
    [[NSFileManager defaultManager]
        createDirectoryAtURL:URL
        withIntermediateDirectories:YES
        attributes:nil
        error:&error];
    XCTAssert(!error);
    URL = [URL URLByAppendingPathComponent:@"TestWrap.log"];
    [[NSFileManager defaultManager]
        removeItemAtURL:URL
        error:&error];
    if (error) {
        NSLog(@"Error removing file: %@.", error);
        error = nil;
    }

    NSInteger const kLogSize = 78*5;

    // Open the file, write 3 records.

    BNCLogSetOutputToURLByteWrap(URL, kLogSize);
    BNCLog(@"Log 1.");
    BNCLog(@"Log 12.");
    BNCLog(@"Log 123.");
    BNCLogCloseLogFile();

    // Check the file.

    NSData *data;
    NSString *string, *truth;
    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    truth  =
        @"****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 1. \n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 12.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 123. \n";
    XCTAssert([string bnc_isEqualToMaskedString:truth]);

    //  Write record.  Check for append and wrap:

    BNCLogSetOutputToURLByteWrap(URL, kLogSize);
    BNCLog(@"Log 1234.");
    BNCLog(@"Log 12345.");
    BNCLog(@"Log 123456.");
    BNCLogCloseLogFile();

    // Check the file.

    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    truth =
        @"****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 123456.\n"
         "-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 12.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 123. \n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 1234.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 12345. \n";

    XCTAssert([string bnc_isEqualToMaskedString:truth]);

    // Re-open the file, write 1 record.

    BNCLogSetOutputToURLByteWrap(URL, kLogSize);
    BNCLog(@"Log 1234567.");
    BNCLogCloseLogFile();

    // Check the file again.

    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    truth  =
        @"****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 123456.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 1234567. \n"
         "T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 123. \n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 1234.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 12345. \n";
    XCTAssert([string bnc_isEqualToMaskedString:truth]);

    // Re-open the file, write 2 records.

    BNCLogSetOutputToURLByteWrap(URL, kLogSize);
    BNCLog(@"Log 12345678.");
    BNCLog(@"Log 123456789.");
    BNCLogCloseLogFile();

    data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
    XCTAssert(!error && data);
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    truth  =
        @"****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 123456.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 1234567. \n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 12345678.\n"
         "****-**-**T**:**:**.******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 123456789. \n"
         "******Z 5 [branch.io] BNCLog.Test.m(***) Log: Log 12345. \n";
    XCTAssert([string bnc_isEqualToMaskedString:truth]);
    //NSLog(@"string:\n%@\n%@.", string, truth);
}

- (void) testLogLevelString {
    XCTAssertEqual(BNCLogLevelAll,      BNCLogLevelFromString(@"BNCLogLevelAll"));
    XCTAssertEqual(BNCLogLevelDebugSDK, BNCLogLevelFromString(@"BNCLogLevelDebugSDK"));
    XCTAssertEqual(BNCLogLevelWarning,  BNCLogLevelFromString(@"BNCLogLevelWarning"));
    XCTAssertEqual(BNCLogLevelNone,     BNCLogLevelFromString(@"BNCLogLevelNone"));
    XCTAssertEqual(BNCLogLevelMax,      BNCLogLevelFromString(@"BNCLogLevelMax"));
}

- (void) testLogLevelEnum {
    XCTAssertEqualObjects(@"BNCLogLevelAll",        BNCLogStringFromLogLevel(BNCLogLevelAll));
    XCTAssertEqualObjects(@"BNCLogLevelAll",        BNCLogStringFromLogLevel(BNCLogLevelDebugSDK));
    XCTAssertEqualObjects(@"BNCLogLevelWarning",    BNCLogStringFromLogLevel(BNCLogLevelWarning));
    XCTAssertEqualObjects(@"BNCLogLevelNone",       BNCLogStringFromLogLevel(BNCLogLevelNone));
    XCTAssertEqualObjects(@"BNCLogLevelMax",        BNCLogStringFromLogLevel(BNCLogLevelMax));
}

@end
