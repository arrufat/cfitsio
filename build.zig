const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const version = std.SemanticVersion{ .major = 4, .minor = 4, .patch = 1 };

    // Custom options
    const use_curl = b.option(bool, "use_curl", "Enable remote file access") orelse false;
    const use_bz2 = b.option(bool, "use_bz2", "Enable reading bzip2-compressed files") orelse false;

    // Dependencies
    const cfitsio_dep = b.dependency("cfitsio", .{});
    const cfitsio_path = cfitsio_dep.path("");

    // Library
    const lib_step = b.step("lib", "Install library");

    const lib = b.addLibrary(.{
        .name = "cfitsio",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .version = version,
    });

    var flags_buffer: [6][]const u8 = undefined;
    var flags = std.ArrayListUnmanaged([]const u8).initBuffer(&flags_buffer);
    flags.appendSliceBounded(&FLAGS) catch unreachable;
    if (target.result.cpu.arch.isX86()) {
        flags.appendSliceBounded(&.{ "-msse2", "-mssse3" }) catch unreachable;
    }
    if (use_curl) {
        lib.linkSystemLibrary("curl");
        flags.appendBounded("-DCFITSIO_HAVE_CURL") catch unreachable;
    }
    if (use_bz2) {
        lib.linkSystemLibrary("bz2");
        flags.appendBounded("-DHAVE_BZIP2=1") catch unreachable;
    }

    lib.addCSourceFiles(.{ .root = cfitsio_path, .files = &SOURCES, .flags = flags.items });
    lib.installHeadersDirectory(cfitsio_path, "", .{ .include_extensions = &HEADERS });
    lib.linkSystemLibrary2("z", .{ .preferred_link_mode = .static });
    lib.linkLibC();

    const lib_install = b.addInstallArtifact(lib, .{});
    lib_step.dependOn(&lib_install.step);
    b.default_step.dependOn(lib_step);

    // Module
    const module = b.addModule("cfitsio", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/lib.zig"),
    });
    module.linkLibrary(lib);

    // Formatting checks
    const fmt_step = b.step("fmt", "Run formatting checks");

    const fmt = b.addFmt(.{
        .paths = &.{
            "build.zig",
        },
        .check = true,
    });
    fmt_step.dependOn(&fmt.step);
    b.default_step.dependOn(fmt_step);
}

const HEADERS = .{
    "fitsio.h",
    "fitsio2.h",
    "longnam.h",
    "drvrsmem.h",
    "cfortran.h",
    "f77_wrap.h",
    "region.h",
};

const SOURCES = .{
    "buffers.c",
    "cfileio.c",
    "checksum.c",
    "drvrfile.c",
    "drvrmem.c",
    "drvrnet.c",
    "drvrsmem.c",
    "editcol.c",
    "edithdu.c",
    "eval_l.c",
    "eval_y.c",
    "eval_f.c",
    "fitscore.c",
    "getcol.c",
    "getcolb.c",
    "getcold.c",
    "getcole.c",
    "getcoli.c",
    "getcolj.c",
    "getcolk.c",
    "getcoll.c",
    "getcols.c",
    "getcolsb.c",
    "getcoluk.c",
    "getcolui.c",
    "getcoluj.c",
    "getkey.c",
    "group.c",
    "grparser.c",
    "histo.c",
    "iraffits.c",
    "modkey.c",
    "putcol.c",
    "putcolb.c",
    "putcold.c",
    "putcole.c",
    "putcoli.c",
    "putcolj.c",
    "putcolk.c",
    "putcoluk.c",
    "putcoll.c",
    "putcols.c",
    "putcolsb.c",
    "putcolu.c",
    "putcolui.c",
    "putcoluj.c",
    "putkey.c",
    "region.c",
    "scalnull.c",
    "swapproc.c",
    "wcssub.c",
    "wcsutil.c",
    "imcompress.c",
    "quantize.c",
    "ricecomp.c",
    "pliocomp.c",
    "fits_hcompress.c",
    "fits_hdecompress.c",
    "simplerng.c",
    "zcompress.c",
    "zuncompress.c",
};

const FLAGS = .{
    "-std=gnu89",
    "-D_REENTRANT",
    "-fsanitize=undefined",
    "-fsanitize-trap=undefined",
};
