import importlib.util, pathlib
p = pathlib.Path(__file__).resolve().parents[1] / "plugins" / "nfb-guard" / "__init__.py"
spec = importlib.util.spec_from_file_location("nfb_guard", p); g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
out = g.clean("We hire for profit and returns from the treasury, an asset class of tradeable intelligence.")
for w in ["hire", "profit", "returns", "treasury", "asset class", "tradeable intelligence"]:
    assert w not in out.lower(), (w, out)
assert g.clean("my key is sk-ant-abcdefghijklmnop") == "my key is [hidden]"
assert g._transform(response_text="hello") is None
print("guard ok:", out)
