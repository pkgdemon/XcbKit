//
//  XCBTitleBar.m
//  XCBKit
//
//  Created by Alessandro Sangiuliano on 06/08/19.
//  Copyright (c) 2019 alex. All rights reserved.
//

#import "XCBTitleBar.h"
#import "utils/CairoDrawer.h"
#import "XCBThemeService.h"

@implementation XCBTitleBar

@synthesize hideWindowButton;
@synthesize minimizeWindowButton;
@synthesize maximizeWindowButton;
@synthesize arc;
@synthesize hideButtonColor;
@synthesize minimizeButtonColor;
@synthesize maximizeButtonColor;
@synthesize titleBarUpColor;
@synthesize titleBarDownColor;
@synthesize ewmhService;
@synthesize titleIsSet;


- (id) initWithFrame:(XCBFrame *)aFrame withConnection:(XCBConnection *)aConnection
{
    self = [super init];

    if (self == nil)
        return nil;

    windowMask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
    
    [super setConnection:aConnection];

    ewmhService = [EWMHService sharedInstanceWithConnection:[super connection]];
    
    // CRITICAL FIX: Initialize windowTitle to nil instead of leaving it uninitialized
    windowTitle = nil;
    titleIsSet = NO;
    
    return self;
}

- (void) drawArcsForColor:(TitleBarColor)aColor
{
    XCBColor stopColor = XCBMakeColor(1,1,1,1);
    XCBWindow *rootWindow = [parentWindow parentWindow];
    XCBScreen *scr = [rootWindow screen];
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[scr screen]->root_visual];
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    [visual setVisualTypeForScreen:scr];
    XCBRect area;

    CairoDrawer *drawer = nil;
    
    if (hideWindowButton != nil)
    {
        NSString* path = [thisBundle pathForResource:@"close" ofType:@"png"];
        drawer = [[CairoDrawer alloc] initWithConnection:[super connection] window:hideWindowButton visual:visual];

        area = [hideWindowButton windowRect];
        area.position.x = 0;
        area.position.y = 0;

        [hideWindowButton clearArea:area generatesExposure:NO];

        [drawer drawTitleBarButtonWithColor:aColor == TitleBarUpColor ? hideButtonColor : titleBarDownColor withStopColor:stopColor];
        [drawer putImage:path forDPixmap:aColor == TitleBarUpColor ? NO : YES];

        drawer = nil;
        path= nil;
    }
    
    if (minimizeWindowButton != nil)
    {
        NSString* path = [thisBundle pathForResource:@"min" ofType:@"png"];
        drawer = [[CairoDrawer alloc] initWithConnection:[super connection] window:minimizeWindowButton visual:visual];

        area = [minimizeWindowButton windowRect];
        area.position.x = 0;
        area.position.y = 0;
        [minimizeWindowButton clearArea:area generatesExposure:NO];

        [drawer drawTitleBarButtonWithColor: aColor == TitleBarUpColor ? minimizeButtonColor : titleBarDownColor  withStopColor:stopColor];
        [drawer putImage:path forDPixmap:aColor == TitleBarUpColor ? NO : YES];

        drawer = nil;
        path = nil;
    }
    
    if (maximizeWindowButton != nil)
    {
        NSString* path = [thisBundle pathForResource:@"max" ofType:@"png"];
        drawer = [[CairoDrawer alloc] initWithConnection:[super connection] window:maximizeWindowButton visual:visual];

        area = [maximizeWindowButton windowRect];
        area.position.x = 0;
        area.position.y = 0;
        [maximizeWindowButton clearArea:area generatesExposure:NO];

        [drawer drawTitleBarButtonWithColor: aColor == TitleBarUpColor ? maximizeButtonColor : titleBarDownColor  withStopColor:stopColor];
        [drawer putImage:path forDPixmap:aColor == TitleBarUpColor ? NO : YES];

        path = nil;
        drawer = nil;
    }
    
    scr = nil;
    visual = nil;
    rootWindow = nil;
    thisBundle = nil;
}

- (void) drawTitleBarForColor:(TitleBarColor)aColor
{
    XCBColor aux;
    
    if (aColor == TitleBarUpColor)
        aux = titleBarUpColor;
    
    if (aColor == TitleBarDownColor)
        aux = titleBarDownColor;

    XCBRect area = XCBMakeRect(XCBMakePoint([super windowRect].position.x, [super windowRect].position.y),
                               XCBMakeSize([super windowRect].size.width, [super windowRect].size.height));

    [super clearArea:area generatesExposure:NO];
    
    XCBScreen *screen = [self onScreen];
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];
    [visual setVisualTypeForScreen:screen];
    
    CairoDrawer *drawer = [[CairoDrawer alloc] initWithConnection:[super connection] window:self visual:visual];
    
    XCBColor stopColor = XCBMakeColor(0.850, 0.850, 0.850, 1);
    [drawer drawTitleBarWithColor:aux andStopColor: stopColor];

    /*** This is better than allocating/deallocating the drawer object for each window to draw, however find
     * a better solution to avoid all the sets methods/messages ***/

    //FIXME: now probably useless code.
    /*if (hideWindowButton != nil)
    {
        [drawer setWindow:hideWindowButton];
        [drawer setHeight:[hideWindowButton windowRect].size.height];
        [drawer setWidth:[hideWindowButton windowRect].size.width];
    }
    
    if (minimizeWindowButton != nil)
    {
        [drawer setWindow:minimizeWindowButton];
        [drawer setHeight:[minimizeWindowButton windowRect].size.height];
        [drawer setWidth:[minimizeWindowButton windowRect].size.width];
    }
    
    if (maximizeWindowButton != nil)
    {
        [drawer setWindow:maximizeWindowButton];
        [drawer setHeight:[maximizeWindowButton windowRect].size.height];
        [drawer setWidth:[maximizeWindowButton windowRect].size.width];
    }*/
    
    drawer = nil;
    screen = nil;
    visual = nil;
}

- (void) generateButtons
{
    XCBWindow *rootWindow = [parentWindow parentWindow];
    XCBScreen *screen = [rootWindow screen];
    XCBVisual *rootVisual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];

    [rootVisual setVisualTypeForScreen:screen];
    uint32_t mask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
    uint32_t values[2];
    values[0] = [screen screen]->white_pixel;
    values[1] = XCB_EVENT_MASK_EXPOSURE | XCB_EVENT_MASK_BUTTON_PRESS;

    BOOL shapeExtensionSupported;

    XCBFrame* frame = (XCBFrame*)parentWindow;

    XCBThemeService *theme = [XCBThemeService sharedInstance];

    if ([[frame childWindowForKey:ClientWindow] canClose])
    {
        hideWindowButton = [[super connection] createWindowWithDepth:XCB_COPY_FROM_PARENT
                                                    withParentWindow:self
                                                       withXPosition:5
                                                       withYPosition:5
                                                           withWidth:14
                                                          withHeight:14
                                                    withBorrderWidth:0
                                                        withXCBClass:XCB_WINDOW_CLASS_INPUT_OUTPUT
                                                        withVisualId:rootVisual
                                                       withValueMask:mask
                                                       withValueList:values
                                                      registerWindow:YES];

        [hideWindowButton setWindowMask:mask];
        [hideWindowButton setCanMove:NO];
        [hideWindowButton setIsCloseButton:YES];

	hideButtonColor = [theme buttonCloseColor];

        shapeExtensionSupported = [[hideWindowButton shape] checkSupported];
        [[hideWindowButton shape] calculateDimensionsFromGeometries:[hideWindowButton geometries]];

        if (shapeExtensionSupported)
        {
            [[hideWindowButton shape] createPixmapsAndGCs];
            [[hideWindowButton shape] createArcsWithRadius:7];
        }
        else
            NSLog(@"Shape extension not supported for window: %u", [hideWindowButton window]);

    }

    if ([[frame childWindowForKey:ClientWindow] canMinimize])
    {
        minimizeWindowButton = [[super connection] createWindowWithDepth:XCB_COPY_FROM_PARENT
                                                        withParentWindow:self
                                                           withXPosition:24
                                                           withYPosition:5
                                                               withWidth:14
                                                              withHeight:14
                                                        withBorrderWidth:0
                                                            withXCBClass:XCB_WINDOW_CLASS_INPUT_OUTPUT
                                                            withVisualId:rootVisual
                                                           withValueMask:mask
                                                           withValueList:values
                                                          registerWindow:YES];

        [minimizeWindowButton setWindowMask:mask];
        [minimizeWindowButton setCanMove:NO];
        [minimizeWindowButton setIsMinimizeButton:YES];

	minimizeButtonColor = [theme buttonMinimizeColor]; 

        shapeExtensionSupported = [[minimizeWindowButton shape] checkSupported];
        [[minimizeWindowButton shape] calculateDimensionsFromGeometries:[minimizeWindowButton geometries]];

        if (shapeExtensionSupported)
        {
            [[minimizeWindowButton shape] createPixmapsAndGCs];
            [[minimizeWindowButton shape] createArcsWithRadius:7];
        }
        else
            NSLog(@"Shape extension not supported for window: %u", [minimizeWindowButton window]);

    }

    if ([[frame childWindowForKey:ClientWindow] canFullscreen])
    {
        maximizeWindowButton = [[super connection] createWindowWithDepth:XCB_COPY_FROM_PARENT
                                                        withParentWindow:self
                                                           withXPosition:44
                                                           withYPosition:5
                                                               withWidth:14
                                                              withHeight:14
                                                        withBorrderWidth:0
                                                            withXCBClass:XCB_WINDOW_CLASS_INPUT_OUTPUT
                                                            withVisualId:rootVisual
                                                           withValueMask:mask
                                                           withValueList:values
                                                          registerWindow:YES];

        [maximizeWindowButton setWindowMask:mask];
        [maximizeWindowButton setCanMove:NO];
        [maximizeWindowButton setIsMaximizeButton:YES];

	maximizeButtonColor = [theme buttonMaximizeColor];

        shapeExtensionSupported = [[maximizeWindowButton shape] checkSupported];
        [[maximizeWindowButton shape] calculateDimensionsFromGeometries:[maximizeWindowButton geometries]];

        if (shapeExtensionSupported)
        {
            [[maximizeWindowButton shape] createPixmapsAndGCs];
            [[maximizeWindowButton shape] createArcsWithRadius:7];
        }
        else
            NSLog(@"Shape extension not supported for window: %u", [maximizeWindowButton window]);
    }

    [[super connection] mapWindow:hideWindowButton];
    [[super connection] mapWindow:minimizeWindowButton];
    [[super connection] mapWindow:maximizeWindowButton];
    [hideWindowButton onScreen];
    [minimizeWindowButton onScreen];
    [maximizeWindowButton onScreen];
    [hideWindowButton updateAttributes];
    [minimizeWindowButton updateAttributes];
    [maximizeWindowButton updateAttributes];
    [hideWindowButton createPixmap];
    [minimizeWindowButton createPixmap];
    [maximizeWindowButton createPixmap];

    screen = nil;
    rootVisual = nil;
    rootWindow = nil;
    frame = nil;
}

// CRITICAL FIX: Override drawTitleBarComponents to ensure title is rendered
- (void)drawTitleBarComponents
{
    [super drawArea:[super windowRect]];
    
    // Always redraw the title when drawing components
    if (windowTitle != nil && [windowTitle length] > 0)
    {
        XCBWindow *rootWindow = [parentWindow parentWindow];
        XCBScreen *screen = [rootWindow screen];
        XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];
        [visual setVisualTypeForScreen:screen];
        
        CairoDrawer *drawer = [[CairoDrawer alloc] initWithConnection:[super connection] window:self visual:visual];
        XCBColor black = XCBMakeColor(0,0,0,1);
        [drawer drawText:windowTitle withColor:black];
        
        drawer = nil;
        screen = nil;
        visual = nil;
        rootWindow = nil;
    }
    
    // Draw buttons
    if (hideWindowButton != nil)
    {
        XCBRect area = [hideWindowButton windowRect];
        area.position.x = 0;
        area.position.y = 0;
        [hideWindowButton drawArea:area];
    }
    
    if (maximizeWindowButton != nil)
    {
        XCBRect area = [maximizeWindowButton windowRect];
        area.position.x = 0;
        area.position.y = 0;
        [maximizeWindowButton drawArea:area];
    }
    
    if (minimizeWindowButton != nil)
    {
        XCBRect area = [minimizeWindowButton windowRect];
        area.position.x = 0;
        area.position.y = 0;
        [minimizeWindowButton drawArea:area];
    }
}

- (void) drawTitleBarComponentsPixmaps
{
    [self drawTitleBarForColor:TitleBarUpColor];
    [self drawTitleBarForColor:TitleBarDownColor];
    [self drawArcsForColor:TitleBarUpColor];
    [self drawArcsForColor:TitleBarDownColor];
    [self setWindowTitle:windowTitle];
}

- (void) setButtonsAbove:(BOOL)aValue
{
    [hideWindowButton setIsAbove:aValue];
    [minimizeWindowButton setIsAbove:aValue];
    [maximizeWindowButton setIsAbove:aValue];
}

- (void)putButtonsBackgroundPixmaps:(BOOL)aValue
{
    [hideWindowButton clearArea:[hideWindowButton windowRect] generatesExposure:NO];
    [minimizeWindowButton clearArea:[minimizeWindowButton windowRect] generatesExposure:NO];
    [hideWindowButton clearArea:[maximizeWindowButton windowRect] generatesExposure:NO];

    if (aValue)
    {
        [hideWindowButton putWindowBackgroundWithPixmap:[hideWindowButton pixmap]];
        [minimizeWindowButton putWindowBackgroundWithPixmap:[minimizeWindowButton pixmap]];
        [maximizeWindowButton putWindowBackgroundWithPixmap:[maximizeWindowButton pixmap]];
    }
    else
    {
        [hideWindowButton putWindowBackgroundWithPixmap:[hideWindowButton dPixmap]];
        [minimizeWindowButton putWindowBackgroundWithPixmap:[minimizeWindowButton dPixmap]];
        [maximizeWindowButton putWindowBackgroundWithPixmap:[maximizeWindowButton dPixmap]];
    }
}

- (void) setWindowTitle:(NSString *) title
{
    NSLog(@"=== TITLE DEBUG: Setting window title: '%@' ===", title);
    
    if (title == nil || [title length] == 0) {
        windowTitle = @"";
        titleIsSet = NO;
    } else {
        windowTitle = [title copy];
        titleIsSet = YES;
    }

    // Don't draw to window - draw to pixmaps instead!
    if (windowTitle != nil && [windowTitle length] > 0) {
        [self drawTitleToPixmaps:windowTitle];
    }
}

// Add this new method to XCBTitleBar.m:
- (void)drawTitleToPixmaps:(NSString*)title {
    XCBWindow *rootWindow = [parentWindow parentWindow];
    XCBScreen *screen = [rootWindow screen];
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];
    [visual setVisualTypeForScreen:screen];
    
    XCBColor black = XCBMakeColor(0, 0, 0, 1);
    
    // Draw to active pixmap
    cairo_surface_t *activeSurface = cairo_xcb_surface_create([[super connection] connection], 
                                                              [self pixmap], 
                                                              [visual visualType], 
                                                              [self windowRect].size.width, 
                                                              [self windowRect].size.height);
    cairo_t *activeCr = cairo_create(activeSurface);
    
    [self drawTitleText:title withCairo:activeCr color:black];
    
    cairo_surface_flush(activeSurface);
    cairo_surface_destroy(activeSurface);
    cairo_destroy(activeCr);
    
    // Draw to inactive pixmap
    cairo_surface_t *inactiveSurface = cairo_xcb_surface_create([[super connection] connection], 
                                                                [self dPixmap], 
                                                                [visual visualType], 
                                                                [self windowRect].size.width, 
                                                                [self windowRect].size.height);
    cairo_t *inactiveCr = cairo_create(inactiveSurface);
    
    [self drawTitleText:title withCairo:inactiveCr color:black];
    
    cairo_surface_flush(inactiveSurface);
    cairo_surface_destroy(inactiveSurface);
    cairo_destroy(inactiveCr);
    
    // Clean up
    visual = nil;
    rootWindow = nil;
}

// Add this helper method:
- (void)drawTitleText:(NSString*)text withCairo:(cairo_t*)cr color:(XCBColor)color {
    cairo_set_source_rgb(cr, color.redComponent, color.greenComponent, color.blueComponent);
    cairo_select_font_face(cr, "Serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 11);
    
    cairo_text_extents_t extents;
    const char* utfString = [text UTF8String];
    cairo_text_extents(cr, utfString, &extents);

    CGFloat halfLength = extents.width / 2;
    CGFloat textPositionX = (CGFloat)[self windowRect].size.width / 2;
    CGFloat textPositionY = (CGFloat)[self windowRect].size.height / 2 + 2;
    
    cairo_move_to(cr, textPositionX - halfLength, textPositionY);
    cairo_show_text(cr, utfString);
}

- (NSString*) windowTitle
{
    return windowTitle;
}

- (xcb_arc_t*) arcs
{
    return arcs;
}

- (void) dealloc
{
    hideWindowButton = nil;
    minimizeWindowButton = nil;
    maximizeWindowButton = nil;
    ewmhService = nil;
    windowTitle = nil; // CRITICAL FIX: Clean up windowTitle
}

@end
