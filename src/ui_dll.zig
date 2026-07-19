//! Updates the taskbar UI.
//!
//! First it is injected to `explorer.exe` and then used as DLL for `InitializeXamlDiagnosticsEx`.
//!
//! Compiled file must be named `ui.dll` (see the `constants.zig`).

const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");
const constants = @import("constants.zig");

const utils = @import("utils.zig");

const TaskbarHook = @import("taskbar_hook.zig");

const UiDllCode = constants.UiDllCode;

var taskbarHook = TaskbarHook.taskbarHook;

export fn DllMain(
    hinstDLL: zigWin.HINSTANCE,
    fwdReason: zigWin.DWORD,
    lpvReserved: zigWin.LPVOID,
) callconv(.winapi) win.BOOL {
    _ = lpvReserved;

    if (fwdReason == win.DLL_PROCESS_ATTACH) {
        _ = win.DisableThreadLibraryCalls(@ptrCast(hinstDLL));

        // New thread is used 'cause `initXamlDiags`
        // loads libraries and can cause loader lock
        const thread = utils.createThread(&initXamlDiags, null);

        if (thread) |handle| {
            _ = win.CloseHandle(handle);

            return win.TRUE;
        }

        return win.FALSE;
    }

    return win.TRUE;
}

/// Called when `InitializeXamlDiagnosticsEx` loads this DLL.
export fn DllGetClassObject(
    rclsid: *const zigWin.GUID,
    riid: *const zigWin.GUID,
    ppv: *zigWin.LPVOID,
) callconv(.winapi) win.HRESULT {
    // The check is not actually needed
    // 'cause `DllGetClassObject` is called only by `InitializeXamlDiagnoticsEx`.
    // But it ensures there won't be any problem
    if (std.meta.eql(rclsid.*, TaskbarHook.TASKBAR_HOOK_GUID)) {
        return taskbarHook.vtable.QueryInterface(taskbarHook, riid, ppv);
    }

    return .CLASS_E_CLASSNOTAVAILABLE;
}

/// Loads `Windows.Ui.Xaml.dll` and calls `InitializeXamlDiagnosticsEx`.
///
/// `InitializeXamlDiagnosticsEx` loads this dll again, calls `DllGetClassObject`,
/// and if it succeed `taskbarHook.xamlDiagsInterface` has `IXamlDiagnostics`,
/// which is used to style taskbar.
fn initXamlDiags(
    /// Used in `CreateThread` so this parameter is needed.
    lpParameter: ?zigWin.LPVOID,
) callconv(.winapi) zigWin.DWORD {
    _ = lpParameter;

    const winUiXamlDll = win.LoadLibraryExW(
        unicode.utf8ToUtf16LeStringLiteral(win.WINDOWS_UI_XAML_DLL_NAME),
        null,
        win.LOAD_LIBRARY_SEARCH_SYSTEM32,
    );

    const initializeXamlDiagnosticsEx: *const win.InitializeXamlDiagnosticsEx = @ptrCast(win.GetProcAddress(
        winUiXamlDll,
        "InitializeXamlDiagnostics",
    ));

    const uiDllPath = block: {
        var exeDirPath = utils.getExeDirPath() orelse {
            _ = utils.setEventOfEnum(
                UiDllCode.EVENT_NAME_PREFIX,
                UiDllCode.GetExeDirFailed,
                UiDllCode.EVENT_DESIRED_ACCESS,
                win.FALSE,
            );

            return 0;
        };

        utils.exeDirPathToUiDllPath(&exeDirPath);

        break :block exeDirPath;
    };

    const currentPid = win.GetCurrentProcessId();

    // Name of diagnostics must be unique in the whole system.
    //
    // Start with 10 to have stable length.
    // If start with 0-9 numbers, there is an unused whitespace

    var diagsName: [5]u16 = "tZy" ++ constants.UTF16_NUMBERS[10];

    // Need to do multiple attempts 'cause when `explorer.exe`
    // is loading (e.g the system has just waken up), it can block `InitializeXamlDiagnosticsEx`

    var attemptCount = 0;

    while (attemptCount < 60) : ({
        attemptCount += 1;

        const diagsNameCount = constants.UTF16_NUMBERS[attemptCount + 10];

        diagsName[diagsName.len - 2] = diagsNameCount[0];
        diagsName[diagsName.len - 1] = diagsNameCount[1];
    }) {
        // Call `InitializeXamlDiagnosticsEx` in another thread
        // 'cause it works only once per thread

        utils.joinThread(
            utils.createThread(
                &initXamlDiagsRoutine,
                InitXamlDiagsRoutineContext{
                    .initializeXamlDiagnosticsEx = initializeXamlDiagnosticsEx,
                    .endPointName = diagsName,
                    .pid = currentPid,
                    .wszTAPDllName = uiDllPath,
                    .tapClsid = TaskbarHook.TASKBAR_HOOK_GUID,
                },
            ),
        );
    }

    // Neccessarily indicate success
    _ = utils.setEventOfEnum(
        UiDllCode.EVENT_NAME_PREFIX,
        UiDllCode.Success,
        UiDllCode.EVENT_DESIRED_ACCESS,
        win.FALSE,
    );

    return 1;
}

const InitXamlDiagsRoutineContext = struct {
    /// Pointer to the `InitializeXamlDiagnosticsEx` function.
    initializeXamlDiagnosticsEx: *const win.InitializeXamlDiagnosticsEx,

    // `InitializeXamlDiagnosticsEx` parameters.

    endPointName: []const u16,
    pid: zigWin.DWORD,
    wszTAPDllName: []const u16,
    tapClsid: *const zigWin.GUID,
};

/// Used as start routine of a thread in `initXamlDiagnostics`.
export fn initXamlDiagsRoutine(
    context: InitXamlDiagsRoutineContext,
) callconv(.winapi) @typeInfo(win.InitializeXamlDiagnosticsEx).@"fn".return_type {
    return context.initializeXamlDiagnosticsEx(
        context.endPointName,
        context.pid,
        null,
        context.wszTAPDllName,
        context.tapClsid,
        null,
    );
}
