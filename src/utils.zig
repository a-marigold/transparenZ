const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");

const constants = @import("constants.zig");

/// Returns slice of `buffer` or `null` in case of error.
pub inline fn getExePath(
    /// Handle of a module (for example, from `LoadLibrary` function), exe path of which to return.
    ///
    /// `null` treated as current module handle.
    module: ?zigWin.HMODULE,
    /// Receives the result.
    buffer: *[zigWin.MAX_PATH]u16,
) ?[]u16 {
    const pathLen = win.GetModuleFileNameW(module, buffer, buffer.len);

    if (pathLen == 0) {
        @branchHint(.cold);

        return null;
    }

    return buffer[0..pathLen];
}

/// Opens process which owns the window of `windowClassName`.
///
/// Passes `dwDesiredAccess` to `win.GetWindowThreadProcessId`.
///
/// Returns `zigWin.HANDLE` to the process or `null` in case of error.
pub fn findProcessByWindowClass(windowClassName: zigWin.LPCWSTR, dwDesiredAccess: zigWin.DWORD) ?zigWin.HANDLE {
    const hwnd = win.FindWindowExW(
        null,
        null,
        windowClassName,
        null,
    ) orelse {
        @branchHint(.cold);

        return null;
    };

    var pid: zigWin.DWORD = 0;
    if (win.GetWindowThreadProcessId(hwnd, &pid) == 0) {
        @branchHint(.cold);

        return null;
    }

    return win.OpenProcess(
        dwDesiredAccess,
        win.FALSE,
        pid,
    );
}

/// Allocates memory in process of `processHandler` and then writes `data` there.
///
/// Returns start address of allocated memory or `null` in case of error.
pub fn allocWriteProcessMemory(
    data: *const anyopaque,
    /// Size in bytes
    size: zigWin.SIZE_T,
    processHandle: zigWin.HANDLE,
) ?zigWin.LPVOID {
    const startAddress = win.VirtualAllocEx(
        processHandle,
        null,
        size,
        win.MEM_RESERVE | win.MEM_COMMIT,
        win.PAGE_READWRITE,
    ) orelse {
        return null;
    };
    if (win.WriteProcessMemory(
        processHandle,
        startAddress,
        data,
        size,
        null,
    ) == win.FALSE) {
        return null;
    }

    return startAddress;
}

/// High-level wrapper over `CreateThread` win api.
///
/// Returns handle to created thread or `null` in case of error.
pub inline fn createThread(
    /// Init function.
    startRoutine: *const zigWin.THREAD_START_ROUTINE,
    /// `lpParameter` of `CreateThread`.
    routineArg: ?*anyopaque,
) ?zigWin.HANDLE {
    return win.CreateThread(
        null,
        0,
        startRoutine,
        routineArg,
        0,
        null,
    );
}

/// High-level wrapper over `CreateRemoteThread` win api.
pub inline fn createRemoteThread(
    /// Process in which to create thread.
    process: zigWin.HANDLE,
    startRoutine: *const zigWin.THREAD_START_ROUTINE,
    /// `lpParameter` of `CreateRemoteThread`.
    routineArg: ?*anyopaque,
) ?zigWin.HANDLE {
    return win.CreateRemoteThread(
        process,
        null,
        0,
        startRoutine,
        routineArg,
        0,
        null,
    );
}

/// Waits for `thread` and then closes the handle.
pub inline fn joinThread(thread: zigWin.HANDLE) void {
    _ = win.WaitForSingleObject(thread, win.INFINITE);

    _ = win.CloseHandle(thread);
}

/// Exits the current process.
pub inline fn exit(exitCode: zigWin.UINT) noreturn {
    _ = win.TerminateProcess(win.GetCurrentProcess(), exitCode);
    unreachable;
}

/// Creates events via `CreateEventExW` for every element of `EnumValues`.
///
/// Uses `getEventNameOfEnumValue` to create names for events.
///
/// Returns created array of event handles, where handles
/// are located in strict order of `EnumValues`.
///
/// If any call of `CreateEventExW` fails, returns `null`.
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
pub fn createEventsFromEnum(
    /// `field_values` of an `Enum`.
    comptime EnumValues: @FieldType(std.lang.Type.Enum, "field_values"),
    /// Must be at least `'Local\\\\'` or `'Global\\\\'`, but not empty.
    comptime namePrefix: []const u8,
    /// To be passed to `CreateEventExW`.
    dwFlags: zigWin.DWORD,
    /// To be passed to `CreateEventExW`.
    dwDesiredAccess: zigWin.DWORD,
) ?[EnumValues.len]zigWin.HANDLE {
    var events: [EnumValues.len]zigWin.HANDLE = undefined;

    inline for (EnumValues, 0..) |value, index| {
        const event = win.CreateEventExW(
            null,
            comptime getEventNameOfEnumValue(namePrefix, value),
            dwFlags,
            dwDesiredAccess,
        );

        if (event) |eventHandle| {
            events[index] = eventHandle;
        } else {
            @branchHint(.cold);

            return null;
        }
    }
    return events;
}

/// Calls `OpenEventW` with name `namePrefix ++ EnumValue`,
/// calls `SetEvent` with the event and closes it with `CloseHandle`.
///
/// Uses `getEventNameOfEnumValue` to create names for events.
///
/// Returns `BOOL` indicating success or fail.
pub inline fn setEventOfEnum(
    /// Must be at least `'Local\\\\'` or `'Global\\\\'`, but not empty.
    comptime namePrefix: []const u8,
    comptime EnumValue: comptime_int,
    /// To be passed to `OpenEventW`.
    dwDesiredAccess: zigWin.DWORD,
) win.BOOL {
    const event = win.OpenEventW(
        dwDesiredAccess,
        win.FALSE,
        comptime getEventNameOfEnumValue(namePrefix, EnumValue),
    );

    if (event) |eventHandle| {
        defer _ = win.CloseHandle(eventHandle);

        return win.SetEvent(eventHandle);
    } else {
        @branchHint(.cold);

        return win.FALSE;
    }
}

const WaitEventOfEnumError = error{
    WaitFail,
    WaitTimeout,
};

/// Waits for `events` via `WaitForMultipleObjects`.
///
/// Returns value of enum, event of which `WaitForMultipleObjects` returned or `WaitEventOfEnumError`.
pub inline fn waitAnyEventOfEnum(
    comptime TagType: @FieldType(std.lang.Type.Enum, "tag_type"),
    comptime enumValuesLen: u64,
    /// Events from `createEventsFromEnum` function.
    events: *const [enumValuesLen]zigWin.HANDLE,
    /// Runtime enum values from `getRuntimeEnumValues` function.
    enumValues: *const [enumValuesLen]TagType,
    /// Time in milliseconds
    timeoutMs: u32,
) WaitEventOfEnumError!TagType {
    const waitResult = win.WaitForMultipleObjects(events.len, events, win.FALSE, timeoutMs);

    if (waitResult == win.WAIT_FAILED) {
        @branchHint(.cold);

        return WaitEventOfEnumError.WaitFail;
    } else if (waitResult == win.WAIT_TIMEOUT) {
        @branchHint(.cold);

        return WaitEventOfEnumError.WaitTimeout;
    }

    const eventIndex = waitResult - win.WAIT_OBJECT_0;

    return enumValues[eventIndex];
}

/// Intended to be called at comptime.
///
/// Returns `namePrefix ++ EnumValue`.
fn getEventNameOfEnumValue(
    /// Must be at least `'Local\\\\'` or `'Global\\\\'`, but not empty.
    comptime namePrefix: []const u8,
    comptime EnumValue: comptime_int,
) [:0]const u16 {
    return unicode.utf8ToUtf16LeStringLiteral(namePrefix) ++ constants.UTF16_NUMBERS[EnumValue];
}

/// Intended to be called at comptime.
///
/// Converts comptime `EnumValues` to runtime array with `TagType` elements type.
pub fn getRuntimeEnumValues(
    comptime EnumValues: @FieldType(std.lang.Type.Enum, "field_values"),
    comptime TagType: @FieldType(std.lang.Type.Enum, "tag_type"),
) [EnumValues.len]TagType {
    var runtimeValues: [EnumValues.len]TagType = undefined;

    inline for (EnumValues, 0..) |value, index| {
        runtimeValues[index] = value;
    }
    return runtimeValues;
}
