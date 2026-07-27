const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");

const utils = @import("utils.zig");

pub const UI_DLL_FILE_NAME = "ui.dll";

/// The windows class name of task bar.
pub const TASKBAR_CLASS_NAME = "Shell_TrayWnd";

pub const WINDOWS_UI_XAML_DLL_NAME = "Windows.UI.Xaml.dll";

pub const TaskbarElementNames = struct {
    pub const BACKGROUND_FILL = unicode.utf8ToUtf16LeStringLiteral("BackgroundFill");

    pub const BACKGROUND_STROKE = unicode.utf8ToUtf16LeStringLiteral("BackgroundStroke");
};

/// Used to share successfull completion of taskbar styling or an error from `ui.dll` to main process.
///
/// Main process creates events via `CreateEventExW`
/// with prefix `UiDllCode.EVENT_NAME_PREFIX` for every variant of this enumiration.
///
/// When taskbar is succesfully styled or an error appears,
/// `ui.dll` calls `SetEvent` with corresponding event name.
///
/// `ui.dll` **must** set `UiDllCode.Success` if it ended successfully.
///
/// Example of how event names combined:
///
/// `UiDllCode.EVENT_PREFIX` ++ `UiDllCode.ErrorName` == `"Local\\\\SomePrefix1"`.
pub const UiDllCode = enum(usize) { // `usize` 'cause it is used as index of `UI_DLL_ERRORS` array
    Success,

    GetExePathFail,
    InitXamlDiagsFail,
    RegisterTreeServiceCallbackFail,
    GetIShapeInCallbackFail,
    IXamlDiagnosticsNullInCallback,

    /// See `UiDllCode`.
    pub const EVENT_NAME_PREFIX = "Local\\\\tZyC";

    /// Desired access of events created from `UiDllCode` enum.
    pub const EVENT_DESIRED_ACCESS = win.SYNCHRONIZE | win.EVENT_MODIFY_STATE;
};

/// Error messages of main process and `ui.dll`.
///
/// Main errors are in a struct 'cause they are accessed directly at known positions in code, but `ui.dll` errors are in an array 'cause they are accessed by dynamic indexes (see how `main` handles them).
pub const Errors = struct {
    /// Messages of errors appearing only in the main process.
    pub const Main = struct {
        pub const OPEN_EXPLORER_FAIL =
            "Failed to open 'explorer.exe' process.";

        pub const GET_EXE_PATH_FAIL =
            "Failed to get path to the 'transparenZ' executable.";

        pub const ALLOC_UI_DLL_FILE_NAME_FAIL =
            "Failed to allocate '" ++ UI_DLL_FILE_NAME ++ "' path string in explorer.exe.";

        pub const CREATE_UI_DLL_CODE_EVENT_FAIL =
            "Failed to create event for '" ++ UI_DLL_FILE_NAME ++ "' code.";

        pub const WAIT_UI_DLL_CODE_EVENTS_FAIL =
            "Waiting for '" ++ UI_DLL_FILE_NAME ++ "' completion failed.";
    };

    /// Array with error messages appearing only in `ui.dll`.
    ///
    /// Indexes of this array are codes of `UiDllCode`.
    ///
    /// That is, to access, for example, message of `InitXamlDiagsFail`, do `UI_DLL_ERRORS[UiDllCode.InitXamlDiagsFail]`.
    ///
    /// `UI_DLL_ERRORS[UiDllCode.Success]` causes undefined behavior 'cause `UiDllCode.Success` index of this array is not filled.
    pub const UI_DLL = block: {
        var errors: [@typeInfo(UiDllCode).@"enum".field_values.len][:0]const u8 = undefined;

        errors[@intFromEnum(UiDllCode.GetExePathFail)] =
            "Failed to get path to the '" ++ UI_DLL_FILE_NAME ++ "' executable.";

        errors[@intFromEnum(UiDllCode.InitXamlDiagsFail)] =
            "Failed to initialize XAML diagnostics.";

        errors[@intFromEnum(UiDllCode.RegisterTreeServiceCallbackFail)] =
            "Failed to register tree service callback.";

        errors[@intFromEnum(UiDllCode.GetIShapeInCallbackFail)] =
            "Failed to get 'IShape' interface inside tree service callback.";

        errors[@intFromEnum(UiDllCode.IXamlDiagnosticsNullInCallback)] =
            "'IXamlDiagnostics' unexpectedly equals 'null' in tree service callback.";

        break :block errors;
    };
};

/// Contains numbers from 0 to `quantity` converted to UTF-16.
///
/// Used not to convert numbers to UTF-16 in runtime.
///
/// `quantity` is increased on demand.
///
/// That is, when a part of application using this array needs more numbers, it exapnds the array.
///
/// For example, to convert 16 to UTF-16, use `UTF16_NUMBERS[16]`.
pub const UTF16_NUMBERS = block: {
    @setEvalBranchQuota(100_000);

    const quantity = 16;

    var numbers: [quantity][:0]const u16 = undefined;

    var number = 0;

    while (number < quantity) : (number += 1) {
        const utf8Number = std.fmt.comptimePrint("{d}", .{number});

        const utf16Number: [utf8Number.len:0]u16 = numberBlock: {
            var result: [utf8Number.len:0]u16 = undefined;

            _ = unicode.utf8ToUtf16Le(&result, utf8Number) catch |err| {
                @compileError(err);
            };

            break :numberBlock result;
        };

        numbers[number] = &utf16Number;
    }
    break :block numbers;
};
