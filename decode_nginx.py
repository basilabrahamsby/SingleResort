with open("c:\\releasing\\New Orchid\\teqmates_err.txt", "rb") as f:
    raw = f.read()
    print(raw.decode("utf-16").replace("\r\n", "\n"))
