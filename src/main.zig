const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");

const constants = @import("constants.zig");

const AbsPath = struct {
    /// `buffer.len` does not represent the real length of path.
    ///
    /// Use `AbsPath.len` instead.
    buffer: [win.MAX_WIN_PATH_SIZE]zigWin.WCHAR,

    /// Length of path in `buffer`, including the Null Terminator.
    len: zigWin.DWORD,
};

pub fn main() void {
    const explorerProcess = getProcess(
        unicode.utf8ToUtf16LeStringLiteral(win.TASK_BAR_CLASS_NAME),
        win.PROCESS_VM_OPERATION | win.PROCESS_VM_WRITE | win.PROCESS_CREATE_THREAD,
    ) orelse {
        @branchHint(.cold);

        @panic("Unable to open 'explorer.exe' process.");
    };

    var uiDllAbsPath = getAbsPath(
        unicode.utf8ToUtf16LeStringLiteral(constants.UI_DLL_PATH),
    ) orelse {
        @branchHint(.cold);

        @panic("Unable to get absolute path of './" ++ constants.UI_DLL_PATH ++ "'.");
    };

    const uiDllAbsPathStartAddress = allocWriteProcessMemory(
        &uiDllAbsPath.buffer,
        uiDllAbsPath.len * @sizeOf(zigWin.WCHAR),
        explorerProcess,
    ) orelse {
        @branchHint(.cold);

        @panic("Unable to allocate '" ++ constants.UI_DLL_PATH ++ "' string in explorer.exe.");
    };

    const loadLibraryAddress = win.GetProcAddress(
        win.GetModuleHandleW(unicode.utf8ToUtf16LeStringLiteral("kernel32")),

        "LoadLibraryW",
    );

    _ = win.CreateRemoteThread(
        explorerProcess,
        null,
        0,
        @ptrCast(loadLibraryAddress),
        uiDllAbsPathStartAddress,
        0,
        null,
    );
}

/// Opens process which owns the window of `windowClassName`.
/// Passes `dwDesiredAccess` to `win.GetWindowThreadProcessId`.
///
/// Returns `zigWin.HANDLE` to process, or in case of error returns `null`.
inline fn getProcess(windowClassName: zigWin.LPCWSTR, dwDesiredAccess: zigWin.DWORD) ?zigWin.HANDLE {
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

/// Allocates memory in process of `processHandler` and then writes it with `data`.
///
/// Returns start address of allocated memory or `null` in case of error.
inline fn allocWriteProcessMemory(
    data: *anyopaque,
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

/// Returns `AbsPath` struct or `null` in case of error.
inline fn getAbsPath(path: zigWin.LPCWSTR) ?AbsPath {
    var buffer: @FieldType(AbsPath, "buffer") = undefined;

    const absPathLen = win.GetFullPathNameW(
        path,
        win.MAX_WIN_PATH_SIZE,
        @ptrCast(&buffer),
        null,
    ) + 1; // Include the Null Terminator

    if (absPathLen == 0) {
        @branchHint(.cold);

        return null;
    }

    return .{ .buffer = buffer, .len = absPathLen };
}

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

    @trap();
}
