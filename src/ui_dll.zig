//! Compiled to windows DLL.
//! Named exactly `ui.dll` (see the `constants.zig`).

const std = @import("std");
const zigWin = std.os.windows;

const win = @import("win.zig");

export fn DllMain(
    hinstDLL: zigWin.HINSTANCE,
    fwdReason: zigWin.DWORD,
    lpvReserved: zigWin.LPVOID,
) callconv(.c) win.BOOL {
    _ = lpvReserved;

    switch (fwdReason) {
        win.DLL_PROCESS_ATTACH => {
            _ = win.DisableThreadLibraryCalls(@ptrCast(hinstDLL));
        },

        win.DLL_PROCESS_DETACH => {},

        else => {},
    }

    return win.TRUE;
}
