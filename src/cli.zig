const builtin = @import("builtin");
const std = @import("std");

const args = @import("args");
const drivercon = @import("drivercon");
const serial = @import("serial");
const command = @import("cli/command.zig");

pub var port: ?std.fs.File = null;
pub var help: bool = false;
pub var timeout: usize = 100;

const Options = struct {
    port: ?[]const u8 = null,
    /// Serial communication reponse timeout in milliseconds.
    timeout: usize = 100,
    help: bool = false,

    pub const shorthands = .{
        .p = "port",
        .t = "timeout",
        .h = "help",
    };

    pub const meta = .{
        .full_text = "PMF Smart Driver connection utility",
        .usage_summary = "[--port] [--timeout] <command>",

        .option_docs = .{
            .help = "command usage guidance",
            .port = "COM port to use for driver connection",
            .timeout = "timeout for message response",
        },
    };
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const options = args.parseWithVerbForCurrentProcess(
        Options,
        union(enum) {
            @"port.detect": command.port.detect,
            @"port.list": command.port.list,
            @"port.ping": command.port.ping,
        },
        allocator,
        .print,
    ) catch return;

    const stdout = std.io.getStdOut().writer();

    var port_name: ?[]const u8 = null;
    inline for (std.meta.fields(@TypeOf(options.options))) |fld| {
        if (comptime std.mem.eql(u8, "help", fld.name)) {
            help = @field(options.options, fld.name);
        }
        if (comptime std.mem.eql(u8, "timeout", fld.name)) {
            timeout = @field(options.options, fld.name);
        }
        if (comptime std.mem.eql(u8, "port", fld.name)) {
            port_name = @field(options.options, fld.name);
        }
    }

    if (port_name) |name| {
        if (!help and options.verb != null) {
            var port_iterator = try serial.list();
            defer port_iterator.deinit();

            while (try port_iterator.next()) |_port| {
                if (comptime builtin.os.tag == .linux) {
                    if (_port.display_name.len < "/dev/ttyUSBX".len) {
                        continue;
                    }
                    if (!std.mem.eql(
                        u8,
                        "/dev/ttyUSB",
                        _port.display_name[0.."/dev/ttyUSB".len],
                    )) {
                        continue;
                    }
                }
                if (!std.mem.eql(u8, name, _port.display_name)) {
                    continue;
                }
                port = try std.fs.cwd().openFile(_port.file_name, .{
                    .mode = .read_write,
                });
                break;
            } else {
                std.log.err("No COM port found with name: {s}\n", .{name});
            }
        }
    }

    if (options.verb) |verb| switch (verb) {
        inline else => |cmd| try cmd.execute(),
    } else {
        try args.printHelp(Options, "drivercon", stdout);
        // TODO: Print a list of commands
    }
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
