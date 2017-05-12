
module hps_fpga (
	clk_clk,
	cpu_0_rx_0_external_connection_export,
	cpu_0_rx_1_external_connection_export,
	cpu_0_rx_2_external_connection_export,
	cpu_0_rx_3_external_connection_export,
	cpu_0_rx_4_external_connection_export,
	cpu_0_rx_5_external_connection_export,
	cpu_0_rx_6_external_connection_export,
	cpu_0_rx_7_external_connection_export,
	cpu_0_tx_0_external_connection_export,
	cpu_0_tx_1_external_connection_export,
	cpu_0_tx_2_external_connection_export,
	cpu_0_tx_3_external_connection_export,
	cpu_0_tx_4_external_connection_export,
	cpu_0_tx_5_external_connection_export,
	cpu_0_tx_6_external_connection_export,
	cpu_0_tx_7_external_connection_export,
	cpu_1_rx_0_external_connection_export,
	cpu_1_rx_1_external_connection_export,
	cpu_1_rx_2_external_connection_export,
	cpu_1_rx_3_external_connection_export,
	cpu_1_rx_4_external_connection_export,
	cpu_1_rx_5_external_connection_export,
	cpu_1_rx_6_external_connection_export,
	cpu_1_rx_7_external_connection_export,
	cpu_1_tx_0_external_connection_export,
	cpu_1_tx_1_external_connection_export,
	cpu_1_tx_2_external_connection_export,
	cpu_1_tx_3_external_connection_export,
	cpu_1_tx_4_external_connection_export,
	cpu_1_tx_5_external_connection_export,
	cpu_1_tx_6_external_connection_export,
	cpu_1_tx_7_external_connection_export,
	hps_0_h2f_reset_reset_n,
	hps_io_hps_io_emac1_inst_TX_CLK,
	hps_io_hps_io_emac1_inst_TXD0,
	hps_io_hps_io_emac1_inst_TXD1,
	hps_io_hps_io_emac1_inst_TXD2,
	hps_io_hps_io_emac1_inst_TXD3,
	hps_io_hps_io_emac1_inst_RXD0,
	hps_io_hps_io_emac1_inst_MDIO,
	hps_io_hps_io_emac1_inst_MDC,
	hps_io_hps_io_emac1_inst_RX_CTL,
	hps_io_hps_io_emac1_inst_TX_CTL,
	hps_io_hps_io_emac1_inst_RX_CLK,
	hps_io_hps_io_emac1_inst_RXD1,
	hps_io_hps_io_emac1_inst_RXD2,
	hps_io_hps_io_emac1_inst_RXD3,
	hps_io_hps_io_sdio_inst_CMD,
	hps_io_hps_io_sdio_inst_D0,
	hps_io_hps_io_sdio_inst_D1,
	hps_io_hps_io_sdio_inst_CLK,
	hps_io_hps_io_sdio_inst_D2,
	hps_io_hps_io_sdio_inst_D3,
	hps_io_hps_io_usb1_inst_D0,
	hps_io_hps_io_usb1_inst_D1,
	hps_io_hps_io_usb1_inst_D2,
	hps_io_hps_io_usb1_inst_D3,
	hps_io_hps_io_usb1_inst_D4,
	hps_io_hps_io_usb1_inst_D5,
	hps_io_hps_io_usb1_inst_D6,
	hps_io_hps_io_usb1_inst_D7,
	hps_io_hps_io_usb1_inst_CLK,
	hps_io_hps_io_usb1_inst_STP,
	hps_io_hps_io_usb1_inst_DIR,
	hps_io_hps_io_usb1_inst_NXT,
	hps_io_hps_io_uart0_inst_RX,
	hps_io_hps_io_uart0_inst_TX,
	led_external_connection_export,
	memory_mem_a,
	memory_mem_ba,
	memory_mem_ck,
	memory_mem_ck_n,
	memory_mem_cke,
	memory_mem_cs_n,
	memory_mem_ras_n,
	memory_mem_cas_n,
	memory_mem_we_n,
	memory_mem_reset_n,
	memory_mem_dq,
	memory_mem_dqs,
	memory_mem_dqs_n,
	memory_mem_odt,
	memory_mem_dm,
	memory_oct_rzqin,
	noc_clock_clk,
	noc_ctrl_0_external_connection_export,
	noc_ctrl_1_external_connection_export,
	noc_status_0_external_connection_export,
	noc_status_1_external_connection_export,
	pll_0_outclk0_clk,
	reset_reset_n,
	sw_external_connection_export);	

	input		clk_clk;
	input	[31:0]	cpu_0_rx_0_external_connection_export;
	input	[31:0]	cpu_0_rx_1_external_connection_export;
	input	[31:0]	cpu_0_rx_2_external_connection_export;
	input	[31:0]	cpu_0_rx_3_external_connection_export;
	input	[31:0]	cpu_0_rx_4_external_connection_export;
	input	[31:0]	cpu_0_rx_5_external_connection_export;
	input	[31:0]	cpu_0_rx_6_external_connection_export;
	input	[31:0]	cpu_0_rx_7_external_connection_export;
	output	[31:0]	cpu_0_tx_0_external_connection_export;
	output	[31:0]	cpu_0_tx_1_external_connection_export;
	output	[31:0]	cpu_0_tx_2_external_connection_export;
	output	[31:0]	cpu_0_tx_3_external_connection_export;
	output	[31:0]	cpu_0_tx_4_external_connection_export;
	output	[31:0]	cpu_0_tx_5_external_connection_export;
	output	[31:0]	cpu_0_tx_6_external_connection_export;
	output	[31:0]	cpu_0_tx_7_external_connection_export;
	input	[31:0]	cpu_1_rx_0_external_connection_export;
	input	[31:0]	cpu_1_rx_1_external_connection_export;
	input	[31:0]	cpu_1_rx_2_external_connection_export;
	input	[31:0]	cpu_1_rx_3_external_connection_export;
	input	[31:0]	cpu_1_rx_4_external_connection_export;
	input	[31:0]	cpu_1_rx_5_external_connection_export;
	input	[31:0]	cpu_1_rx_6_external_connection_export;
	input	[31:0]	cpu_1_rx_7_external_connection_export;
	output	[31:0]	cpu_1_tx_0_external_connection_export;
	output	[31:0]	cpu_1_tx_1_external_connection_export;
	output	[31:0]	cpu_1_tx_2_external_connection_export;
	output	[31:0]	cpu_1_tx_3_external_connection_export;
	output	[31:0]	cpu_1_tx_4_external_connection_export;
	output	[31:0]	cpu_1_tx_5_external_connection_export;
	output	[31:0]	cpu_1_tx_6_external_connection_export;
	output	[31:0]	cpu_1_tx_7_external_connection_export;
	output		hps_0_h2f_reset_reset_n;
	output		hps_io_hps_io_emac1_inst_TX_CLK;
	output		hps_io_hps_io_emac1_inst_TXD0;
	output		hps_io_hps_io_emac1_inst_TXD1;
	output		hps_io_hps_io_emac1_inst_TXD2;
	output		hps_io_hps_io_emac1_inst_TXD3;
	input		hps_io_hps_io_emac1_inst_RXD0;
	inout		hps_io_hps_io_emac1_inst_MDIO;
	output		hps_io_hps_io_emac1_inst_MDC;
	input		hps_io_hps_io_emac1_inst_RX_CTL;
	output		hps_io_hps_io_emac1_inst_TX_CTL;
	input		hps_io_hps_io_emac1_inst_RX_CLK;
	input		hps_io_hps_io_emac1_inst_RXD1;
	input		hps_io_hps_io_emac1_inst_RXD2;
	input		hps_io_hps_io_emac1_inst_RXD3;
	inout		hps_io_hps_io_sdio_inst_CMD;
	inout		hps_io_hps_io_sdio_inst_D0;
	inout		hps_io_hps_io_sdio_inst_D1;
	output		hps_io_hps_io_sdio_inst_CLK;
	inout		hps_io_hps_io_sdio_inst_D2;
	inout		hps_io_hps_io_sdio_inst_D3;
	inout		hps_io_hps_io_usb1_inst_D0;
	inout		hps_io_hps_io_usb1_inst_D1;
	inout		hps_io_hps_io_usb1_inst_D2;
	inout		hps_io_hps_io_usb1_inst_D3;
	inout		hps_io_hps_io_usb1_inst_D4;
	inout		hps_io_hps_io_usb1_inst_D5;
	inout		hps_io_hps_io_usb1_inst_D6;
	inout		hps_io_hps_io_usb1_inst_D7;
	input		hps_io_hps_io_usb1_inst_CLK;
	output		hps_io_hps_io_usb1_inst_STP;
	input		hps_io_hps_io_usb1_inst_DIR;
	input		hps_io_hps_io_usb1_inst_NXT;
	input		hps_io_hps_io_uart0_inst_RX;
	output		hps_io_hps_io_uart0_inst_TX;
	output	[9:0]	led_external_connection_export;
	output	[14:0]	memory_mem_a;
	output	[2:0]	memory_mem_ba;
	output		memory_mem_ck;
	output		memory_mem_ck_n;
	output		memory_mem_cke;
	output		memory_mem_cs_n;
	output		memory_mem_ras_n;
	output		memory_mem_cas_n;
	output		memory_mem_we_n;
	output		memory_mem_reset_n;
	inout	[31:0]	memory_mem_dq;
	inout	[3:0]	memory_mem_dqs;
	inout	[3:0]	memory_mem_dqs_n;
	output		memory_mem_odt;
	output	[3:0]	memory_mem_dm;
	input		memory_oct_rzqin;
	output		noc_clock_clk;
	output	[31:0]	noc_ctrl_0_external_connection_export;
	output	[31:0]	noc_ctrl_1_external_connection_export;
	input	[31:0]	noc_status_0_external_connection_export;
	input	[31:0]	noc_status_1_external_connection_export;
	output		pll_0_outclk0_clk;
	input		reset_reset_n;
	input	[9:0]	sw_external_connection_export;
endmodule
