#pragma once
#include "fcutils.h"

namespace fractal_compression {

	class BlockCode {
	public:
		int xoffset;
		int yoffset;
		int xdoffset;
		int ydoffset;
		unsigned char transformType;
		int blockSize;
		short brightnessDifference;
		float contrastCoefficient;
		unsigned char* blockcodeToBitStream(int, int, int, unsigned char*);
		BlockCode();
		BlockCode(unsigned char* bitstream, int maxblocksize, int maxwidth, int maxheight);
	};

	unsigned char evaluateBlockLengthInBits(int blocksize, int maxheight, int maxwidth);
	unsigned char blockSizeToCode(int blocksize, int maxblocksize);
	int codeToBlockSize(unsigned char code, int maxblocksize);

}
