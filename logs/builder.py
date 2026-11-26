# 2026-11-26T16:44:12.042831800
import vitis

client = vitis.create_client()
client.set_workspace(path="C:/Users/Admin/Desktop/QBER_Estimator")

comp = client.get_component(name="demo")
comp.build()

comp = client.get_component(name="fulltest")
comp.build()

comp = client.get_component(name="main")
comp.build()

comp = client.get_component(name="oledtest")
comp.build()

vitis.dispose()

vitis.dispose()

