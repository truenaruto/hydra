#import "helpers.h"
void new_application(lua_State* L, pid_t pid);

#define hydra_window(L, idx) *((AXUIElementRef*)luaL_checkudata(L, idx, "window"))

static int window_gc(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    CFRelease(win);
    return 0;
}

static int window_eq(lua_State* L) {
    AXUIElementRef winA = hydra_window(L, 1);
    AXUIElementRef winB = hydra_window(L, 2);
    
    lua_pushboolean(L, CFEqual(winA, winB));
    return 1;
}

extern AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);
NSWindow* hydra_nswindow_for_accessibility_window(AXUIElementRef win) {
    CGWindowID winid;
    AXError err = _AXUIElementGetWindow(win, &winid);
    if (err) return nil;
    
    for (NSWindow* window in [NSApp windows]) {
        if ([window windowNumber] == winid)
            return window;
    }
    
    return nil;
}

void new_window(lua_State* L, AXUIElementRef win) {
    AXUIElementRef* winptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    *winptr = win;
    
    luaL_getmetatable(L, "window");
    lua_setmetatable(L, -2);
    
    lua_newtable(L);
    lua_setuservalue(L, -2);
}

static AXUIElementRef system_wide_element() {
    static AXUIElementRef element;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        element = AXUIElementCreateSystemWide();
    });
    return element;
}

static hydradoc doc_window_focusedwindow = {
    "window", "focusedwindow", "window.focusedwindow() -> window",
    "Returns the focused window, or nil."
};

static int window_focusedwindow(lua_State* L) {
    CFTypeRef app;
    AXUIElementCopyAttributeValue(system_wide_element(), kAXFocusedApplicationAttribute, &app);
    
    if (app) {
        CFTypeRef win;
        AXError result = AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityFocusedWindowAttribute, &win);
        
        CFRelease(app);
        
        if (result == kAXErrorSuccess) {
            new_window(L, win);
            return 1;
        }
    }
    
    lua_pushnil(L);
    return 1;
}

static id get_window_prop(AXUIElementRef win, NSString* propType, id defaultValue) {
    CFTypeRef _someProperty;
    if (AXUIElementCopyAttributeValue(win, (__bridge CFStringRef)propType, &_someProperty) == kAXErrorSuccess)
        return CFBridgingRelease(_someProperty);
    
    return defaultValue;
}

static BOOL set_window_prop(AXUIElementRef win, NSString* propType, id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        AXError result = AXUIElementSetAttributeValue(win, (__bridge CFStringRef)(propType), (__bridge CFTypeRef)(value));
        if (result == kAXErrorSuccess)
            return YES;
    }
    return NO;
}

static hydradoc doc_window_title = {
    "window", "title", "window:title() -> string",
    "Returns the title of the window (as UTF8)."
};

static int window_title(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    NSString* title = get_window_prop(win, NSAccessibilityTitleAttribute, @"");
    lua_pushstring(L, [title UTF8String]);
    return 1;
}

static hydradoc doc_window_subrole = {
    "window", "subrole", "window:subrole() -> string",
    "Returns the subrole of the window, whatever that means."
};

static int window_subrole(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    NSString* str = get_window_prop(win, NSAccessibilitySubroleAttribute, @"");
    
    lua_pushstring(L, [str UTF8String]);
    return 1;
}

static hydradoc doc_window_role = {
    "window", "role", "window:role() -> string",
    "Returns the role of the window, whatever that means."
};

static int window_role(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    NSString* str = get_window_prop(win, NSAccessibilityRoleAttribute, @"");
    
    lua_pushstring(L, [str UTF8String]);
    return 1;
}

static hydradoc doc_window_isstandard = {
    "window", "isstandard", "window:isstandard() -> bool",
    "True if the window's subrole indicates it's 'a standard window'."
};

static int window_isstandard(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    NSString* subrole = get_window_prop(win, NSAccessibilitySubroleAttribute, @"");
    
    BOOL is_standard = [subrole isEqualToString: (__bridge NSString*)kAXStandardWindowSubrole];
    lua_pushboolean(L, is_standard);
    return 1;
}

static hydradoc doc_window_topleft = {
    "window", "topleft", "window:topleft() -> point",
    "The top-left corner of the window in absolute coordinates."
};

static int window_topleft(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    CFTypeRef positionStorage;
    AXError result = AXUIElementCopyAttributeValue(win, (CFStringRef)NSAccessibilityPositionAttribute, &positionStorage);
    
    CGPoint topLeft;
    if (result == kAXErrorSuccess) {
        if (!AXValueGetValue(positionStorage, kAXValueCGPointType, (void *)&topLeft)) {
//            NSLog(@"could not decode topLeft");
            topLeft = CGPointZero;
        }
    }
    else {
//        NSLog(@"could not get window topLeft");
        topLeft = CGPointZero;
    }
    
    if (positionStorage)
        CFRelease(positionStorage);
    
    hydra_pushpoint(L, topLeft);
    return 1;
}

static hydradoc doc_window_size = {
    "window", "size", "window:size() -> size",
    "The size of the window."
};

static int window_size(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    CFTypeRef sizeStorage;
    AXError result = AXUIElementCopyAttributeValue(win, (CFStringRef)NSAccessibilitySizeAttribute, &sizeStorage);
    
    CGSize size;
    if (result == kAXErrorSuccess) {
        if (!AXValueGetValue(sizeStorage, kAXValueCGSizeType, (void *)&size)) {
//            NSLog(@"could not decode topLeft");
            size = CGSizeZero;
        }
    }
    else {
//        NSLog(@"could not get window size");
        size = CGSizeZero;
    }
    
    if (sizeStorage)
        CFRelease(sizeStorage);
    
    hydra_pushsize(L, size);
    return 1;
}

static hydradoc doc_window_settopleft = {
    "window", "settopleft", "window:settopleft(point)",
    "Moves the window to the given point in absolute coordinate."
};

static int window_settopleft(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    NSPoint thePoint = hydra_topoint(L, 2);
    
    CFTypeRef positionStorage = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
    AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilityPositionAttribute, positionStorage);
    if (positionStorage)
        CFRelease(positionStorage);
    
    return 0;
}

static hydradoc doc_window_setsize = {
    "window", "setsize", "window:setsize(size)",
    "Resizes the window."
};

static int window_setsize(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    NSSize theSize = hydra_tosize(L, 2);
    
    CFTypeRef sizeStorage = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&theSize));
    AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilitySizeAttribute, sizeStorage);
    if (sizeStorage)
        CFRelease(sizeStorage);
    
    return 0;
}

static hydradoc doc_window_close = {
    "window", "close", "window:close() -> bool",
    "Closes the window; returns whether it succeeded."
};

static int window_close(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    BOOL worked = NO;
    AXUIElementRef button = NULL;
    
    if (AXUIElementCopyAttributeValue(win, kAXCloseButtonAttribute, (CFTypeRef*)&button) != noErr) goto cleanup;
    if (AXUIElementPerformAction(button, kAXPressAction) != noErr) goto cleanup;
    
    worked = YES;
    
cleanup:
    if (button) CFRelease(button);
    
    lua_pushboolean(L, worked);
    return 1;
}

static void set_window_minimized(AXUIElementRef win, NSNumber* minimized) {
    set_window_prop(win, NSAccessibilityMinimizedAttribute, minimized);
}

static hydradoc doc_window_minimize = {
    "window", "minimize", "window:minimize()",
    "Minimizes the window."
};

static int window_minimize(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    set_window_minimized(win, @YES);
    return 0;
}

static hydradoc doc_window_unminimize = {
    "window", "unminimize", "window:unminimize()",
    "Un-minimizes the window."
};

static int window_unminimize(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    set_window_minimized(win, @NO);
    return 0;
}

static hydradoc doc_window_isminimized = {
    "window", "isminimized", "window:isminimized() -> bool",
    "True if the window is currently minimized in the dock."
};

static int window_isminimized(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    BOOL minimized = [get_window_prop(win, NSAccessibilityMinimizedAttribute, @(NO)) boolValue];
    lua_pushboolean(L, minimized);
    return 1;
}

// args: [win]
// ret: [pid]
static int window_pid(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    pid_t pid = 0;
    if (AXUIElementGetPid(win, &pid) == kAXErrorSuccess) {
        lua_pushnumber(L, pid);
        return 1;
    }
    else {
        return 0;
    }
}

static hydradoc doc_window_application = {
    "window", "application", "window:application() -> app",
    "Returns the app that the window belongs to."
};

static int window_application(lua_State* L) {
    if (window_pid(L)) {
        pid_t pid = lua_tonumber(L, -1);
        new_application(L, pid);
        return 1;
    }
    else {
        return 0;
    }
}

static hydradoc doc_window_becomemain = {
    "window", "becomemain", "window:becomemain() -> bool",
    "Make this window the main window of the given application; deos not implicitly focus the app."
};

// args: [win]
// ret: [bool]
static int window_becomemain(lua_State* L) {
    AXUIElementRef win = hydra_window(L, 1);
    
    BOOL success = (AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilityMainAttribute, kCFBooleanTrue) == kAXErrorSuccess);
    lua_pushboolean(L, success);
    return 1;
}

static int window__orderedwinids(lua_State* L) {
    lua_newtable(L);
    
    CFArrayRef wins = CGWindowListCreate(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    
    for (int i = 0; i < CFArrayGetCount(wins); i++) {
        int winid = (int)CFArrayGetValueAtIndex(wins, i);
        
        lua_pushnumber(L, winid);
        lua_rawseti(L, -2, i+1);
    }
    
    CFRelease(wins);
    
    return 1;
}

static hydradoc doc_window_id = {
    "window", "id", "window:id() -> number, sometimes nil",
    "Returns a unique number identifying this window."
};

static int window_id(lua_State* L) {
    lua_settop(L, 1);
    AXUIElementRef win = hydra_window(L, 1);
    
    lua_getuservalue(L, 1);
    
    lua_getfield(L, -1, "id");
    if (lua_isnumber(L, -1))
        return 1;
    else
        lua_pop(L, 1);
    
    CGWindowID winid;
    AXError err = _AXUIElementGetWindow(win, &winid);
    if (err) {
        lua_pushnil(L);
        return 1;
    }
    
    // cache it
    lua_pushnumber(L, winid);
    lua_setfield(L, -2, "id");
    
    lua_pushnumber(L, winid);
    return 1;
}

static const luaL_Reg windowlib[] = {
    {"focusedwindow", window_focusedwindow},
    {"_orderedwinids", window__orderedwinids},
    
    {"title", window_title},
    {"subrole", window_subrole},
    {"role", window_role},
    {"isstandard", window_isstandard},
    {"topleft", window_topleft},
    {"size", window_size},
    {"settopleft", window_settopleft},
    {"setsize", window_setsize},
    {"minimize", window_minimize},
    {"unminimize", window_unminimize},
    {"isminimized", window_isminimized},
    {"pid", window_pid},
    {"application", window_application},
    {"becomemain", window_becomemain},
    {"id", window_id},
    {"close", window_close},
    
    {NULL, NULL}
};

int luaopen_window(lua_State* L) {
    hydra_add_doc_group(L, "window", "(overwritten in window.lua)");
    hydra_add_doc_item(L, &doc_window_focusedwindow);
    hydra_add_doc_item(L, &doc_window_title);
    hydra_add_doc_item(L, &doc_window_subrole);
    hydra_add_doc_item(L, &doc_window_role);
    hydra_add_doc_item(L, &doc_window_isstandard);
    hydra_add_doc_item(L, &doc_window_topleft);
    hydra_add_doc_item(L, &doc_window_size);
    hydra_add_doc_item(L, &doc_window_settopleft);
    hydra_add_doc_item(L, &doc_window_setsize);
    hydra_add_doc_item(L, &doc_window_minimize);
    hydra_add_doc_item(L, &doc_window_unminimize);
    hydra_add_doc_item(L, &doc_window_isminimized);
    hydra_add_doc_item(L, &doc_window_application);
    hydra_add_doc_item(L, &doc_window_becomemain);
    hydra_add_doc_item(L, &doc_window_id);
    hydra_add_doc_item(L, &doc_window_close);
    
    luaL_newlib(L, windowlib);
    
    if (luaL_newmetatable(L, "window")) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");
        
        lua_pushcfunction(L, window_gc);
        lua_setfield(L, -2, "__gc");
        
        lua_pushcfunction(L, window_eq);
        lua_setfield(L, -2, "__eq");
    }
    lua_pop(L, 1);
    
    return 1;
}
