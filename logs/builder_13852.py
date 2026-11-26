# 2026-11-26T16:12:23.836570300
import vitis

client = vitis.create_client()
client.set_workspace(path="C:/Users/Admin/Desktop/QBER_Estimator")

platform = client.create_platform_component(name = "qber_platform",hw = "C:/Users/Admin/Desktop/QBER_Estimator/design_1_wrapper.xsa",os = "standalone",cpu = "ps7_cortexa9_0")

comp = client.create_app_component(name="fulltest",platform = "C:/Users/Admin/Desktop/QBER_Estimator/qber_platform/export/qber_platform/qber_platform.xpfm",domain = "standalone_ps7_cortexa9_0")

comp = client.create_app_component(name="demo",platform = "C:/Users/Admin/Desktop/QBER_Estimator/qber_platform/export/qber_platform/qber_platform.xpfm",domain = "standalone_ps7_cortexa9_0")

comp = client.create_app_component(name="oledtest",platform = "C:/Users/Admin/Desktop/QBER_Estimator/qber_platform/export/qber_platform/qber_platform.xpfm",domain = "standalone_ps7_cortexa9_0")

comp = client.create_app_component(name="main",platform = "C:/Users/Admin/Desktop/QBER_Estimator/qber_platform/export/qber_platform/qber_platform.xpfm",domain = "standalone_ps7_cortexa9_0")

comp = client.get_component(name="demo")
status = comp.import_files(from_loc="C:/Users/Admin/Desktop/QBER_Estimator/qber_files/vitis/demo", files=["btnsw.c", "btnsw.h", "font8x8.h", "kypd.c", "kypd.h", "link_emu.c", "link_emu.h", "main.c", "oled.c", "oled.h", "params.c", "params.h", "platform.h", "qber_hw.c", "qber_hw.h", "qber_regs.h", "sw_estimator.c", "sw_estimator.h", "sweeps.c", "sweeps.h", "uart_log.c", "uart_log.h", "ui.c", "ui.h", "ui_hw.h", "xs64.h"], dest_dir_in_cmp = "src")

comp = client.get_component(name="fulltest")
status = comp.import_files(from_loc="C:/Users/Admin/Desktop/QBER_Estimator/qber_files/vitis/fulltest", files=["fulltest.c", "golden_cases.h", "link_emu.c", "link_emu.h", "params.c", "params.h", "platform.h", "qber_hw.c", "qber_hw.h", "qber_regs.h", "sw_estimator.c", "sw_estimator.h", "sweeps.c", "sweeps.h", "uart_log.c", "uart_log.h", "xs64.h"], dest_dir_in_cmp = "src")

comp = client.get_component(name="main")
status = comp.import_files(from_loc="C:/Users/Admin/Desktop/QBER_Estimator/qber_files/vitis/main", files=["link_emu.c", "link_emu.h", "params.c", "params.h", "platform.h", "qber_hw.c", "qber_hw.h", "qber_regs.h", "suite.c", "sw_estimator.c", "sw_estimator.h", "sweeps.c", "sweeps.h", "uart_log.c", "uart_log.h", "xs64.h"], dest_dir_in_cmp = "src")

comp = client.get_component(name="oledtest")
status = comp.import_files(from_loc="C:/Users/Admin/Desktop/QBER_Estimator/qber_files/vitis/oledtest", files=["font8x8.h", "oledtest.c", "ui_hw.h"], dest_dir_in_cmp = "src")

platform = client.get_platform_component(name="qber_platform")
status = platform.build()

comp = client.get_component(name="demo")
comp.build()

comp.build()

comp = client.get_component(name="fulltest")
comp.build()

comp = client.get_component(name="demo")
comp.build()

comp = client.get_component(name="fulltest")
comp.build()

comp = client.get_component(name="main")
comp.build()

comp = client.get_component(name="oledtest")
comp.build()

vitis.dispose()

