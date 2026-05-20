syn:
	quartus_sh --flow compile fpga

gui:
	quartus fpga &

drc: syn
	quartus_drc fpga

clean:
	rm -rf db incremental_db output fpga.qws *.bak

.PHONY: syn gui drc clean
