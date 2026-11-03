#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <sys/mman.h>
#import <unistd.h>
#import <stdint.h>

@interface SmokeDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation SmokeDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    (void)application; (void)options;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightMedium];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [label.trailingAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor]
    ]];
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    const size_t guestSize = (size_t)UINT64_C(0x100000000);
    void *guest = mmap(NULL, guestSize, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
    BOOL reserved = guest != MAP_FAILED;
    BOOL committed = NO;
    if (reserved) {
        size_t page = (size_t)getpagesize();
        if (mprotect(guest, page, PROT_READ | PROT_WRITE) == 0) {
            volatile uint32_t *probe = (volatile uint32_t *)guest;
            *probe = 0x4E465355u;
            committed = (*probe == 0x4E465355u);
        }
        munmap(guest, guestSize);
    }
    label.text = [NSString stringWithFormat:@"NFSU2 iOS Phase 2.5\n\nMetal: %@\n4 GB address reservation: %@\nFirst-page read/write: %@\n\nThis is a platform smoke test, not the game.",
        device ? @"PASS" : @"FAIL", reserved ? @"PASS" : @"FAIL", committed ? @"PASS" : @"FAIL"];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([SmokeDelegate class])); }
}
