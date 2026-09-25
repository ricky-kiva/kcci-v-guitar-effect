## Audio Codec/external EEPROM IIC bus
set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 } [get_ports IIC_1_0_scl_io]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports IIC_1_0_sda_io]

##I2S Audio Codec
set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports BCLK]; #IO_L12N_T1_MRCC_35 Sch=AC_BCLK
set_property -dict { PACKAGE_PIN R17   IOSTANDARD LVCMOS33 } [get_ports MCLK]; #IO_25_34 Sch=AC_MCLK
set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports MUTE]; #IO_L23N_T3_34 Sch=AC_MUTEN
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports PBDAT]; #IO_L8P_T1_AD10P_35 Sch=AC_PBDAT
set_property -dict { PACKAGE_PIN T19   IOSTANDARD LVCMOS33 } [get_ports PBLRC]; #IO_L11N_T1_SRCC_35 Sch=AC_PBLRC
set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports RECDAT]; #IO_L12P_T1_MRCC_35 Sch=AC_RECDAT
set_property -dict { PACKAGE_PIN Y18   IOSTANDARD LVCMOS33 } [get_ports RECLRC]; #IO_L8N_T1_AD10N_35 Sch=AC_RECLRC