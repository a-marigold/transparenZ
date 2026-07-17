const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");

pub const UI_DLL_FILE_NAME = "ui.dll";

pub const UI_DLL_INIT_FUNC_NAME = "init";

pub const UTF16_BACK_SLASH: zigWin.WCHAR = unicode.utf8ToUtf16LeStringLiteral("\\")[0];

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
/// Only success is zero, any non-zero code means an error.
///
/// Main process creates events via `CreateEventExW`
/// with prefix `UiDllErrorEventPrefix` for every variant of this enumiration.
///
/// When taskbar is succesfully styled or an error appears,
/// `ui.dll` calls `SetEvent` with corresponding event name.
///
/// Example of how event names combined:
///
/// `UiDllErrorEventPrefix` ++ `UiDllCode.ErrorName` == `"Local\\\\SomePrefix1"`.
pub const UiDllCode = enum(u32) {
    Success = 0,
    GetExeDirFailed,
};

/// See `UiDllErrorEvent`.
pub const UI_DLL_CODE_EVENT_PREFIX = "Local\\\\tZyE";
