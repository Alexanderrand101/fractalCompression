#include "extcomp.h"
#include "compressor.h"
#include "blockcodes.h"

using namespace fractal_compression;

unsigned char* externalFraclalCompression(unsigned char* pixels, int width, int height, int* bitStreamSize) {
	int paddedWidth = roundToDivisibleBy(width, 16);
	int paddedHeight = roundToDivisibleBy(height, 16);
	unsigned char* paddedPixels = padtoSize(pixels, width, height, paddedWidth, paddedHeight);
	QuadTree* tree = fractalCompressionStep4(paddedPixels, paddedWidth, paddedHeight, 16);
	BlockCodes* codes = new BlockCodes(tree);
	*bitStreamSize = 0;
	unsigned char* bitStream = codes->blockcodesToBitStream(16, paddedWidth, paddedHeight, bitStreamSize);
	delete tree;
	delete codes;
	delete[] paddedPixels;
	return bitStream;
}