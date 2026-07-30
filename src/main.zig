const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;
const builtin = @import("builtin");

const win = @import("win.zig");
const constants = @import("constants.zig");
const utils = @import("utils.zig");

const Errors = constants.Errors;

const UiDllCode = constants.UiDllCode;

const FileMapping = utils.FileMapping;

pub const panic = std.debug.FullPanic(struct {
    fn panic(msg: []const u8, first_trace_addr: ?usize) noreturn {
        @branchHint(.cold);

        if (builtin.mode == .Debug) {
            std.debug.defaultPanic(msg, first_trace_addr);
        }

        // Safe stderr writing without allocations

        if (win.GetStdHandle(win.STD_ERROR_HANDLE)) |handle| {
            @branchHint(.likely);

            if (handle != zigWin.INVALID_HANDLE_VALUE) {
                var writtenBytes: zigWin.DWORD = 0;
                _ = win.WriteFile(
                    handle,
                    msg.ptr,
                    @intCast(msg.len),
                    &writtenBytes,
                    null,
                );
            }
        }

        utils.exit(1);
    }
}.panic);

pub fn main() void {
    const explorerProcess = utils.findProcessByWindowClass(
        unicode.utf8ToUtf16LeStringLiteral(constants.TASKBAR_CLASS_NAME),

        win.PROCESS_VM_OPERATION | win.PROCESS_VM_WRITE | win.PROCESS_CREATE_THREAD,
    ) orelse {
        @branchHint(.cold);

        @panic(Errors.Main.OPEN_EXPLORER_FAIL);
    };

    const uiDllPath: [:0]u16 = block: {
        var buffer: [zigWin.MAX_PATH:0]u16 = undefined;

        const exePath = utils.getExePath(null, &buffer) orelse {
            @branchHint(.cold);

            @panic(Errors.Main.GET_EXE_PATH_FAIL);
        };

        const exeDirName = utils.getDirPath(exePath);

        break :block utils.appendPathStringLiteral(
            &buffer,
            exeDirName.len,
            comptime unicode.utf8ToUtf16LeStringLiteral(constants.UI_DLL_FILE_NAME),
        );
    };
    const uiDllPathSizeWithNullTerm = (uiDllPath.len + 1) * @sizeOf(u16);

    const remoteUiDllPathAddress = utils.allocRemoteMemory(
        explorerProcess,
        uiDllPathSizeWithNullTerm,
    ) orelse {
        @panic(Errors.Main.ALLOC_UI_DLL_PATH_FAIL);
    };
    defer utils.freeRemoteMemory(
        explorerProcess,
        remoteUiDllPathAddress,
        uiDllPathSizeWithNullTerm,
    );

    utils.writeRemoteMemory(
        explorerProcess,
        remoteUiDllPathAddress,
        uiDllPath.ptr,
        uiDllPathSizeWithNullTerm,
    ) orelse {
        @panic(Errors.Main.ALLOC_UI_DLL_PATH_FAIL);
    };

    const UiDllCodeTagType = @typeInfo(UiDllCode).@"enum".tag_type;

    const uiDllCodeMapping = FileMapping.create(
        unicode.utf8ToUtf16LeStringLiteral(UiDllCode.FILE_MAPPING_NAME),
        @sizeOf(UiDllCode),
        win.PAGE_READWRITE,
    ) orelse {
        @panic(Errors.Main.CREATE_UI_DLL_CODE_MAPPING_FAIL);
    };

    // Init value of `UiDllCode` mapping
    const uiDllCodeSentinel: UiDllCodeTagType = @bitCast(@as(isize, -1));

    const uiDllCodeAddress: *UiDllCodeTagType = @ptrCast(@alignCast(uiDllCodeMapping.address));
    uiDllCodeAddress.* = uiDllCodeSentinel;

    const uiDllCodeSyncEvent = utils.createEvent(
        unicode.utf8ToUtf16LeStringLiteral(UiDllCode.SYNC_EVENT_NAME),
        UiDllCode.SYNC_EVENT_DESIRED_ACCESS,
    ) orelse {
        @panic(Errors.Main.CREATE_UI_DLL_CODE_EVENT_FAIL);
    };

    _ = injectDll(
        explorerProcess,
        remoteUiDllPathAddress,
        utils.getLibFn(
            win.GetModuleHandleW(unicode.utf8ToUtf16LeStringLiteral("kernel32.dll")),
            win.LoadLibraryW,
            "LoadLibraryW",
        ),
    ) orelse {
        @panic(Errors.Main.INJECT_UI_DLL_FAIL);
    };

    const waitResult = win.WaitForSingleObject(
        uiDllCodeSyncEvent,
        constants.STYLE_TASKBAR_ATTEMPTS_TIME_MS + 6_000,
    );

    if (waitResult != win.WAIT_OBJECT_0) {
        @panic(Errors.Main.WAIT_UI_DLL_CODE_EVENTS_FAIL);
    }

    const uiDllCodeResult = uiDllCodeAddress.*;

    if (uiDllCodeResult == uiDllCodeSentinel) {
        @panic(Errors.Main.UI_DLL_CODE_MAPPING_EMPTY);
    }
    if (uiDllCodeResult != @intFromEnum(UiDllCode.Success)) {
        @panic(Errors.UI_DLL[uiDllCodeResult]);
    }
}

/// Injects DLL of `remoteDllPathAddress` to `process`.
///
/// Returns handle of injected remote thread or `null` in case of error.
inline fn injectDll(
    process: zigWin.HANDLE,
    remoteDllPathAddress: *const anyopaque,
    /// Pointer to `LoadLibraryW` function of `kernel32.dll` that is valid in `process` address space.
    ///
    /// This parameter is needed not to search
    /// `LoadLibraryW` every time, when DLLs injected multiple times.
    loadLibraryW: *const win.LoadLibraryW,
) ?zigWin.HANDLE {
    return utils.createRemoteThread(
        process,
        @ptrCast(loadLibraryW),
        @constCast(remoteDllPathAddress),
    );
}
