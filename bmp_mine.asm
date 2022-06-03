.include "codes_table.asm"
.eqv ImgInfo_file_name	0
.eqv ImgInfo_header_bufor 	4
.eqv ImgInfo_img_begin_ptr	8
.eqv ImgInfo_width	12
.eqv ImgInfo_height	16
.eqv ImgInfo_line_bytes	20
.eqv MAX_IMG_SIZE 147456 # 768 x 64
.eqv BMPHeader_Size 54
.eqv BMPHeader_width 18
.eqv BMPHeader_height 22

# systen calls
.eqv system_OpenFile	1024
.eqv system_ReadFile	63
.eqv system_WriteFile	64
.eqv system_CloseFile	57


# "variables"
.eqv stripes_per_char 11

.eqv BYTES_PER_ROW 192



imgInfo: .space	24	# deskryptor obrazu

	.align 2		# wyrównanie do granicy słowa
dummy:		.space 2
bmpHeader:	.space	BMPHeader_Size

	.align 2
imgData: 	.space	MAX_IMG_SIZE

# -------------------------------- variables for user --------------------------------
text_to_code: .asciz "1234"
output_file_name: .asciz "result.bmp"
pixels_per_stripe: .byte 2
#---------------------------------------------------------------
	.text
main:

	la a0, imgInfo
	la a1, text_to_code
	jal create_barcode_img
	
	li a7, 1 # 0 - succes (img generated) otherwise 1 - error code
	ecall

# exit
	li a7, 10
	ecall
	
#================================================================
validate_width:
	# a1 - result (0 - too_narrow, otherwise right indent for img)
	mv t4, zero # calc text_to_code length
	la t0, text_to_code
calc_string_len:
	lbu t1, (t0)
	addi t4, t4, 1
	addi t0, t0, 1
	bne t1, zero, calc_string_len
	addi t4, t4, 3 # now it is 1 bigger than legth
	# but we need 2 more than length (start code and control sum)
	# and later we divide by 2

	srli t4, t4, 1

	li t0, stripes_per_char

	la t2, pixels_per_stripe
	lb t2, (t2)
	mul t3, t0, t2 # t3 = pixels_per_stripe x stripes_per_char
	mul t3, t3, t4 # t3 = (pixels_per_stripe x stripes_per_char) x (text_len + 2)

	li t0, 13 # wdith of 7 stipes in stop code
	mul t4, t2, t0 # width of stop code

	add t3, t3, t4 # total width of stripes

	li t1, 768 # width of picture (constant in this task)
	sub t1, t1, t3

	li t0, 20
	la t2, pixels_per_stripe
	lb t2, (t2)
	mul t0, t0, t2 # required space for 2 silent zones
	blt t1, t0, too_narrow_flag # negative -> too narrow 
	srli a2, t1, 1
	jr ra

too_narrow_flag:
	li a2, 0
	jr ra
	
# =============================================================
save_bmp:
	mv t0, a0	# preserve imgInfo structure pointer
	
	#open file
	li a7, system_OpenFile
    lw a0, ImgInfo_file_name(t0)	#file name 
    li a1, 1					#flags: 1-write file
    ecall
	
	blt a0, zero, wb_error
	mv t1, a0					# save file handle for the future
	
	#write header
	li a7, system_WriteFile
	lw a1, ImgInfo_header_bufor(t0)
	li a2, BMPHeader_Size
	ecall
	
	#write image data
	li a7, system_WriteFile
	mv a0, t1
	# compute image size (linebytes * height)
	lw a2, ImgInfo_line_bytes(t0)
	lw a1, ImgInfo_height(t0)
	mul a2, a2, a1
	lw a1, ImgInfo_img_begin_ptr(t0)
	ecall

	#close file
	li a7, system_CloseFile
	mv a0, t1
    ecall
	
	mv a0, zero
	jr ra
	
wb_error:
	li a0, 2 # error writing file
	jr ra


#================================================================
paint_stripe:
	#arguments:
	#	a0 - address of ImgInfo image descriptor
	#	a1 - offset from the end
	#return value:
	#	a0 - preserved
	# TODO refactor registers in whole function
	la t2, pixels_per_stripe
	lb t2, (t2)

	lw t4, ImgInfo_height(a0)
	addi t4, t4, -1

	lw t5, ImgInfo_width(a0)
	addi t5, t5, -1

	lw t6, ImgInfo_img_begin_ptr(a0) # address of image data
	lw a3, ImgInfo_line_bytes(a0)

	mv a4, a1 # save a1 - offset

	mv t1, a3 # t1 line bytes

	
	# load vertical address
	mv a1, t5	# a1 - img width
	sub a1, a1, a4	# x = width - offset

	add t0, a1, a1	
	add t0, t0, a1 	# t0 = x * 3
	add t0, t0, t6 	# t0 is address of the pixel (add img begin ptr)

	mul a3, t4, t1 # height * line bytes
	add a3, a3, t1
	add t0, t0, a3
width_loop:
	# load height
	mv a2, t4	# a2 - img height
	sub t0, t0, a3

	
	# TODO remove this outside loop
	# remeber to set address again to first row
	# probably before loop load addres at last row at desired column
	# in loop set it to first row (inner loop iterations moves that from first to last)
	


vertical_loop:
	mv s9, t0 # TODO change to non callee save register
	
	li t3, 0x00000000
	#set new color
	sb   t3,(t0)		#store B
	srli t3, t3, 8
	sb   t3, 1(t0)		#store G
	srli t3, t3, 8
	sb   t3, 2(t0)		#store R

	mv t0, s9
	add t0, t0, t1 # started at y = 0; add line bites
	# at each iteration  height++
	addi a2, a2, -1
	bge a2, zero, vertical_loop # vertical loop

	addi t2, t2, -1
	# addi a4, a4, 1
	addi t0, t0, -3 # TODO probably need to change -1 to -3
	bgt t2, zero, width_loop
	
	jr ra

# =============================================================
paint_character:
	# a0 - file handle
	# a1 - offest for character
	# a2 - input - index of the code value
	# a3 - length - of character bianry representation
	# s0 - counter for 11 stripes in char
	# s1 - read bianry number representating colors
	# s2 - offset for next stripes
	addi sp, sp -16
	sw ra, 12(sp)
	sw s2, 8(sp)
	sw s1, 4(sp)
	sw s0, 0(sp)

	# load value from table
	la t0, codes_table
	slli a2, a2, 1 # index * 2 (halfword - 2 bytes)
	add t0, t0, a2
	lh s1, (t0)

	# la s2, pixels_per_stripe
	# lb s2, (s2)
	# add s2, s2, a1
	mv s2, a1

	# loop - read 11/13 bits
	mv s0, a3

bits_loop:
	andi t0, s1, 1

	beqz t0, white_stripe 
	
black_stripe:
	mv a1, s2
	jal paint_stripe


white_stripe:
	la t0, pixels_per_stripe
	lb t0, (t0)
	add s2, s2, t0


	addi s0, s0, -1 # counter--
	
	srli s1, s1, 1
	bnez s0, bits_loop


	lw s0, 0(sp)
	lw s1, 4(sp)
	lw s2, 8(sp)
	lw ra, 12(sp)
	addi sp, sp, 16
	jr ra
	

#================================================================
create_barcode_img:
	# a0 - file handle 
	# a1 - text_to_code
	# s0 - pointer for last character
	# s1 - len of text_to_code
	addi sp, sp, -12
	sw ra, 8(sp)
	sw s1, 4(sp)
	sw s2, 0(sp)
	mv s1, a1 # preserve text to code

	jal validate_width
	mv t0, a0
	li a0, 1
	beqz a2, create_img_exit
	mv a0, t0
	mv s2, a2 # preserve offset - indent

	jal	generate_bmp

	la t1, pixels_per_stripe
	lb, t1, (t1) # t1 - pixel_per_stripe

text_lopp:
	lb t1, (a1)
	addi a1, a1, 1
	
	bnez t1, text_lopp
	
	addi a1, a1, -2
	mv s0, a1
	# now we have pointer for last character - s0

	# s1 - len of text to code
	sub s1, s0, s1
	addi s1, s1, 1

	# stop sign
	mv s8, a1
	mv a1, s2
	li a3, 13
	li a2, 101
	jal paint_character
	mv a1, s8

	mv t4, s1 # copy len of string
	mv t5, s1
	srli t5, t5, 1
	li a2, start_code_value

	li a3, stripes_per_char
    la t1, pixels_per_stripe
    lb t1, (t1)
    slli t1, t1, 1
    add s2, s2, t1

check_sum:
	# unit part
	lb t1, (a1)
	addi t1, t1, -48
	
	# decimal part
	addi a1, a1, -1
	lb t2, (a1)
	addi t2, t2, -48
	li t3, 10
	mul t2, t2, t3
	
	# sum
	add t3, t1, t2
	mul t1, t3, t5
	add a2, a2, t1

	# loop commands
	addi t5, t5, -1
	addi a1, a1, -1
	addi t4, t4, -2
	bnez t4, check_sum

	li t1, 103
	rem a2, a2, t1

	# li a2, 58
	li a3, 11

	la t4, pixels_per_stripe
	lb t4, (t4)
	li t5, stripes_per_char
	mul t4, t4, t5
	add s2, s2, t4
	mv a1, s2
	# li a3, stripes_per_char
	jal paint_character

read_pairs:
	# unit part
	lb t1, (s0)
	addi t1, t1, -48
	
	# decimal part
	addi s0, s0, -1
	lb t2, (s0)
	addi t2, t2, -48
	li t3, 10
	mul t2, t2, t3
	
	# sum
	add a2, t1, t2

	la t4, pixels_per_stripe
	lb t4, (t4)
	li t5, stripes_per_char
	mul t4, t4, t5
	add s2, s2, t4
	mv a1, s2
	# li a3, stripes_per_char
	jal paint_character

	# loop commands
	addi s0, s0, -1
	addi s1, s1, -2
	bnez s1, read_pairs

	# start code
	la t4, pixels_per_stripe
	lb t4, (t4)
	li t5, stripes_per_char
	mul t4, t4, t5
	add s2, s2, t4
	# mv s8, a1
	mv a1, s2
	li a3, 11
	li a2, 100
	jal paint_character
	
	# save img
	la t0, output_file_name
	sw t0, ImgInfo_file_name(a0)
	jal save_bmp
	mv a0, zero # success flag

create_img_exit:
	lw s2, 0(sp)
	lw s1, 4(sp)
	lw ra, 8(sp)
	addi sp, sp, 12
	jr ra

# =============================================================
generate_bmp:
	# a0 - file handle (preserved)
	la t0, output_file_name 
	sw t0, ImgInfo_file_name(a0) # store word
	la t0, bmpHeader
	sw t0, ImgInfo_header_bufor(a0)
	la t0, imgData
	sw t0, ImgInfo_img_begin_ptr(a0) 

	# mv t0, a0	# preserve imgInfo structure pointer
		
	# mv a1, t0
	mv t1, a0
	addi t1, t1, 12
	
	li t3, 768 #width
	sw t3, (t1)
	addi t1, t1, 4
	
	li t2, 64 #height
	sw t2, (t1)
	addi t1, t1, 4
	
	li t2, 0x900
	sw t2, (t1)
	addi t1, t1, 4
	
	li t2, 0x4d420000 
	sw t2, (t1)
	addi t1, t1, 4
	
	li t2, 0x00024036 
	sw t2, (t1)
	addi t1, t1, 8
	
	li t2, 0x36 # 54 - head size
	sw t2, (t1)
	addi t1, t1, 4
	
	li t2, 0x28
	sw t2, (t1)
	addi t1, t1, 4
	
	li t2, 0x300 
	sw t2, (t1)
	addi t1, t1, 4
	
	li t2, 0x40
	sw t2, (t1)
	addi t1, t1, 4
	
	li t2, 0x180001
	sw t2, (t1)
	addi t1, t1, 8
	
	li t2, 0x24000
	sw t2, (t1)
	addi t1, t1, 20
	


	li t3, MAX_IMG_SIZE
	li t2, 0xffffffff
paint_white:
	beqz t3, paint_white_exit
	addi t3, t3, -4
	sw t2, (t1)
	addi t1, t1, 4
	b paint_white

paint_white_exit:
	jr ra
