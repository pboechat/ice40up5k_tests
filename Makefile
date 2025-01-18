# parameters
SYNTH := yosys
PNR := nextpnr-ice40
PACKAGER := icepack
DEVICE := up5k
PACKAGE := sg48
IVERILOG := iverilog
VVP := vvp
OUT_DIR := out

# inputs
PROJECT ?= project
SRC_DIR ?= $(PROJECT)/src/rtl
TEST_DIR ?= $(PROJECT)/src/test
TOP_MODULE ?= top
PCF_FILE ?= $(PROJECT)/constraints/board.pcf
BENCH ?= $(TOP_MODULE)_tb

synth:
	@echo ""
	@echo "##################################################"
	@echo "Synthesizing $(PROJECT)..."
	@echo "##################################################"
	@echo ""

	@mkdir -p $(OUT_DIR)/$(PROJECT)
	
	$(SYNTH) -p "read_verilog $(SRC_DIR)/*.v; synth_ice40 -top $(TOP_MODULE); write_json $(OUT_DIR)/$(PROJECT)/synth.json"

pnr:
	@echo ""
	@echo "##################################################"
	@echo "Path'n'Routing $(PROJECT)..."
	@echo "##################################################"
	@echo ""

	$(PNR) --$(DEVICE) --package $(PACKAGE) --json $(OUT_DIR)/$(PROJECT)/synth.json --pcf $(PCF_FILE) --asc $(OUT_DIR)/$(PROJECT)/stream.asc

pack:
	@echo ""
	@echo "##################################################"
	@echo "Packing $(PROJECT)..."
	@echo "##################################################"
	@echo ""

	$(PACKAGER) $(OUT_DIR)/$(PROJECT)/stream.asc $(OUT_DIR)/$(PROJECT)/stream.bin

test:
	@echo ""
	@echo "##################################################"
	@echo "Testing $(PROJECT): $(BENCH)..."
	@echo "##################################################"
	@echo ""

	@mkdir -p $(OUT_DIR)/$(PROJECT)/vvp/$(dir $(BENCH))

	$(IVERILOG) -I $(SRC_DIR) -o $(OUT_DIR)/$(PROJECT)/vvp/$(BENCH).vvp $(TEST_DIR)/$(BENCH)/.v


clean:
	rm -Rdf $(OUT_DIR)/$(PROJECT)

all: synth pnr pack

.PHONY: all synth pnr pack clean