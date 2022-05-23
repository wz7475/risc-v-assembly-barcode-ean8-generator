#	struct {
	#		char* filename;		// wskazanie na nazwę pliku
	#		unsigned char* hdrData; // wskazanie na bufor nagłówka pliku BMP
	#		unsigned char* imgData; // wskazanie na pierwszy piksel obrazu w pamięci
	#		int width, height;	// szerokość i wysokość obrazu w pikselach
	#		int linebytes;		// rozmiar linii (wiersza) obrazu w bajtach
	#	} imgInfo;

# bmp offsets declarations
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
# .eqv pixels_per_stripe 4

.eqv BYTES_PER_ROW 192

	.data
start_symbol: .half 0x69c
stop_symbol: .half 0x63a
codes_table: .half 
	0x6cc,
	0x66c,
	0x666,
	0x498,
	0x48c,
	0x44c,
	0x4c8,
	0x4c4,
	0x464,
	0x648,
	0x644,
	0x624,
	0x59c,
	0x4dc,
	0x4ce,
	0x5cc,
	0x4ec,
	0x4e6,
	0x672,
	0x65c,
	0x64e,
	0x6e4,
	0x674,
	0x76e,
	0x74c,
	0x72c,
	0x726,
	0x764,
	0x734,
	0x732,
	0x6d8,
	0x6c6,
	0x636,
	0x518,
	0x458,
	0x446,
	0x588,
	0x468,
	0x462,
	0x688,
	0x628,
	0x622,
	0x5b8,
	0x58e,
	0x46e,
	0x5d8,
	0x5c6,
	0x476,
	0x776,
	0x68e,
	0x62e,
	0x6e8,
	0x6e2,
	0x6ee,
	0x758,
	0x746,
	0x716,
	0x768,
	0x762,
	0x71a,
	0x77a,
	0x642,
	0x78a,
	0x530,
	0x50c,
	0x4b0,
	0x486,
	0x42c,
	0x426,
	0x590,
	0x584,
	0x4d0,
	0x4c2,
	0x434,
	0x432,
	0x612,
	0x650,
	0x7ba,
	0x614,
	0x47a,
	0x53c,
	0x4bc,
	0x49e,
	0x5e4,
	0x4f4,
	0x4f2,
	0x7a4,
	0x794,
	0x792,
	0x6de,
	0x6f6,
	0x7b6,
	0x578,
	0x51e,
	0x45e,
	0x5e8,
	0x5e2,
	0x7a8,
	0x7a2,
	0x5de


imgInfo: .space	24	# deskryptor obrazu

	.align 2		# wyrównanie do granicy słowa
dummy:		.space 2
bmpHeader:	.space	BMPHeader_Size

	.align 2
imgData: 	.space	MAX_IMG_SIZE

# -------------------------------- variables for user --------------------------------
text_to_code: .asciz "12345678"
output_file_name: .asciz "result.bmp"
pixels_per_stripe: .byte 1
#---------------------------------------------------------------
	.text
main:
	# wypełnienie deskryptora obrazu
	la a0, imgInfo  
	la t0, output_file_name 
	sw t0, ImgInfo_file_name(a0) # store word
	la t0, bmpHeader
	sw t0, ImgInfo_header_bufor(a0)
	la t0, imgData
	sw t0, ImgInfo_img_begin_ptr(a0) 

	jal	generate_bmp

	jal validate_width
	li a7, 1
	ecall

	# li a0, 1
	# jal get_code_value
	# li a7, 1
	# ecall


	# jal go_throuth_text



	
	la a0, imgInfo

	# li a3, 40
	# jal paint_stripe

	li a4, 10
	li a3, 400
loop:
	
	jal paint_stripe
	addi a3, a3, -1
	addi a4, a4, -1
	bge a4, zero, loop

	la a0, imgInfo
	la t0, output_file_name
	sw t0, ImgInfo_file_name(a0)
	jal save_bmp

	li a7, 10
	ecall
	
# validate_width
	# a0 - result (0 - ok, 1 - too_narrow)
validate_width:
	# t1 - img witdh
	# t0 - stripes_per_char
	# t2 - pixels_per_stripe
	# t4 - string length

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
	sb t2, (t2)
	mul t3, t0, t2 # t3 = pixels_per_stripe x stripes_per_char
	mul t3, t3, t4 # t3 = (pixels_per_stripe x stripes_per_char) x text_len
	sub t1, t1, t3 
	li a0, 0
	ble t1, zero, too_narrow_flag
	jr ra

too_narrow_flag:
	li a0, 1
	jr ra
	

# save_bmp - saves bmp file stored in memory to a file
	# arguments:
	#	a0 - address of ImgInfo structure containing description of the image`
	# return value: 
	#	a0 - zero if successful, error code in other cases

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


# set_pixel - sets the color of specified pixel
	#arguments:
	#	a0 - address of ImgInfo image descriptor
	#	a1 - x coordinate
	#	a2 - y coordinate - (0,0) - bottom left corner
	#	a3 - 0RGB - pixel color
	#return value: none
	#remarks - a0, a1, a2 values are left unchanged

set_pixel:
	lw t1, ImgInfo_line_bytes(a0)
	mul t1, t1, a2  # t1 = y * linebytes
	add t0, a1, a1
	add t0, t0, a1 	# t0 = x * 3
	add t0, t0, t1  # t0 is offset of the pixel

	lw t1, ImgInfo_img_begin_ptr(a0) # address of image data
	add t0, t0, t1 	# t0 is address of the pixel
	
	#set new color
	sb   a3,(t0)		#store B
	srli a3, a3, 8
	sb   a3, 1(t0)		#store G
	srli a3, a3, 8
	sb   a3, 2(t0)		#store R

	jr ra

set_pixel_black:
	lw t1, ImgInfo_line_bytes(a0)
	mul t1, t1, a2  # t1 = y * linebytes
	add t0, a1, a1
	add t0, t0, a1 	# t0 = x * 3
	add t0, t0, t1  # t0 is offset of the pixel

	lw t1, ImgInfo_img_begin_ptr(a0) # address of image data
	add t0, t0, t1 	# t0 is address of the pixel
	
	li t3, 0x00000000
	#set new color
	sb   t3,(t0)		#store B
	srli t3, t3, 8
	sb   t3, 1(t0)		#store G
	srli t3, t3, 8
	sb   t3, 2(t0)		#store R

	jr ra




# get_pixel- returns color of specified pixel
	#arguments:
	#	a0 - address of ImgInfo image descriptor
	#	a1 - x coordinate
	#	a2 - y coordinate - (0,0) - bottom left corner
	#return value:
	#	a0 - 0RGB - pixel color
	#remarks: a1, a2 are preserved

get_pixel:
	lw t1, ImgInfo_line_bytes(a0)
	mul t1, t1, a2  # t1 = y * linebytes
	add t0, a1, a1
	add t0, t0, a1 	# t0 = x * 3
	add t0, t0, t1  # t0 is offset of the pixel

	lw t1, ImgInfo_img_begin_ptr(a0) # address of image data
	add t0, t0, t1 	# t0 is address of the pixel

	#get color
	lbu a0,(t0)		#load B
	lbu t1,1(t0)		#load G
	slli t1,t1,8
	or a0, a0, t1
	lbu t1,2(t0)		#load R
    slli t1,t1,16
	or a0, a0, t1
					
	jr ra


# paint_stripe - paint vertical stripe
	#arguments:
	#	a0 - address of ImgInfo image descriptor
	#return value:
	#	none

	# for (int y = imgInfo->height-1; y >= 0; --y)
	#   for (int x = imgInfo->width-1; x >= 0; --x)
	#   {
	#     unsigned rgb = get_pixel(imgInfo, x, y);
	#     rgb = (rgb & 0x0000FFFF) | (0x00FF0000 - (rgb & 0x00FF0000));
	#     set_pixel(imgInfo, x, y, rgb);
	#   }
paint_stripe:
	# a3 - offset from the end - input, 
	addi sp, sp, -4
	sw ra, 0(sp)		#push ra

	la t6, pixels_per_stripe
	lb t6, (t6)
width_loop:
	
	lw a2, ImgInfo_height(a0)
	addi a2, a2, -1		

	# a1 - address of right-most pixel
	lw a1, ImgInfo_width(a0)
	addi a1, a1, -1
	sub a1, a1, a3
	addi a1, a1, 1
	# sub a1, a1, t6
vertical_loop:

	jal set_pixel_black


	addi a2, a2, -1
	bge a2, zero, vertical_loop # vertical loop

	addi t6, t6, -1
	# addi a3, a3, -1
	bge t6, zero, width_loop
	

	lw ra, 0(sp)		#pop ra
	addi sp, sp, 4
	jr ra


get_code_value:
	# a0 - input - index of the code value
	# a0 - output - loaded value 
	la t0, codes_table
	slli a0, a0, 1 # index * 2 (halfword - 2 bytes)
	add t0, t0, a0
	lh t1, (t0)

	# loop - read 11 bits
	li t0, 10
	li a7, 1 # to delete after calling own function
bits_loop:
	andi a0, t1, 1

	# to swap with set black_white
	ecall

	addi t0, t0, -1 # counter--
	
	srli t1, t1, 1
	bnez t0, bits_loop

	jr ra
	


go_throuth_text:
	la t0, text_to_code
text_lopp:
	lb t1, (t0)
	addi t0, t0, 1
	
	bnez t1, text_lopp
	
	addi t0, t0, -2
	# now we have pointer for last character
	la t4, text_to_code
	sub t4, t0, t4
	addi t4, t4, 1

read_pairs:
	# unit part
	lb t1, (t0)
	addi t1, t1, -48
	
	# decimal part
	addi t0, t0, -1
	lb t2, (t0)
	addi t2, t2, -48
	li t3, 10
	mul t2, t2, t3
	
	# sum
	add a0, t1, t2
	li a7, 1
	ecall

	# loop commands
	addi t0, t0, -1
	addi t4, t4, -2
	bnez t4, read_pairs

	jr ra

generate_bmp:
	mv t0, a0	# preserve imgInfo structure pointer
		
	mv a1, t0
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