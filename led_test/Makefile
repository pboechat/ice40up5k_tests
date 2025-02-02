PROJECT := led_test

synth:
	make -C . sync PROJECT=$(PROJECT)

pnr:
	make -C . pnr PROJECT=$(PROJECT)

pack:
	make -C . pnr PROJECT=$(PROJECT)

all:
	make -C . all PROJECT=$(PROJECT)

clean:
	make -C . clean PROJECT=$(PROJECT)

.PHONY: all clean synth pnr pack
