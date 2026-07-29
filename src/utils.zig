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
    buffer: *[zigWin.MAX_PATH:0]u16,
) ?[:0]u16 {
    const pathLen = win.GetModuleFileNameW(module, buffer, buffer.len);

    if (pathLen == 0) {
        @branchHint(.cold);
        return null;
    }

    return @ptrCast(buffer[0..pathLen]);
}

/// Does not add null terminator to the end of dir path.
///
/// Returned slice length does not include `\`.
pub inline fn getDirPath(path: []u16) []u16 {
    const backSlash: u16 = '\\';
    var pathIndex = path.len - 1;
    while (path[pathIndex] != backSlash and pathIndex >= 0) {
        pathIndex -= 1;
    }

    return path[0..pathIndex];
}

/// Copies `literal` to `path` starting from `startIndex` and inserts null terminator after it.
///
/// `path` must not have trailing backslash.
///
/// Returns slice of path with copied `literal`.
pub inline fn appendPathStringLiteral(path: *[zigWin.MAX_PATH]u16, startIndex: usize, comptime literal: [:0]const u16) [:0]u16 {
    const newComponent = "\\" ++ literal;

    const newComponentLenWithNullTerm = comptime newComponent.len + 1;

    @memcpy(
        path[startIndex .. startIndex + newComponentLenWithNullTerm],
        newComponent[0..newComponentLenWithNullTerm],
    );

    return path[0 .. startIndex + newComponent.len :0];
}

/// Returns `true` if `a` and `b` have the same amount of elements before null terminator and equality operator returned true for them all.
pub fn compareNullTermPtrs(comptime T: type, a: [*:0]const T, b: [*:0]const T) bool {
    var index: usize = 0;

    while (true) : (index += 1) {
        const elA = a[index];
        const elB = b[index];

        if (elA != elB) {
            return false;
        }

        const isAEnd = elA == 0;
        const isBEnd = elB == 0;

        if (isAEnd or isBEnd) {
            if (isAEnd and isBEnd) {
                return true;
            }

            return false;
        }
    }
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

/// Allocates `size` amount of bytes in remote `process`.
pub inline fn allocRemoteMemory(
    process: zigWin.HANDLE,
    /// Size in bytes.
    size: usize,
) ?*anyopaque {
    return win.VirtualAllocEx(
        process,
        null,
        size,
        win.MEM_RESERVE | win.MEM_COMMIT,
        win.PAGE_READWRITE,
    );
}

/// Completely frees `process` memory, that is, after freeing,
/// the memory is not reserved and does not belong to `process`.
pub inline fn freeRemoteMemory(
    process: zigWin.HANDLE,
    /// Address of process address space.
    address: *anyopaque,
    /// Size in bytes.
    size: usize,
) void {
    _ = win.VirtualFreeEx(
        process,
        address,
        size,
        win.MEM_RELEASE,
    );
}

/// Writes `size` amount of `data` to `address` in memory of `process`.
///
pub inline fn writeRemoteMemory(
    process: zigWin.HANDLE,
    /// Address from address space of `process`.
    address: *anyopaque,
    data: *const anyopaque,
    /// Size in bytes.
    size: usize,
) ?void {
    if (win.WriteProcessMemory(
        process,
        address,
        data,
        size,
        null,
    ) == win.FALSE) {
        return null;
    }
}

const ThreadRoutine = fn (routineArg: ?*anyopaque) callconv(.winapi) ThreadRoutineResult;

pub const ThreadRoutineResult = enum(zigWin.DWORD) {
    Success = 0,
    Fail = 1,
};

/// High-level wrapper over `CreateThread` win api.
///
/// Returns handle to created thread or `null` in case of error.
pub inline fn createThread(
    /// Init function.
    routine: *const ThreadRoutine,
    /// `lpParameter` of `CreateThread`.
    routineArg: ?*anyopaque,
) ?zigWin.HANDLE {
    return win.CreateThread(
        null,
        0,
        @ptrCast(routine),
        routineArg,
        0,
        null,
    );
}

const RemoteThreadRoutine = fn (routineArg: ?*anyopaque) callconv(.winapi) zigWin.DWORD;

/// High-level wrapper over `CreateRemoteThread` win api.
pub inline fn createRemoteThread(
    /// Process in which to create thread.
    process: zigWin.HANDLE,
    routine: *const RemoteThreadRoutine,
    /// `lpParameter` of `CreateRemoteThread`. Must be in address space of `process`.
    routineArg: ?*anyopaque,
) ?zigWin.HANDLE {
    return win.CreateRemoteThread(
        process,
        null,
        0,
        routine,
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

/// Returns address of `lib` function with name `fnName`.
pub inline fn getLibFn(lib: zigWin.HMODULE, comptime Fn: type, fnName: [:0]const u8) *const Fn {
    return @ptrCast(win.GetProcAddress(lib, fnName));
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
/// const events = createEventsFromEnum(letterValues, "Local\\Letter", win.EVENT_ALL_ACCESS);
///
/// // Created 'Local\LetterA', 'Local\LetterB', 'Local\LetterC'
/// // `events[0]` is `Letter.A`, `events[1]` is `Letter.B` and so on
/// ```
pub fn createEventsFromEnum(
    /// `field_values` of an `Enum`.
    comptime EnumValues: @FieldType(std.lang.Type.Enum, "field_values"),
    /// Must be at least `'Local\'` or `'Global\'`, but not empty.
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
    /// Must be at least `'Local\'` or `'Global\'`, but not empty.
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

/// Waits for `events` via `WaitForMultipleObjects`.
///
/// Returns value of enum, event of which `WaitForMultipleObjects` returned, or `null` in case of error.
pub inline fn waitAnyEventOfEnum(
    comptime TagType: @FieldType(std.lang.Type.Enum, "tag_type"),
    comptime enumValuesLen: u64,
    /// Events from `createEventsFromEnum` function.
    events: *const [enumValuesLen]zigWin.HANDLE,
    /// Runtime enum values from `getRuntimeEnumValues` function.
    enumValues: *const [enumValuesLen]TagType,
    /// Time in milliseconds
    timeoutMs: u32,
) ?TagType {
    const waitResult = win.WaitForMultipleObjects(events.len, events, win.FALSE, timeoutMs);

    // `WAIT_TIMEOUT` and `WAIT_FAILED` are in out of `enumValuesLen` range
    if (waitResult >= comptime enumValuesLen + win.WAIT_OBJECT_0) {
        return null;
    }

    const eventIndex = waitResult - win.WAIT_OBJECT_0;

    return enumValues[eventIndex];
}

/// Intended to be called at comptime.
///
/// Returns `namePrefix ++ EnumValue`.
fn getEventNameOfEnumValue(
    /// Must be at least `'Local\'` or `'Global\'`, but not empty.
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

/// Creates nonsignaled auto reseted event.
pub inline fn createEvent(
    name: []const u16,
    /// `dwDesiredAccess` parameter of `CreateEventExW`.
    desiredAccess: u32,
) ?zigWin.HANDLE {
    return win.CreateEventExW(null, name, 0, desiredAccess);
}

pub const FileMapping = struct {
    /// Handle of mapping.
    handle: zigWin.HANDLE,

    /// Address of mapped memory in the address space of process.
    address: *anyopaque,

    pub inline fn init(
        name: []const u16,
        /// `flProtect` parameter of `CreateFileMappingW`.
        protectFlags: u32,
    ) ?FileMapping {
        const mapping = win.CreateFileMappingW(
            win.INVALID_HANDLE_VALUE,
            null,
            protectFlags,
            0,
            0,
            name,
        ) orelse {
            return null;
        };

        const address = win.MapViewOfFile(
            mapping,
            protectFlags,
            0,
            0,
            0,
            null,
        ) orelse {
            return null;
        };

        return .{
            .handle = mapping,
            .address = address,
        };
    }
};
