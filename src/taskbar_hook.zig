//! `TaskbarHook` inherited from `IObjectWithSite`.

const TaskbarHook = @This();

const std = @import("std");
const zigWin = std.os.windows;

const win = @import("win.zig");

pub const TASKBAR_HOOK_GUID: zigWin.GUID = .{
    .Data1 = 0xe59f556e,

    .Data2 = 0x7b96,
    .Data3 = 0x4620,

    .Data4 = .{ 0xad, 0xf9, 0x19, 0x01, 0x0d, 0xad, 0xb9, 0xad },
};

vtable: *const win.IObjectWithSite.VTable,

/// Pointer to `IXamlDiagnostics`.
///
/// Initialized in `taskbarHook.vtable.SetSite`,
/// when the OS calls this function after executing `DllGetClassObject`.
iXamlDiagnostics: ?*win.IXamlDiagnostics,

/// `AddRef` and `Release` no-op implemenation of `taskbarHook`.
///
/// It is no-op 'cause `taskbarHook` is a singleton and it is useless to manage its lifetime
fn refMangingNoopFn(self: *anyopaque) callconv(.winapi) zigWin.ULONG {
    _ = self;
    // Returning `1` means `taskbarHook`'s ref count is one
    return 1;
}

/// Singleton intended to be located in `.data` instead of heap.
///
/// Used to intercept `IXamlDiagnostics` and use it for taskbar customization.
pub var taskbarHook: TaskbarHook = .{
    .vtable = &.{
        .QueryInterface = struct {
            fn QueryInterface(self: *anyopaque, riid: *const zigWin.GUID, ppvObject: *?*anyopaque) callconv(.winapi) win.HRESULT {
                _ = self;

                if (std.meta.eql(riid.*, win.IID_IObjectWithSite)) {
                    ppvObject.* = &taskbarHook;

                    return .S_OK;
                }

                return .E_NOINTERFACE;
            }
        }.QueryInterface,

        .AddRef = TaskbarHook.refMangingNoopFn,

        .Release = TaskbarHook.refMangingNoopFn,

        .SetSite = struct {
            fn SetSite(self: *anyopaque, pUnkSite: ?*win.IUnknown) callconv(.winapi) win.HRESULT {
                const taskbarHookSelf: *TaskbarHook = @ptrCast(@alignCast(self));

                if (pUnkSite) |iUnknown| {
                    return iUnknown.vtable.QueryInterface(
                        @ptrCast(iUnknown),
                        &win.IID_IXamlDiagnostics,
                        @ptrCast(&taskbarHookSelf.iXamlDiagnostics),
                    );
                }

                if (taskbarHookSelf.iXamlDiagnostics) |iXamlDiagnostics| {
                    _ = iXamlDiagnostics.vtable.Release(iXamlDiagnostics);

                    taskbarHookSelf.iXamlDiagnostics = null;
                }

                return .S_OK;
            }
        }.SetSite,

        .GetSite = struct {
            fn GetSite(
                self: *anyopaque,
                riid: *const zigWin.GUID,
                ppvSite: **anyopaque,
            ) callconv(.winapi) win.HRESULT {
                _ = self;
                _ = riid;
                _ = ppvSite;

                // `InitializeXamlDiagnosticsEx` never causes call of `GetSite`
                // So it is no-op
                return .E_NOINTERFACE;
            }
        }.GetSite,
    },
    .iXamlDiagnostics = null,
};
