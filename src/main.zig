const std = @import("std");
const dbus = @import("dbus.zig");

const Window = struct {
    in_current_workspace: bool,
    wm_class: []const u8,
    wm_class_instance: []const u8,
    title: []const u8,
    pid: i32,
    id: u32,
    frame_type: i32,
    window_type: i32,
    focus: bool,
};

const window_calls_dest = "org.gnome.Shell";
const window_calls_path = "/org/gnome/Shell/Extensions/Windows";
const window_calls_iface = "org.gnome.Shell.Extensions.Windows";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const conn = dbus.Connection.init() catch {
        std.debug.print("Failed to connect to D-Bus session bus.\n", .{});
        return error.DBusConnectionFailed;
    };
    defer conn.deinit();

    const json_slice = conn.callNoArgsReturnString(
        window_calls_dest,
        window_calls_path,
        window_calls_iface,
        "List",
    ) catch {
        std.debug.print("Failed to list windows via window-calls.\n", .{});
        return error.DBusCallFailed;
    };

    const parsed = try std.json.parseFromSlice(
        []Window,
        allocator,
        json_slice,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const windows = parsed.value;
    const last_window = if (windows.len > 1) windows[windows.len - 2] else null;

    if (last_window) |win| {
        std.debug.print("{d}\n", .{win.id});
        conn.callU32(
            window_calls_dest,
            window_calls_path,
            window_calls_iface,
            "Activate",
            win.id,
        ) catch {
            std.debug.print("Failed to activate window {d}.\n", .{win.id});
            return error.DBusCallFailed;
        };
    } else {
        std.debug.print("There are no open windows.\n", .{});
    }
}
