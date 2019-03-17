#pragma once
#include "blockcode.h"
#include "fcutils.h"
#include "quadtree.h"

namespace fractal_compression {

	class BlockCodes{
	public:
		BlockCode** blockCodes;
		int codeCount;
		unsigned char* blockcodesToBitStream(int maxblocksize, int maxwidth, int maxheight, int* streambitlength);
		void restoreOffsets(int startingBlockSize, int width, int height);
		void decompressQuad(int blockSize, int offsetx, int offsety, int* counter);
		BlockCodes(unsigned char* bitstream, int maxblocksize, int maxwidth, int maxheight, int streambitlength);
		BlockCodes(QuadTree* qtree);
		~BlockCodes();
	};

}