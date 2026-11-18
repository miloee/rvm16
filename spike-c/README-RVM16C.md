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

- tested: ALU-12 (10), M (7), F32 (20), CSR csrw/csrr/csrs/csrc,
  SYS ecall/ebreak/mret/fence/fence.i/wfi, Zcb, branches, GP/PC, LD/ST,
  Zcmp, Zcmt;
- fcmp writes x7 (not x31); x16-x31 are non-architectural in RVM16-C;
- c.sext.b/h require Zbb (run with Zbb enabled).
