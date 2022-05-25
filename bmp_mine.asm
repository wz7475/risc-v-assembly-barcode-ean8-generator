#	struct {
	#		char* filename;		// wskazanie na nazwę pliku
	#		unsigned char* hdrData; // wskazanie na bufor nagłówka pliku BMP
	#		unsigned char* imgData; // wskazanie na pierwszy piksel obrazu w pamięci
	#		int width, height;	// szerokość i wysokość obrazu w pikselach
	#		int linebytes;		// rozmiar linii (wiersza) obrazu w bajtach
	#	} imgInfo;

# bmp offsets declarations
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
text_to_code: .asciz "0200"
output_file_name: .asciz "result.bmp"
pixels_per_stripe: .byte 2
#---------------------------------------------------------------
	.text
main:
	# wypełnienie deskryptora obrazu
	la a0, imgInfo  
	

	jal	generate_bmp

	# jal validate_width
	# li a7, 1
	# ecall
	# la a0, imgInfo
	# li a2, 0
	# li a1, 100
	# jal paint_character

	# li a2, 2
	# li a1, 111
	# jal paint_character

	la a0, imgInfo
	la a1, text_to_code
	jal go_throuth_text



# paint stripes	
	# la a0, imgInfo
	# li a1, 0
	# jal paint_stripe

	# addi a1, a1, 1
	# jal paint_stripe


# save img
	la a0, imgInfo
	la t0, output_file_name
	sw t0, ImgInfo_file_name(a0)
	jal save_bmp

# exit
	li a7, 10
	ecall
	
#================================================================
validate_width:
	# t1 - img witdh
	# t0 - stripes_per_char
	# t2 - pixels_per_stripe
	# t4 - string length
	# validate_width
	# a0 - result (0 - ok, 1 - too_narrow)

	# calc text_to_code length
	mv t4, zero
	la t0, text_to_code
calc_string_len:
	lbu t1, (t0)
	addi t4, t4, 1
	addi t0, t0, 1
	bne t1, zero, calc_string_len
	addi t4, t4, -1

	la t0, imgInfo
	lw t1, ImgInfo_width(t0)
	li t0, stripes_per_char
	# li t2, pixels_per_stripe
	la t2, pixels_per_stripe
	lb t2, (t2)
	mul t3, t0, t2 # t3 = pixels_per_stripe x stripes_per_char
	mul t3, t3, t4 # t3 = (pixels_per_stripe x stripes_per_char) x text_len
	sub t1, t1, t3 
	li a0, 0
	ble t1, zero, too_narrow_flag
	jr ra

too_narrow_flag:
	li a0, 1
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

	la t2, pixels_per_stripe
	lb t2, (t2)

	lw t4, ImgInfo_height(a0)
	addi t4, t4, -1

	lw t5, ImgInfo_width(a0)
	addi t5, t5, -1

	lw t6, ImgInfo_img_begin_ptr(a0) # address of image data
	lw a3, ImgInfo_line_bytes(a0)

	mv a4, a1 # save a1 - offset


width_loop:
	mv a2, t4	
	mv a1, t5	# a1 - address of right-most pixel
	sub a1, a1, a4

vertical_loop:
	mv t1, a3
	mul t1, t1, a2  # t1 = y * linebytes
	add t0, a1, a1
	add t0, t0, a1 	# t0 = x * 3
	add t0, t0, t1  # t0 is offset of given pixel

	
	add t0, t0, t6 	# t0 is address of the pixel
	
	li t3, 0x00000000
	#set new color
	sb   t3,(t0)		#store B
	srli t3, t3, 8
	sb   t3, 1(t0)		#store G
	srli t3, t3, 8
	sb   t3, 2(t0)		#store R

	addi a2, a2, -1
	bge a2, zero, vertical_loop # vertical loop

	addi t2, t2, -1
	addi a4, a4, 1
	bgt t2, zero, width_loop
	
	jr ra

# =============================================================
paint_character:
	# a0 - file handle
	# a1 - offest for character
	# a2 - input - index of the code value
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

	la s2, pixels_per_stripe
	lb s2, (s2)
	add s2, s2, a1

	# loop - read 11 bits
	li s0, stripes_per_char

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
go_throuth_text:
	# a0 - file handle 
	# a1 - text_to_code
	# so - pointer for last character
	# s1 - len of text_to_code
	addi sp, sp, -4
	sw ra, 0(sp)
	mv t0, a1 # preserve offset

	la t1, pixels_per_stripe
	lb, t1, (t1) # t1 - pixel_per_stripe

	li t2, 10 # silent zone - 10 * pixels_per_stripe
	mul t1, t1, t2
	mv s9, t1

text_lopp:
	lb t1, (a1)
	addi a1, a1, 1
	
	bnez t1, text_lopp
	
	addi s0, a1, -2
	# now we have pointer for last character - s0

	# s1 - len of text to code
	sub s1, s0, t0
	addi s1, s1, 1

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
	add s9, s9, t4
	mv a1, s9
	la a0, imgInfo	
	jal paint_character

	# loop commands
	addi s0, s0, -1
	addi s1, s1, -2
	bnez s1, read_pairs

	lw ra, 0(sp)
	addi sp, sp, 4
	jr ra

# =============================================================
generate_bmp:
	la t0, output_file_name 
	sw t0, ImgInfo_file_name(a0) # store word
	la t0, bmpHeader
	sw t0, ImgInfo_header_bufor(a0)
	la t0, imgData
	sw t0, ImgInfo_img_begin_ptr(a0) 

	# mv t0, a0	# preserve imgInfo structure pointer
		
	# mv a1, t0
	mv a1, a0
	addi a1, a1, 12
	
	li t3, 768 #width
	sw t3, (a1)
	addi a1, a1, 4
	
	li t2, 64 #height
	sw t2, (a1)
	addi a1, a1, 4
	
	li t2, 0x900 #2304 = 48 * 48
	sw t2, (a1)
	addi a1, a1, 4
	
	li t2, 0x4d420000 # 1 296 171 008 ??
	sw t2, (a1)
	addi a1, a1, 4
	
	li t2, 0x00024036 # 147 510
	sw t2, (a1)
	addi a1, a1, 8
	
	li t2, 0x36 # 54 - head size
	sw t2, (a1)
	addi a1, a1, 4
	
	li t2, 0x28 # 40
	sw t2, (a1)
	addi a1, a1, 4
	
	li t2, 0x300 
	sw t2, (a1)
	addi a1, a1, 4
	
	li t2, 0x40
	sw t2, (a1)
	addi a1, a1, 4
	
	li t2, 0x180001
	sw t2, (a1)
	addi a1, a1, 8
	
	li t2, 0x24000
	sw t2, (a1)
	addi a1, a1, 20
	


	li t3, MAX_IMG_SIZE
	li t2, 0xffffffff
paint_white:
	beqz t3, paint_white_exit
	addi t3, t3, -4
	sw t2, (a1)
	addi a1, a1, 4
	b paint_white

paint_white_exit:
	jr ra
