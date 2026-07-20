const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");

const constants = @import("constants.zig");

pub const AbsPath = struct {
    /// `buffer.len` does not represent the real length of path.
    ///
    /// Use `AbsPath.len` instead.
    ///
    ///
    /// Everything that is after `AbsPath.buffer[AbsPath.len - 1]` is a stack garbage.
    buffer: [zigWin.MAX_PATH:0]zigWin.WCHAR,

    /// Length of path in `buffer`.
    len: zigWin.DWORD,
};

/// Returns `AbsPath` struct or `null` in case of error.
///
/// Returned `len` **doesn't** include trailing backslash (`\`) of path char in `buffer`.
///
/// (it means `result.buffer[result.len - 1]` **doesn't** retrieves `\`).
pub fn getExeDirPath() ?AbsPath {
    var buffer: @FieldType(AbsPath, "buffer") = undefined;

    const absPathLen = win.GetModuleFileNameW(null, &buffer, buffer.len);

    if (absPathLen == 0) {
        @branchHint(.cold);

        return null;
    }

    const utf16BackSlash: u16 = '\\';

    var pathIndex = absPathLen - 1;

    while (pathIndex > 0) : (pathIndex -= 1) {
        if (buffer[pathIndex] == utf16BackSlash) {
            break;
        }
    }

    return .{ .buffer = buffer, .len = pathIndex };
}

/// Mutates `exeDirPath.buffer` via copying and appending `constants.UI_DLL_FILE_NAME` there.
///
/// Also appends Null Terminator to the path and includes it in `AbsPath.len`.
///
/// Example:
///
/// After function call `exeDirPath.buffer` contains `...\somePath\ui.dll\0`, and `exeDirPath.len` is updated.
pub inline fn exeDirPathToUiDllPath(exeDirPath: *AbsPath) void {
    const uiDllPath = comptime unicode.utf8ToUtf16LeStringLiteral("\\" ++ constants.UI_DLL_FILE_NAME);

    @memcpy(exeDirPath.buffer[exeDirPath.len..], uiDllPath);

    exeDirPath.len += uiDllPath.len + 1; // Add 1 for Null Terminator
    exeDirPath.buffer[exeDirPath.len - 1] = 0; // Add Null Terminator
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

/// High-level wrapper of `CreateThread` win api.
///
/// Returns handle to created thread or `null` in case of error.
pub inline fn createThread(
    startRoutine: *const zigWin.THREAD_START_ROUTINE,
    /// Passed to `CreateThread` as `lpParameter`.
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
    namePrefix: []const u8,
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

        if (event == null) {
            @branchHint(.cold);

            return null;
        }

        events[index] = event;
    }

    return events;
}

/// Calls `OpenEventW` with name `namePrefix ++ EnumValue`,
/// calls `SetEvent` with the event and closes it with `CloseHandle`.
///
/// Uses `getEventNameOfEnumValue` to create names for events.
///
/// Returns result of `SetEvent` call.
pub inline fn setEventOfEnum(
    /// mMust be at least `'Local\\\\'` or `'Global\\\\'`, but not empty.
    namePrefix: []const u8,
    comptime EnumValue: comptime_int,
    /// To be passed to `OpenEventW`.
    dwDesiredAccess: zigWin.DWORD,
) win.BOOL {
    const event = win.OpenEventW(
        dwDesiredAccess,
        win.FALSE,
        comptime getEventNameOfEnumValue(namePrefix, EnumValue),
    );

    defer _ = win.CloseHandle(event);

    return win.SetEvent(event);
}

/// Intended to be called at comptime.
///
/// Returns `namePrefix ++ EnumValue`.
fn getEventNameOfEnumValue(
    /// Must be at least `'Local\\\\'` or `'Global\\\\'`, but not empty.
    namePrefix: []const u8,
    comptime EnumValue: comptime_int,
) []const u16 {
    return unicode.utf8ToUtf16LeStringLiteral(namePrefix) ++ constants.UTF16_NUMBERS[EnumValue];
}

/// Intended to be called at comptime.
///
/// Converts comptime `enumValues` to runtime array with `tagType` elements type.
pub fn getRuntimeEnumValues(
    comptime EnumValues: @FieldType(std.lang.Type.Enum, "field_values"),
    comptime TagType: @FieldType(std.lang.Type.Enum, "tag_type"),
) [EnumValues.len]TagType {
    var result: [EnumValues.len]TagType = undefined;
    inline for (EnumValues, 0..) |value, index| {
        result[index] = value;
    }

    return result;
}
