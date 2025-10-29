// Compile Home kernel to assembly
// This script is called from the build process to compile main.home → main.s

const std = @import("std");

// Import Home compiler components
// We'll use relative paths to the Home compiler
const Lexer = @import("../../../home/packages/lexer/src/lexer.zig").Lexer;
const Parser = @import("../../../home/packages/parser/src/parser.zig").Parser;
const HomeKernelCodegen = @import("../../../home/packages/codegen/src/home_kernel_codegen.zig").HomeKernelCodegen;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} <input.home> <output.s>\n", .{args[0]});
        std.process.exit(1);
    }

    const input_file = args[1];
    const output_file = args[2];

    std.debug.print("Compiling Home kernel: {s} → {s}\n", .{ input_file, output_file });

    // Read input file
    const source = try std.fs.cwd().readFileAlloc(allocator, input_file, 1024 * 1024);
    defer allocator.free(source);

    // Lex
    std.debug.print("  Lexing...\n", .{});
    var lexer = Lexer.init(allocator, source);
    const tokens = try lexer.tokenize();
    defer tokens.deinit(allocator);

    std.debug.print("  Parsed {} tokens\n", .{tokens.items.len});

    // Parse
    std.debug.print("  Parsing...\n", .{});
    var parser = try Parser.init(allocator, tokens.items);
    const program = try parser.parse();

    std.debug.print("  Parsed {} statements\n", .{program.statements.len});

    // Generate assembly
    std.debug.print("  Generating assembly...\n", .{});
    var codegen = HomeKernelCodegen.init(
        allocator,
        &parser.symbol_table,
        &parser.module_resolver,
    );
    defer codegen.deinit();

    const asm_code = try codegen.generate(program);

    std.debug.print("  Generated {} bytes of assembly\n", .{asm_code.len});

    // Write output
    try std.fs.cwd().writeFile(.{
        .sub_path = output_file,
        .data = asm_code,
    });

    std.debug.print("✓ Compilation successful!\n", .{});
}
