#import "XCBRenderingEngine.h"
#import "XCBTitleBar.h"
#import "XCBFrame.h"
#import "XCBThemeService.h"
#import "services/TitleBarSettingsService.h"
#import <cairo/cairo-xcb.h>
#import <xcb/xcb_aux.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846264338327950288
#endif

@implementation XCBRenderingEngine

#pragma mark - Singleton

+ (instancetype)sharedEngine {
    static XCBRenderingEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XCBRenderingEngine alloc] init];
    });
    return instance;
}

#pragma mark - Public Methods

+ (void)renderTitleBar:(XCBTitleBar *)titleBar {
    [[self sharedEngine] renderTitleBarInternal:titleBar];
}

+ (void)renderButton:(XCBWindow *)button active:(BOOL)active {
    [[self sharedEngine] renderButtonInternal:button active:active];
}

+ (void)renderFrame:(XCBFrame *)frame {
    [[self sharedEngine] renderFrameInternal:frame];
}

#pragma mark - Title Bar Rendering

- (void)renderTitleBarInternal:(XCBTitleBar *)titleBar {
    if (!titleBar || !titleBar.connection || !titleBar.pixmap || !titleBar.dPixmap) {
        NSLog(@"[XCBRenderingEngine] Invalid titleBar for rendering");
        return;
    }
    
    // Get visual
    XCBWindow *rootWindow = [titleBar.parentWindow parentWindow];
    XCBScreen *screen = [rootWindow screen];
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];
    [visual setVisualTypeForScreen:screen];
    
    // Get theme colors
    XCBThemeService *theme = [XCBThemeService sharedInstance];
    XCBColor activeColor = [theme titleBarActiveColor];
    XCBColor inactiveColor = [theme titleBarInactiveColor];
    
    // Render to both pixmaps
    [self renderTitleBarToPixmap:titleBar.pixmap 
                       titleBar:titleBar 
                         visual:visual 
                         active:YES 
                          color:activeColor];
    
    [self renderTitleBarToPixmap:titleBar.dPixmap 
                       titleBar:titleBar 
                         visual:visual 
                         active:NO 
                          color:inactiveColor];
    
    // Mark as rendered
    titleBar.isRendered = YES;
}

- (void)renderTitleBarToPixmap:(xcb_pixmap_t)pixmap 
                      titleBar:(XCBTitleBar *)titleBar
                        visual:(XCBVisual *)visual
                        active:(BOOL)active
                         color:(XCBColor)color {
    
    CGFloat width = titleBar.windowRect.size.width;
    CGFloat height = titleBar.windowRect.size.height;
    
    // Create Cairo surface
    cairo_surface_t *surface = cairo_xcb_surface_create(
        [titleBar.connection connection],
        pixmap,
        [visual visualType],
        width,
        height - 1  // Account for border
    );
    
    cairo_t *cr = cairo_create(surface);
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);
    
    // Draw gradient background
    [self drawTitleBarGradient:cr width:width height:height color:color];
    
    // Draw window title if set
    NSString *title = [titleBar windowTitle];
    if (title && [title length] > 0) {
        [self drawTitleText:title context:cr width:width height:height];
    }
    
    // Clean up
    cairo_surface_flush(surface);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
}

- (void)drawTitleBarGradient:(cairo_t *)cr 
                       width:(CGFloat)width 
                      height:(CGFloat)height 
                       color:(XCBColor)color {
    
    // Create gradient
    cairo_pattern_t *pat = cairo_pattern_create_linear(0, height, 0, 0);
    
    // Lighter at top
    cairo_pattern_add_color_stop_rgb(pat, 0.2, 
        color.redComponent,
        color.greenComponent,
        color.blueComponent);
    
    // Slightly darker at bottom for depth
    cairo_pattern_add_color_stop_rgb(pat, 0.99,
        color.redComponent * 0.93,
        color.greenComponent * 0.93,
        color.blueComponent * 0.93);
    
    cairo_set_source(cr, pat);
    cairo_rectangle(cr, 0, 0, width, height - 1);
    cairo_fill(cr);
    
    cairo_pattern_destroy(pat);
}

- (void)drawTitleText:(NSString *)text 
              context:(cairo_t *)cr
                width:(CGFloat)width
               height:(CGFloat)height {
    
    if (!text || [text length] == 0) return;
    
    // Set text color (black)
    cairo_set_source_rgb(cr, 0, 0, 0);
    
    // Set font
    cairo_select_font_face(cr, "Serif", 
                          CAIRO_FONT_SLANT_NORMAL, 
                          CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 11);
    
    // Calculate text position (centered)
    cairo_text_extents_t extents;
    const char *utfString = [text UTF8String];
    cairo_text_extents(cr, utfString, &extents);
    
    CGFloat textX = (width - extents.width) / 2.0;
    CGFloat textY = (height / 2.0) + 2;  // Slightly below center
    
    // Draw text
    cairo_move_to(cr, textX, textY);
    cairo_show_text(cr, utfString);
}

#pragma mark - Button Rendering

- (void)renderButtonInternal:(XCBWindow *)button active:(BOOL)active {
    if (!button || !button.connection || !button.pixmap || !button.dPixmap) {
        NSLog(@"[XCBRenderingEngine] Invalid button for rendering");
        return;
    }
    
    XCBTitleBar *titleBar = (XCBTitleBar *)[button parentWindow];
    XCBWindow *rootWindow = [titleBar.parentWindow parentWindow];
    XCBScreen *screen = [rootWindow screen];
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];
    [visual setVisualTypeForScreen:screen];
    
    // Determine button color
    XCBThemeService *theme = [XCBThemeService sharedInstance];
    XCBColor buttonColor;
    
    if ([button isCloseButton]) {
        buttonColor = [theme buttonCloseColor];
    } else if ([button isMinimizeButton]) {
        buttonColor = [theme buttonMinimizeColor];
    } else if ([button isMaximizeButton]) {
        buttonColor = [theme buttonMaximizeColor];
    } else {
        buttonColor = XCBMakeColor(0.5, 0.5, 0.5, 1.0);
    }
    
    // Render to both pixmaps
    [self renderButtonToPixmap:button.pixmap 
                        button:button 
                        visual:visual 
                        active:YES 
                         color:buttonColor
                    titleColor:titleBar.titleBarUpColor];
    
    [self renderButtonToPixmap:button.dPixmap 
                        button:button 
                        visual:visual 
                        active:NO 
                         color:titleBar.titleBarDownColor
                    titleColor:titleBar.titleBarDownColor];
}

- (void)renderButtonToPixmap:(xcb_pixmap_t)pixmap
                       button:(XCBWindow *)button
                       visual:(XCBVisual *)visual
                       active:(BOOL)active
                        color:(XCBColor)buttonColor
                   titleColor:(XCBColor)titleBarColor {
    
    CGFloat width = button.windowRect.size.width;
    CGFloat height = button.windowRect.size.height;
    
    cairo_surface_t *surface = cairo_xcb_surface_create(
        [button.connection connection],
        pixmap,
        [visual visualType],
        width,
        height
    );
    
    cairo_t *cr = cairo_create(surface);
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);
    
    // Fill with title bar background color first
    cairo_set_source_rgb(cr, 
        titleBarColor.redComponent,
        titleBarColor.greenComponent,
        titleBarColor.blueComponent);
    cairo_paint(cr);
    
    // Draw button circle
    if (active) {
        [self drawButtonCircle:cr 
                         width:width 
                        height:height 
                         color:buttonColor];
    }
    
    cairo_surface_flush(surface);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
}

- (void)drawButtonCircle:(cairo_t *)cr 
                   width:(CGFloat)width
                  height:(CGFloat)height
                   color:(XCBColor)color {
    
    CGFloat centerX = width / 2.0;
    CGFloat centerY = height / 2.0;
    CGFloat radius = 6.0;
    
    // Create gradient for 3D effect
    cairo_pattern_t *pat = cairo_pattern_create_radial(
        centerX - radius/4, centerY - radius/4, radius/8,
        centerX, centerY, radius
    );
    
    // Highlight at top-left
    cairo_pattern_add_color_stop_rgb(pat, 0.0,
        fmin(color.redComponent * 1.3, 1.0),
        fmin(color.greenComponent * 1.3, 1.0),
        fmin(color.blueComponent * 1.3, 1.0));
    
    // Base color
    cairo_pattern_add_color_stop_rgb(pat, 0.5,
        color.redComponent,
        color.greenComponent,
        color.blueComponent);
    
    // Shadow at edges
    cairo_pattern_add_color_stop_rgb(pat, 1.0,
        color.redComponent * 0.85,
        color.greenComponent * 0.85,
        color.blueComponent * 0.85);
    
    // Draw circle
    cairo_set_source(cr, pat);
    cairo_arc(cr, centerX, centerY, radius, 0, 2 * M_PI);
    cairo_fill_preserve(cr);
    
    // Add subtle border
    cairo_set_line_width(cr, 0.75);
    cairo_set_source_rgba(cr, 0, 0, 0, 0.2);
    cairo_stroke(cr);
    
    cairo_pattern_destroy(pat);
}

#pragma mark - Frame Rendering

- (void)renderFrameInternal:(XCBFrame *)frame {
    if (!frame || !frame.connection) {
        NSLog(@"[XCBRenderingEngine] Invalid frame for rendering");
        return;
    }
    
    // Get visual
    XCBScreen *screen = [frame onScreen];
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];
    [visual setVisualTypeForScreen:screen];
    
    [self renderFrameResizeBar:frame visual:visual];
}

- (void)renderFrameResizeBar:(XCBFrame *)frame visual:(XCBVisual *)visual {
    #define RESIZE_BAR_HEIGHT 9
    
    CGFloat width = frame.windowRect.size.width;
    CGFloat height = frame.windowRect.size.height;
    CGFloat barY = height - RESIZE_BAR_HEIGHT;
    
    cairo_surface_t *surface = cairo_xcb_surface_create(
        [frame.connection connection],
        [frame window],
        [visual visualType],
        width,
        height
    );
    
    cairo_t *cr = cairo_create(surface);
    
    // Create gradient for resize bar
    cairo_pattern_t *pat = cairo_pattern_create_linear(0, barY, 0, height);
    cairo_pattern_add_color_stop_rgb(pat, 0.0, 0.85, 0.85, 0.85);
    cairo_pattern_add_color_stop_rgb(pat, 1.0, 0.65, 0.65, 0.65);
    
    cairo_rectangle(cr, 0, barY, width, RESIZE_BAR_HEIGHT);
    cairo_set_source(cr, pat);
    cairo_fill(cr);
    
    cairo_pattern_destroy(pat);
    cairo_surface_flush(surface);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
}

#pragma mark - Utility Methods

+ (void)updateTitleForTitleBar:(XCBTitleBar *)titleBar {
    // This just updates the title without full re-render
    XCBRenderingEngine *engine = [self sharedEngine];
    
    // Only re-render if we have a valid title
    NSString *title = [titleBar windowTitle];
    if (title && [title length] > 0) {
        [engine renderTitleBarInternal:titleBar];
    }
}

+ (void)refreshTitleBar:(XCBTitleBar *)titleBar {
    // Force complete re-render
    titleBar.isRendered = NO;
    [[self sharedEngine] renderTitleBarInternal:titleBar];
}

@end
