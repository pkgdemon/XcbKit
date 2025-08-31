#import "XCBThemeService.h"
#import <AppKit/AppKit.h>

@implementation XCBThemeService

+ (instancetype)sharedInstance {
    static XCBThemeService *instance = nil;
    if (!instance) {
        instance = [[XCBThemeService alloc] init];
    }
    return instance;
}

- (XCBColor)titleBarActiveColor {
    @try {
        // Try to get theme colors from GNUstep
        NSColor *color = [[NSColor controlColor] highlightWithLevel:0.1];
        return [self xcbColorFromNSColor:color];
    }
    @catch (NSException *exception) {
        // Fallback to original color if GSTheme fails
        return XCBMakeColor(0.720, 0.720, 0.720, 1);
    }
}

- (XCBColor)titleBarInactiveColor {
    @try {
        NSColor *color = [NSColor controlBackgroundColor];
        return [self xcbColorFromNSColor:color];
    }
    @catch (NSException *exception) {
        return XCBMakeColor(0.898, 0.898, 0.898, 1);
    }
}

- (XCBColor)buttonCloseColor {
    @try {
        NSColor *color = [[NSColor redColor] highlightWithLevel:0.2];
        return [self xcbColorFromNSColor:color];
    }
    @catch (NSException *exception) {
        return XCBMakeColor(0.411, 0.176, 0.673, 1);
    }
}

- (XCBColor)buttonMinimizeColor {
    @try {
        NSColor *color = [[NSColor yellowColor] highlightWithLevel:0.1];
        return [self xcbColorFromNSColor:color];
    }
    @catch (NSException *exception) {
        return XCBMakeColor(0.9, 0.7, 0.3, 1);
    }
}

- (XCBColor)buttonMaximizeColor {
    @try {
        NSColor *color = [[NSColor greenColor] highlightWithLevel:0.1];
        return [self xcbColorFromNSColor:color];
    }
    @catch (NSException *exception) {
        return XCBMakeColor(0, 0.74, 1, 1);
    }
}

- (XCBColor)xcbColorFromNSColor:(NSColor*)nsColor {
    if (!nsColor) {
        return XCBMakeColor(0.5, 0.5, 0.5, 1.0); // Gray fallback
    }
    
    // Convert to RGB color space
    NSColor *rgbColor = [nsColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    if (!rgbColor) {
        return XCBMakeColor(0.5, 0.5, 0.5, 1.0); // Gray fallback
    }
    
    CGFloat r, g, b, a;
    [rgbColor getRed:&r green:&g blue:&b alpha:&a];
    return XCBMakeColor(r, g, b, a);
}

@end
