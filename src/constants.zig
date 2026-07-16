const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");

pub const UI_DLL_FILE_NAME = "ui.dll";

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

/// Enumiration of errors that appear in the `ui.dll`.
///
/// Error is allocated in `explorer.exe`, written by `ui.dll` and read in the main process.
pub const UiDllError = enum(u32) {
    GetExeDirFailed,
};
