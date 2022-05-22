	# read byte word 
    la t0, value
    lb a0, (t0)
    # srli a0, a0, 1 # devides by 2 - wromg way
    li a7, 1
    ecall