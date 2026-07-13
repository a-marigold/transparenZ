const std = @import("std");

const unicode = std.unicode;

const zigWin = std.os.windows;

pub const UI_DLL_FILE_NAME = "ui.dll";

pub const UTF16_BACK_SLASH: zigWin.WCHAR = unicode.utf8ToUtf16LeStringLiteral("\\")[0];
