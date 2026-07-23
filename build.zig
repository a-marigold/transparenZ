const std = @import("std");
const Build = std.Build;

const constants = @import("src/constants.zig");

const TARGETS = [_]std.Target.Query{
    .{
        .cpu_arch = .aarch64,
        .os_tag = .windows,
    },
    .{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
    },
};
pub fn build(b: *Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    const release = b.option(
        bool,
        "release",
        \\ Whether to apply release logic:
        \\ - compilation for every target ('-Dtarget' is ignored).
        \\ - compression to 'tar.gz'.
        \\ Flag '-Doptimize' still defines optimization level.
        ,
    ) orelse false;

    if (release) {
        inline for (TARGETS) |target| {
            try buildTransparenZ(b, b.resolveTargetQuery(target), optimize, true);
        }
    } else {
        try buildTransparenZ(b, b.standardTargetOptions(.{}), optimize, false);
    }
}

fn buildTransparenZ(
    b: *std.Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    /// Whether to enable release logic.
    release: bool,
) !void {
    const allocator = b.allocator;
    const installStep = b.getInstallStep();

    // const win32DepModule = b.dependency("win32", .{
    //     .target = target,
    //     .optimize = optimize,
    // }).module("win32");

    const exe = b.addExecutable(.{
        .name = "transparenZ",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .single_threaded = true,
            .strip = release,
            .error_tracing = !release,
            .omit_frame_pointer = release,
            .unwind_tables = if (release) .none else null,
        }),
    });

    // exe.root_module.addImport("win32", win32DepModule);

    b.installArtifact(exe);

    const uiDll = b.addLibrary(.{
        .name = constants.UI_DLL_FILE_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui_dll.zig"),
            .target = target,
            .optimize = optimize,
            .strip = true,
            .error_tracing = !release,
            .omit_frame_pointer = release,
            .unwind_tables = if (release) .none else null,
        }),
        .linkage = .dynamic,
    });

    // exe.root_module.addImport("win32", win32DepModule);

    b.installArtifact(uiDll);

    if (release) {
        const runTar = b.addSystemCommand(&.{
            "tar",
            "-caf",
            try std.fmt.allocPrint(
                allocator,
                "transparenZ-{s}",
                .{try target.query.zigTriple(allocator)},
            ),
            "-C",
            "zig-out",
            ".",
        });

        runTar.step.dependOn(installStep);
    }
}
