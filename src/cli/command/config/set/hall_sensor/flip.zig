const std = @import("std");
const command = @import("../../../../command.zig");
const cli = @import("../../../../../cli.zig");
const args = @import("args");
const drivercom = @import("drivercom");
const yaml = @import("yaml");

file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Set hall sensor flip.",
    .usage_summary = "[--file] <axis> <true/false>",

    .option_docs = .{
        .file = "set hall sensor flip in configuration file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.set.hall_sensor.flip",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null and self.file == null) {
        std.log.err("serial port or file must be provided", .{});
        return;
    }

    if (cli.positionals.len != 2) {
        std.log.err("axis and flip true/false must be provided", .{});
        return;
    }

    var axes_buf: [3]u16 = undefined;
    const axes = try command.parseAxis(cli.positionals[0], &axes_buf);

    var flip: bool = false;
    if (cli.positionals[1].len == 1) {
        if (cli.positionals[1][0] == 't') {
            flip = true;
        } else if (cli.positionals[1][0] == 'f') {
            flip = false;
        } else {
            std.log.err("{c} is not t or f", .{cli.positionals[1][0]});
            return;
        }
    } else {
        if (std.ascii.eqlIgnoreCase("true", cli.positionals[1])) {
            flip = true;
        } else if (std.ascii.eqlIgnoreCase("false", cli.positionals[1])) {
            flip = false;
        } else {
            std.log.err(
                "{s} is not true or false",
                .{cli.positionals[1]},
            );
        }
    }

    if (self.file) |name| {
        var file = try std.fs.cwd().openFile(name, .{ .mode = .read_write });
        defer file.close();

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const file_str = try file.readToEndAlloc(allocator, 1_024_000_000);
        defer allocator.free(file_str);
        var untyped = try yaml.Yaml.load(
            allocator,
            file_str,
        );
        defer untyped.deinit();
        var config = try untyped.parse(drivercom.Config);

        for (axes) |axis_index| {
            switch (axis_index) {
                0 => config.flags.flip_sensors.axis1 = if (flip) 1 else 0,
                1 => config.flags.flip_sensors.axis2 = if (flip) 1 else 0,
                2 => config.flags.flip_sensors.axis3 = if (flip) 1 else 0,
                else => unreachable,
            }
        }

        try file.seekTo(0);
        try yaml.stringify(allocator, config, file.writer());
    }

    if (cli.port) |_| {
        var flags: drivercom.Config.SystemFlags = undefined;

        var sequence: u16 = 0;
        var msg = drivercom.Message.init(.get_system_flags, sequence, {});
        try command.sendMessage(&msg);
        const req = try command.readMessage();
        if (req.kind == .set_system_flags and req.sequence == sequence) {
            sequence += 1;
            const payload = req.payload(.set_system_flags);
            flags = payload.flags;
        } else {
            std.log.err("received invalid response: {any}", .{req});
            return error.CommunicationFailure;
        }

        for (axes) |axis_index| {
            switch (axis_index) {
                0 => flags.flip_sensors.axis1 = if (flip) 1 else 0,
                1 => flags.flip_sensors.axis2 = if (flip) 1 else 0,
                2 => flags.flip_sensors.axis3 = if (flip) 1 else 0,
                else => unreachable,
            }
        }

        msg = drivercom.Message.init(.set_system_flags, sequence, .{
            .flags = flags,
        });
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(.save_config, sequence, {});
        try command.sendMessage(&msg);
    }
}
