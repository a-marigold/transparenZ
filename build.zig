const std = @import("std");

pub fn build(b: *const std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const allocator = b.allocator;

    const installStep = b.getInstallStep();

    const exe = b.addExecutable(.{
        .name = "transparenZ",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .single_threaded = true,
            .strip = true,
            .error_tracing = false,
            .omit_frame_pointer = true,
            .unwind_tables = false,
            .stack_check = false,
        }),
    });
    b.installArtifact(exe);

    const uiDll = b.addLibrary(.{
        .name = "ui",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = .optimize,
            .strip = true,
            .error_tracing = false,
            .omit_frame_pointer = true,
            .unwind_tables = false,
            .stack_check = false,
        }),
        .linkage = .dynamic,
    });
    b.installArtifact(uiDll);

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
