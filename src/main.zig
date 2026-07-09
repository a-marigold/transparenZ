const std = @import("std");

const windows = std.os.windows;

const utlralight = @import("utlralight");

const LPDWORD = *windows.DWORD;

const STD_ERROR_HANDLE: windows.DWORD = -12;

const WINDOWCOMPOSITIONATTRIB = enum(c_uint) {
    WCA_ACCENT_POLICY = 19,
};

const ACCENT_STATE = enum(u32) {
    ACCENT_DISABLED = 0,
    ACCENT_ENABLE_GRADIENT = 1,
    ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
    ACCENT_ENABLE_BLURBEHIND = 3,
    ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
    ACCENT_INVALID_STATE = 5,
};

const ACCENT_POLICY = extern struct {
    accent_state: ACCENT_STATE,
    accent_flags: u32,
    gradient_color: u32,
    animation_id: u32,
};

const WINDOWCOMPOSITIONATTRIBDATA = struct {
    Attrib: WINDOWCOMPOSITIONATTRIB,
    pvData: *anyopaque,
    cbData: c_uint,
};

extern "kernel32" fn LoadLibraryW(lpLibFileName: windows.LPCSTR) callconv(.winapi) ?windows.HMODULE;

extern "kernel32" fn FreeLibrary(hLibModule: windows.HMODULE) callconv(.winapi) ?windows.BOOL;

extern "kernel32" fn GetProcAddress(
    hModule: windows.HMODULE,
    lcProcName: windows.LPCSTR,
) callconv(.winapi) ?windows.FARPROC;

extern "kernel32" fn GetStdHandle(nStdHandle: windows.DWORD) callconv(.winapi) ?windows.HANDLE;

extern "kernel32" fn FindWindowW(
    lpClassName: windows.LPCWSTR,
    lpWindowName: windows.LPCWSTR,
) callconv(.winapi) ?windows.HWND;

extern "kernel32" fn WriteFileW(
    hFile: windows.HANDLE,
    lpBuffer: windows.LPCVOID,
    nNumberOfBytesToWrite: windows.DWORD,
    lpNumberOfBytesWritten: LPDWORD,
    lpOverlapped: null,
) callconv(.winapi) ?windows.BOOL;

const SetWindowCompositionAttributeType = fn (hwnd: windows.HWND, pwcad: WINDOWCOMPOSITIONATTRIBDATA) callconv(.winapi) ?windows.BOOL;
