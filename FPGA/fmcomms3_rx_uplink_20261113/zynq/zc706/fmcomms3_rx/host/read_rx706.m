function [rx1, rx2, meta] = read_rx706(filename, first_tuple, tuple_count)
% Read a bounded block of the unchanged little-endian I1 Q1 I2 Q2 stream.
% Example: [x1,x2,m] = read_rx706('capture.bin',0,1048576);
if nargin < 2, first_tuple = 0; end
if nargin < 3, tuple_count = 1048576; end
meta = jsondecode(fileread([filename '.json']));
assert(meta.complete && meta.file_bytes == meta.capture.bytes, 'Incomplete capture');
assert(first_tuple >= 0 && fix(first_tuple) == first_tuple, 'Invalid offset');
assert(tuple_count > 0 && fix(tuple_count) == tuple_count, 'Invalid block length');
assert(first_tuple + tuple_count <= meta.capture.tuples, 'Block exceeds capture');
listing = dir(filename);
assert(listing.bytes == meta.file_bytes, 'File length does not match metadata');
fid = fopen(filename, 'rb', 'ieee-le');
assert(fid >= 0, 'Cannot open capture');
guard = onCleanup(@() fclose(fid)); %#ok<NASGU>
assert(fseek(fid, first_tuple * 8, 'bof') == 0, 'Seek failed');
raw = fread(fid, [4 tuple_count], '*int16');
assert(size(raw,2) == tuple_count, 'Truncated capture');
rx1 = complex(single(raw(1,:)), single(raw(2,:)));
rx2 = complex(single(raw(3,:)), single(raw(4,:)));
end
