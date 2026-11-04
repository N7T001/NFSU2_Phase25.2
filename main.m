#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include "cpu.h"

extern uint8_t *g_mem;
extern uint64_t mem_committed(void);

typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    int ready;
    int woke;
    int counter;
} SyncState;

static void *waiter(void *opaque) {
    SyncState *s = (SyncState *)opaque;
    pthread_mutex_lock(&s->mutex);
    struct timespec deadline;
    clock_gettime(CLOCK_REALTIME, &deadline);
    deadline.tv_sec += 5;
    int rc = 0;
    while (!s->ready && rc == 0) {
        rc = pthread_cond_timedwait(&s->cond, &s->mutex, &deadline);
    }
    s->woke = (rc == 0 && s->ready) ? 1 : 0;
    pthread_mutex_unlock(&s->mutex);
    return NULL;
}

static void *signaler(void *opaque) {
    SyncState *s = (SyncState *)opaque;
    struct timespec delay = {0, 50000000L};
    nanosleep(&delay, NULL);
    pthread_mutex_lock(&s->mutex);
    s->ready = 1;
    pthread_cond_signal(&s->cond);
    pthread_mutex_unlock(&s->mutex);
    return NULL;
}

static void *counter_worker(void *opaque) {
    SyncState *s = (SyncState *)opaque;
    for (int i = 0; i < 10000; ++i) {
        pthread_mutex_lock(&s->mutex);
        s->counter++;
        pthread_mutex_unlock(&s->mutex);
    }
    return NULL;
}

static NSString *runTests(void) {
    NSMutableString *report = [NSMutableString stringWithString:@"NFSU2 iOS Phase 2.7\n\n"];
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    [report appendFormat:@"Metal: %@\n", device ? @"PASS" : @"FAIL"];

    // Reuses the real NFSU2Recomp guest memory implementation.
    mem_init();
    if (!g_mem) {
        [report appendString:@"Guest reservation: FAIL\n"];
        return report;
    }
    const uint32_t addresses[] = {0x00400000u, 0x10000000u, 0x7E000000u, 0xFFFF0000u};
    BOOL memOK = YES;
    for (unsigned i = 0; i < 4; ++i) {
        uint32_t a = addresses[i];
        mem_commit(a, 16384u);
        volatile uint32_t *p = (volatile uint32_t *)(g_mem + (uint64_t)a);
        uint32_t value = 0x4E465300u + i;
        *p = value;
        memOK &= (*p == value) && mem_is_committed(a) && mem_is_committed(a + 16383u);
    }
    [report appendFormat:@"Guest memory: %@ (%llu KiB)\n\n",
        memOK ? @"PASS" : @"FAIL", (unsigned long long)(mem_committed()/1024u)];

    SyncState s;
    memset(&s, 0, sizeof(s));
    int m = pthread_mutex_init(&s.mutex, NULL);
    int c = (m == 0) ? pthread_cond_init(&s.cond, NULL) : -1;
    if (m != 0 || c != 0) {
        [report appendFormat:@"pthread init: FAIL (%d/%d)\n", m, c];
        if (m == 0) pthread_mutex_destroy(&s.mutex);
        return report;
    }
    pthread_attr_t attr;
    int ar = pthread_attr_init(&attr);
    if (ar == 0) ar = pthread_attr_setstacksize(&attr, 8u * 1024u * 1024u);
    [report appendFormat:@"8 MiB stack attribute: %@\n", ar == 0 ? @"PASS" : @"FAIL"];
    pthread_t a, b;
    int ra = -1, rb = -1;
    if (ar == 0) {
        ra = pthread_create(&a, &attr, waiter, &s);
        if (ra == 0) rb = pthread_create(&b, &attr, signaler, &s);
    }
    if (ar == 0) pthread_attr_destroy(&attr);
    if (ra == 0 && rb != 0) {
        pthread_mutex_lock(&s.mutex);
        s.ready = 1;
        pthread_cond_signal(&s.cond);
        pthread_mutex_unlock(&s.mutex);
    }
    if (ra == 0) pthread_join(a, NULL);
    if (rb == 0) pthread_join(b, NULL);
    BOOL wakeOK = ra == 0 && rb == 0 && s.woke == 1;
    [report appendFormat:@"Thread create/join: %@\n", ra == 0 && rb == 0 ? @"PASS" : @"FAIL"];
    [report appendFormat:@"Condvar wake: %@\n", wakeOK ? @"PASS" : @"FAIL"];

    s.counter = 0;
    int r1 = pthread_create(&a, NULL, counter_worker, &s);
    int r2 = pthread_create(&b, NULL, counter_worker, &s);
    if (r1 == 0) pthread_join(a, NULL);
    if (r2 == 0) pthread_join(b, NULL);
    BOOL mutexOK = r1 == 0 && r2 == 0 && s.counter == 20000;
    [report appendFormat:@"Mutex counter: %@ (%d/20000)\n", mutexOK ? @"PASS" : @"FAIL", s.counter];
    pthread_cond_destroy(&s.cond);
    pthread_mutex_destroy(&s.mutex);
    BOOL all = device != nil && memOK && ar == 0 && wakeOK && mutexOK;
    [report appendFormat:@"\nOverall: %@\n\nHost pthread test; guest threads not yet connected.", all ? @"PASS" : @"FAIL"];
    return report;
}

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
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.65;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.leadingAnchor constant:12],
        [label.trailingAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor]
    ]];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    label.text = @"NFSU2 iOS Phase 2.7\n\nRunning tests...";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *result = runTests();
        dispatch_async(dispatch_get_main_queue(), ^{ label.text = result; });
    });
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([SmokeDelegate class])); }
}
