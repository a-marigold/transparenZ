const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");
const constants = @import("constants.zig");

const utils = @import("utils.zig");

const errors = constants.errors;

const UiDllCode = constants.UiDllCode;

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = trace;
    _ = ret_addr;
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

pub fn main() void {
    const explorerProcess = utils.findProcessByWindowClass(
        unicode.utf8ToUtf16LeStringLiteral(win.TASK_BAR_CLASS_NAME),

        win.PROCESS_VM_OPERATION | win.PROCESS_VM_WRITE | win.PROCESS_CREATE_THREAD,
    ) orelse {
        @branchHint(.cold);

        @panic(errors.OPEN_EXPLORER_FAIL);
    };

    const uiDllPath = block: {
        var exeDirPath = utils.getExeDirPath() orelse {
            @branchHint(.cold);

            @panic(errors.GET_EXE_PATH_FAIL);
        };

        utils.exeDirPathToUiDllPath(&exeDirPath);

        break :block exeDirPath;
    };

    const uiDllPathStartAddress = utils.allocWriteProcessMemory(
        &uiDllPath.buffer,
        uiDllPath.len * @sizeOf(zigWin.WCHAR),
        explorerProcess,
    ) orelse {
        @branchHint(.cold);

        @panic(errors.ALLOC_UI_DLL_FILE_NAME_FAIL);
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

        @panic(errors.UI_DLL_CODE_EVENT_CREATION_FAILED);
    };

    _ = win.CreateRemoteThread(
        explorerProcess,
        null,
        0,
        @ptrCast(loadLibraryW),
        uiDllPathStartAddress,
        0,
        null,
    );

    const waitCount = uiDllCodeEvents.len;

    const waitResult = win.WaitForMultipleObjects(
        waitCount,
        &uiDllCodeEvents,
        win.FALSE,
        32_000,
    );

    if (waitResult == win.WAIT_TIMEOUT) {
        @panic(errors.WAIT_UI_DLL_TIMEOUT);
    } else if (waitResult == win.WAIT_FAILED) {
        @panic(errors.WAIT_UI_DLL_FAIL);
    }

    const runtimeUiDllCodeValues = utils.getRuntimeEnumValues(
        UiDllCodeValues,
        UiDllCodeInfo.tag_type,
    );

    const eventIndex = waitResult - win.WAIT_OBJECT_0;
    // `eventIndex` is exactly less than `uiDllCodeValues.len`
    // 'cause `WAIT_TIMEOUT` and `WAIT_FAILED` are checked,
    // and `WAIT_ABANDONED` appears only for mutexes, not for events
    switch (runtimeUiDllCodeValues[eventIndex]) {
        @intFromEnum(UiDllCode.Success) => {
            utils.exit(0);
        },
        @intFromEnum(UiDllCode.GetExeDirFailed) => {
            @panic(errors.UI_DLL_GET_EXE_PATH_FAIL);
        },
        else => {
            unreachable;
        },
    }
}
