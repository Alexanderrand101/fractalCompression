#include "blockcode.h"

namespace fractal_compression {

	BlockCode::BlockCode()
	{
		xoffset = 0;
		yoffset = 0;
		xdoffset = 0;
		ydoffset = 0;
		transformType = 0;
		blockSize = 0;
		brightnessDifference = 0;
		contrastCoefficient = 0;
	}

	unsigned char evaluateBlockLengthInBits(int blocksize, int maxheight, int maxwidth)
	{
		return 5 + evaluate(maxheight / blocksize) + evaluate(maxwidth / blocksize) + (sizeof(short) + sizeof(float)) * 8;
	}

	unsigned char blockSizeToCode(int blocksize, int maxblocksize)
	{
		return evaluate(maxblocksize / blocksize) - 1;
	}

	unsigned char* BlockCode::blockcodeToBitStream(int maxblocksize, int maxwidth, int maxheight, unsigned char* length)
	{
		*length = evaluateBlockLengthInBits(blockSize, maxheight, maxwidth);
		unsigned char* bitstream = new unsigned char[minbytesforbits(*length)];
		unsigned char sizecode = blockSizeToCode(blockSize, maxblocksize);
		*bitstream = sizecode << 6;
		*bitstream |= transformType << 3;
		int bitstreamoffset = 5;
		int xbitoffset = 32 - evaluate(maxwidth / blockSize);
		int ybitoffset = 32 - evaluate(maxheight / blockSize);
		int compoffdx = xdoffset / blockSize;
		int compoffdy = ydoffset / blockSize;
		voodo((unsigned char*)&compoffdx);
		voodo((unsigned char*)&compoffdy);
		copyBits(bitstream, (unsigned char*)&compoffdx, &bitstreamoffset, xbitoffset, 32 - xbitoffset);
		copyBits(bitstream, (unsigned char*)&compoffdy, &bitstreamoffset, ybitoffset, 32 - ybitoffset);
		copyBits(bitstream, (unsigned char*)&(brightnessDifference), &bitstreamoffset, 0, 16);//can compress this to 9 bits
		copyBits(bitstream, (unsigned char*)&(contrastCoefficient), &bitstreamoffset, 0, 32);
		return bitstream;
	}

	int codeToBlockSize(unsigned char code, int maxblocksize)
	{
		return maxblocksize / (1 << code);
	}

	BlockCode::BlockCode(unsigned char* bitstream, int maxblocksize, int maxwidth, int maxheight) :BlockCode()
	{
		blockSize = codeToBlockSize(*bitstream >> 6, maxblocksize);
		transformType = (*bitstream & 0x3F) >> 3;
		int dummyoffset = 0;
		int bitstreamoffset = 5;
		int compoffdx = 0;
		int compoffdy = 0;
		int xbitoffset = 32 - evaluate(maxwidth / blockSize);
		int ybitoffset = 32 - evaluate(maxheight / blockSize);
		short brightnessDifference = 0;
		float contrastCoeff = 0;
		copyBits((unsigned char*)&compoffdx, bitstream, &xbitoffset, bitstreamoffset, 32 - xbitoffset);
		bitstreamoffset += evaluate(maxwidth / blockSize);
		voodo((unsigned char*)&compoffdx);
		compoffdx *= blockSize;
		copyBits((unsigned char*)&compoffdy, bitstream, &ybitoffset, bitstreamoffset, 32 - ybitoffset);
		bitstreamoffset += evaluate(maxheight / blockSize);
		voodo((unsigned char*)&compoffdy);
		compoffdy *= blockSize;
		copyBits((unsigned char*)&brightnessDifference, bitstream, &dummyoffset, bitstreamoffset, 16);
		bitstreamoffset += 16;
		dummyoffset = 0;
		copyBits((unsigned char*)&contrastCoeff, bitstream, &dummyoffset, bitstreamoffset, 32);
		bitstreamoffset += 32;
		dummyoffset = 0;
		xdoffset = compoffdx;
		ydoffset = compoffdy;
		this->brightnessDifference = brightnessDifference;
		contrastCoefficient = contrastCoeff;
	}

}