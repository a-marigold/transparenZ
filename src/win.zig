//! Definitions of `win32` types used in `transparenZ`.
//!
//! Contains only types that are missing in `std.os.windows`.

pub const zigWin = @import("std").os.windows;

/// The windows class name of task bar.
pub const TASK_BAR_CLASS_NAME = "Shell_TrayWnd";

pub const WINDOWS_UI_XAML_DLL_NAME = "Windows.UI.Xaml.dll";

pub const LPDWORD = *zigWin.DWORD;

pub const BOOL = c_int;

pub const FALSE: BOOL = 0;
pub const TRUE: BOOL = 1;

pub const WPARAM = zigWin.UINT;
pub const LPARAM = WPARAM;

pub const STD_ERROR_HANDLE: zigWin.DWORD = @bitCast(@as(i32, -12));

pub const PROCESS_CREATE_THREAD = 0x0002;
pub const PROCESS_VM_OPERATION = 0x0008;
pub const PROCESS_VM_WRITE = 0x0020;

pub const MEM_RESERVE = 0x00002000;
pub const MEM_COMMIT = 0x00001000;

pub const PAGE_READWRITE = 0x04;

pub const DLL_PROCESS_ATTACH: zigWin.DWORD = 1;
pub const DLL_PROCESS_DETACH: zigWin.DWORD = 0;

pub const HRESULT = enum(zigWin.DWORD) {
    S_OK = 0x00000000,
    E_NOTIMPL = 0x80004001,
    E_NOINTERFACE = 0x80004002,
    E_POINTER = 0x80004003,
    E_ABORT = 0x80004004,
    E_FAIL = 0x80004005,
    E_UNEXPECTED = 0x8000FFFF,
    E_ACCESSDENIED = 0x80070005,
    E_HANDLE = 0x80070006,
    E_OUTOFMEMORY = 0x8007000E,
    E_INVALIDARG = 0x80070057,
    CLASS_E_CLASSNOTAVAILABLE = 0x80040111,
};

pub const ACCENT_STATE = enum(i32) {
    ACCENT_DISABLED = 0,
    ACCENT_ENABLE_GRADIENT = 1,
    ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
    ACCENT_ENABLE_BLURBEHIND = 3,
    ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
    ACCENT_INVALID_STATE = 5,
};

pub const ACCENT_POLICY = extern struct {
    AccentState: ACCENT_STATE,
    AccentFlags: i32,
    GradientColor: i32,
    AnimationId: i32,
};

pub const WINDOW_COMPOSITION_ATTRIB = enum(i32) {
    WCA_ACCENT_POLICY = 19,
};

pub const WINDOWCOMPOSITIONATTRIBDATA = extern struct {
    Attrib: WINDOW_COMPOSITION_ATTRIB,
    pvData: *const anyopaque,
    cbData: u32,
};

pub const LOAD_LIBRARY_SEARCH_SYSTEM32: zigWin.DWORD = 0x00000800;

pub const InitializeXamlDiagnosticsEx = fn (
    endPointName: zigWin.LPCWSTR,
    pid: zigWin.DWORD,
    wszDllXamlDiagnostics: zigWin.LPCWSTR,
    wszTAPDllName: zigWin.LPCWSTR,
    tapClsid: zigWin.CLSID,
    wszInitializationData: zigWin.LPCWSTR,
) callconv(.winapi) HRESULT;

pub const IUnknown = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *@This(), riid: *const zigWin.GUID, ppvObject: *?*anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (self: *@This()) callconv(.winapi) zigWin.ULONG,
        Release: *const fn (self: *@This()) callconv(.winapi) zigWin.ULONG,
    };
};

pub const IObjectWithSite = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        QueryInterface: IUnknown.VTable.QueryInterface,
        AddRef: IUnknown.VTable.AddRef,
        Release: IUnknown.VTable.Release,
        SetSite: *const fn (self: *@This(), pUnkSite: *const IUnknown) callconv(.winapi) HRESULT,
        GetSite: *const fn (self: *@This(), riid: *const zigWin.GUID, ppvSite: **anyopaque) callconv(.winapi) HRESULT,
    };
};

pub extern "kernel32" fn LoadLibraryExW(
    lpLibFileName: zigWin.LPCWSTR,
    hFile: zigWin.HANDLE,
    dwFlags: zigWin.DWORD,
) callconv(.winapi) zigWin.HMODULE;

pub extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) zigWin.DWORD;

pub extern "user32" fn SetWindowCompositionAttribute(
    hwnd: zigWin.HWND,
    pAttrData: *const WINDOWCOMPOSITIONATTRIBDATA,
) callconv(.winapi) BOOL;

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

pub extern "kernel32" fn CreateThread(
    lpThreadAttributes: ?*zigWin.SECURITY_ATTRIBUTES,
    dwStackSize: zigWin.SIZE_T,
    lpStartAddress: *const zigWin.THREAD_START_ROUTINE,
    lpParameter: ?zigWin.LPVOID,
    dwCreationFlags: zigWin.DWORD,
    lpThreadId: ?LPDWORD,
) callconv(.winapi) ?zigWin.HANDLE;

pub extern "kernel32" fn CreateRemoteThread(
    hProcess: zigWin.HANDLE,
    lpThreadAttributes: ?*zigWin.SECURITY_ATTRIBUTES,
    dwStackSize: zigWin.SIZE_T,
    lpStartAddress: *const zigWin.THREAD_START_ROUTINE,
    lpParameter: ?zigWin.LPVOID,
    dwCreationFlags: zigWin.DWORD,
    lpThreadId: ?LPDWORD,
) callconv(.winapi) zigWin.HANDLE;

pub extern "kernel32" fn CloseHandle(
    hObject: zigWin.HANDLE,
) callconv(.winapi) BOOL;

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
