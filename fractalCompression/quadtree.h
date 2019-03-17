#pragma once
#include "blockcode.h"

namespace fractal_compression {

	class QuadNode
	{
	public:
		int blocksize;
		BlockCode* blockCode;
		QuadNode** quadNodes;
		QuadNode(int);
		~QuadNode();
		BlockCode* obtainNode(int offseti, int offsetj, int blocksize);
	};

	class QuadTree
	{
		int startingBlockSize;
	public:
		int width;
		int height;
		int codeCount;
		QuadNode** quadNodes;
		QuadTree(int, int, int);
		BlockCode* obtainNodeStart(int offsety, int offsetx, int blocksize);
		~QuadTree();
	};

}
