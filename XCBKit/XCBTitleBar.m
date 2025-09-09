//
//  XCBTitleBar.m
//  XCBKit
//
//  Created by Alessandro Sangiuliano on 06/08/19.
//  Copyright (c) 2019 alex. All rights reserved.
//

#import "XCBTitleBar.h"
#import "XCBRenderingEngine.h"
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
    
    // Initialize theme colors
    XCBThemeService *theme = [XCBThemeService sharedInstance];
    titleBarUpColor = [theme titleBarActiveColor];
    titleBarDownColor = [theme titleBarInactiveColor];
    
    // CRITICAL FIX: Initialize windowTitle to nil instead of leaving it uninitialized
    windowTitle = nil;
    titleIsSet = NO;
    
    return self;
}

- (void) drawArcsForColor:(TitleBarColor)aColor
{
    // The rendering engine handles button drawing now
    BOOL active = (aColor == TitleBarUpColor);
    
    if (hideWindowButton != nil)
    {
        [XCBRenderingEngine renderButton:hideWindowButton active:active];
    }
    
    if (minimizeWindowButton != nil)
    {
        [XCBRenderingEngine renderButton:minimizeWindowButton active:active];
    }
    
    if (maximizeWindowButton != nil)
    {
        [XCBRenderingEngine renderButton:maximizeWindowButton active:active];
    }
}

- (void) drawTitleBarForColor:(TitleBarColor)aColor
{
    // The rendering engine handles this now
    // It will render to both pixmaps internally
    [XCBRenderingEngine renderTitleBar:self];
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

- (void)drawTitleBarComponents
{
    // Just copy from the appropriate pixmap - the title is already there
    [super drawArea:[super windowRect]];
    
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
    // Use the rendering engine to draw everything
    [XCBRenderingEngine renderTitleBar:self];
    
    // Render buttons to their pixmaps
    if (hideWindowButton != nil)
    {
        [XCBRenderingEngine renderButton:hideWindowButton active:YES];
        [XCBRenderingEngine renderButton:hideWindowButton active:NO];
    }
    
    if (minimizeWindowButton != nil)
    {
        [XCBRenderingEngine renderButton:minimizeWindowButton active:YES];
        [XCBRenderingEngine renderButton:minimizeWindowButton active:NO];
    }
    
    if (maximizeWindowButton != nil)
    {
        [XCBRenderingEngine renderButton:maximizeWindowButton active:YES];
        [XCBRenderingEngine renderButton:maximizeWindowButton active:NO];
    }
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
    [maximizeWindowButton clearArea:[maximizeWindowButton windowRect] generatesExposure:NO];

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

    // Use the rendering engine to update the title
    if (titleIsSet && [self pixmap] && [self dPixmap]) {
        [XCBRenderingEngine updateTitleForTitleBar:self];
    }
}

- (void)drawTextToPixmaps:(NSString*)title {
    // This is now handled by the rendering engine
    // Keep this method for compatibility but delegate to rendering engine
    if (title && [title length] > 0) {
        [self setWindowTitle:title];
    }
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
    windowTitle = nil;
}

@end
