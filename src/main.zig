const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");
const constants = @import("constants.zig");

const utils = @import("utils.zig");

const UiDllCode = constants.UiDllCode;
const UiDllCodeValues = @typeInfo(UiDllCode).@"enum".field_values;

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

    // Create events before injection
    const uiDllCodeEvents = createUiDllCodeEvents();

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

    switch (UiDllCodeValues[eventIndex]) {
        UiDllCode.Success => {
            utils.exit(0);
        },
        UiDllCode.GetExeDirFailed => {
            @panic("Failed to get path to the '" ++ constants.UI_DLL_FILE_NAME ++ "' executable.");
        },
    }
}

/// Creates events for every variant of `UiDllCode`.
///
/// Returns array of event handles, where handles are located in strict order of `UiDllCode` enum fields.
///
/// Example:
///
/// Accessing `UiDllCode.Success` (the first field of `UiDllCode`) - `uiDllCodeEvents[0]`.
inline fn createUiDllCodeEvents() [UiDllCodeValues.len]zigWin.HANDLE {
    const uiDllCodeEvents: [UiDllCodeValues.len]zigWin.HANDLE = undefined;

    inline for (UiDllCodeValues, 0..) |code, index| {
        uiDllCodeEvents[index] = win.CreateEventExW(
            null,
            unicode.utf8ToUtf16LeStringLiteral(utils.getUiDllCodeEventName(code)),
            0,
            win.SYNCHRONIZE | win.EVENT_MODIFY_STATE,
        );
    }

    return uiDllCodeEvents;
}

/// Opens process which owns the window of `windowClassName`.
///
/// Passes `dwDesiredAccess` to `win.GetWindowThreadProcessId`.
///
/// Returns `zigWin.HANDLE` to the process or `null` in case of error.
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

/// Allocates memory in process of `processHandler` and then writes `data` there.
///
/// Returns start address of allocated memory or `null` in case of error.
inline fn allocWriteProcessMemory(
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
