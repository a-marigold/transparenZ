const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");
const constants = @import("constants.zig");

const utils = @import("utils.zig");

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
    const explorerProcess = getProcess(
        unicode.utf8ToUtf16LeStringLiteral(win.TASK_BAR_CLASS_NAME),
        win.PROCESS_VM_OPERATION | win.PROCESS_VM_WRITE | win.PROCESS_CREATE_THREAD,
    ) orelse {
        @branchHint(.cold);

        @panic("Failed to open 'explorer.exe' process.");
    };

    const uiDllPath = block: {
        var exeDirPath = utils.getExeDirPath() orelse {
            @branchHint(.cold);

            @panic("Failed to get path to the 'transparenZ' executable.");
        };

        utils.exeDirPathToUiDllPath(&exeDirPath);

        break :block exeDirPath;
    };

    const uiDllPathStartAddress = allocWriteProcessMemory(
        &uiDllPath.buffer,
        uiDllPath.len * @sizeOf(zigWin.WCHAR),
        explorerProcess,
    ) orelse {
        @branchHint(.cold);

        @panic("Failed to allocate '" ++ constants.UI_DLL_FILE_NAME ++ "' string in explorer.exe.");
    };

    const loadLibraryW = win.GetProcAddress(
        win.GetModuleHandleW(unicode.utf8ToUtf16LeStringLiteral("kernel32.dll")),
        "LoadLibraryW",
    );

    const uiDllCodeValues = @typeInfo(uiDllCodeEvents).@"enum".field_values;

    // Create events before injection
    const uiDllCodeEvents = createEventsFromEnum(
        uiDllCodeValues,
        constants.UI_DLL_FILE_NAME,
        win.SYNCHRONIZE | win.EVENT_MODIFY_STATE,
    );

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
        @panic("Waiting time of '" ++ constants.UI_DLL_FILE_NAME ++ "' completion expired.");
    } else if (waitResult == win.WAIT_FAILED) {
        @panic("Waiting for '" ++ constants.UI_DLL_FILE_NAME ++ "' completion failed.");
    }

    const eventIndex = waitResult - win.WAIT_OBJECT_0;

    switch (enumFieldValues[eventIndex]) {
        UiDllCode.Success => {
            utils.exit(0);
        },

        UiDllCode.GetExeDirFailed => {
            @panic("Failed to get path to the '" ++ constants.UI_DLL_FILE_NAME ++ "' executable.");
        },
    }
}

/// Creates events via `CreateEventExW` for every element of `enumValues`.
///
/// Returns created array of event handles, where handles
/// are located in strict order of `UiDllCodeEvent` enum fields.
///
/// Example:
/// ```zig
/// const Letter = enum(u32) {
///   A,
///   B,
///   C,
/// };
/// const letterValues = @typeInfo(Letter).@"enum".field_values;
///
/// const events = createEventsFromEnum(letterValues, "Local\\\\Letter", win.EVENT_ALL_ACCESS);
///
/// // Created 'Local\\LetterA', 'Local\\LetterB', 'Local\\LetterC'
///
/// // `events[0]` is `Letter.A`, `events[1]` is `Letter.B` and so on
/// ```
/// Accessing `UiDllCode.Success` (the first field of `UiDllCode`) - `uiDllCodeEvents[0]`.
inline fn createEventsFromEnum(
    /// `field_values` of an `Enum`.
    comptime enumValues: @FieldType(std.lang.Type.Enum, "field_values"),
    /// Prefix name of events. It must be at least `'Local\\\\'` or `'Global\\\\'`, but not empty.
    comptime namePrefix: [:0]const u8,
    /// `dwDesiredAccess` parameter of `CreateEventExW`.
    dwDesiredAccess: zigWin.DWORD,
) [enumValues.len]zigWin.HANDLE {
    const events: [enumValues.len]zigWin.HANDLE = undefined;

    inline for (enumValues, 0..) |value, index| {
        events[index] = win.CreateEventExW(
            null,
            unicode.utf8ToUtf16LeStringLiteral(namePrefix ++ value),
            0,
            dwDesiredAccess,
        );
    }

    return events;
}
