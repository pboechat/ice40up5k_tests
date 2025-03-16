PROJECT := common

fifo_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=common/src/test/fifo_tb.v

clock_divider_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=common/src/test/clock_divider_tb.v

uart_dbg_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=common/src/test/uart_dbg_tb.v

uart_rx_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=common/src/test/uart/uart_rx_tb.v

ili9341_spi_controller_tb:
	make -C . test PROJECT=$(PROJECT) BENCH=common/src/test/ili9341/ili9341_spi_controller_tb.v

clean:
	make -C . clean PROJECT=$(PROJECT)

.PHONY: clean
