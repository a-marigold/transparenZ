const std = @import("std");

const windows = std.os.windows;

const utlralight = @import("utlralight");

const LPDWORD = *windows.DWORD;

const BOOL = c_int;

const STD_ERROR_HANDLE: windows.DWORD = @bitCast(@as(i32, -12));

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

const WINDOWCOMPOSITIONATTRIBDATA = extern struct {
    Attrib: WINDOWCOMPOSITIONATTRIB,
    pvData: *anyopaque,
    cbData: c_uint,
};

extern "kernel32" fn LoadLibraryW(lpLibFileName: windows.LPCSTR) callconv(.winapi) ?windows.HMODULE;

extern "kernel32" fn FreeLibrary(hLibModule: windows.HMODULE) callconv(.winapi) BOOL;

extern "kernel32" fn GetProcAddress(
    hModule: windows.HMODULE,
    lcProcName: windows.LPCSTR,
) callconv(.winapi) ?windows.FARPROC;

extern "kernel32" fn GetStdHandle(nStdHandle: windows.DWORD) callconv(.winapi) ?windows.HANDLE;

extern "kernel32" fn FindWindowW(
    lpClassName: windows.LPCWSTR,
    lpWindowName: ?windows.LPCWSTR,
) callconv(.winapi) ?windows.HWND;

extern "kernel32" fn WriteFile(
    hFile: windows.HANDLE,
    lpBuffer: windows.LPCVOID,
    nNumberOfBytesToWrite: windows.DWORD,
    lpNumberOfBytesWritten: LPDWORD,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) BOOL;

const SetWindowCompositionAttributeType = *const fn (
    hwnd: windows.HWND,
    pwcad: *const WINDOWCOMPOSITIONATTRIBDATA,
) callconv(.winapi) BOOL;

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = trace;
    _ = ret_addr;

    // Safe writing without allocations
    if (GetStdHandle(STD_ERROR_HANDLE)) |handle| {
        if (handle != windows.INVALID_HANDLE_VALUE) {
            var writtenBytes: windows.DWORD = 0;
            _ = WriteFile(
                handle,
                msg.ptr,
                @intCast(msg.len),
                &writtenBytes,
                null,
            );
        }
    }
    @trap();
}
