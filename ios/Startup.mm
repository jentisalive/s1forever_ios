#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <unistd.h>
#include <cstring>
#include <cstdio>

static NSString *Documents() {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}
const char *getDocumentsPath() {
    static char path[1024];
    static dispatch_once_t once;
    dispatch_once(&once, ^{ snprintf(path, sizeof(path), "%s", Documents().fileSystemRepresentation); });
    return path;
}

static BOOL ValidPack(NSURL *url) {
    NSFileHandle *file = [NSFileHandle fileHandleForReadingFromURL:url error:nil];
    if (!file) return NO;
    NSData *header = [file readDataOfLength:8];
    [file closeFile];
    if (header.length != 8 || memcmp(header.bytes, "RSDKvB", 6)) return NO;
    const unsigned char *bytes = (const unsigned char *)header.bytes;
    NSUInteger count = bytes[6] | (bytes[7] << 8);
    NSNumber *size;
    if (![url getResourceValue:&size forKey:NSURLFileSizeKey error:nil]) return NO;
    return count > 0 && size.unsignedLongLongValue >= 8 + count * 24;
}

@interface ForeverImportController : UIViewController <UIDocumentPickerDelegate>
@property(nonatomic) BOOL ready;
@property(nonatomic, strong) UILabel *status;
@end
@implementation ForeverImportController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *title = [UILabel new];
    title.text = @"Sonic Forever";
    title.font = [UIFont boldSystemFontOfSize:32];
    title.textAlignment = NSTextAlignmentCenter;
    self.status = [UILabel new];
    self.status.text = @"Choose Data.rsdk from your copy of Sonic 1.\nYour saves stay on this device.";
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.numberOfLines = 0;
    self.status.font = [UIFont systemFontOfSize:17];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:@"Import Data.rsdk" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [button addTarget:self action:@selector(importPack) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, self.status, button]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 24;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:550],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24]
    ]];
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)importPack {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *source = urls.firstObject;
    if (!source) return;
    BOOL scoped = [source startAccessingSecurityScopedResource];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *temporary = [NSURL fileURLWithPath:[Documents() stringByAppendingPathComponent:@"Data.import"]];
    NSURL *destination = [NSURL fileURLWithPath:[Documents() stringByAppendingPathComponent:@"Data.rsdk"]];
    [fm removeItemAtURL:temporary error:nil];
    __block NSError *error = nil;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateReadingItemAtURL:source options:0 error:&error byAccessor:^(NSURL *readURL) {
        [fm copyItemAtURL:readURL toURL:temporary error:&error];
    }];
    if (scoped) [source stopAccessingSecurityScopedResource];
    if (!error && !ValidPack(temporary)) {
        error = [NSError errorWithDomain:@"Forever" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Choose an RSDKv4 Data.rsdk file from Sonic 1."}];
    }
    if (!error) {
        if ([fm fileExistsAtPath:destination.path]) {
            [fm replaceItemAtURL:destination withItemAtURL:temporary backupItemName:nil options:0 resultingItemURL:nil error:&error];
        } else {
            [fm moveItemAtURL:temporary toURL:destination error:&error];
        }
    }
    if (error) {
        [fm removeItemAtURL:temporary error:nil];
        self.status.text = error.localizedDescription;
    } else {
        self.status.text = @"Starting Sonic Forever…";
        // Let the system finish dismissing its document picker first.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ self.ready = YES; });
    }
}
@end

bool IOSPrepareGame() {
    @autoreleasepool {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *docs = Documents();
        NSError *error = nil;
        [fm createDirectoryAtPath:docs withIntermediateDirectories:YES attributes:nil error:&error];
        if (error || chdir(docs.fileSystemRepresentation) != 0) return false;
        NSString *resources = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"ForeverResources"];
        NSString *mods = [docs stringByAppendingPathComponent:@"mods"];
        [fm createDirectoryAtPath:mods withIntermediateDirectories:YES attributes:nil error:&error];
        NSString *version = @"1.5.0-ios-1";
        NSString *marker = [docs stringByAppendingPathComponent:@".bundled-version"];
        NSString *installed = [NSString stringWithContentsOfFile:marker encoding:NSUTF8StringEncoding error:nil];
        NSString *targetMod = [mods stringByAppendingPathComponent:@"Sonic 1 Forever"];
        if (![installed isEqualToString:version] || ![fm fileExistsAtPath:targetMod]) {
            [fm removeItemAtPath:targetMod error:nil];
            if (![fm copyItemAtPath:[resources stringByAppendingPathComponent:@"mods/Sonic 1 Forever"] toPath:targetMod error:&error]) {
                NSLog(@"Forever resources: %@", error); return false;
            }
            [version writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        NSString *config = [mods stringByAppendingPathComponent:@"modconfig.ini"];
        if (![fm fileExistsAtPath:config])
            [fm copyItemAtPath:[resources stringByAppendingPathComponent:@"mods/modconfig.ini"] toPath:config error:nil];
        NSString *settings = [docs stringByAppendingPathComponent:@"settings.ini"];
        if (![fm fileExistsAtPath:settings])
            [fm copyItemAtPath:[resources stringByAppendingPathComponent:@"settings.ini"] toPath:settings error:nil];
        NSURL *pack = [NSURL fileURLWithPath:[docs stringByAppendingPathComponent:@"Data.rsdk"]];
        if (ValidPack(pack)) return true;
        UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        ForeverImportController *controller = [ForeverImportController new];
        window.rootViewController = controller;
        [window makeKeyAndVisible];
        while (!controller.ready) {
            @autoreleasepool {
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            }
        }
        window.hidden = YES;
        return true;
    }
}
