with open("code_binary.txt") as f:
    data = f.readlines()

hex_output = []
for binary_string in data:
    hex_output.append("\t" + str(hex(int(binary_string, 2))) + ",\n")

with open("hex_output.tx", "w") as f:
    f.writelines(hex_output)
