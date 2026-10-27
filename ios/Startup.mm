#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include "ImportCopy.hpp"
#include <cmath>
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
@property(nonatomic) BOOL importing;
@property(nonatomic, strong) UILabel *status;
@property(nonatomic, strong) UILabel *detail;
@property(nonatomic, strong) UIProgressView *progress;
@property(nonatomic, strong) UIActivityIndicatorView *activity;
@property(nonatomic, strong) UIButton *importButton;
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
    self.detail = [UILabel new];
    self.detail.textAlignment = NSTextAlignmentCenter;
    self.detail.numberOfLines = 0;
    self.detail.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.detail.textColor = UIColor.secondaryLabelColor;
    self.detail.hidden = YES;
    self.progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progress.accessibilityLabel = @"Data import progress";
    self.progress.hidden = YES;
    self.activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activity.hidesWhenStopped = YES;
    self.importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.importButton setTitle:@"Import Data.rsdk" forState:UIControlStateNormal];
    self.importButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.importButton addTarget:self action:@selector(importPack) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, self.status, self.progress, self.detail, self.activity, self.importButton]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    NSLayoutConstraint *preferredWidth = [stack.widthAnchor constraintEqualToConstant:550];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        preferredWidth,
        [stack.widthAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-48],
        [stack.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor]
    ]];
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)importPack {
    if (self.importing || self.presentedViewController) return;
    // public.data can grey out unknown .rsdk extensions. Let the user select
    // any file, then check its archive signature after copying it.
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeItem] asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.shouldShowFileExtensions = YES;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.status.text = @"Choose Data.rsdk from your copy of Sonic 1.";
}
- (void)showCopied:(uint64_t)copied total:(uint64_t)total elapsed:(double)elapsed {
    double fraction = total ? fmin(1.0, (double)copied / total) : 0;
    self.progress.hidden = NO;
    [self.progress setProgress:(float)fraction animated:NO];
    self.progress.accessibilityValue = [NSString stringWithFormat:@"%.0f percent", floor(fraction * 100)];
    [self.activity stopAnimating];
    self.status.text = [NSString stringWithFormat:@"Importing Data.rsdk… %.0f%%", floor(fraction * 100)];
    NSString *time = @"Estimating time…";
    if (copied >= total) {
        time = @"Finalizing…";
        self.status.text = @"Checking imported data…";
        [self.activity startAnimating];
    } else if (copied > 0 && elapsed >= 0.5) {
        double seconds = (double)(total - copied) * elapsed / copied;
        if (seconds < 1) time = @"Less than 1 second remaining";
        else if (seconds < 60) time = [NSString stringWithFormat:@"About %.0f s remaining", ceil(seconds)];
        else time = [NSString stringWithFormat:@"About %.0f min remaining", ceil(seconds / 60)];
    }
    self.detail.text = [NSString stringWithFormat:@"%.1f / %.1f MB · %@", copied / 1048576.0, total / 1048576.0, time];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *source = urls.firstObject;
    if (!source || self.importing) return;
    self.importing = YES;
    self.importButton.enabled = NO;
    self.progress.progress = 0;
    self.progress.hidden = NO;
    self.detail.hidden = NO;
    self.detail.text = @"Waiting for the file provider…";
    self.status.text = @"Preparing selected file…";
    [self.activity startAnimating];
    // Coordination, cloud-provider downloads and copying must not block UIKit.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            BOOL scoped = [source startAccessingSecurityScopedResource];
            NSFileManager *fm = NSFileManager.defaultManager;
            NSURL *temporary = [NSURL fileURLWithPath:[Documents() stringByAppendingPathComponent:@"Data.import"]];
            NSURL *destination = [NSURL fileURLWithPath:[Documents() stringByAppendingPathComponent:@"Data.rsdk"]];
            [fm removeItemAtURL:temporary error:nil];
            __block NSError *copyError = nil;
            NSError *coordinationError = nil;
            NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            [coordinator coordinateReadingItemAtURL:source options:0 error:&coordinationError byAccessor:^(NSURL *readURL) {
                double started = NSProcessInfo.processInfo.systemUptime;
                double lastUpdate = -1;
                int result = forever::CopyFileWithProgress(readURL.fileSystemRepresentation, temporary.fileSystemRepresentation,
                    [&](uint64_t copied, uint64_t total) {
                        double elapsed = NSProcessInfo.processInfo.systemUptime - started;
                        if (copied != 0 && copied != total && elapsed - lastUpdate < 0.1) return;
                        lastUpdate = elapsed;
                        dispatch_async(dispatch_get_main_queue(), ^{ [self showCopied:copied total:total elapsed:elapsed]; });
                    });
                if (result) copyError = [NSError errorWithDomain:NSPOSIXErrorDomain code:result userInfo:nil];
            }];
            if (scoped) [source stopAccessingSecurityScopedResource];
            NSError *error = coordinationError ?: copyError;
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
            if (error) [fm removeItemAtURL:temporary error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.importing = NO;
                [self.activity stopAnimating];
                if (error) {
                    self.status.text = @"Import failed";
                    self.detail.text = error.localizedDescription;
                    self.progress.hidden = YES;
                    self.importButton.enabled = YES;
                    [self.importButton setTitle:@"Choose another file" forState:UIControlStateNormal];
                } else {
                    self.progress.progress = 1;
                    self.status.text = @"Import complete — 100%";
                    self.detail.text = @"Starting Sonic Forever…";
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ self.ready = YES; });
                }
            });
        }
    });
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
        NSString *version = @"1.5.0-ios-3";
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
