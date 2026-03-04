import sys

def read_file(path):
    with open(path, "r") as f:
        for i, line in enumerate(f, 1):
            if i >= 90 and i <= 140:
                print(f"{i}: {line.strip()}")

if __name__ == "__main__":
    read_file("/tmp/teqmates_new")
