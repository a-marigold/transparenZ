//! Shared utils used both in the `ui.dll` and the main.

const std = @import("std");
const unicode = std.unicode;
const zigWin = std.os.windows;

const win = @import("win.zig");

const constants = @import("constants.zig");

pub const AbsPath = struct {
    /// `buffer.len` does not represent the real length of path.
    ///
    /// Use `AbsPath.len` instead.
    ///
    /// Everything that is after `AbsPath.buffer[AbsPath.len - 1]` is a stack garbage.
    buffer: [zigWin.MAX_PATH:0]zigWin.WCHAR,

    /// Length of path in `buffer`.
    len: zigWin.DWORD,
};

/// Returns `AbsPath` struct or `null` in case of error.
///
/// Returned `len` **doesn't** include trailing backslash (`\`) of path char in `buffer`.
///
/// (it means `result.buffer[result.len - 1]` **doesn't** retrieves `\`).
pub fn getExeDirPath() ?AbsPath {
    var buffer: @FieldType(AbsPath, "buffer") = undefined;

    const absPathLen = win.GetModuleFileNameW(null, &buffer, buffer.len);

    if (absPathLen == 0) {
        @branchHint(.cold);

        return null;
    }

    var pathIndex = absPathLen - 1;

    while (pathIndex > 0) : (pathIndex -= 1) {
        if (buffer[pathIndex] == constants.UTF16_BACK_SLASH) {
            break;
        }
    }

    return .{ .buffer = buffer, .len = pathIndex };
}

/// Mutates `exeDirPath.buffer` via copying and appending `constants.UI_DLL_FILE_NAME` there.
///
/// Also appends Null Terminator to the path and includes it in `AbsPath.len`.
///
/// Example:
///
/// After function call `exeDirPath.buffer` contains `...\somePath\ui.dll\0`, and `exeDirPath.len` is updated.
pub inline fn exeDirPathToUiDllPath(exeDirPath: *AbsPath) void {
    const uiDllPath = comptime unicode.utf8ToUtf16LeStringLiteral("\\" ++ constants.UI_DLL_FILE_NAME);

    @memcpy(exeDirPath.buffer[exeDirPath.len..], uiDllPath);

    exeDirPath.len += uiDllPath.len + 1; // Add 1 for Null Terminator
    exeDirPath.buffer[exeDirPath.len - 1] = 0; // Add Null Terminator
}
