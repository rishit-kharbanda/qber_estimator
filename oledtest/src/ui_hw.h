/* ============================================================================
 * ui_hw.h - addresses of the UI hardware (Part 3)
 *
 * Vitis generates xparameters.h from the hardware. If a name below does not
 * compile, open the platform's xparameters.h, search "BASEADDR", and put the
 * right name here.
 * ========================================================================== */
#ifndef UI_HW_H
#define UI_HW_H

#include "xparameters.h"

#ifdef SDT            /* Vitis 2023.2+ : drivers take a base address */
  #define UI_KYPD_ID     XPAR_AXI_GPIO_KYPD_BASEADDR
  #define UI_BTNSW_ID    XPAR_AXI_GPIO_BTNSW_BASEADDR
  #define UI_SCORE_ID    XPAR_AXI_GPIO_SCORE_BASEADDR   /* stand-alone test only */
  #define UI_OLED_IIC_ID XPAR_XIICPS_0_BASEADDR
#else                 /* older Vitis : drivers take a device ID */
  #define UI_KYPD_ID     XPAR_AXI_GPIO_KYPD_DEVICE_ID
  #define UI_BTNSW_ID    XPAR_AXI_GPIO_BTNSW_DEVICE_ID
  #define UI_SCORE_ID    XPAR_AXI_GPIO_SCORE_DEVICE_ID
  #define UI_OLED_IIC_ID XPAR_XIICPS_0_DEVICE_ID
#endif

#endif
