# Used for production builds
# Receives one argument: compilation target for zig

zig build-lib src/main.zig -target $1 -dynamic -O ReleaseFast -fsingle-threaded \
	-fno-unwind-tables -fstrip -femit-bin="zig-out/ui.dll"
