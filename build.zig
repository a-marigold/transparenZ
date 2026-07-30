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
const INSTALL_ARTIFACT_OPTIONS: Build.Step.InstallArtifact.Options = .{
    .dest_dir = .{ .override = .prefix },
};

const MAIN_BIN_NAME = "transparenZ";
const UI_DLL_BIN_NAME = std.fs.path.stem(constants.UI_DLL_FILE_NAME);

pub fn build(b: *Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    const isRelease = b.option(
        bool,
        "release",
        \\ Whether to apply release logic:
        \\ - compilation for every target ('-Dtarget' is ignored).
        \\ - compression to 'tar.gz'.
        \\ Flag '-Doptimize' still defines optimization level.
        ,
    ) orelse false;

    if (isRelease) {
        inline for (TARGETS) |target| {
            try buildTransparenZ(
                b,
                b.resolveTargetQuery(target),
                optimize,
                true,
            );
        }
    } else {
        try buildTransparenZ(
            b,
            b.standardTargetOptions(.{}),
            optimize,
            false,
        );
    }
}

fn buildTransparenZ(
    b: *std.Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    /// Whether to enable release logic.
    isRelease: bool,
) !void {
    const allocator = b.allocator;

    const installStep = b.getInstallStep();

    const exe = b.addExecutable(.{
        .name = MAIN_BIN_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .single_threaded = true,
            .strip = isRelease,
            .error_tracing = !isRelease,
            .omit_frame_pointer = isRelease,
            .unwind_tables = if (isRelease) .none else .sync,
        }),
    });

    installStep.dependOn(
        &b.addInstallArtifact(exe, INSTALL_ARTIFACT_OPTIONS).step,
    );

    const uiDll = b.addLibrary(.{
        .name = UI_DLL_BIN_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui_dll.zig"),
            .target = target,
            .optimize = optimize,
            .strip = true,
            .error_tracing = !isRelease,
            .omit_frame_pointer = isRelease,
            .unwind_tables = if (isRelease) .none else null,
        }),

        .linkage = .dynamic,
    });

    installStep.dependOn(
        &b.addInstallArtifact(uiDll, INSTALL_ARTIFACT_OPTIONS).step,
    );

    if (isRelease) {
        const runTar = b.addSystemCommand(&.{
            "tar",
            "-cf",
            try allocator.print(
                "transparenZ-{s}.tar",
                .{try target.query.zigTriple(allocator)},
            ),
            MAIN_BIN_NAME ++ ".exe",
            UI_DLL_BIN_NAME ++ ".dll",
        });

        runTar.setCwd(b.path("zig-out"));

        installStep.dependOn(&runTar.step);
    }
}
