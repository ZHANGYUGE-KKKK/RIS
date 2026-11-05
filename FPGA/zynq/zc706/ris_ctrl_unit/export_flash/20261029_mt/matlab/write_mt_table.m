function write_mt_table(filename, MT)
%WRITE_MT_TABLE Export one uniform RIS pulse per carrier cycle.
% MT is N-by-2: [duty_percent, delay_percent], both in [0,100].
% Within cycle i, high iff mod(local_phase_percent-T,100) < M.
% When T+M>100, the excess wraps to the beginning of the SAME cycle.
% Example [50,80]: high 0..30%, low 30..80%, high 80..100%.
% Frequency and once/loop selection are made in the RIS GUI.
% Example: write_mt_table('mt_example.txt', [50 10; 30 0]);
    validateattributes(MT, {'numeric'}, ...
        {'real', 'finite', '2d', 'nonempty', '>=', 0, '<=', 100});
    assert(size(MT,2) == 2, 'MT:Columns', 'MT must be an N-by-2 matrix.');
    assert(size(MT,1) <= 512, 'MT:TooManyRows', 'This version supports at most 512 cycles.');
    fid = fopen(filename, 'wt', 'n', 'UTF-8');
    assert(fid >= 0, 'MT:OpenFailed', 'Cannot open MT output file.');
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%% RIS MT table: M=duty percent, T=delay percent\n');
    % Fixed-point text is intentionally compatible with the GUI strict parser.
    for k = 1:size(MT,1)
        fprintf(fid, '(%.9f,%.9f);\n', MT(k,1), MT(k,2));
    end
end
