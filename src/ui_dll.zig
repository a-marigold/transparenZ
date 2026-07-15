//! Updates the taskbar UI.
//!
//! First injected to `explorer.exe` and then used as DLL for `InitializeXamlDiagnosticsEx`.
//!
//! Compile file must be named `ui.dll` (see the `constants.zig`).

const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");
const constants = @import("constants.zig");

const utils = @import("utils.zig");

const TaskbarHook = @import("taskbar_hook.zig");

var taskbarHook = TaskbarHook.taskbarHook;

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

/// Called when `InitializeXamlDiagnosticsEx` loads this DLL.
export fn DllGetClassObject(
    rclsid: *const zigWin.GUID,
    riid: *const zigWin.GUID,
    ppv: *zigWin.LPVOID,
) callconv(.winapi) win.HRESULT {
    // The check is not actually needed
    // 'cause `DllGetClassObject` is called only by `InitializeXamlDiagnoticsEx`
    // But it ensures there won't be any problem
    if (std.meta.eql(rclsid.*, TaskbarHook.TASKBAR_HOOK_GUID)) {
        return taskbarHook.vtable.QueryInterface(taskbarHook, riid, ppv);
    }

    return .CLASS_E_CLASSNOTAVAILABLE;
}

fn initXamlDiagnostics(lpParameter: ?zigWin.LPVOID) callconv(.winapi) zigWin.DWORD {
    _ = lpParameter;

    const windowsUiXaml = win.LoadLibraryExW(
        unicode.utf8ToUtf16LeStringLiteral(win.WINDOWS_UI_XAML_DLL_NAME),
        null,
        win.LOAD_LIBRARY_SEARCH_SYSTEM32,
    );

    const initializeXamlDiagnosticsEx: *const win.InitializeXamlDiagnosticsEx = @ptrCast(win.GetProcAddress(
        windowsUiXaml,
        "InitializeXamlDiagnostics",
    ));

    const uiDllPath = block: {
        var exeDirPath = utils.getExeDirPath() orelse {
            return 0;
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
        TaskbarHook.TASKBAR_HOOK_GUID,
        null,
    );

    return 1;
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
