pub const id = @import("set/id.zig");
pub const neighbor = @import("set/neighbor.zig");
pub const calibration_magnet_length =
    @import("set/calibration_magnet_length.zig");
pub const gain = @import("set/gain.zig");
pub const hall_sensor = @import("set/hall_sensor.zig");

const std = @import("std");
const cli = @import("../../../cli.zig");
const command = @import("../../command.zig");
const args = @import("args");
const drivercom = @import("drivercom");

file: ?[]const u8 = null,

pub const shorthands = .{
    .f = "file",
};

pub const meta = .{
    .full_text = "Set driver configuration.",
    .usage_summary = "[--file]",

    .option_docs = .{
        .file = "set driver configuration from file",
    },
};

pub fn help(_: @This()) !void {
    const stdout = std.io.getStdOut().writer();
    try args.printHelp(
        @This(),
        "drivercom [--port] [--timeout] config.set",
        stdout,
    );
}

pub fn execute(self: @This()) !void {
    if (cli.port == null) {
        std.log.err("serial port must be provided", .{});
        return;
    }

    const file = try std.fs.cwd().openFile(self.file orelse {
        std.log.err("file must be provided", .{});
        return;
    }, .{});
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_str = try file.readToEndAlloc(allocator, 1_024_000_000);
    defer allocator.free(file_str);
    var untyped = try std.json.parseFromSlice(
        drivercom.Config,
        allocator,
        file_str,
        .{},
    );
    defer untyped.deinit();
    const config = untyped.value;

    var sequence: u16 = 0;
    var msg = drivercom.Message.init(
        .set_id_station,
        sequence,
        .{ .id = config.id, .station = config.station_id },
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_system_flags,
        sequence,
        .{ .flags = config.flags },
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_magnet,
        sequence,
        .{ .pitch = config.magnet.pitch, .length = config.magnet.length },
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_vehicle_mass,
        sequence,
        config.vehicle_mass,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_angle_offset,
        sequence,
        config.mechanical_angle_offset,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_angle_offset,
        sequence,
        config.mechanical_angle_offset,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_axis_length,
        sequence,
        .{
            .axis_length = config.axis_length,
            .motor_length = config.motor.length,
        },
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_calibrated_home,
        sequence,
        config.calibrated_home_position,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_total_axes,
        sequence,
        config.total_axes,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_warmup_voltage,
        sequence,
        config.warmup_voltage_reference,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_calibration_magnet_length,
        sequence,
        .{
            .backward = config.calibration_magnet_length.backward,
            .forward = config.calibration_magnet_length.forward,
        },
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_voltage_target,
        sequence,
        config.vdc.target,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_voltage_limits,
        sequence,
        .{
            .lower = config.vdc.limit.lower,
            .upper = config.vdc.limit.upper,
        },
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_max_current,
        sequence,
        config.motor.max_current,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(
        .set_continuous_current,
        sequence,
        config.motor.continuous_current,
    );
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(.set_rs, sequence, config.motor.rs);
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(.set_ls, sequence, config.motor.ls);
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(.set_kf, sequence, config.motor.kf);
    try command.sendMessage(&msg);

    sequence += 1;
    msg = drivercom.Message.init(.set_kbm, sequence, config.motor.kbm);
    try command.sendMessage(&msg);

    for (0..drivercom.Config.MAX_AXES) |_i| {
        const i: u16 = @intCast(_i);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_current_gain_p,
            sequence,
            .{ .axis = i, .p = config.axes[i].current_gain.p },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_current_gain_i,
            sequence,
            .{ .axis = i, .i = config.axes[i].current_gain.i },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_current_gain_denominator,
            sequence,
            .{
                .axis = i,
                .denominator = config.axes[i].current_gain.denominator,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_velocity_gain_p,
            sequence,
            .{ .axis = i, .p = config.axes[i].velocity_gain.p },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_velocity_gain_i,
            sequence,
            .{ .axis = i, .i = config.axes[i].velocity_gain.i },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_velocity_gain_denominator,
            sequence,
            .{
                .axis = i,
                .denominator = config.axes[i].velocity_gain.denominator,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_velocity_gain_denominator_pi,
            sequence,
            .{
                .axis = i,
                .denominator = config.axes[i].velocity_gain.denominator_pi,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_position_gain_p,
            sequence,
            .{ .axis = i, .p = config.axes[i].position_gain.p },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_position_gain_denominator,
            sequence,
            .{
                .axis = i,
                .denominator = config.axes[i].position_gain.denominator,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_in_position_threshold,
            sequence,
            .{ .axis = i, .threshold = config.axes[i].in_position_threshold },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_base_position,
            sequence,
            .{ .axis = i, .position = config.axes[i].base_position },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_back_sensor_off,
            sequence,
            .{
                .axis = i,
                .position = config.axes[i].back_sensor_off.position,
                .section_count = config.axes[i].back_sensor_off.section_count,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_front_sensor_off,
            sequence,
            .{
                .axis = i,
                .position = config.axes[i].front_sensor_off.position,
                .section_count = config.axes[i].front_sensor_off.section_count,
            },
        );
        try command.sendMessage(&msg);
    }

    for (0..drivercom.Config.MAX_AXES * 2) |_i| {
        const i: u16 = @intCast(_i);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_calibrated_magnet_length_backward,
            sequence,
            .{
                .sensor = i,
                .length = config.hall_sensors[i].calibrated_magnet_length.backward,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_calibrated_magnet_length_forward,
            sequence,
            .{
                .sensor = i,
                .length = config.hall_sensors[i].calibrated_magnet_length.forward,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_ignore_distance_backward,
            sequence,
            .{
                .sensor = i,
                .distance = config.hall_sensors[i].ignore_distance.backward,
            },
        );
        try command.sendMessage(&msg);

        sequence += 1;
        msg = drivercom.Message.init(
            .set_ignore_distance_forward,
            sequence,
            .{
                .sensor = i,
                .distance = config.hall_sensors[i].ignore_distance.forward,
            },
        );
        try command.sendMessage(&msg);
    }

    sequence += 1;
    msg = drivercom.Message.init(.save_config, sequence, {});
    try command.sendMessage(&msg);
}
