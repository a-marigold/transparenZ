const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;
const builtin = @import("builtin");

const win = @import("win.zig");
const constants = @import("constants.zig");

const utils = @import("utils.zig");

const Errors = constants.Errors;

const UiDllCode = constants.UiDllCode;

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
            unicode.utf8ToUtf16LeStringLiteral(constants.UI_DLL_FILE_NAME),
        );
    };

    const uiDllPathSizeWithNullTerminator = uiDllPath.len * @sizeOf(zigWin.WCHAR);

    const uiDllPathStartAddress = utils.allocWriteProcessMemory(
        uiDllPath.ptr,
        uiDllPathSizeWithNullTerminator,
        explorerProcess,
    ) orelse {
        @branchHint(.cold);

        @panic(Errors.Main.ALLOC_UI_DLL_FILE_NAME_FAIL);
    };

    const loadLibraryW = win.GetProcAddress(
        win.GetModuleHandleW(unicode.utf8ToUtf16LeStringLiteral("kernel32.dll")),
        "LoadLibraryW",
    );

    const UiDllCodeInfo = @typeInfo(UiDllCode).@"enum";

    const UiDllCodeValues = UiDllCodeInfo.field_values;

    // Create events before injection
    const uiDllCodeEvents = utils.createEventsFromEnum(
        UiDllCodeValues,
        UiDllCode.EVENT_NAME_PREFIX,
        0,
        UiDllCode.EVENT_DESIRED_ACCESS,
    ) orelse {
        @branchHint(.cold);

        @panic(Errors.Main.CREATE_UI_DLL_CODE_EVENT_FAIL);
    };

    _ = utils.createRemoteThread(
        explorerProcess,
        @ptrCast(@alignCast(loadLibraryW)),
        uiDllPathStartAddress,
    );

    const eventUiDllCode = utils.waitAnyEventOfEnum(
        UiDllCodeInfo.tag_type,
        UiDllCodeValues.len,
        &uiDllCodeEvents,
        &comptime utils.getRuntimeEnumValues(UiDllCodeValues, UiDllCodeInfo.tag_type),

        comptime constants.STYLE_TASKBAR_ATTEMPTS_TIME_MS + 6000,
    ) orelse {
        @panic(Errors.Main.WAIT_UI_DLL_CODE_EVENTS_FAIL);
    };

    if (eventUiDllCode != @intFromEnum(UiDllCode.Success)) {
        @panic(Errors.UI_DLL[eventUiDllCode]);
    }
}
