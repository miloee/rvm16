# Spike-C for RVM16-C

This is the RVM16-C Spike source overlay, copied from the working tree at
/mnt/d/dsh_workspace/spike-c (build/ excluded).

Build:

    mkdir build && cd build
    ../configure --prefix=$PWD/install
    # if configure enables Boost, undef HAVE_BOOST/HAVE_BOOST_ASIO/HAVE_BOOST_REGEX in config.h
    make -j20

Run FIR/sum:

    spike --isa=RV32IMC_Zcb_Zc16 --pc=0x80000100 fir_c.elf
    spike --isa=RV32IMC_Zcb_Zc16 --pc=0x80000100 sum_c.elf

Status of this overlay:

- implemented and tested: add/sub, bne/blt/blez, lw/sw, GP/PC, Zcmp, Zcmt;
- source added but build/test pending: and/or/xor/sll/srl/sra/slt/sltu;
- not implemented: M (mulh/div/rem), F32, CSR (except csrw cold path), SYS.

The full patch against the RVA-E16 tree is patches/spike-c/0001-spike-c-full.patch.
