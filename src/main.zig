const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");
const constants = @import("constants.zig");

const utils = @import("utils.zig");

const MainErrors = constants.MainErrors;
const UI_DLL_ERRORS = constants.UI_DLL_ERRORS;

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

        @panic(MainErrors.OPEN_EXPLORER_FAIL);
    };

    const uiDllPath = block: {
        var exeDirPath = utils.getExeDirPath() orelse {
            @branchHint(.cold);

            @panic(MainErrors.GET_EXE_PATH_FAIL);
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

        @panic(MainErrors.ALLOC_UI_DLL_FILE_NAME_FAIL);
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

        @panic(MainErrors.UI_DLL_CODE_EVENT_CREATION_FAILED);
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

    const waitResult = win.WaitForMultipleObjects(
        uiDllCodeEvents.len,
        &uiDllCodeEvents,
        win.FALSE,
        win.INFINITE,
    );

    if (waitResult == win.WAIT_FAILED) {
        @panic(MainErrors.WAIT_UI_DLL_FAIL);
    }

    const runtimeUiDllCodeValues = comptime utils.getRuntimeEnumValues(
        UiDllCodeValues,

        UiDllCodeInfo.tag_type,
    );

    // `eventIndex` is exactly less than `runtimeUiDllCodeValues` length:
    // `WAIT_TIMEOUT` cannot appear here, `WAIT_FAILED` is checked,
    // and `WAIT_ABANDONED` appears only for mutexes, not for events
    const eventIndex = waitResult - win.WAIT_OBJECT_0;

    const eventUiDllCode = runtimeUiDllCodeValues[eventIndex];

    if (eventUiDllCode != UiDllCode.Success) {
        @panic(UI_DLL_ERRORS[eventUiDllCode]);
    }
}
