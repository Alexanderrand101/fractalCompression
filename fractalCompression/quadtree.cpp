#include "quadtree.h"

namespace fractal_compression {

	QuadNode::QuadNode(int blocksize) {
		this->blocksize = blocksize;
		blockCode = nullptr;
		quadNodes = nullptr;
	}

	QuadTree::QuadTree(int height, int width, int startingBlockSize) {
		this->height = height;
		this->width = width;
		this->startingBlockSize = startingBlockSize;
		codeCount = 0;
		quadNodes = new QuadNode*[height * width];
		for (int i = 0; i < height * width; i++) quadNodes[i] = nullptr;
	}

	BlockCode* QuadNode::obtainNode(int offseti, int offsetj, int blocksize)
	{
		if (this->blocksize == blocksize)
		{
			if (blockCode == nullptr) blockCode = new BlockCode();
			return blockCode;
		}
		else
		{
			if (quadNodes == nullptr)
			{
				quadNodes = new QuadNode*[4];
				for (int i = 0; i < 4; i++) quadNodes[i] = nullptr;
			}
			int newblocksize = this->blocksize / 2;
			int i = offseti / newblocksize;
			int j = offsetj / newblocksize;
			if (quadNodes[i * 2 + j] == nullptr)
			{
				quadNodes[i * 2 + j] = new QuadNode(newblocksize);
			}
			return quadNodes[i * 2 + j]->obtainNode(offseti % newblocksize,
				offsetj % newblocksize, blocksize);
		}
	}

	BlockCode* QuadTree::obtainNodeStart(int offsety, int offsetx, int blocksize)
	{
		int i = offsety / startingBlockSize;
		int j = offsetx / startingBlockSize;
		if (quadNodes[i * width + j] == nullptr)
		{
			quadNodes[i * width + j] = new QuadNode(startingBlockSize);
		}
		return quadNodes[i * width + j]->obtainNode(offsety % startingBlockSize,
			offsetx % startingBlockSize, blocksize);
	}

	QuadTree::~QuadTree()
	{
		for (int i = 0; i < height * width; i++)
			if (quadNodes[i] != nullptr)
				delete quadNodes[i];
		delete[] quadNodes;
	}

	QuadNode::~QuadNode()
	{
		if (blockCode == nullptr) {
			for (int i = 0; i < 4; i++)
				if (quadNodes[i] != nullptr)
					delete quadNodes[i];
		}
		if (quadNodes != nullptr)
			delete[] quadNodes;
	}
}