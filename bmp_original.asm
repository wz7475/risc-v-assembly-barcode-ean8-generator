#-------------------------------------------------------------------------------
#author: Rajmund Kozuszek
#date : 2022.05.05
#description : example RISC V program for reading, modifying and writing a BMP file 
#-------------------------------------------------------------------------------

# for purpose of this example I define structure which will contain important
# bitmap data for image read from the bmp file. Its C definition could be:
#	struct {
#		char* filename;		// wskazanie na nazwę pliku
#		unsigned char* hdrData; // wskazanie na bufor nagłówka pliku BMP
#		unsigned char* imgData; // wskazanie na pierwszy piksel obrazu w pamięci
#		int width, height;	// szerokość i wysokość obrazu w pikselach
#		int linebytes;		// rozmiar linii (wiersza) obrazu w bajtach
#	} imgInfo;

.eqv ImgInfo_fname	0
.eqv ImgInfo_hdrdat 	4
.eqv ImgInfo_imdat	8
.eqv ImgInfo_width	12
.eqv ImgInfo_height	16
.eqv ImgInfo_lbytes	20

# .eqv MAX_IMG_SIZE 	230400 # 320 x 240 x 3 (piksele)
.eqv MAX_IMG_SIZE 110592 # 768 x 48 

# more information about bmp format: https://en.wikipedia.org/wiki/BMP_file_format
.eqv BMPHeader_Size 54
.eqv BMPHeader_width 18
.eqv BMPHeader_height 22


.eqv system_OpenFile	1024
.eqv system_ReadFile	63
.eqv system_WriteFile	64
.eqv system_CloseFile	57

	.data
imgInfo: .space	24	# deskryptor obrazu

	.align 2		# wyrównanie do granicy słowa
dummy:		.space 2
bmpHeader:	.space	BMPHeader_Size

	.align 2
imgData: 	.space	MAX_IMG_SIZE

ifname:	.asciz "orange_and_black.bmp"
ofname: .asciz "result.bmp"

	.text
main:
	# wypełnienie deskryptora obrazu
	la a0, imgInfo 
	la t0, ifname
	sw t0, ImgInfo_fname(a0)
	la t0, bmpHeader
	sw t0, ImgInfo_hdrdat(a0)
	la t0, imgData
	sw t0, ImgInfo_imdat(a0)
	jal	read_bmp
	# bnez a0, main_failure
	
	# la a0, imgInfo
	# jal invert_red

	la a0, imgInfo
	la t0, ofname
	sw t0, ImgInfo_fname(a0)
	jal save_bmp

main_failure:
	li a7, 10
	ecall

read_bmp:
	mv t0, a0	# preserve imgInfo structure pointer
	
#open file					# save file handle for the future
	
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
fill_bmp_loop:
	beqz t3, fill_exit
	addi t3, t3, -4
	sw t2, (a1)
	addi a1, a1, 4
	b fill_bmp_loop

fill_exit:
	jr ra
	
# ============================================================================
# save_bmp - saves bmp file stored in memory to a file
# arguments:
#	a0 - address of ImgInfo structure containing description of the image`
# return value: 
#	a0 - zero if successful, error code in other cases

save_bmp:
	mv t0, a0	# preserve imgInfo structure pointer
	
#open file
	li a7, system_OpenFile
    lw a0, ImgInfo_fname(t0)	#file name 
    li a1, 1					#flags: 1-write file
    ecall
	
	blt a0, zero, wb_error
	mv t1, a0					# save file handle for the future
	
#write header
	li a7, system_WriteFile
	lw a1, ImgInfo_hdrdat(t0)
	li a2, BMPHeader_Size
	ecall
	
#write image data
	li a7, system_WriteFile
	mv a0, t1
	# compute image size (linebytes * height)
	lw a2, ImgInfo_lbytes(t0)
	lw a1, ImgInfo_height(t0)
	mul a2, a2, a1
	lw a1, ImgInfo_imdat(t0)
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


# ============================================================================
# set_pixel - sets the color of specified pixel
#arguments:
#	a0 - address of ImgInfo image descriptor
#	a1 - x coordinate
#	a2 - y coordinate - (0,0) - bottom left corner
#	a3 - 0RGB - pixel color
#return value: none
#remarks - a0, a1, a2 values are left unchanged

set_pixel:
	lw t1, ImgInfo_lbytes(a0)
	mul t1, t1, a2  # t1 = y * linebytes
	add t0, a1, a1
	add t0, t0, a1 	# t0 = x * 3
	add t0, t0, t1  # t0 is offset of the pixel

	lw t1, ImgInfo_imdat(a0) # address of image data
	add t0, t0, t1 	# t0 is address of the pixel
	
	#set new color
	sb   a3,(t0)		#store B
	srli a3, a3, 8
	sb   a3, 1(t0)		#store G
	srli a3, a3, 8
	sb   a3, 2(t0)		#store R

	jr ra

# ============================================================================
# get_pixel- returns color of specified pixel
#arguments:
#	a0 - address of ImgInfo image descriptor
#	a1 - x coordinate
#	a2 - y coordinate - (0,0) - bottom left corner
#return value:
#	a0 - 0RGB - pixel color
#remarks: a1, a2 are preserved

get_pixel:
	lw t1, ImgInfo_lbytes(a0)
	mul t1, t1, a2  # t1 = y * linebytes
	add t0, a1, a1
	add t0, t0, a1 	# t0 = x * 3
	add t0, t0, t1  # t0 is offset of the pixel

	lw t1, ImgInfo_imdat(a0) # address of image data
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

# ============================================================================

# ============================================================================
# invert_red - inverts red component in the input image
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

invert_red:
	addi sp, sp, -8
	sw ra, 4(sp)		#push ra
	sw s1, 0(sp)		#push s1
	mv s1, a0 			#preserve imgInfo for further use
	
	lw a2, ImgInfo_height(a0)
	addi a2, a2, -1		
	
invert_line:
	lw a1, ImgInfo_width(a0)
	addi a1, a1, -1
	
invert_pixel:
	jal get_pixel
	
	lui t0, 0x00FF0
	and a3, a0, t0
	sub a3, t0, a3
	
	slli a0, a0, 16
	srli a0, a0, 16
	or a3, a3, a0
	
	mv a0, s1
	jal set_pixel
	
	addi a1, a1, -1
	bge a1, zero, invert_pixel
	
	addi a2, a2, -1
	bge a2, zero, invert_line
	
	lw s1, 0(sp)		#pop s1
	lw ra, 4(sp)		#pop ra
	addi sp, sp, 8
	jr ra
