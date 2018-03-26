
unsigned char *BLZ_Decode(unsigned char *pak_buffer, unsigned int pak_len, unsigned int *output_len);
unsigned char *BLZ_Encode(unsigned char *raw_buffer, unsigned int raw_len, unsigned int *output_len, int mode);

#define BLZ_NORMAL    0          // normal mode
#define BLZ_BEST      1          // best mode
