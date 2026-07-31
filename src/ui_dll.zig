//! Updates the taskbar UI.
//!
//! First it is injected to `explorer.exe` and then used as DLL for `InitializeXamlDiagnosticsEx`.
//!
//! Compiled file must be named `ui.dll` (see the `constants.zig`).

// TODO: add panic handler

const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");
const constants = @import("constants.zig");
const utils = @import("utils.zig");
const TaskbarHook = @import("taskbar_hook.zig");

const UiDllCode = constants.UiDllCode;
const UiDllCodeTagType = @typeInfo(UiDllCode).@"enum".tag_type;
const TaskbarElementNames = constants.TaskbarElementNames;

const FileMapping = utils.FileMapping;

var taskbarHook = &TaskbarHook.taskbarHook;

/// Handle of this DLL.
///
/// Initialized in `DllMain`.
var dllHandle: zigWin.HMODULE = undefined;

pub const panic = std.debug.FullPanic(struct {
    fn panic(msg: []const u8, first_trace_addr: ?usize) noreturn {
        @branchHint(.cold);

        _ = msg;

        _ = first_trace_addr;

        if (comptime utils.isDebugMode()) {
            __debugLog__("panic0");
        }

        exitDll(dllHandle, .Fail);
    }
}.panic);

export fn DllMain(
    hinstDLL: zigWin.HINSTANCE,
    fwdReason: zigWin.DWORD,
    lpvReserved: zigWin.LPVOID,
) callconv(.winapi) win.BOOL {
    _ = lpvReserved;

    __debugLog__("0");

    dllHandle = @ptrCast(hinstDLL);

    if (fwdReason == win.DLL_PROCESS_ATTACH) {
        _ = win.DisableThreadLibraryCalls(@ptrCast(hinstDLL));

        // New thread is used 'cause `initXamlDiags`
        // loads libraries and can cause loader lock
        const thread = utils.createThread(&init, null);

        __debugLog__("1");

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
        __debugLog__("2");

        return taskbarHook.vtable.QueryInterface(taskbarHook, riid, ppv);
    }

    __debugLog__("3");

    return .CLASS_E_CLASSNOTAVAILABLE;
}

/// Loads `Windows.Ui.Xaml.dll`, calls `InitializeXamlDiagnosticsEx` and styles taskbar.
fn init(
    /// Used in `createThread` so this parameter is needed.
    routineArg: ?*anyopaque,
) callconv(.winapi) utils.ThreadRoutineResult {
    _ = routineArg;

    const uiDllCodeMapping = FileMapping.open(
        unicode.utf8ToUtf16LeStringLiteral(UiDllCode.FileMapping.NAME),
        UiDllCode.FileMapping.SIZE,
        win.FILE_MAP_WRITE,
    ) orelse {
        exitDll(dllHandle, .Fail);
    };
    const uiDllCodePtr: *UiDllCodeTagType = @ptrCast(@alignCast(uiDllCodeMapping.ptr));

    const uiDllSyncEvent = utils.openEvent(
        unicode.utf8ToUtf16LeStringLiteral(UiDllCode.SyncEvent.NAME),
        UiDllCode.SyncEvent.DESIRED_ACCESS,
    ) orelse {
        exitDll(dllHandle, .Fail);
    };

    const initializeXamlDiagnosticsEx = utils.getLibFn(
        win.GetModuleHandleW("Windows.UI.Xaml.dll"),
        win.InitializeXamlDiagnosticsEx,
        "InitializeXamlDiagnosticsEx",
    );

    const uiDllPath = block: {
        var buffer: [zigWin.MAX_PATH:0]u16 = undefined;

        break :block utils.getExePath(@ptrCast(dllHandle), &buffer);
    } orelse {
        setUiDllCode(
            .GetExePathFail,
            uiDllSyncEvent,
            uiDllCodePtr,
        );

        exitDll(dllHandle, .Fail);
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
        fn routine(context: *@This().Context) callconv(.winapi) utils.ThreadRoutineResult {
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

            // TODO: consider replacing `result` with `taskbarHook.iXamlDiagnostics` null-check
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
    const attemptInterval = comptime constants.STYLE_TASKBAR_ATTEMPTS_TIME_MS / maxAttemptCount;

    var attemptCount: u32 = 0;

    // Need to do multiple attempts 'cause when `explorer.exe`
    // is loading (e.g the system has just waken up), it can block `InitializeXamlDiagnosticsEx`
    while (attemptCount < maxAttemptCount) : ({
        attemptCount += 1;

        const diagsNameCount = constants.UTF16_NUMBERS[attemptCount + 10];
        diagsName[diagsName.len - 2] = diagsNameCount[0];
        diagsName[diagsName.len - 1] = diagsNameCount[1];
    }) {
        __debugLog__("diags attempt");

        var initXamlDiagsResult: win.HRESULT = undefined;

        routineContext.result = &initXamlDiagsResult;

        routineContext.endPointName = &diagsName;

        // Call `InitializeXamlDiagnosticsEx`
        // in another thread 'cause it works only once per thread

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

        __debugLog__("diags result");

        win.Sleep(attemptInterval);
    }

    if (taskbarHook.iXamlDiagnostics) |iXamlDiagnostics| {
        const registerCallbackResult = registerVisualTreeServiceCallback(
            iXamlDiagnostics,
            &iVisualTreeServiceCallback,
        );

        if (registerCallbackResult != .S_OK) {
            setUiDllCode(.RegisterTreeServiceCallbackFail, uiDllSyncEvent, uiDllCodePtr);

            exitDll(dllHandle, .Fail);
        }
    } else {
        setUiDllCode(.InitXamlDiagsFail, uiDllSyncEvent, uiDllCodePtr);

        __debugLog__("init diags fail");

        exitDll(dllHandle, .Fail);
    }

    // Neccessarily indicate success

    setUiDllCode(.Success, uiDllSyncEvent, uiDllCodePtr);

    return .Success;
}

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
        }.QueryInterface,

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
                    if (utils.compareNullTermPtrs(u16, element.Name, TaskbarElementNames.BACKGROUND_FILL)) {
                        if (taskbarHook.iXamlDiagnostics) |iXamlDiagnostics| {
                            const backgroundFill = getInspectableFromHandle(
                                win.IShape,
                                &win.IID_IShape,
                                element.Handle,
                                iXamlDiagnostics,
                            ) orelse {
                                // setUiDllCodeEvent(.GetIShapeInCallbackFail);

                                return .E_FAIL;
                            };

                            _ = backgroundFill.vtable.put_Fill(backgroundFill, null);
                        } else {
                            // setUiDllCodeEvent(.IXamlDiagnosticsNullInCallback);

                            return .E_FAIL;
                        }
                    }
                }

                return .S_OK;
            }
        }.OnVisualTreeChange,
    },
};

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

/// Calls `iXamlDiagnostics.GetIInspectableFromHandle` and then coerces
/// its result to `T` by using `QueryInterface` method of the inspectable with `TGuid` argument.
inline fn getInspectableFromHandle(
    comptime T: type,
    /// `GUID` of `T`.
    comptime TGuid: *const zigWin.GUID,
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
            @ptrCast(&inspectablePointer),
        ) == .S_OK) {
            return @ptrCast(inspectablePointer);
        }
    }

    return null;
}

// inline fn setUiDllCodeEvent(code: UiDllCode) void {
//     _ = utils.setEventOfEnum(
//         UiDllCode.EVENT_NAME_PREFIX,
//         @intFromEnum(code),
//         UiDllCode.EVENT_DESIRED_ACCESS,
//     );
// }

/// Writes `code` to `mappingPtr` (the `UiDllCode` file mapping) and signals `syncEvent`.
fn setUiDllCode(
    code: UiDllCode,
    /// See `UiDllCode.SYNC_EVENT_NAME`.
    syncEvent: zigWin.HANDLE,
    /// `UiDllCode.FILE_MAPPING_NAME`.
    mappingPtr: *UiDllCodeTagType,
) void {
    mappingPtr.* = @intFromEnum(code);

    _ = win.SetEvent(syncEvent);
}

/// Unloads `dll` from the current process and exits the current thread.
inline fn exitDll(dll: zigWin.HMODULE, exitCode: utils.ThreadRoutineResult) noreturn {
    _ = win.FreeLibraryAndExitThread(dll, @intFromEnum(exitCode));
    unreachable;
}

/// Used only in Debug build mode.
///
/// Outputs debug string to `explorer.exe` with added new line.
///
/// To read the output, debugger must be attached to `explorer.exe`.
fn __debugLog__(comptime pos: []const u8) void {
    if (comptime !utils.isDebugMode()) {
        @compileError("'__debugLog__' function is only for Debug build mode");
    }

    // const allocator = std.heap.smp_allocator;

    // // Intended not to free the strings

    // const formattedString = allocator.print("transparenZ: " ++ format ++ "\n", args) catch unreachable;
    // const debugString = unicode.utf8ToUtf16LeAllocZ(
    //     allocator,
    //     formattedString,
    // ) catch unreachable;

    // win.OutputDebugStringW(unicode.utf8ToUtf16LeStringLiteral("TRASNPARENZ"));
    const file = win.CreateFileW(
        unicode.utf8ToUtf16LeStringLiteral("C:\\Windows\\Temp\\tZyF") ++ unicode.utf8ToUtf16LeStringLiteral(pos),
        0x40000000,
        0,
        null,
        2,
        128,

        null,
    );

    _ = win.CloseHandle(file);
}
