#include "blockcodes.h"

namespace fractal_compression {

	unsigned char* BlockCodes::blockcodesToBitStream(int maxblocksize, int maxwidth, int maxheight, int* streambitlength)
	{
		*streambitlength = 0;
		for (int i = 0; i < codeCount; i++)
		{
			(*streambitlength) += evaluateBlockLengthInBits(blockCodes[i]->blockSize, maxheight, maxwidth);
		}
		int l = minbytesforbits(*streambitlength);
		unsigned char* bitstream = new unsigned char[minbytesforbits(*streambitlength)];
		int bitstreamoffset = 0;
		for (int i = 0; i < codeCount; i++)
		{
			unsigned char blockLength = 0;
			unsigned char* block = blockCodes[i]->blockcodeToBitStream(maxblocksize, maxwidth, maxheight, &blockLength);
			copyBits(bitstream, block, &bitstreamoffset, 0, blockLength);
			delete[] block;
		}
		return bitstream;
	}

	BlockCodes::BlockCodes(unsigned char* bitstream, int maxblocksize, int maxwidth, int maxheight, int streambitlength)
	{
		codeCount = 0;
		int offset = 0;
		while (offset < streambitlength)
		{
			unsigned char sizecode = 0;
			int dummyoffset = 6;
			copyBits(&sizecode, bitstream, &dummyoffset, offset, 2);
			int blocksize = codeToBlockSize(sizecode, maxblocksize);
			offset += evaluateBlockLengthInBits(blocksize, maxheight, maxwidth);
			codeCount++;
		}
		blockCodes = new BlockCode*[codeCount];
		offset = 0;
		for (int i = 0; i < codeCount; i++)
		{
			unsigned char sizecode = 0;
			int dummyoffset = 6;
			copyBits(&sizecode, bitstream, &dummyoffset, offset, 2);
			int blocksize = codeToBlockSize(sizecode, maxblocksize);
			int blocklength = evaluateBlockLengthInBits(blocksize, maxheight, maxwidth);
			unsigned char* bitblock = new unsigned char[minbytesforbits(blocklength)];
			dummyoffset = 0;
			copyBits(bitblock, bitstream, &dummyoffset, offset, blocklength);
			offset += blocklength;
			blockCodes[i] = new BlockCode(bitblock, maxblocksize, maxwidth, maxheight);
			delete[] bitblock;
		}
	}

	void insertQuadNodeIntoArray(QuadNode* node, BlockCode** blockCodes, int* blockcounter)
	{
		for (int i = 0; i < 4; i++)
		{
			if (node->quadNodes[i]->blockCode == nullptr)
			{
				insertQuadNodeIntoArray(node->quadNodes[i], blockCodes, blockcounter);
			}
			else
			{
				blockCodes[*blockcounter] = node->quadNodes[i]->blockCode;
				(*blockcounter)++;
			}
		}
	}

	BlockCodes::BlockCodes(QuadTree* qtree)
	{
		blockCodes = new BlockCode*[qtree->codeCount];
		codeCount = qtree->codeCount;
		int blockcounter = 0;
		for (int i = 0; i < qtree->height * qtree->width; i++)
		{
			if (qtree->quadNodes[i]->blockCode == nullptr)
			{
				insertQuadNodeIntoArray(qtree->quadNodes[i], blockCodes, &blockcounter);
			}
			else
			{
				blockCodes[blockcounter] = qtree->quadNodes[i]->blockCode;
				blockcounter++;
			}
		}
	}

	BlockCodes::~BlockCodes() {
		for (int i = 0; i < codeCount; i++) {
			delete blockCodes[i];
		}
		delete[] blockCodes;
	}

	void BlockCodes::decompressQuad(int blockSize, int offsetx, int offsety, int* counter)
	{
		for (int i = 0; i < 2; i++)
		{
			for (int j = 0; j < 2; j++)
			{
				if (blockCodes[*counter]->blockSize == blockSize)
				{
					blockCodes[*counter]->yoffset = i * blockSize + offsety;
					blockCodes[*counter]->xoffset = j * blockSize + offsetx;
					(*counter)++;
				}
				else
				{
					decompressQuad(blockSize / 2, offsetx + j * blockSize,
						offsety + i * blockSize, counter);
				}
			}
		}
	}

	void BlockCodes::restoreOffsets(int startingBlockSize, int width, int height)
	{
		//needs more here
		int counter = 0;
		for (int i = 0; i < height; i += startingBlockSize)
		{
			for (int j = 0; j < width; j += startingBlockSize)
			{
				if (blockCodes[counter]->blockSize == startingBlockSize)
				{
					blockCodes[counter]->xoffset = j;
					blockCodes[counter]->yoffset = i;
					counter++;
				}
				else
				{
					decompressQuad(startingBlockSize / 2, j, i, &counter);
				}
			}
		}
	}
}