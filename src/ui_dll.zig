//! Updates the taskbar UI.
//! Compiled to windows DLL.
//! Must be named `ui.dll` (see the `constants.zig`).

const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");

const constants = @import("constants.zig");

export fn DllMain(
    hinstDLL: zigWin.HINSTANCE,
    fwdReason: zigWin.DWORD,
    lpvReserved: zigWin.LPVOID,
) callconv(.winapi) win.BOOL {
    _ = lpvReserved;

    switch (fwdReason) {
        win.DLL_PROCESS_ATTACH => {
            _ = win.DisableThreadLibraryCalls(@ptrCast(hinstDLL));

            const thread = win.CreateThread(
                null,
                0,
                &updateTaskBar,
                null,
                0,
                null,
            );

            if (thread) |handle| {
                _ = win.CloseHandle(handle);

                return win.TRUE;
            }

            return win.FALSE;
        },
        else => {
            return win.TRUE;
        },
    }
}

fn updateTaskBar(lpParameter: ?zigWin.LPVOID) callconv(.winapi) zigWin.DWORD {
    _ = lpParameter;
}

// Only To test DLL loading
extern "kernel32" fn CreateFileW(
    lpFileName: zigWin.LPCWSTR,
    dwDesiredAccess: zigWin.DWORD,
    dwShareMode: zigWin.DWORD,
    lpSecurityAttributes: ?*zigWin.SECURITY_ATTRIBUTES,
    dwCreationDisposition: zigWin.DWORD,
    dwFlagsAndAttributes: zigWin.DWORD,
    hTemplateFile: ?zigWin.HANDLE,
) callconv(.winapi) ?zigWin.HANDLE;
