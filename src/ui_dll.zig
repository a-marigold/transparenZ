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

const UiDllCode = constants.UiDllCode;
const TaskbarElementNames = constants.TaskbarElementNames;

const TaskbarHook = @import("taskbar_hook.zig");

var taskbarHook = &TaskbarHook.taskbarHook;

/// Handle of this DLL.
///
/// Initialized in `DllMain`.
var dllHandle: zigWin.HINSTANCE = undefined;

export fn DllMain(
    hinstDLL: zigWin.HINSTANCE,
    fwdReason: zigWin.DWORD,
    lpvReserved: zigWin.LPVOID,
) callconv(.winapi) win.BOOL {
    _ = lpvReserved;

    dllHandle = hinstDLL;

    if (fwdReason == win.DLL_PROCESS_ATTACH) {
        _ = win.DisableThreadLibraryCalls(@ptrCast(hinstDLL));

        // New thread is used 'cause `initXamlDiags`
        // loads libraries and can cause loader lock
        const thread = utils.createThread(&init, null);

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
    ppv: *?zigWin.LPVOID,
) callconv(.winapi) win.HRESULT {
    // The check is not actually needed
    // 'cause `DllGetClassObject` is called only by `InitializeXamlDiagnoticsEx`.
    // But it ensures there won't be any problem
    if (std.meta.eql(rclsid.*, TaskbarHook.TASKBAR_HOOK_GUID)) {
        return taskbarHook.vtable.QueryInterface(taskbarHook, riid, ppv);
    }

    return .CLASS_E_CLASSNOTAVAILABLE;
}

/// Loads `Windows.Ui.Xaml.dll`, calls `InitializeXamlDiagnosticsEx` and styles taskbar.
fn init(
    /// Used in `createThread` so this parameter is needed.
    routineArg: ?*anyopaque,
) callconv(.winapi) utils.ThreadReturnValue {
    _ = routineArg;

    const winUiXamlDll = win.LoadLibraryExW(
        unicode.utf8ToUtf16LeStringLiteral(constants.WINDOWS_UI_XAML_DLL_NAME),
        null,
        win.LOAD_LIBRARY_SEARCH_SYSTEM32,
    );

    const initializeXamlDiagnosticsEx: *const win.InitializeXamlDiagnosticsEx = @ptrCast(win.GetProcAddress(
        winUiXamlDll,

        "InitializeXamlDiagnosticsEx",
    ));

    const uiDllPath = block: {
        var buffer: [zigWin.MAX_PATH:0]u16 = undefined;

        break :block utils.getExePath(@ptrCast(dllHandle), &buffer);
    } orelse {
        setUiDllCodeEvent(.GetExePathFail);

        return .Fail;
    };

    const currentPid = win.GetCurrentProcessId();

    const InitXamlDiagsRoutine = struct {
        pub const Context = struct {
            /// Pointer to which assign result of `InitializeXamlDiagnosticsEx`.
            result: *win.HRESULT,
            /// Pointer to the `InitializeXamlDiagnosticsEx` function.
            initializeXamlDiagnosticsEx: *const win.InitializeXamlDiagnosticsEx,

            // `InitializeXamlDiagnosticsEx` parameters

            endPointName: [:0]const u16,
            pid: zigWin.DWORD,
            diagsDllName: [:0]const u16,
            tapClsid: *const zigWin.GUID,
        };
        /// Used as start routine of a thread in the loop below.
        fn routine(context: *@This().Context) callconv(.winapi) utils.ThreadReturnValue {
            context.result.* = context.initializeXamlDiagnosticsEx(
                context.endPointName,
                context.pid,
                null,
                context.diagsDllName,
                context.tapClsid,
                null,
            );

            return .Success;
        }
    };

    // Use anonymous struct to allocate it once in `.data` section for perf
    var routineContext = &struct {
        var context: InitXamlDiagsRoutine.Context = .{
            // Values are assigned below or in the loop

            .result = undefined,
            .initializeXamlDiagnosticsEx = undefined,

            .endPointName = undefined,
            .pid = undefined,
            .diagsDllName = undefined,
            .tapClsid = undefined,
        };
    }.context;

    routineContext.initializeXamlDiagnosticsEx = initializeXamlDiagnosticsEx;

    routineContext.pid = currentPid;
    routineContext.diagsDllName = uiDllPath;
    routineContext.tapClsid = &TaskbarHook.TASKBAR_HOOK_GUID;

    // Name of diagnostics must be unique in the whole system.
    // Start with 10, 'cause if start with 0-9 numbers, there is an unused whitespace or unstable length
    var diagsName: [5:0]u16 = ("tZy" ++ constants.UTF16_NUMBERS[10]).*;

    const maxAttemptCount = 60;
    const attemptInterval = 600;

    var attemptCount: u32 = 0;

    // Need to do multiple attempts 'cause when `explorer.exe`
    // is loading (e.g the system has just waken up), it can block `InitializeXamlDiagnosticsEx`
    while (attemptCount < maxAttemptCount) : ({
        attemptCount += 1;

        const diagsNameCount = constants.UTF16_NUMBERS[attemptCount + 10];
        diagsName[diagsName.len - 2] = diagsNameCount[0];
        diagsName[diagsName.len - 1] = diagsNameCount[1];
    }) {
        var initXamlDiagsResult: win.HRESULT = undefined;

        routineContext.result = &initXamlDiagsResult;

        routineContext.endPointName = &diagsName;

        // Call `InitializeXamlDiagnosticsEx` in another thread
        // 'cause it works only once per thread
        const initXamlDiagsRoutineThread = utils.createThread(
            @ptrCast(&InitXamlDiagsRoutine.routine),
            @constCast(routineContext),
        );

        if (initXamlDiagsRoutineThread) |thread| {
            utils.joinThread(thread);

            if (initXamlDiagsResult == win.HRESULT.S_OK) {
                break;
            }
        }

        win.Sleep(attemptInterval);
    }

    if (taskbarHook.iXamlDiagnostics) |iXamlDiagnostics| {
        const registerCallbackResult = registerVisualTreeServiceCallback(
            iXamlDiagnostics,
            &iVisualTreeServiceCallback,
        );

        if (registerCallbackResult != .S_OK) {
            setUiDllCodeEvent(.InitVisualTreeServiceFail);

            return .Fail;
        }
    } else {
        setUiDllCodeEvent(.InitXamlDiagsFail);

        return .Fail;
    }

    // Neccessarily indicate success
    setUiDllCodeEvent(.Success);

    return .Success;
}
/// Queries `IVisualTreeService` from `iXamlDiagnostics` argument and then registers `callback` via `AdviseVisualTreeChange`.
/// Returns result of `AdviseVisualTreeChange` or `HRESULT.E_FAIL` if querying `IVisualTreeService` failed.
fn registerVisualTreeServiceCallback(
    iXamlDiagnostics: *win.IXamlDiagnostics,
    callback: *win.IVisualTreeServiceCallback,
) win.HRESULT {
    var iVisualTreeService: ?*win.IVisualTreeService = null;

    _ = iXamlDiagnostics.vtable.QueryInterface(
        iXamlDiagnostics,
        &win.IID_IVisualTreeService,
        @ptrCast(&iVisualTreeService),
    );
    if (iVisualTreeService) |treeService| {
        return treeService.vtable.AdviseVisualTreeChange(treeService, callback);
    }
    return .E_FAIL;
}

// TODO: iVisualTreeServiceCallback commit

/// Used as callback for `IVisualTreeService.vtable.AdviseVisualTreeChange`.
///
/// Triggered immediatly after callback is registered
/// or taskbar elements are changed during work.
var iVisualTreeServiceCallback: win.IVisualTreeServiceCallback = .{
    .vtable = &.{
        .QueryInterface = struct {
            fn QueryInterface(self: *anyopaque, riid: *const zigWin.GUID, ppvObject: *?*anyopaque) callconv(.winapi) win.HRESULT {
                const riidValue = riid.*;

                if (std.meta.eql(
                    riidValue,
                    win.IID_IUnknown,
                ) or std.meta.eql(
                    riidValue,
                    win.IID_IVisualTreeServiceCallback,
                )) {
                    ppvObject.* = self;

                    return .S_OK;
                }

                return .E_NOINTERFACE;
            }
        },

        .AddRef = win.IUnknownNoOpMethods.AddRef,
        .Release = win.IUnknownNoOpMethods.Release,

        .OnVisualTreeChange = struct {
            fn OnVisualTreeChange(
                self: *anyopaque,
                relation: *anyopaque,
                element: win.VisualElement,
                mutationType: win.VisualMutationType,
            ) callconv(.winapi) win.HRESULT {
                _ = self;
                _ = relation;

                if (mutationType == .Add) {
                    if (std.mem.eql(u16, element.Name, TaskbarElementNames.BACKGROUND_FILL)) {
                        if (taskbarHook.iXamlDiagnostics) |iXamlDiagnostics| {
                            const backgroundFill = getInspectableFromHandle(
                                win.IShape,
                                win.IID_IShape,
                                element.Handle,
                                iXamlDiagnostics,
                            );
                        } else {
                            // TODO: handlei
                        }
                    }
                }
            }
        }.OnVisualTreeChange,
    },
};

/// Calls `iXamlDiagnostics.GetIInspectableFromHandle` and then coerces
/// it to `T` by using `QueryInterface` method of the inspectable with `TGuid` argument.
inline fn getInspectableFromHandle(
    comptime T: type,
    /// `GUID` of `T`.
    comptime TGuid: zigWin.GUID,
    handle: win.InstanceHandle,
    /// `IXamlDiagnostics` for methods that help to get inspectable.
    iXamlDiagnostics: *win.IXamlDiagnostics,
) ?*T {
    var inspectablePointer: ?*win.IInspectable = null;

    _ = iXamlDiagnostics.vtable.GetIInspectableFromHandle(
        handle,
        &inspectablePointer,
    );

    if (inspectablePointer) |inspectable| {
        if (inspectable.vtable.QueryInterface(
            inspectable,
            TGuid,
            &inspectablePointer,
        ) == .S_OK) {
            return inspectablePointer;
        }
    }
    return null;
}

inline fn setUiDllCodeEvent(code: UiDllCode) void {
    _ = utils.setEventOfEnum(
        UiDllCode.EVENT_NAME_PREFIX,
        @intFromEnum(code),
        UiDllCode.EVENT_DESIRED_ACCESS,
    );
}
