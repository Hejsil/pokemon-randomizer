#include <stdint.h>
#include <stddef.h>
#include "blz_wrapper.h"


unsigned char *BLZ_Decode(unsigned char *pak_buffer, unsigned int pak_len, unsigned int *output_len);
unsigned char *BLZ_Encode(unsigned char *raw_buffer, unsigned int raw_len, unsigned int *output_len, int mode);

int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
  return 0;
}
