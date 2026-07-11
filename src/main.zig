const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");

const constants = @import("constants.zig");

const AbsPath = struct {
    buffer: [win.MAX_WIN_PATH_SIZE]zigWin.WCHAR,
    /// Length of path in `buffer`, including the Null Terminator.
    len: zigWin.DWORD,
};

pub fn main() void {
    const explorerProcess = getProcess(
        unicode.utf8ToUtf16LeStringLiteral(win.TASK_BAR_CLASS_NAME),
        win.PROCESS_VM_OPERATION | win.PROCESS_VM_WRITE | win.PROCESS_CREATE_THREAD,
    ) orelse {
        @panic("Unable to open 'explorer.exe' process.");
    };

    const uiDllAbsPath = getAbsPath(
        unicode.utf8ToUtf16LeStringLiteral(constants.UI_DLL_PATH),
    ) orelse {
        @branchHint(.cold);

        @panic("Unable to get absolute path of './" ++ constants.UI_DLL_PATH ++ "'.");
    };

    const uiDllPathAddress = win.VirtualAllocEx(
        explorerProcess,
        null,
        uiDllAbsPath.len * zigWin.WCHAR,
        win.MEM_RESERVE | win.MEM_COMMIT,
        win.PAGE_READWRITE,
    ) orelse {
        @panic("Unable to allocate '" ++ constants.UI_DLL_PATH ++ "'' path string.");
    };

    var writtenBytes: zigWin.SIZE_T = 0;

    if (win.WriteProcessMemory(
        explorerProcess,
        uiDllPathAddress,
        constants.UI_DLL_PATH,
        @sizeOf(@TypeOf(constants.UI_DLL_PATH)),

        &writtenBytes,
    ) == win.FALSE) {
        @panic("Unable to write '" ++ constants.UI_DLL_PATH ++ "' path string memory.");
    }

    _ = win.CreateRemoteThread(
        explorerProcess,
        null,
        0,
        @ptrCast(&win.LoadLibraryW),
        uiDllPathAddress,
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

/// Returns `AbsPath` struct or `null` in case of error.
inline fn getAbsPath(path: zigWin.LPCWSTR) ?AbsPath {
    const buffer: AbsPath.buffer = undefined;

    const absPathLen = win.GetFullPathNameW(
        path,
        win.MAX_WIN_PATH_SIZE,
        &buffer,
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
