const std = @import("std");
const zigWin = std.os.windows;

const win = @import("win.zig");

const utils = @import("utils.zig");

pub const UI_DLL_FILE_NAME = "ui.dll";

// const ACCENT_POLICY: win.ACCENT_POLICY = .{
//     .AccentState = .ACCENT_ENABLE_ACRYLICBLURBEHIND,
//
//     .AccentFlags = 0,
//     .GradientColor = 0x010000,

//     .AnimationId = 0,
// };
// pub const TASKBAR_COMPOSITION_ATTRIB_DATA: win.WINDOWCOMPOSITIONATTRIBDATA = .{
//     .Attrib = .WCA_ACCENT_POLICY,
//     .pvData = &ACCENT_POLICY,
//     .cbData = @sizeOf(win.ACCENT_POLICY),
// };

/// Used to share successfull completion of taskbar styling or an error from `ui.dll` to main process.
///
/// Main process creates events via `CreateEventExW`
/// with prefix `UiDllCode.EVENT_PREFIX` for every variant of this enumiration.
///
/// When taskbar is succesfully styled or an error appears,
/// `ui.dll` calls `SetEvent` with corresponding event name.
///
/// `ui.dll` MUST set `UiDllCode.Success` if it ended successfully.
///
/// Example of how event names combined:
///
/// `UiDllCode.EVENT_PREFIX` ++ `UiDllCode.ErrorName` == `"Local\\\\SomePrefix1"`.
pub const UiDllCode = enum(u32) {
    Success,

    GetExeDirFail,
    InitXamlDiagsFail,

    /// See `UiDllCode`.
    pub const EVENT_NAME_PREFIX = "Local\\\\tZyC";

    /// Desired access of events created from `UiDllCode` enum.
    pub const EVENT_DESIRED_ACCESS = win.SYNCHRONIZE | win.EVENT_MODIFY_STATE;
};

/// Messages of errors appearing only in the main process.
pub const MainErrors = struct {
    pub const OPEN_EXPLORER_FAIL = "Failed to open 'explorer.exe' process.";
    pub const GET_EXE_PATH_FAIL = "Failed to get path to the 'transparenZ' executable.";

    pub const ALLOC_UI_DLL_FILE_NAME_FAIL = "Failed to allocate '" ++ UI_DLL_FILE_NAME ++ "' string in explorer.exe.";

    pub const WAIT_UI_DLL_FAIL = "Waiting for '" ++ UI_DLL_FILE_NAME ++ "' completion failed.";

    pub const UI_DLL_CODE_EVENT_CREATION_FAILED = "Failed to create event for '" ++ UI_DLL_FILE_NAME ++ "' code.";
};

/// Array with error messages appearing only in `ui.dll`.
///
/// Indexes of this array are codes of `UiDllCode`.
///
/// That is, to access, for example, message of `InitXamlDiagsFail`, do `UI_DLL_ERRORS[UiDllCode.InitXamlDiagsFail]`.
///
/// `UI_DLL_ERRORS[UiDllCode.Success]` causes undefined behavior 'cause `UiDllCode.Success` index of this array is not filled.
pub const UI_DLL_ERRORS = block: {
    var errors: [@typeInfo(UiDllCode).@"enum".field_values.len][:0]const u8 = undefined;

    errors[UiDllCode.GetExeDirFail] = "Failed to get path to the '" ++ UI_DLL_FILE_NAME ++ "' executable.";

    errors[UiDllCode.InitXamlDiagsFail] = "Failed to initialize xaml diagnostics in '" ++ UI_DLL_FILE_NAME ++ "'.";

    break :block errors;
};

/// Contains numbers from 0 to `quantity` converted to UTF-16.
///
/// Used not to convert numbers to UTF-16 in runtime.
///
/// `quantity` is increased on demand.
/// That is, when a part of application using this array needs more numbers, the array is expanded.
///
/// For example, to convert 16 to UTF-16, use `UTF16_NUMBERS[16]`.
pub const UTF16_NUMBERS = block: {
    const quantity = 20;

    var numbers: [quantity][]const u16 = undefined;
    var number = 0;
    while (number < quantity) : (number += 1) {
        numbers[number] = std.fmt.comptimePrint("{d}", .{number});
    }
    break :block numbers;
};
