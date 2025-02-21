PROJECT := image_streaming_test

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

image_streaming_controller_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=$(PROJECT)/src/test/image_streaming_controller_tb.v

.PHONY: all clean synth pnr pack
