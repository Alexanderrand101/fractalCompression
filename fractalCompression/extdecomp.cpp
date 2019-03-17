#include "extdecomp.h"
#include "decompressor.h"

using namespace fractal_compression;

unsigned char* externalFraclalDecompression(unsigned char* bitstream, int width, int height, int bitStreamSize) {
	int paddedWidthDec = roundToDivisibleBy(width, 16);
	int paddedHeightDec = roundToDivisibleBy(height, 16);
	BlockCodes* codes = new BlockCodes(bitstream, 16, paddedWidthDec, paddedHeightDec, bitStreamSize);
	codes->restoreOffsets(16, paddedWidthDec, paddedHeightDec);
	unsigned char* paddedPixels = fractalDecompressionStep3(codes, paddedWidthDec, paddedHeightDec);
	unsigned char* pixels = croptoSize(paddedPixels, paddedWidthDec, paddedHeightDec, width, height);
	delete codes;
	delete paddedPixels;
	return pixels;
}