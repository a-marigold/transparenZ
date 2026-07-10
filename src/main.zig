const std = @import("std");

const zigWin = std.os.windows;

const win = @import("win.zig");

const xamlDllPath = "xaml.dll";

pub fn main() void {
    const taskBarHwnd = win.FindWindowExW(
        null,
        null,
        std.unicode.utf8ToUtf16LeStringLiteral("Shell_TrayWnd"),
        null,
    ) orelse {
        @panic("Unable to find 'Shell_TrayWnd' window.");
    };

    var explorerProcessId: zigWin.DWORD = 0;
    if (win.GetWindowThreadProcessId(taskBarHwnd, &explorerProcessId) == win.FALSE) {
        @panic("Unable to get 'explorer.exe' pid.");
    }

    const explorerProcess = win.OpenProcess(
        win.PROCESS_VM_OPERATION | win.PROCESS_VM_WRITE,
        0,
        explorerProcessId,
    ) orelse {
        @panic("Unable to call 'OpenProcess' with 'explorer.exe' pid.");
    };

    const xamlDllPathAddress = win.VirtualAllocEx(
        explorerProcess,
        null,
        @sizeOf(@TypeOf(xamlDllPath)),
        win.MEM_RESERVE | win.MEM_COMMIT,
        win.PAGE_READWRITE,
    ) orelse {
        @panic("Unable to allocate 'xaml.dll' path string.");
    };

    const writtenBytes = 0;
    if (win.WriteProcessMemory(
        explorerProcess,
        xamlDllPathAddress,
        xamlDllPath,
        @sizeOf(@TypeOf(xamlDllPath)),

        &writtenBytes,
    ) == win.FALSE) {
        @panic("Unable to write 'xaml.dll' path string memory.");
    }

    _ = win.CreateRemoteThread(
        explorerProcess,
        null,
        0,
        win.LoadLibraryW,
        xamlDllPathAddress,
        0,
        null,
    );
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = trace;
    _ = ret_addr;

    // Safe stderr writing without allocations
    if (win.GetStdHandle(win.STD_ERROR_HANDLE)) |handle| {
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
