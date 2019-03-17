#pragma once
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "quadtree.h"

namespace fractal_compression{

	QuadTree* fractalCompressionStep4(unsigned char* h_pixels, int sizeX, int sizeY, int startingBlockSize);

}