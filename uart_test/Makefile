PROJECT := uart_test

synth:
	make -C . sync PROJECT=$(PROJECT)

pnr:
	make -C . pnr PROJECT=$(PROJECT)

pack:
	make -C . pnr PROJECT=$(PROJECT)

uart_receiver_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=uart_test/src/test/uart_receiver_tb.v

all:
	make -C . all PROJECT=$(PROJECT)

clean:
	make -C . clean PROJECT=$(PROJECT)

.PHONY: all clean synth pnr pack
