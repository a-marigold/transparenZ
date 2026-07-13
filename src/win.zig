//! Definitions of `win32` types used in `transparenZ`.
//!
//! Contains only types that are missing in `std.os.windows`.

pub const zigWin = @import("std").os.windows;

/// The windows class name of task bar.
pub const TASK_BAR_CLASS_NAME = "Shell_TrayWnd";

pub const LPDWORD = *zigWin.DWORD;
pub const BOOL = c_int;
pub const FALSE: BOOL = 0;
pub const TRUE: BOOL = 1;

pub const WPARAM = zigWin.UINT;
pub const LPARAM = WPARAM;

pub const STD_ERROR_HANDLE: zigWin.DWORD = @bitCast(@as(i32, -12));

pub const PROCESS_CREATE_THREAD = 0x0002;
pub const PROCESS_VM_OPERATION = 0x0008;

pub const PROCESS_VM_READ = 0x0010;
pub const PROCESS_VM_WRITE = 0x0020;

pub const MEM_RESERVE = 0x00002000;
pub const MEM_COMMIT = 0x00001000;

pub const PAGE_READWRITE = 0x04;

pub const DLL_PROCESS_ATTACH: zigWin.DWORD = 1;

pub const DLL_PROCESS_DETACH: zigWin.DWORD = 0;

pub extern "kernel32" fn WriteFile(
    hFile: zigWin.HANDLE,
    lpBuffer: zigWin.LPCVOID,
    nNumberOfBytesToWrite: zigWin.DWORD,
    lpNumberOfBytesWritten: LPDWORD,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn OpenProcess(
    dwDesiredAccess: zigWin.DWORD,
    bInheritHandle: BOOL,
    dwProcessId: zigWin.DWORD,
) callconv(.winapi) ?zigWin.HANDLE;

pub extern "kernel32" fn GetStdHandle(nStdHandle: zigWin.DWORD) callconv(.winapi) ?zigWin.HANDLE;

pub extern "user32" fn FindWindowExW(
    hWndParent: ?zigWin.HWND,
    hWndChildAfter: ?zigWin.HWND,
    lpClassName: zigWin.LPCWSTR,
    lpWindowName: ?zigWin.LPCWSTR,
) callconv(.winapi) ?zigWin.HWND;

pub extern "user32" fn GetWindowThreadProcessId(
    hwnd: zigWin.HWND,
    lpwdProcessId: *zigWin.DWORD,
) callconv(.winapi) zigWin.DWORD;

pub extern "user32" fn VirtualAllocEx(
    hProcess: zigWin.HANDLE,
    lpAddress: ?zigWin.LPVOID,
    dwSize: zigWin.SIZE_T,
    flAllocationType: zigWin.DWORD,
    flProtect: zigWin.DWORD,
) callconv(.winapi) ?zigWin.LPVOID;

pub extern "kernel32" fn WriteProcessMemory(
    hProcess: zigWin.HANDLE,
    lpBaseAddress: zigWin.LPVOID,
    lpBuffer: zigWin.LPCVOID,
    nSize: zigWin.SIZE_T,
    lpNumberOfBytesWritten: ?*zigWin.SIZE_T,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn CreateRemoteThread(
    hProcess: zigWin.HANDLE,
    lpThreadAttributes: ?*zigWin.SECURITY_ATTRIBUTES,
    dwStackSize: zigWin.SIZE_T,
    lpStartAddress: *const zigWin.THREAD_START_ROUTINE,
    lpParameter: zigWin.LPVOID,
    dwCreationFlags: zigWin.DWORD,
    lpThreadId: ?LPDWORD,
) callconv(.winapi) zigWin.HANDLE;

pub extern "user32" fn MessageBoxA(
    hWnd: ?zigWin.HWND,
    lpText: zigWin.LPCSTR,
    lpCaption: ?zigWin.LPCSTR,
    uType: zigWin.UINT,
) callconv(.winapi) c_int;

pub extern "kernel32" fn DisableThreadLibraryCalls(
    hLibModule: zigWin.HMODULE,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn GetModuleHandleW(
    lpModuleName: zigWin.LPCWSTR,
) callconv(.winapi) zigWin.HMODULE;

pub extern "kernel32" fn GetProcAddress(
    hModule: zigWin.HMODULE,
    lpProcName: zigWin.LPCSTR,
) callconv(.winapi) *anyopaque;

pub extern "kernel32" fn GetModuleFileNameW(
    hModule: ?zigWin.HMODULE,
    lpFilename: zigWin.LPWSTR,
    nSize: zigWin.DWORD,
) callconv(.winapi) zigWin.DWORD;
