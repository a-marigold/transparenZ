//! Definitions of `win32` types used in `transparenZ`.
//!
//! Contains only types that are missing in `std.os.windows`.

const zigWin = @import("std").os.windows;

const LPDWORD = *zigWin.DWORD;
const BOOL = c_int;
const FALSE: BOOL = 0;
const TRUE: BOOL = 1;

const WPARAM = zigWin.UINT;
const LPARAM = WPARAM;

const STD_ERROR_HANDLE: zigWin.DWORD = @bitCast(@as(i32, -12));
const PROCESS_CREATE_THREAD = 0x0002;
const PROCESS_VM_OPERATION = 0x0008;
const PROCESS_VM_WRITE = 0x0020;

const MEM_RESERVE = 0x00002000;
const MEM_COMMIT = 0x00001000;
const PAGE_READWRITE = 0x04;

const DLL_PROCESS_ATTACH: zigWin.DWORD = 1;
const DLL_PROCESS_DETACH: zigWin.DWORD = 0;

extern "kernel32" fn WriteFile(
    hFile: zigWin.HANDLE,
    lpBuffer: zigWin.LPCVOID,
    nNumberOfBytesToWrite: zigWin.DWORD,
    lpNumberOfBytesWritten: LPDWORD,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) BOOL;

extern "kernel32" fn OpenProcess(
    dwDesiredAccess: zigWin.DWORD,
    bInheritHandle: BOOL,
    dwProcessId: zigWin.DWORD,
) callconv(.winapi) ?zigWin.HANDLE;

extern "kernel32" fn GetStdHandle(nStdHandle: zigWin.DWORD) callconv(.winapi) ?zigWin.HANDLE;

extern "user32" fn FindWindowExW(
    hWndParent: ?zigWin.HWND,
    hWndChildAfter: ?zigWin.HWND,
    lpClassName: zigWin.LPCWSTR,
    lpWindowName: ?zigWin.LPCWSTR,
) callconv(.winapi) ?zigWin.HWND;

extern "user32" fn GetWindowThreadProcessId(
    hwnd: zigWin.HWND,
    lpwdProcessId: *zigWin.DWORD,
) callconv(.winapi) zigWin.DWORD;

extern "user32" fn VirtualAllocEx(
    hProcess: zigWin.HANDLE,
    lpAddress: zigWin.LPVOID,
    dwSize: zigWin.SIZE_T,
    flAllocationType: zigWin.DWORD,
    flProtect: zigWin.DWORD,
) callconv(.winapi) ?zigWin.LPVOID;

extern "kernel32" fn WriteProcessMemory(
    hProcess: zigWin.HANDLE,
    lpBaseAddress: zigWin.LPVOID,
    lpBuffer: zigWin.LPCVOID,
    nSize: zigWin.SIZE_T,
    lpNumberOfBytesWritten: *zigWin.SIZE_T,
) callconv(.winapi) BOOL;

extern "kernel32" fn CreateRemoteThread(
    hProcess: zigWin.HANDLE,
    lpThreadAttributes: *zigWin.SECURITY_ATTRIBUTES,
    dwStackSize: zigWin.SIZE_T,
    lpStartAddress: zigWin.THREAD_START_ROUTINE,
    lpParameter: zigWin.LPVOID,
    dwCreationFlags: zigWin.DWORD,
    lpThreadId: zigWin.LPDWORD,
) callconv(.winapi) zigWin.HANDLE;

extern "kernel32" fn LoadLibraryW(lpLibFileName: zigWin.LPCWSTR) callconv(.winapi) zigWin.HMODULE;
