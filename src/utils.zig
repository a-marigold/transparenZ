const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;
const builtin = @import("builtin");

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
///
/// Returns pointer to allocated bytes that is valid in `process` address space.
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
    /// Pointer from which to begin freeing in `process` address space.
    ptr: *anyopaque,
    /// Size in bytes.
    size: usize,
) void {
    _ = win.VirtualFreeEx(
        process,
        ptr,
        size,
        win.MEM_RELEASE,
    );
}

/// Writes `size` amount of `data` to `address` in memory of `process`.
///
pub inline fn writeRemoteMemory(
    process: zigWin.HANDLE,
    /// Pointer from address space of `process`.
    ptr: *anyopaque,
    data: *const anyopaque,
    /// Size in bytes.
    size: usize,
) ?void {
    if (win.WriteProcessMemory(
        process,
        ptr,
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
    return @ptrCast(@alignCast(win.GetProcAddress(lib, fnName)));
}

/// Creates nonsignaled non-inheritable auto reseted event.
pub inline fn createEvent(
    name: [:0]const u16,
    /// `dwDesiredAccess` parameter of `CreateEventExW`.
    desiredAccess: u32,
) ?zigWin.HANDLE {
    return win.CreateEventExW(null, name, 0, desiredAccess);
}

/// Opens non-inheritable event.
pub inline fn openEvent(
    name: [:0]const u16,
    /// `dwDesiredAccess` parameter of `OpenEventW`.
    desiredAccess: u32,
) ?zigWin.HANDLE {
    return win.OpenEventW(desiredAccess, win.FALSE, name);
}

pub const FileMapping = struct {
    /// Handle of mapping.
    handle: zigWin.HANDLE,

    // TODO: rename to 'ptr'

    /// Pointer to mapped memory in address space of the current process.
    ptr: *anyopaque,

    pub inline fn create(
        name: [:0]const u16,
        /// Size of mapping in bytes.
        size: u32,
        /// `flProtect` parameter of `CreateFileMappingW`.
        protectFlags: u32,
    ) ?FileMapping {
        const mapping = win.CreateFileMappingW(
            win.INVALID_HANDLE_VALUE,
            null,
            protectFlags,
            0,
            size,
            name,
        ) orelse {
            return null;
        };

        const ptr = win.MapViewOfFileEx(
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

            .ptr = ptr,
        };
    }

    pub fn open(name: [:0]const u16, size: u32, protectFlags: u32) ?FileMapping {
        const mapping = win.OpenFileMappingW(
            protectFlags,
            win.FALSE,
            name,
        ) orelse {
            return null;
        };

        const ptr = win.MapViewOfFileEx(
            mapping,
            protectFlags,
            0,
            size,
            0,
            null,
        ) orelse {
            return null;
        };

        return .{
            .handle = mapping,

            .ptr = ptr,
        };
    }
};

/// Intended to be called at comptime.
pub fn isDebugMode() bool {
    return builtin.mode == .Debug;
}
