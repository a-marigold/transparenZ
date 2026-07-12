# Used for production builds
# Receives two arguments: 
# 1. compilation target for zig
# 2. path to of archive to be outputed (e.g `transparenZ.tar.gz`s`)

zig build-exe src/main.zig -target $1 -O ReleaseFast -fsingle-threaded \
	-fno-unwind-tables -fstrip -femit-bin="zig-out/transparenZ.exe"
zig build-lib src/main.zig -target $1 -dynamic -O ReleaseFast -fsingle-threaded \
	-fno-unwind-tables -fstrip -femit-bin="zig-out/ui.dll"
	tar -caf $2.tar.gz -C zig-out .
