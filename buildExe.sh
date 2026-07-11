# Used for production builds
# Receives one argument: compilation target for zig

zig build-exe src/main.zig -target $1 -O ReleaseFast -fsingle-threaded \
	-fno-unwind-tables -fstrip -femit-bin="zig-out/transparenZ.exe"
