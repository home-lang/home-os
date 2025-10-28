// VGA text mode driver for home-os
// 80x25 color text mode

const VGA_WIDTH: usize = 80;
const VGA_HEIGHT: usize = 25;
const VGA_BUFFER_ADDR: usize = 0xB8000;

// Get VGA buffer pointer (runtime evaluation)
inline fn getVgaBuffer() *volatile [VGA_HEIGHT][VGA_WIDTH]u16 {
    return @ptrFromInt(VGA_BUFFER_ADDR);
}

pub const Color = enum(u8) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGray = 7,
    DarkGray = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    Yellow = 14,
    White = 15,
};

// Explicitly initialized variables (not .bss)
var row: usize = 0;
var column: usize = 0;
var fg_color: Color = Color.White;
var bg_color: Color = Color.Black;

// Create VGA entry (character + color)
inline fn vgaEntry(c: u8, fg: Color, bg: Color) u16 {
    const fg_val: u8 = @intCast(@intFromEnum(fg));
    const bg_val: u8 = @intCast(@intFromEnum(bg));
    const color_code: u8 = fg_val | (bg_val << 4);
    return @as(u16, c) | (@as(u16, color_code) << 8);
}

// Initialize VGA
pub fn init() void {
    // Don't access any variables - they cause crashes in current setup
    // Variables will be implicitly zero-initialized from .bss
    // Just return for now
    _ = row;
    _ = column;
    _ = fg_color;
    _ = bg_color;
}

// Set colors
pub fn setColor(fg: Color, bg: Color) void {
    fg_color = fg;
    bg_color = bg;
}

// Clear screen
pub fn clear() void {
    var y: usize = 0;
    while (y < VGA_HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            getVgaBuffer()[y][x] = vgaEntry(' ', fg_color, bg_color);
        }
    }
    row = 0;
    column = 0;
}

// Scroll screen up one line
fn scroll() void {
    // Move all rows up
    var y: usize = 0;
    while (y < VGA_HEIGHT - 1) : (y += 1) {
        var x: usize = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            getVgaBuffer()[y][x] = getVgaBuffer()[y + 1][x];
        }
    }

    // Clear last row
    var x: usize = 0;
    while (x < VGA_WIDTH) : (x += 1) {
        getVgaBuffer()[VGA_HEIGHT - 1][x] = vgaEntry(' ', fg_color, bg_color);
    }

    row = VGA_HEIGHT - 1;
}

// Write a single character
pub fn writeChar(c: u8) void {
    if (c == '\n') {
        column = 0;
        row += 1;
        if (row >= VGA_HEIGHT) {
            scroll();
        }
        return;
    }

    if (c == '\r') {
        column = 0;
        return;
    }

    getVgaBuffer()[row][column] = vgaEntry(c, fg_color, bg_color);

    column += 1;
    if (column >= VGA_WIDTH) {
        column = 0;
        row += 1;
        if (row >= VGA_HEIGHT) {
            scroll();
        }
    }
}

// Write a string
pub fn writeString(s: []const u8) void {
    for (s) |c| {
        writeChar(c);
    }
}

// Write a hexadecimal number
pub fn writeHex(value: u64) void {
    const hex_chars = "0123456789ABCDEF";

    writeString("0x");

    var i: u6 = 60;
    while (true) : (i -%= 4) {
        const nibble: u4 = @truncate(value >> i);
        writeChar(hex_chars[nibble]);

        if (i == 0) break;
    }
}

// Write a decimal number
pub fn writeDec(value: u64) void {
    if (value == 0) {
        writeChar('0');
        return;
    }

    var buf: [20]u8 = undefined;
    var i: usize = 0;
    var n = value;

    while (n > 0) {
        buf[i] = @intCast('0' + (n % 10));
        n /= 10;
        i += 1;
    }

    // Reverse and print
    while (i > 0) {
        i -= 1;
        writeChar(buf[i]);
    }
}

// Set cursor position
pub fn setCursor(x: usize, y: usize) void {
    if (x < VGA_WIDTH and y < VGA_HEIGHT) {
        column = x;
        row = y;
    }
}

// Get current cursor position
pub fn getCursor() struct { x: usize, y: usize } {
    return .{ .x = column, .y = row };
}
