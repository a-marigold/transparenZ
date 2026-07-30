//! Definitions of `win32` types used in `transparenZ`.
//!
//! Contains only types that are missing in `std.os.windows`.

pub const zigWin = @import("std").os.windows;

pub const LPDWORD = *zigWin.DWORD;

pub const BOOL = c_int;

pub const FALSE: BOOL = 0;
pub const TRUE: BOOL = 1;

pub const INFINITE: zigWin.DWORD = @bitCast(@as(i32, -1));

pub const WPARAM = zigWin.UINT;
pub const LPARAM = WPARAM;

pub const STD_ERROR_HANDLE: zigWin.DWORD = @bitCast(@as(i32, -12));

pub const INVALID_HANDLE_VALUE: *opaque {} = @ptrFromInt(0xFFFFFFFFFFFFFFFF);

pub const PROCESS_CREATE_THREAD = 0x0002;
pub const PROCESS_VM_OPERATION = 0x0008;
pub const PROCESS_VM_WRITE = 0x0020;

pub const MEM_RESERVE = 0x00002000;
pub const MEM_COMMIT = 0x00001000;
pub const PAGE_READWRITE = 0x04;

pub const DLL_PROCESS_ATTACH: zigWin.DWORD = 1;
pub const DLL_PROCESS_DETACH: zigWin.DWORD = 0;

pub const MEM_RELEASE = 0x00008000;

pub const WM_CLOSE: zigWin.UINT = 0x0010;

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

pub const WAIT_OBJECT_0: zigWin.DWORD = 0;
pub const WAIT_TIMEOUT: zigWin.DWORD = 0x00000102;
pub const WAIT_FAILED: zigWin.DWORD = 0xFFFFFFFF;

pub const MAXIMUM_WAIT_OBJECTS: zigWin.DWORD = 64;

pub const LOAD_LIBRARY_SEARCH_SYSTEM32: zigWin.DWORD = 0x00000800;
pub const LOAD_LIBRARY_AS_DATAFILE: zigWin.DWORD = 0x00000002;

pub const SYNCHRONIZE: zigWin.DWORD = 0x00100000;

pub const EVENT_MODIFY_STATE: zigWin.DWORD = 0x0002;

pub const InstanceHandle = u32;

pub const IUnknown = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *anyopaque, riid: *const zigWin.GUID, ppvObject: *?*anyopaque) callconv(.winapi) HRESULT,
        AddRef: *const fn (self: *anyopaque) callconv(.winapi) zigWin.ULONG,
        Release: *const fn (self: *anyopaque) callconv(.winapi) zigWin.ULONG,
    };
};

pub const IID_IUnknown: zigWin.GUID = .{
    .Data1 = 0x00000000,
    .Data2 = 0x0000,
    .Data3 = 0x0000,
    .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 },
};

/// Not a part of winapi.
///
/// Many interfaces declared in `transparenZ` are inherited from `IUnknown`,
/// they don't need all the methods of `IUnknown`.
///
/// Contains correct no-op fns to be used in `IUnknown` not to bloat binary with identical functions.
///
/// Does not contain `QueryInterface` 'cause this function is always not a no-op.
pub const IUnknownNoOpMethods = struct {
    fn refManagingNoOp(self: *anyopaque) callconv(.winapi) zigWin.ULONG {
        _ = self;

        // `1` means there is one reference on this object left
        return 1;
    }

    pub const AddRef = refManagingNoOp;

    pub const Release = refManagingNoOp;
};

pub const IID_IObjectWithSite = zigWin.GUID{
    .Data1 = 0xfc4801a3,
    .Data2 = 0x2ba9,
    .Data3 = 0x11cf,
    .Data4 = .{ 0xa2, 0x29, 0x00, 0xaa, 0x00, 0x3d, 0x73, 0x52 },
};

pub const IObjectWithSite = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        QueryInterface: @FieldType(IUnknown.VTable, "QueryInterface"),
        AddRef: @FieldType(IUnknown.VTable, "AddRef"),
        Release: @FieldType(IUnknown.VTable, "Release"),
        SetSite: *const fn (self: *anyopaque, pUnkSite: *IUnknown) callconv(.winapi) HRESULT,
        GetSite: *const fn (self: *anyopaque, riid: *const zigWin.GUID, ppvSite: *?*anyopaque) callconv(.winapi) HRESULT,
    };
};
pub const IXamlDiagnostics = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        QueryInterface: @FieldType(IUnknown.VTable, "QueryInterface"),
        AddRef: @FieldType(IUnknown.VTable, "AddRef"),
        Release: @FieldType(IUnknown.VTable, "Release"),
        GetUiLayer: *anyopaque,
        GetApplication: *anyopaque,
        GetIInspectableFromHandle: *const fn (instanceHandle: InstanceHandle, ppInstance: *?*IInspectable) callconv(.winapi) HRESULT,
        GetHandleFromIInspectable: *anyopaque,
        HitTest: *anyopaque,
        RegisterInstance: *anyopaque,
        GetInitializationData: *anyopaque,
    };
};

pub const IID_IXamlDiagnostics = zigWin.GUID{
    .Data1 = 0x18c9e2b6,
    .Data2 = 0x3c43,
    .Data3 = 0x4116,
    .Data4 = .{ 0x9f, 0x2b, 0xff, 0x93, 0x5d, 0x77, 0x70, 0xd2 },
};

pub const IInspectable = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        QueryInterface: @FieldType(IUnknown.VTable, "QueryInterface"),
        AddRef: @FieldType(IUnknown.VTable, "AddRef"),
        Release: @FieldType(IUnknown.VTable, "Release"),
        GetIids: *anyopaque,
        GetRuntimeClassName: *anyopaque,
        GetTrustLevel: *anyopaque,
    };
};

pub const VisualElement = extern struct {
    Handle: InstanceHandle,
    SrcInfo: *opaque {},
    Type: zigWin.BSTR,
    Name: zigWin.BSTR,
    NumChildren: zigWin.UINT,
};

pub const VisualMutationType = enum(c_int) {
    Add = 0,
    Remove,
};

pub const IVisualTreeService = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        QueryInterface: @FieldType(IUnknown.VTable, "QueryInterface"),
        AddRef: @FieldType(IUnknown.VTable, "AddRef"),
        Release: @FieldType(IUnknown.VTable, "Release"),
        AdviseVisualTreeChange: *const fn (self: *anyopaque, pCallback: *IVisualTreeServiceCallback) callconv(.winapi) HRESULT,
        UnadviseVisualTreeChange: *anyopaque,
        GetEnums: *anyopaque,
        CreateInstance: *anyopaque,
        GetPropertyValuesChain: *anyopaque,
        SetProperty: *anyopaque,
        ClearProperty: *anyopaque,
        GetCollectionCount: *anyopaque,
        GetCollectionElements: *anyopaque,
        AddChild: *anyopaque,
        RemoveChild: *anyopaque,
        ClearChildren: *anyopaque,
    };
};

pub const IID_IVisualTreeService: zigWin.GUID = .{
    .Data1 = 0xA593B11A,
    .Data2 = 0xD17F,
    .Data3 = 0x48BB,
    .Data4 = .{ 0x8F, 0x66, 0x83, 0x91, 0x07, 0x31, 0xC8, 0xA5 },
};

pub const IVisualTreeServiceCallback = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        QueryInterface: @FieldType(IUnknown.VTable, "QueryInterface"),
        AddRef: @FieldType(IUnknown.VTable, "AddRef"),
        Release: @FieldType(IUnknown.VTable, "Release"),
        OnVisualTreeChange: *const fn (
            self: *anyopaque,
            relation: *anyopaque,
            element: VisualElement,
            mutationType: VisualMutationType,
        ) callconv(.winapi) HRESULT,
    };
};

pub const IID_IVisualTreeServiceCallback: zigWin.GUID = .{
    .Data1 = 0xAA7A8931,
    .Data2 = 0x80E4,
    .Data3 = 0x4FEC,
    .Data4 = .{ 0x8f, 0x3B, 0x55, 0x3F, 0x87, 0xB4, 0x96, 0x6E },
};

pub const IShape = struct {
    vtable: *const VTable,
    pub const VTable = struct {
        QueryInterface: @FieldType(IInspectable.VTable, "QueryInterface"),
        AddRef: @FieldType(IInspectable.VTable, "AddRef"),
        Release: @FieldType(IInspectable.VTable, "Release"),
        GetIids: @FieldType(IInspectable.VTable, "GetIids"),
        GetRuntimeClassName: @FieldType(IInspectable.VTable, "GetRuntimeClassName"),
        GetTrustLevel: @FieldType(IInspectable.VTable, "GetTrustLevel"),
        get_Fill: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_Fill: *const fn (self: *IShape, brush: ?*anyopaque) callconv(.winapi) i32,
        get_Stroke: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_Stroke: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        get_StrokeMiterLimit: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_StrokeMiterLimit: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        get_StrokeThickness: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_StrokeThickness: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        get_StrokeStartLineCap: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_StrokeStartLineCap: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        get_StrokeEndLineCap: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_StrokeEndLineCap: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        get_StrokeLineJoin: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_StrokeLineJoin: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        get_StrokeDashOffset: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_StrokeDashOffset: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        get_StrokeDashCap: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_StrokeDashCap: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        get_StrokeDashArray: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_StrokeDashArray: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        get_Stretch: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        put_Stretch: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
        get_GeometryTransform: *const fn (self: *IShape, *anyopaque) callconv(.winapi) i32,
    };
};

pub const IID_IShape: zigWin.GUID = .{
    .Data1 = 0x786F2B75,
    .Data2 = 0x9AA0,
    .Data3 = 0x454D,
    .Data4 = .{ 0xAE, 0x06, 0xA2, 0x46, 0x6E, 0x37, 0xC8, 0x32 },
};

// const ISolidColorBrush = struct {
//     vtable: *const VTable,
//     pub const VTable = struct {
//         QueryInterface: @FieldType(IInspectable.VTable, "QueryInterface"),
//         AddRef: @FieldType(IInspectable.VTable, "AddRef"),
//         Release: @FieldType(IInspectable.VTable, "Release"),
//         GetIids: @FieldType(IInspectable.VTable, "GetIids"),
//         GetRuntimeClassName: @FieldType(IInspectable.VTable, "GetRuntimeClassName"),
//         GetTrustLevel: @FieldType(IInspectable.VTable, "GetTrustLevel"),
//         get_Color: *const fn (*struct_Windows_UI_Color) callconv(.winapi) i32,
//         put_Color: *const fn (struct_Windows_UI_Color) callconv(.winapi) i32,
//     };
// };

// const struct_Windows_UI_Color = extern struct {
//     a: u8,
//     r: u8,
//     g: u8,
//     b: u8,
// };

pub const InitializeXamlDiagnosticsEx = fn (
    endPointName: zigWin.LPCWSTR,
    pid: zigWin.DWORD,
    wszDllXamlDiagnostics: ?zigWin.LPCWSTR,
    wszTAPDllName: zigWin.LPCWSTR,
    tapClsid: *const zigWin.GUID,
    wszInitializationData: ?zigWin.LPCWSTR,
) callconv(.winapi) HRESULT;

pub const LoadLibraryW = fn (
    lpLibFileName: zigWin.LPCWSTR,
) callconv(.winapi) zigWin.HMODULE;

pub extern "kernel32" fn LoadLibraryExW(
    lpLibFileName: zigWin.LPCWSTR,
    hFile: ?zigWin.HANDLE,
    dwFlags: zigWin.DWORD,
) callconv(.winapi) zigWin.HMODULE;

pub extern "kernel32" fn FreeLibraryAndExitThread(
    hLibModule: zigWin.HMODULE,
    dwExitCode: zigWin.DWORD,
) callconv(.winapi) void;

pub extern "kernel32" fn WriteFile(
    hFile: zigWin.HANDLE,
    lpBuffer: zigWin.LPCVOID,
    nNumberOfBytesToWrite: zigWin.DWORD,
    lpNumberOfBytesWritten: LPDWORD,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn GetCurrentProcess() callconv(.winapi) zigWin.HANDLE;

pub extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) zigWin.DWORD;
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

pub extern "kernel32" fn CreateFileMappingW(
    hFile: zigWin.HANDLE,
    lpFileMappingAttributes: ?*zigWin.SECURITY_ATTRIBUTES,
    flProtect: zigWin.DWORD,
    dwMaximumSizeHigh: zigWin.DWORD,
    dwMaximumSizeLow: zigWin.DWORD,
    lpName: zigWin.LPCWSTR,
) callconv(.winapi) ?zigWin.HANDLE;

pub extern "kernel32" fn OpenFileMappingW(
    dwDesiredAccess: zigWin.DWORD,
    bInheritHandle: zigWin.BOOL,
    lpName: zigWin.LPCWSTR,
) callconv(.winapi) ?zigWin.HANDLE;

pub extern "kernel32" fn MapViewOfFileEx(
    hFileMappingObject: zigWin.HANDLE,
    dwDesiredAccess: zigWin.DWORD,
    dwFileOffsetHigh: zigWin.DWORD,
    dwFileOffsetLow: zigWin.DWORD,
    dwNumberOfBytesToMap: zigWin.SIZE_T,
    lpBaseAddress: ?zigWin.LPVOID,
) callconv(.winapi) ?*anyopaque;

pub extern "kernel32" fn UnmapViewOfFileEx(
    BaseAddress: zigWin.PVOID,
    UnmapFlags: zigWin.ULONG,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn CreateEventExW(
    lpEventAttributes: ?*zigWin.SECURITY_ATTRIBUTES,
    lpName: zigWin.LPCWSTR,
    dwFlags: zigWin.DWORD,
    dwDesiredAccess: zigWin.DWORD,
) callconv(.winapi) ?zigWin.HANDLE;

pub extern "kernel32" fn OpenEventW(
    dwDesiredAccess: zigWin.DWORD,
    bInheritHandle: BOOL,
    lpName: zigWin.LPCWSTR,
) callconv(.winapi) ?zigWin.HANDLE;

pub extern "kernel32" fn SetEvent(
    hEvent: zigWin.HANDLE,
) callconv(.winapi) BOOL;

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

pub extern "kernel32" fn TerminateProcess(
    hProcess: zigWin.HANDLE,
    uExitCode: zigWin.UINT,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn WaitForSingleObject(
    hHandle: zigWin.HANDLE,
    dwMilliseconds: zigWin.DWORD,
) callconv(.winapi) zigWin.DWORD;

pub extern "kernel32" fn WaitForMultipleObjects(
    nCount: zigWin.DWORD,
    lpHandles: [*]const zigWin.HANDLE,
    bWaitAll: BOOL,
    dwMilliseconds: zigWin.DWORD,
) callconv(.winapi) zigWin.DWORD;

pub extern "kernel32" fn Sleep(dwMilliseconds: zigWin.DWORD) callconv(.winapi) void;

pub extern "kernel32" fn OutputDebugStringW(
    lpOutputString: zigWin.LPCWSTR,
) callconv(.winapi) void;

pub extern "user32" fn PostMessageW(
    hWnd: zigWin.HWND,
    Msg: zigWin.UINT,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn VirtualFreeEx(
    hProcess: zigWin.HANDLE,
    lpAddress: zigWin.LPVOID,
    dwSize: zigWin.SIZE_T,
    dwFreeType: zigWin.DWORD,
) callconv(.winapi) BOOL;
