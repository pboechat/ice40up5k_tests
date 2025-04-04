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
DEFINES ?= -D DEBUG

synth:
	@echo ""
	@echo "##################################################"
	@echo "Synthesizing $(PROJECT)..."
	@echo "##################################################"
	@echo ""

	@mkdir -p $(OUT_DIR)/$(PROJECT)
	
	set -e
	$(SYNTH) -Wall -p "setattr -mod -set error_on_warning 1; verilog_defines $(DEFINES); read_verilog -I common/src/rtl $(SRC_DIR)/*.v; synth_ice40 -top $(TOP_MODULE); write_json $(OUT_DIR)/$(PROJECT)/synth.json" 2>&1 | tee yosys.log 
	@if grep -i "Warning:" yosys.log | grep -v "ABC: Warning:" | grep -v "Found log message matching"; then exit 1; fi
	! grep -i "ERROR:" yosys.log

pnr:
	@echo ""
	@echo "##################################################"
	@echo "Path'n'Routing $(PROJECT)..."
	@echo "##################################################"
	@echo ""

	$(PNR) --$(DEVICE) --package $(PACKAGE) --json $(OUT_DIR)/$(PROJECT)/synth.json --pcf $(PCF_FILE) --asc $(OUT_DIR)/$(PROJECT)/$(PROJECT).asc

pack:
	@echo ""
	@echo "##################################################"
	@echo "Packing $(PROJECT)..."
	@echo "##################################################"
	@echo ""

	$(PACKAGER) $(OUT_DIR)/$(PROJECT)/$(PROJECT).asc $(OUT_DIR)/$(PROJECT)/$(PROJECT).bin

test:
	@echo ""
	@echo "##################################################"
	@echo "Testing $(PROJECT): $(BENCH)..."
	@echo "##################################################"
	@echo ""

	@VVP_OUT=$(OUT_DIR)/$(PROJECT)/vvp/$(notdir $(BENCH)).vvp; \
		mkdir -p $(OUT_DIR)/$(PROJECT)/vvp; \
		$(IVERILOG) -DSIMULATION -I common/src/rtl -I $(SRC_DIR) -o $$VVP_OUT $(BENCH); \
		$(VVP) $$VVP_OUT +notimingcheck +stop_time=10000;


clean:
	rm -Rdf $(OUT_DIR)/$(PROJECT)

all: synth pnr pack

.PHONY: all synth pnr pack clean