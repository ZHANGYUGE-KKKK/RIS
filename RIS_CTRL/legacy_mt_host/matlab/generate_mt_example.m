% Run this script in MATLAB. Output is placed alongside the script.
output_dir = fileparts(mfilename('fullpath'));
MT = [50, 10; 30, 0];
write_mt_table(fullfile(output_dir, 'mt_example.txt'), MT);
% Circular phase within EACH cycle. [50,80] is high 0..30% and 80..100%.
% The following zero-duty cycle stays entirely low.
write_mt_table(fullfile(output_dir, 'mt_wrap.txt'), [50, 80; 0, 0; 30, 0]);
disp('MT files generated. Load them in the GUI and begin at 1 MHz or lower.');
