CLANG  := clang
CFLAGS := -O2 -g -Wall -target bpf

SRC_DIR := .
OBJ_DIR := obj

BPF_NAME := ipv4_forward
SRC_FILE := $(SRC_DIR)/$(BPF_NAME).c

XDP_LE_OBJ_FILE := $(OBJ_DIR)/xdp_le_$(BPF_NAME).o
XDP_BE_OBJ_FILE := $(OBJ_DIR)/xdp_be_$(BPF_NAME).o
TC_LE_OBJ_FILE 	:= $(OBJ_DIR)/tc_le_$(BPF_NAME).o
TC_BE_OBJ_FILE 	:= $(OBJ_DIR)/tc_be_$(BPF_NAME).o

all: xdp-le xdp-be tc-le tc-be

xdp: xdp-le xdp-be

tc: tc-le tc-be

le: xdp-le tc-le

be: xdp-be tc-be

xdp-le: $(XDP_LE_OBJ_FILE)

tc-le: $(TC_LE_OBJ_FILE)

xdp-be: $(XDP_BE_OBJ_FILE)

tc-be: $(TC_BE_OBJ_FILE)

clean:
	@rm -rf $(OBJ_DIR)

$(XDP_LE_OBJ_FILE): $(SRC_FILE) | $(OBJ_DIR)
	$(CLANG) $(CFLAGS) -mlittle-endian -DXDP_PROGRAM -c $< -o $@

$(XDP_BE_OBJ_FILE): $(SRC_FILE) | $(OBJ_DIR)
	$(CLANG) $(CFLAGS) -mbig-endian -DXDP_PROGRAM -c $< -o $@

$(TC_LE_OBJ_FILE): $(SRC_FILE) | $(OBJ_DIR)
	$(CLANG) $(CFLAGS) -mlittle-endian -DTC_PROGRAM -c $< -o $@

$(TC_BE_OBJ_FILE): $(SRC_FILE) | $(OBJ_DIR)
	$(CLANG) $(CFLAGS) -mbig-endian -DTC_PROGRAM -c $< -o $@

$(OBJ_DIR):
	@mkdir -p $(OBJ_DIR)
