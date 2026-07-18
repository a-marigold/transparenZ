const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");

pub const UI_DLL_FILE_NAME = "ui.dll";

// const ACCENT_POLICY: win.ACCENT_POLICY = .{
//     .AccentState = .ACCENT_ENABLE_ACRYLICBLURBEHIND,
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
/// Example of how event names combined:
///
/// `UiDllCode.EVENT_PREFIX` ++ `UiDllCode.ErrorName` == `"Local\\\\SomePrefix1"`.
pub const UiDllCode = enum(u32) {
    Success,
    GetExeDirFailed,

    /// See `UiDllCode`.
    pub const EVENT_PREFIX = "Local\\\\tZyC";

    /// Desired access of events created from `UiDllCode` enum.
    pub const EVENT_DESIRED_ACCESS = win.SYNCHRONIZE | win.EVENT_MODIFY_STATE;
};

pub const errors = struct {
    // main process errors
    pub const OPEN_EXPLORER_FAIL = "Failed to open 'explorer.exe' process.";
    pub const GET_EXE_PATH_FAIL = "Failed to get path to the 'transparenZ' executable.";

    pub const ALLOC_UI_DLL_FILE_NAME_FAIL = "Failed to allocate '" ++ UI_DLL_FILE_NAME ++ "' string in explorer.exe.";

    pub const WAIT_UI_DLL_TIMEOUT = "Waiting time of '" ++ UI_DLL_FILE_NAME ++ "' completion expired.";
    pub const WAIT_UI_DLL_FAIL = "Waiting for '" ++ UI_DLL_FILE_NAME ++ "' completion failed.";

    // `ui.dll` errors
    pub const UI_DLL_GET_EXE_PATH_FAIL = "Failed to get path to the '" ++ UI_DLL_FILE_NAME ++ "' executable.";
};
