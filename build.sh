# Used for production builds
# Receives one argument: compilation target for zig
# Emits an archieve

zig build-exe src/main.zig -target $1 -O ReleaseFast -fsingle-threaded \
	-fno-unwind-tables -fstrip -femit-bin="zig-out/transparenZ.exe"

zig build-lib src/main.zig -target $1 -dynamic -O ReleaseFast -fsingle-threaded \
	-fno-unwind-tables -fstrip -femit-bin="zig-out/ui.dll"

(cd zig-out && tar -caf zqjs-$1.tar.gz .)
