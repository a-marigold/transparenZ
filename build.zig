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
pub fn build(b: *const Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const release = b.option(
        bool,
        "release",
        \\ Whether to apply release logic:
        \\ - compilation for every target ('-Dtarget' is ignored).
        \\ - compression to 'tar.gz'.
        \\ Flag '-Doptimize' still defines optimization level.
        ,
    );

    if (release) {
        inline for (TARGETS) |target| {
            buildTransparenZ(b, b.resolveTargetQuery(target), optimize, true);
        }
    } else {
        const target = b.standardTargetOptions(.{});
        buildTransparenZ(b, b.resolveTargetQuery(target), optimize, false);
    }
}

fn buildTransparenZ(
    b: *const std.Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    /// Whether to enable release logic.
    release: bool,
) void {
    const allocator = b.allocator;
    const installStep = b.getInstallStep();

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
            .unwind_tables = !release,
            .stack_check = !release,
        }),
    });
    b.installArtifact(exe);

    const uiDll = b.addLibrary(.{
        .name = constants.UI_DLL_FILE_NAME,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = .optimize,
            .strip = true,
            .error_tracing = !release,
            .omit_frame_pointer = release,
            .unwind_tables = !release,
            .stack_check = !release,
        }),
        .linkage = .dynamic,
    });
    b.installArtifact(uiDll);

    if (release) {
        const runTar = b.addSystemCommand(&.{
            "tar",
            "-caf",
            try std.fmt.allocPrint(
                allocator,
                "transparenZ-{}",
                .{try target.query.zigTriple(allocator)},
            ),
            "-C",
            "zig-out",
            ".",
        });
        runTar.step.dependOn(installStep);
    }
}
