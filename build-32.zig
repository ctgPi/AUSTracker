const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86,
            .os_tag = .windows,
            .abi = .msvc,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    const SDL2_version = "2.28.0";
    const SDL2_ttf_version = "2.20.2";
    const SDL2_image_version = "2.6.3";
    const platform_dir = "/x86";

    const exe = b.addExecutable(.{
        .name = "AUSTracker",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.subsystem = .Windows;

    exe.addIncludePath("SDL2-" ++ SDL2_version ++ "/include");
    exe.addLibraryPath("SDL2-" ++ SDL2_version ++ "/lib" ++ platform_dir);
    b.installBinFile("SDL2-" ++ SDL2_version ++ "/lib" ++ platform_dir ++ "/SDL2.dll", "SDL2.dll");
    exe.linkSystemLibrary("SDL2");

    exe.addIncludePath("SDL2_ttf-" ++ SDL2_ttf_version ++ "/include");
    exe.addLibraryPath("SDL2_ttf-" ++ SDL2_ttf_version ++ "/lib" ++ platform_dir);
    b.installBinFile("SDL2_ttf-" ++ SDL2_ttf_version ++ "/lib" ++ platform_dir ++ "/SDL2_ttf.dll", "SDL2_ttf.dll");
    exe.linkSystemLibrary("SDL2_ttf");

    exe.addIncludePath("SDL2_image-" ++ SDL2_image_version ++ "/include");
    exe.addLibraryPath("SDL2_image-" ++ SDL2_image_version ++ "/lib" ++ platform_dir);
    b.installBinFile("SDL2_image-" ++ SDL2_image_version ++ "/lib" ++ platform_dir ++ "/SDL2_image.dll", "SDL2_image.dll");
    exe.linkSystemLibrary("SDL2_image");

    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("rpcrt4");
    exe.linkSystemLibrary("usp10");

    exe.linkLibC();
    b.installArtifact(exe);
}
