//! Updates the taskbar UI.
//!
//! Injected first to `explorer.exe` and then as DLL for `InitializeXamlDiagnosticsEx`.
//!
//! Compile file must be named `ui.dll` (see the `constants.zig`).

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
                &initXamlDiagnostics,
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

/// Called in `InitializeXamlDiagnosticsEx`.
export fn DllGetClassObject(
    rclsid: *const zigWin.GUID,
    riid: *const zigWin.GUID,
    ppv: *zigWin.LPVOID,
) callconv(.winapi) win.HRESULT {
    _ = rclsid;
    _ = riid;
    _ = ppv;
}

fn initXamlDiagnostics(lpParameter: ?zigWin.LPVOID) callconv(.winapi) zigWin.DWORD {
    _ = lpParameter;

    const windowsUiXaml = win.LoadLibraryExW(
        unicode.utf8ToUtf16LeStringLiteral(win.WINDOWS_UI_XAML_DLL_NAME),
        null,
        0,
    );
    // TODO: free lib

    const initializeXamlDiagnosticsEx: *const win.InitializeXamlDiagnosticsEx = @ptrCast(win.GetProcAddress(
        windowsUiXaml,
        "InitializeXamlDiagnostics",
        win.LOAD_LIBRARY_SEARCH_SYSTEM32,
    ));

    const uiDllPath = block: {
        var exeDirPath = utils.getExeDirPath() orelse {
            // TODO: handle
        };

        utils.exeDirPathToUiDllPath(&exeDirPath);
        break :block exeDirPath;
    };

    _ = initializeXamlDiagnosticsEx(
        // Random, but unique string
        unicode.utf8ToUtf16LeStringLiteral("tZy"),

        win.GetCurrentProcessId(),
        null,
        uiDllPath,
        constants.TAP_CLSID,
        null,
    );
}

// TODO: add safety checks

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
