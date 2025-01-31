PROJECT := display_test

synth:
	make -C . sync PROJECT=$(PROJECT)

pnr:
	make -C . pnr PROJECT=$(PROJECT)

pack:
	make -C . pnr PROJECT=$(PROJECT)

display_controller_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=$(PROJECT)/src/test/display_controller_tb.v

ice40_master_spi_controller_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=common/src/test/spi/ice40_master_spi_controller_tb.v

uart_receiver_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=common/src/test/uart/uart_receiver_tb.v

top_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=$(PROJECT)/src/test/top_tb.v

all:
	make -C . all PROJECT=$(PROJECT)

clean:
	make -C . clean PROJECT=$(PROJECT)

.PHONY: all clean synth pnr pack
