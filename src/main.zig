const std = @import("std");

const windows = std.os.windows;

const LPDWORD = *windows.DWORD;
const BOOL = c_int;

const WPARAM = windows.UINT;
const LPARAM = WPARAM;

const STD_ERROR_HANDLE: windows.DWORD = @bitCast(@as(i32, -12));

const WM_DWMCOLORIZATIONCOLORCHANGED = 0x0320;
const DWMWA_SYSTEM_BACKDROP_TYPE = 38;

const PROCESS_CREATE_THREAD = 0x0002;
const PROCESS_VM_OPERATION = 0x0008;
const PROCESS_VM_WRITE = 0x0020;

const MEM_COMMIT = 0x00001000;
const MEM_RESERVE = 0x00002000;

const PAGE_READWRITE = 0x04;

const xamlDllPath = "xaml.dll";

extern "kernel32" fn WriteFile(
    hFile: windows.HANDLE,
    lpBuffer: windows.LPCVOID,
    nNumberOfBytesToWrite: windows.DWORD,
    lpNumberOfBytesWritten: LPDWORD,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) BOOL;

extern "kernel32" fn OpenProcess(
    dwDesiredAccess: windows.DWORD,
    bInheritHandle: BOOL,
    dwProcessId: windows.DWORD,
) callconv(.winapi) ?windows.HANDLE;

extern "kernel32" fn GetStdHandle(nStdHandle: windows.DWORD) callconv(.winapi) ?windows.HANDLE;

extern "user32" fn FindWindowExW(
    hWndParent: ?windows.HWND,
    hWndChildAfter: ?windows.HWND,
    lpClassName: windows.LPCWSTR,
    lpWindowName: ?windows.LPCWSTR,
) callconv(.winapi) ?windows.HWND;

extern "user32" fn GetWindowThreadProcessId(
    hwnd: windows.HWND,
    lpwdProcessId: *windows.DWORD,
) callconv(.winapi) windows.DWORD;

extern "user32" fn VirtualAllocEx(
    hProcess: windows.HANDLE,
    lpAddress: windows.LPVOID,
    dwSize: windows.SIZE_T,
    flAllocationType: windows.DWORD,
    flProtect: windows.DWORD,
) callconv(.winapi) ?windows.LPVOID;

extern "kernel32" fn WriteProcessMemory(
    hProcess: windows.HANDLE,
    lpBaseAddress: windows.LPVOID,
    lpBuffer: windows.LPCVOID,
    nSize: windows.SIZE_T,
    lpNumberOfBytesWritten: *windows.SIZE_T,
) callconv(.winapi) BOOL;

extern "kernel32" fn CreateRemoteThread(
    hProcess: windows.HANDLE,
    lpThreadAttributes: *windows.SECURITY_ATTRIBUTES,
    dwStackSize: windows.SIZE_T,
    lpStartAddress: windows.THREAD_START_ROUTINE,
    lpParameter: windows.LPVOID,
    dwCreationFlags: windows.DWORD,
    lpThreadId: windows.LPDWORD,
) callconv(.winapi) windows.HANDLE;

extern "kernel32" fn LoadLibraryW(lpLibFileName: windows.LPCWSTR) callconv(.winapi) windows.HMODULE;

pub fn main() void {
    const taskBarHwnd = FindWindowExW(
        null,
        null,
        std.unicode.utf8ToUtf16LeStringLiteral("Shell_TrayWnd"),
        null,
    ) orelse {
        @panic("Unable to find 'Shell_TrayWnd' window.");
    };

    var explorerProcessId: windows.DWORD = 0;
    if (GetWindowThreadProcessId(taskBarHwnd, &explorerProcessId) == 0) {
        @panic("Unable to get 'explorer.exe' pid.");
    }

    const explorerProcess = OpenProcess(
        PROCESS_VM_OPERATION | PROCESS_VM_WRITE,
        0,
        explorerProcessId,
    ) orelse {
        @panic("Unable to call 'OpenProcess' with 'explorer.exe' pid.");
    };

    const xamlDllPathAddress = VirtualAllocEx(
        explorerProcess,
        null,
        @sizeOf(@TypeOf(xamlDllPath)),
        MEM_COMMIT,

        PAGE_READWRITE,
    ) orelse {
        @panic("Unable to allocate 'xaml.dll' path string.");
    };

    const writtenBytes = 0;
    if (WriteProcessMemory(
        explorerProcess,
        xamlDllPathAddress,
        xamlDllPath,
        @sizeOf(@TypeOf(xamlDllPath)),
        &writtenBytes,
    ) == 0) {
        @panic("Unable to write 'xaml.dll' path string memory.");
    }

    _ = CreateRemoteThread(
        explorerProcess,
        null,
        0,
        LoadLibraryW,
        xamlDllPathAddress,
        0,
        null,
    );
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = trace;
    _ = ret_addr;

    // Safe stderr writing without allocations
    if (GetStdHandle(STD_ERROR_HANDLE)) |handle| {
        if (handle != windows.INVALID_HANDLE_VALUE) {
            var writtenBytes: windows.DWORD = 0;
            _ = WriteFile(
                handle,
                msg.ptr,
                @intCast(msg.len),
                &writtenBytes,
                null,
            );
        }
    }
    // TODO: exit instead

    @trap();
}
