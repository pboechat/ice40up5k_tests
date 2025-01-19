PROJECT := uart_test

synth:
	make -C . sync PROJECT=$(PROJECT)

pnr:
	make -C . pnr PROJECT=$(PROJECT)

pack:
	make -C . pnr PROJECT=$(PROJECT)

test: src/test/%.v
	make -C . test PROJECT=$(PROJECT) BENCH=$>

all:
	make -C . all PROJECT=$(PROJECT)

clean:
	make -C . clean PROJECT=$(PROJECT)

.PHONY: all clean synth pnr pack
