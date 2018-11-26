ifneq ($(KERNELRELEASE),)
obj-m := armdsp.o
else

# for the development host =======================================
ARMDSP_DIR=/usr/local/armdsp

ARMDSP_NFSROOT=/arm

# for compiling arm kernel module ================================

#KERNELDIR = /opt/ti/linux-03.20.00.11/
KERNELDIR = $(KERNEL_SRC)
PWD := $(shell pwd)
ARCH=arm
CROSS_COMPILE=arm-none-linux-gnueabi-
export ARCH CROSS_COMPILE

# for compiling user level arm programs ==========================
ARMCC = $(CROSS_COMPILE)gcc -g -Wall

# for compiling dsp programs =====================================
CL6X = cl6x
CL6X_FLAGS = --abi=eabi

.SUFFIXES: .obj .asm

.c.obj:
	$(CL6X) $(CL6X_FLAGS) -c $*.c

.asm.obj:
	$(CL6X) $(CL6X_FLAGS) -c $*.asm
# ================================================================

all: regs-omap-l138.h \
	armdsp.ko dsptest rundsp armhost regdefs regs-omap-l138.h \
	armnet armnet.arm libarmdsp.a armdsp-mkais aisdump

aisdump: aisdump.c
	gcc -g -Wall -o aisdump aisdump.c

armdsp-mkais: armdsp-mkais.c
	gcc -g -Wall -o armdsp-mkais armdsp-mkais.c

armdsp.ko: armdsp.c armdsp.h
	$(MAKE) -C $(KERNELDIR) M=$(PWD) modules

DSPTEST_OBJS = vecs.obj dsptrg.obj dsptest.obj
dsptest: $(DSPTEST_OBJS) armdsp-link.cmd armdsp-mkais
	$(CL6X) $(CL6X_FLAGS) -z armdsp-link.cmd $(DSPTEST_OBJS) \
		--output_file dsptest.elf
	hex6x -q -m --order=M --romwidth=32 -o=dsptest.srec dsptest.elf
	./armdsp-mkais dsptest.srec dsptest
	dis6x dsptest.elf > dsptest.dis
	nm6x dsptest.elf | sort > dsptest.nm

dsptrg.obj: dsptrg.c regs-omap-l138.h

rundsp: rundsp.c libarmdsp.c armdsp.h
	$(ARMCC) -o rundsp rundsp.c libarmdsp.c

armnet: armnet.c
	gcc -g -Wall -o armnet armnet.c

armnet.arm: armnet.c
	$(ARMCC) -o armnet.arm armnet.c

armhost: armdsp.h armhost.c libarmdsp.c
	$(ARMCC) -o armhost armhost.c libarmdsp.c

regdefs: regdefs.c
	cc -g -Wall -o regdefs regdefs.c

regs-omap-l138.h: regdefs regs.conf
	./regdefs

libarmdsp.a: libarmdsp.c
	$(ARMCC) -c libarmdsp.c
	rm -f libarmdsp.a
	$(CROSS_COMPILE)ar r libarmdsp.a libarmdsp.o

install: all
	mkdir -p -m 755 $(ARMDSP_DIR)/bin
	mkdir -p -m 755 $(ARMDSP_DIR)/arm/lib
	mkdir -p -m 755 $(ARMDSP_DIR)/dsp
	mkdir -p -m 755 $(ARMDSP_DIR)/include
	install -c -m 555 armdsp-link $(ARMDSP_DIR)/bin/.
	install -c -m 555 armdsp-mkais $(ARMDSP_DIR)/bin/.
	install -c -m 444 Makefile.armdsp $(ARMDSP_DIR)/.
	install -c -m 444 armdsp.ko $(ARMDSP_DIR)/arm/.
	install -c -m 555 rundsp $(ARMDSP_DIR)/arm/.
	install -c -m 555 armhost $(ARMDSP_DIR)/arm/.
	install -c -m 555 armdsp-ldmod $(ARMDSP_DIR)/arm/.
	install -c -m 444 libarmdsp.a $(ARMDSP_DIR)/arm/lib/.
	install -c -m 444 dsptest $(ARMDSP_DIR)/dsp/.
	install -c -m 444 vecs.obj $(ARMDSP_DIR)/dsp/.
	install -c -m 444 dsptrg.obj $(ARMDSP_DIR)/dsp/.
	install -c -m 444 armdsp-link.cmd $(ARMDSP_DIR)/dsp/.
	install -c -m 444 regs-omap-l138.h $(ARMDSP_DIR)/include/.
	install -c -m 444 armdsp.h $(ARMDSP_DIR)/include/.

test: all
	install -c -m 644 armdsp.ko $(ARMDSP_NFSROOT)/.
	install -c -m 755 rundsp $(ARMDSP_NFSROOT)/.
	install -c -m 755 armhost $(ARMDSP_NFSROOT)/.
	install -c -m 755 armdsp-ldmod $(ARMDSP_NFSROOT)/.
	install -c -m 644 dsptest $(ARMDSP_NFSROOT)/.

clean:
	rm -f *.o *.ko *.obj *.elf *.mod.c *~ .*~ ? *.dis *.nm
	rm -f dsptest.asm
	rm -f rundsp armhost dsptest dsptest.elf regdefs
	rm -f Module.symvers modules.order
	rm -f regs-omap-l138.h
	rm -rf .tmp_versions .*.cmd
	rm -f libarmdsp.a
	$(MAKE) -C example clean

endif
