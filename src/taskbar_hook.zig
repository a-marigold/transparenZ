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

vtable: win.IObjectWithSite.VTable,

/// Pointer to `IXamlDiagnostics`.
///
/// Initialized in `tapSite.vtable.SetSite`,
/// when windows calls this function after executing `DllGetClassObject`.
xamlDiagnosticsInterface: ?*win.IUnknown,

/// `AddRef` and `Release` no-op implemenation of `tapSite`.
///
/// It is no-op 'cause `tapSite` is a singleton and it is useless to manage its lifetime
fn refManagingFn(self: *TaskbarHook) callconv(.winapi) zigWin.ULONG {
    _ = self;

    // Returning `1` means `tapSite`'s ref count is one
    return 1;
}

/// Singleton intended to be located in `.data` instead of heap.
///
/// Used to intercept `IXamlDiagnostics` and use it for taskbar customization.
pub var taskbarHook: TaskbarHook = .{
    .vtable = &.{
        .QueryInterface = struct {
            fn QueryInterface(self: *TaskbarHook, riid: *const zigWin.GUID, ppvObject: *?*anyopaque) callconv(.winapi) win.HRESULT {
                _ = self;

                if (std.meta.eql(riid, __IOBJECTIWTHSITEGUID__)) {
                    ppvObject.* = &taskbarHook;

                    return .S_OK;
                }

                return .E_NOINTERFACE;
            }
        }.QueryInterface,

        .AddRef = TaskbarHook.refManagingFn,

        .Release = TaskbarHook.refManagingFn,

        .SetSite = struct {
            fn SetSite(self: *TaskbarHook, pUnkSite: ?*const win.IUnknown) callconv(.winapi) win.HRESULT {
                if (pUnkSite) |iUnknown| {
                    var xamlDiagnosticsInterfacePointer: *taskbarHook.xamlDiagnosticsInterface = undefined;

                    return iUnknown.vtable.QueryInterface(
                        iUnknown,
                        &xamlDiagnosticsInterfacePointer,
                    );
                }

                if (self.xamlDiagnosticsInterface) |xamlDiagnosticsInterface| {
                    _ = xamlDiagnosticsInterface.vtable.Release(xamlDiagnosticsInterface);

                    self.xamlDiagnosticsInterface = null;
                }

                return .S_OK;
            }
        }.SetSite,

        .GetSite = struct {
            fn GetSite(
                self: *TaskbarHook,
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
    .xamlDiagnosticsInterface = null,
};
