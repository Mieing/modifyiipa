#import <Foundation/Foundation.h>
#import <spawn.h>
#import <unistd.h>
#import <pthread.h>


#define RESET_COLOR "\033[0m" // 重置颜色

// 定义颜色数组
const char *colors[] = {
    "\033[38;5;196m", // 红色
    "\033[38;5;202m", // 橙色
    "\033[38;5;226m", // 黄色
    "\033[38;5;82m",  // 绿色
    "\033[38;5;45m",  // 蓝色
    "\033[38;5;135m", // 紫色
    "\033[38;5;200m", // 粉色
};

void printUsage() {
    printf("\n用法:\n");
    printf("modifyiipa ipa_path param\n\n");

    printf("参数:\n");
    printf("-id newBundleID                 修改 bundle id\n");
    printf("-u  enable RemoveURLSchemes     Remove url schemes\n\n");

    printf("一个例子:\n");
    printf("modifyiipa /var/mobile/Documents/modifyiipa.ipa -id cn.modifyiipa.st -u\n\n");
}

int runCommand(const char *cmd) {
    pid_t pid;
    int status;
    char *argv[] = {"/bin/sh", "-c", (char *)cmd, NULL};
    posix_spawn(&pid, argv[0], NULL, NULL, argv, NULL);
    waitpid(pid, &status, 0);
    return status;
}

// 全局变量，控制动画线程
BOOL isAnimationRunning = NO;

// 随机颜色
const char *randomColor() {
    int colorIndex = arc4random_uniform(sizeof(colors) / sizeof(colors[0]));
    return colors[colorIndex];
}

// 显示动画
void *showProgressAnimation(void *action) {
    isAnimationRunning = YES;
    const char *spinner[] = {"|", "/", "-", "\\", "*", "o", "+", "•"};
    int spinnerIndex = 0;

    while (isAnimationRunning) {
        printf("\r%s %s%s%s", randomColor(), (char *)action, spinner[spinnerIndex], RESET_COLOR);
        fflush(stdout);
        spinnerIndex = (spinnerIndex + 1) % 8;
        usleep(200000); // 每200毫秒更新一次
    }
    return NULL;
}

// 停止动画
void stopProgressAnimation() {
    isAnimationRunning = NO;
    printf("\r\n");  // 清除动画行
}

void unzipIPA(NSString *ipaPath, NSString *tempDir) {
    pthread_t animationThread;
    pthread_create(&animationThread, NULL, showProgressAnimation, "解压 IPA 文件");
    
    NSString *unzipCommand = [NSString stringWithFormat:@"unzip -q %@ -d %@", ipaPath, tempDir];
    runCommand([unzipCommand UTF8String]);
    
    stopProgressAnimation();
    pthread_join(animationThread, NULL);  // 确保动画线程已结束
}

void zipIPA(NSString *outputIpaPath, NSString *tempDir) {
    pthread_t animationThread;
    pthread_create(&animationThread, NULL, showProgressAnimation, "重新打包 IPA 文件");
    
    NSString *zipCommand = [NSString stringWithFormat:@"cd %@ && zip -qr %@ Payload/", tempDir, outputIpaPath];
    runCommand([zipCommand UTF8String]);
    
    stopProgressAnimation();
    pthread_join(animationThread, NULL);  // 确保动画线程已结束
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        BOOL removeURL = NO;
        NSString *ipaPath = nil;
        NSString *newBundleID = nil;

        // 参数解析
        for (int i = 1; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];

            if ([arg isEqualToString:@"-u"]) {
                removeURL = YES;
            } else if ([arg isEqualToString:@"-id"] && (i + 1 < argc)) {
                newBundleID = [NSString stringWithUTF8String:argv[++i]];
            } else if (!ipaPath) {
                ipaPath = arg;
            }
        }

        // 检查输入参数
        if (!ipaPath || !newBundleID) {
            printUsage(); // 打印用法说明
            return 1;
        }

        NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"modifyiipa"];
        NSString *outputIpaPath = [[ipaPath stringByDeletingPathExtension] stringByAppendingString:@"_modified.ipa"];

        // 解压 IPA 文件
        unzipIPA(ipaPath, tempDir);

        // 定位 Info.plist 文件
        NSString *payloadPath = [tempDir stringByAppendingPathComponent:@"Payload"];
        NSString *appPath = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil] firstObject];
        NSString *plistPath = [[payloadPath stringByAppendingPathComponent:appPath] stringByAppendingPathComponent:@"Info.plist"];

        // 修改 Bundle ID
        NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
        if (!plistDict) {
            printf("%sError: Info.plist not found or cannot be read.\n%s", randomColor(), RESET_COLOR);
            return 1;
        }

        plistDict[@"CFBundleIdentifier"] = newBundleID;

        if (removeURL) {
            [plistDict removeObjectForKey:@"CFBundleURLTypes"];
        }

        [plistDict writeToFile:plistPath atomically:YES];

        // 重新打包 IPA
        zipIPA(outputIpaPath, tempDir);

        // 删除临时目录
        [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];

        printf("%sModified IPA generated at: %s\n%s", randomColor(), [outputIpaPath UTF8String], RESET_COLOR);
    }
    return 0;
}
