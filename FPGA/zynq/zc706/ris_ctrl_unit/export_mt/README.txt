RIS MT uniform-control package — ZC706 xc7z045ffg900-2

Use the BIT, ELF and ps7_init.tcl in this directory together. The XSA is the
exact hardware handoff used to build the Vitis platform. manifest.json records
SHA256 checksums; scripts/finalize_export.py verifies the embedded bitstream.

400 uniform outputs; carrier 1 Hz..5 MHz; per-cycle M/T text table; circular
wrap within each row's own cycle; loop or once. Maximum 512 input rows and 2048 compiled
segments. Minimum output update interval: 100 ns.

Full Chinese instructions: ../README_MT.md
MATLAB generator: ../matlab/generate_mt_example.m
GUI: ../host/ris_gui.py
Vivado project: ../vivado_mt/ris_ctrl_unit.xpr
Vitis workspace: ../vitis_mt/
Offline test/build evidence: ../reports/mt/verification.json

The complete MT boot image was programmed to QSPI on cable 210299372306 on
2026-10-29 and passed two complete read-back comparisons. Cold boot is pending.
Complete QSPI boot image: ../export_flash/20261029_mt/BOOT.bin
Flash settings, matching FSBL and checksums: ../export_flash/20261029_mt/README.md
Complete archive: ../export_flash/RIS_ZC706_MT_QSPI_20261029.zip
