
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

// FractalCompressorBasic.cpp : Defines the entry point for the console application.
//

#include <fstream>
#include <iostream>
#include <iomanip>
#include <Windows.h>

typedef struct HEADEROFFCOMFILE //todo. correct the size
{
	int blueDomainCount;
	int redDomainCount;
	int greenDomainCount;
	//int startingblocksize;
};

typedef struct BLOCKCODE //todo. correct the size
{
	int xoffset;
	int yoffset;
	int xdoffset;
	int ydoffset;
	byte transformType;
	int blockSize;
	float brightnessDifference;
	float contrastCoefficient;
};

typedef struct COMPRESSEDBLOCKCODE //todo. correct the size
{
	int xdoffset;
	int ydoffset;
	byte transformType;
	int blockSize;
	float brightnessDifference;
	float contrastCoefficient;
};

typedef struct QUADNODE
{
	int blocksize;
	BLOCKCODE* blockCode;
	QUADNODE** quadNodes;
};

typedef struct QUADTREE
{
	int width;
	int height;
	int startingBlockSize;
	QUADNODE** quadNodes;
};

byte* somebytes;
int valoffset = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);

byte* padtoSize(byte* pixels, int oldx, int oldy, int newx, int newy) 
{
	byte* newPixels = new byte[newx * newy];
	for (int i = 0; i < oldy; i++)
	{
		for (int j = 0; j < oldx; j++) newPixels[i * newx + j] = pixels[i * oldx + j];
		for (int j = oldx; j < newx; j++) newPixels[i * newx + j] = 0;
	}
	for (int i = oldy; i < newy; i++)
		for (int j = 0; j < newx; j++)
			newPixels[i * newx + j] = 0;
	return newPixels;
}

//first draft. needs work. also need to be able to select filetype.
int LoadPixels(const char* fname, byte** reftopixels, BITMAPFILEHEADER* fheader, BITMAPINFOHEADER* iheader)
{
	std::ifstream file(fname, std::ios::binary);
	if (!file)
	{
		std::cout << "can't open file " << fname << "\n";
		return 1;
	}
	file.read((char*)fheader, sizeof(BITMAPFILEHEADER));
	file.read((char*)iheader, sizeof(BITMAPINFOHEADER));
	if (fheader->bfType != 0x4D42)
	{
		std::cout << "file " << fname << "is not a bmp file\n";
		return 2;
	}
	somebytes = new byte[fheader->bfOffBits - valoffset];
	file.read((char*)somebytes, fheader->bfOffBits - valoffset);
	*reftopixels = new byte[iheader->biSizeImage];//чет фигня какаято
	file.read((char*)*reftopixels, iheader->biSizeImage);
	return 0;
}

void SavePixels(const char* fname, byte* pixels, BITMAPFILEHEADER* fheader, BITMAPINFOHEADER* iheader)
{
	std::ofstream file(fname, std::ios::binary);
	file.write((char*)fheader, sizeof(BITMAPFILEHEADER));
	file.write((char*)iheader, sizeof(BITMAPINFOHEADER));
	file.write((char*)somebytes, fheader->bfOffBits - valoffset);
	int padsize = (4 - (iheader->biWidth * 3) % 4);
	if (padsize == 4) padsize = 0;
	byte padding = 0;
	for (int i = 0; i < iheader->biHeight; i++)
	{
		file.write((char*)pixels + i * iheader->biWidth * 3, (iheader->biWidth * 3));
		for (int j = 0; j < padsize; j++)
			file.write((char*)&padding, sizeof(byte));
	}
}

byte* rotate90(byte* block, int n)
{
	byte* newblock = new byte[n * n];
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			newblock[i * n + j] = block[n * (n - j - 1) + i];
		}
	}
	return newblock;
}

byte* rotate180(byte* block, int n)
{
	byte* newblock = new byte[n * n];
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			newblock[i * n + j] = block[n * (n - i - 1) + n - j - 1];
		}
	}
	return newblock;
}

byte* rotate270(byte* block, int n)
{
	byte* newblock = new byte[n * n];
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			newblock[i * n + j] = block[j * n + n - i - 1];
		}
	}
	return newblock;
}

byte* flipHorizontal(byte* block, int n)
{
	byte* newblock = new byte[n * n];
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			newblock[i * n + j] = block[i * n + n - j - 1];
		}
	}
	return newblock;
}

byte* flipVertical(byte* block, int n)
{
	byte* newblock = new byte[n * n];
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			newblock[i * n + j] = block[(n - i - 1) * n + j];
		}
	}
	return newblock;
}

byte* flipAlongMainDiagonal(byte* block, int n)
{
	byte* newblock = new byte[n * n];;
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			newblock[i * n + j] = block[j * n + i];
		}
	}
	return newblock;
}

byte* flipAlongSubDiagonal(byte* block, int n)
{
	byte* newblock = new byte[n * n];
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			newblock[i * n + j] = block[(n - j - 1) * n + n - i - 1];
		}
	}
	return newblock;
}

byte* downsize(byte* pixels, int xoffset, int yoffset, int n, int width)
{
	int m = n / 2;
	byte* newblock = new byte[m * m];
	for (int i = 0; i < m; i++)
	{
		for (int j = 0; j < m; j++)
		{
			newblock[i * m + j] = (pixels[(yoffset + 2 * i) * width + xoffset + 2 * j] + pixels[(yoffset + 2 * i) * width + xoffset + 2 * j + 1] +
				pixels[(yoffset + 2 * i + 1) * width + xoffset + 2 * j] + pixels[(yoffset + 2 * i + 1)* width + xoffset + 2 * j + 1]) / 4;
		}
	}
	return newblock;
}


void compareAndUpdate(double* minDifference, double difference, int* ki, int k, int* li, int l, byte* affineTransform, byte caffineTransform)
{
	if (difference < *minDifference)
	{
		*minDifference = difference;
		*ki = k;
		*li = l;
		*affineTransform = caffineTransform;
	}
}

void free2Dimensions(byte** ptr, int n)
{
	for (int i = 0; i < n; i++)
	{
		delete[] ptr[i];
	}
	delete ptr;
}


void calcCoeffs(byte* block, byte*  pixels, int offsetX, int offsetY, int n, float* brightDiffValue, float* contrastCoefficient, int width)
{
	int pval = 0;
	int dval = 0;
	float a = 0;
	float b = 0;
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			pval += pixels[(offsetY + i) * width + offsetX + j];
			dval += block[i * n + j];
		}
	}
	float daverage = ((float)dval) / (n*n);
	float paverage = ((float)pval) / (n*n);
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			a += (block[i * n + j] - daverage)*(pixels[(offsetY + i) * width + offsetX + j] - paverage);
			b += (block[i * n + j] - daverage)*(block[i * n + j] - daverage);
		}
	}
	if (a - 0.001 < 0 && b - 0.001 < 0) {
		a = 1;
		b = 1;
	}
	*contrastCoefficient = a / b;
	*brightDiffValue = (paverage - (a / b) * daverage);
}

double difference(byte* block, byte*  pixels, int offsetX, int offsetY, int n, int width)
{
	double difference = 0;
	float brightDiffValue = 0;
	float contrastCoefficient = 0;
	calcCoeffs(block, pixels, offsetX, offsetY, n, &brightDiffValue, &contrastCoefficient, width);
	for (int i = 0; i < n; i++)
	{
		for (int j = 0; j < n; j++)
		{
			difference += pow(block[i * n + j] * contrastCoefficient + brightDiffValue - pixels[(offsetY + i) * width +  offsetX + j], 2);
		}
	}
	return difference;
}




int calculateDomainSize()
{
	return 0;//todo this thing later
}

void colorChannelSeparator(byte* pixels, byte* blue, byte* green, byte* red, int width, int height)
{
	for (int i = 0; i < height; i++)
	{
		for (int j = 0; j < width; j++)
		{
			blue[i * width + j] = pixels[i * width * 3 + j * 3];
			green[i * width + j] = pixels[i * width * 3 + j * 3 + 1];
			red[i * width + j] = pixels[i * width * 3 + j * 3 + 2];
		}
	}
}

void colorChannelCombinator(byte* pixels, byte* blue, byte* green, byte* red, int width, int height)
{
	for (int i = 0; i < height; i++)
	{
		for (int j = 0; j < width; j++)
		{
			pixels[i * width * 3 + j * 3] = blue[i * width + j];
			pixels[i * width * 3 + j * 3 + 1] = green[i * width + j];
			pixels[i * width * 3 + j * 3 + 2] = red[i * width + j];
		}
	}
}

void embed(byte* pixels, byte* toEmbed, int offset, int width, int blocksize)
{
	for (int i = 0; i < blocksize; i++)
	{
		for (int j = 0; j < blocksize; j++)
		{
			pixels[offset + i * width + j] = toEmbed[i * blocksize + j];
		}
	}
}

__device__ void calcCoeffsDevice2(byte* pixels, byte* domainPixels, int width, int offsetPixels, int offsetDomain, int blocksize, float* brightDiffValue, float* contrastCoefficient,
	float paverage, float daverage, float b, float* snapshots, int snapshotoffset)
{
	float a = 0;
	for (int i = 0; i < blocksize; i++)
	{
		for (int j = 0; j < blocksize; j++)
		{
			a += (domainPixels[offsetDomain + i * width + j] - daverage)*(pixels[offsetPixels + i * width + j] - paverage);
		}
	}
	*contrastCoefficient = a / b;
	*brightDiffValue = (paverage - (a / b) * daverage);
	snapshots[snapshotoffset * 9] = snapshotoffset;
	snapshots[snapshotoffset * 9 + 1] = width;
	snapshots[snapshotoffset * 9 + 2] = a;
	snapshots[snapshotoffset * 9 + 3] = offsetPixels;
	snapshots[snapshotoffset * 9 + 4] = offsetDomain;
	snapshots[snapshotoffset * 9 + 5] = *brightDiffValue;
	snapshots[snapshotoffset * 9 + 6] = *contrastCoefficient;
	snapshots[snapshotoffset * 9 + 7] = daverage;
	snapshots[snapshotoffset * 9 + 8] = b;
}

void calcCoeffsHost2(byte* pixels, byte* domainPixels, int width, int offsetPixels, int offsetDomain, int blocksize, float* brightDiffValue, float* contrastCoefficient,
	float paverage, float daverage, float b)
{
	float a = 0;
	for (int i = 0; i < blocksize; i++)
	{
		for (int j = 0; j < blocksize; j++)
		{
			a += (domainPixels[offsetDomain + i * width + j] - daverage)*(pixels[offsetPixels + i * width + j] - paverage);
		}
	}
	*contrastCoefficient = a / b;
	*brightDiffValue = (paverage - (a / b) * daverage);
}

__device__ float calcDiff2(byte* pixels, byte* domainPixels, int width, int offsetPixels, int offsetDomain, int blocksize,
	float paverage, float daverage, float b, float* snapshots, int snapshotoffset)
{
	float difference = 0;
	float brightDiffValue = 0;
	float contrastCoefficient = 0;
	calcCoeffsDevice2(pixels, domainPixels, width, offsetPixels, offsetDomain, blocksize, &brightDiffValue, &contrastCoefficient, paverage, daverage, b, snapshots, snapshotoffset);
	/*snapshots[snapshotoffset * 9] = snapshotoffset;
	snapshots[snapshotoffset * 9 + 1] = width;
	snapshots[snapshotoffset * 9 + 2] = blocksize;
	snapshots[snapshotoffset * 9 + 3] = offsetPixels;
	snapshots[snapshotoffset * 9 + 4] = offsetDomain;
	snapshots[snapshotoffset * 9 + 5] = brightDiffValue;
	snapshots[snapshotoffset * 9 + 6] = contrastCoefficient;
	snapshots[snapshotoffset * 9 + 7] = daverage;
	snapshots[snapshotoffset * 9 + 8] = b;*/
	for (int i = 0; i < blocksize; i++)
	{
		for (int j = 0; j < blocksize; j++)
		{
			difference += pow(domainPixels[offsetDomain + i * width + j] * contrastCoefficient + brightDiffValue - pixels[offsetPixels + i * width + j], 2);
		}
	}
	return difference;
}

float calcDiff2Host(byte* pixels, byte* domainPixels, int width, int offsetPixels, int offsetDomain, int blocksize,
	float paverage, float daverage, float b)
{
	float difference = 0;
	float brightDiffValue = 0;
	float contrastCoefficient = 0;
	calcCoeffsHost2(pixels, domainPixels, width, offsetPixels, offsetDomain, blocksize, &brightDiffValue, &contrastCoefficient, paverage, daverage, b);
	for (int i = 0; i < blocksize; i++)
	{
		for (int j = 0; j < blocksize; j++)
		{
			difference += pow(domainPixels[offsetDomain + i * width + j] * contrastCoefficient + brightDiffValue - pixels[offsetPixels + i * width + j], 2);
		}
	}
	return difference;
}

__global__ void pickDomain(byte* pixels, byte* domainPixels, int n, int m, int blocksize, int pixelOffset, float* domainAverage,
	float* domainCoeffB, float paverage, float* resultArray, float* snapshots)
{
	int affineOffset = n * m * blocksize * blocksize;
	int affineOffsetOfSnap = n * m;
	int domainOffset;
	for (int affineTransf = 0; affineTransf < 8; affineTransf++)
	{
		domainOffset = affineOffset * affineTransf + blockIdx.y * m * blocksize * blocksize + blockIdx.x * blocksize;
		resultArray[affineTransf * n * m + blockIdx.y * m + blockIdx.x] = calcDiff2(pixels, domainPixels, m * blocksize, pixelOffset, domainOffset, blocksize,
			paverage, domainAverage[blockIdx.y * m + blockIdx.x], domainCoeffB[blockIdx.y * m + blockIdx.x], snapshots, affineTransf * n * m + blockIdx.y * m + blockIdx.x);
		//snapshots[(affineTransf * n * m + blockIdx.y * m + blockIdx.x) * 9] = n;
		//snapshots[(affineTransf * n * m + blockIdx.y * m + blockIdx.x) * 9 + 1] = resultArray[affineTransf * n * m + blockIdx.y * m + blockIdx.x];
		//snapshots[(affineTransf * n * m + blockIdx.y * m + blockIdx.x) * 9 + 2] = blockIdx.y;
		//snapshots[(affineTransf * n * m + blockIdx.y * m + blockIdx.x) * 9 + 3] = blockIdx.x;
		//snapshots[(affineTransf * n * m + blockIdx.y * m + blockIdx.x) * 9 + 4] = pixelOffset;
		//snapshots[(affineTransf * n * m + blockIdx.y * m + blockIdx.x) * 9 + 5] = domainOffset;
		//snapshots[(affineTransf * n * m + blockIdx.y * m + blockIdx.x) * 9 + 6] = paverage;
		//snapshots[(affineTransf * n * m + blockIdx.y * m + blockIdx.x) * 9 + 7] = domainAverage[blockIdx.y * m + blockIdx.x];
		//snapshots[(affineTransf * n * m + blockIdx.y * m + blockIdx.x) * 9 + 8] = domainCoeffB[blockIdx.y * m + blockIdx.x];
	}
}

void pickDomainHost(byte* pixels, byte* domainPixels, int n, int m, int blocksize, int pixelOffset, float* domainAverage,
	float* domainCoeffB, float paverage, float* resultArray)
{
	int affineOffset = n * m * blocksize * blocksize;
	int domainOffset;
	for (int affineTransf = 0; affineTransf < 8; affineTransf++)
	{
		for (int i = 0; i < n; i++)
			for (int j = 0; j < m; j++)
			{
				domainOffset = affineOffset * affineTransf + i * m * blocksize * blocksize + j * blocksize;
				resultArray[affineTransf * n * m + i * m + j] = calcDiff2Host(pixels, domainPixels, m * blocksize, pixelOffset, domainOffset, blocksize,
					paverage, domainAverage[i * m + j], domainCoeffB[i * m + j]);
			}
	}
}

BLOCKCODE* obtainNode(QUADNODE* node, int offseti, int offsetj, int blocksize)
{
	if (node->blocksize == blocksize) 
	{
		if (node->blockCode == nullptr) node->blockCode = new BLOCKCODE();
		return node->blockCode;
	}
	else
	{
		if (node->quadNodes == nullptr)
		{
			node->quadNodes = new QUADNODE*[4];
			for (int i = 0; i < 4; i++) node->quadNodes[i] = nullptr;
		}
		int newblocksize = node->blocksize / 2;
		int i = offseti / newblocksize;
		int j = offsetj / newblocksize;
		if (node->quadNodes[i * 2 + j] == nullptr)
		{
			node->quadNodes[i * 2 + j] = new QUADNODE();
			node->quadNodes[i * 2 + j]->blocksize = newblocksize;
			node->quadNodes[i * 2 + j]->blockCode = nullptr;
			node->quadNodes[i * 2 + j]->quadNodes = nullptr;
		}
		return obtainNode(node->quadNodes[i * 2 + j], offseti % newblocksize,
			offsetj % newblocksize, blocksize);
	}
}

BLOCKCODE* obtainNodeStart(QUADTREE* quadtree, int offsety, int offsetx, int blocksize) 
{
	int i = offsety / quadtree->startingBlockSize;
	int j = offsetx / quadtree->startingBlockSize;
	QUADNODE** nodes = quadtree->quadNodes;
	if (nodes[i * quadtree->width + j] == nullptr)
	{
		nodes[i * quadtree->width + j] = new QUADNODE();
		nodes[i * quadtree->width + j]->blocksize = quadtree->startingBlockSize;
		nodes[i * quadtree->width + j]->blockCode = nullptr;
		nodes[i * quadtree->width + j]->quadNodes = nullptr;
	}
	return obtainNode(nodes[i * quadtree->width + j], offsety % quadtree->startingBlockSize,
		offsetx % quadtree->startingBlockSize, blocksize);
}

QUADTREE* fractalCompressionStep4(byte* h_pixels, int sizeX, int sizeY, int startingBlockSize, int* codecount)
{
	*codecount = 0;
	QUADTREE* codes = new QUADTREE();
	codes->height = sizeY / startingBlockSize;
	codes->width = sizeX / startingBlockSize;
	codes->startingBlockSize = startingBlockSize;
	codes->quadNodes = new QUADNODE*[sizeX * sizeY];
	for (int i = 0; i < sizeX * sizeY; i++) codes->quadNodes[i] = nullptr;
	int* candidates = new int[sizeX * sizeY / (startingBlockSize * startingBlockSize)];
	byte* h_domainPixels = new byte[sizeX * sizeY * 8];
	byte* h_domainPixels2 = new byte[sizeX * sizeY * 8];
	byte* d_domainPixels;
	cudaMalloc(&d_domainPixels, sizeX * sizeY * 8 * sizeof(byte));
	byte* d_pixels;
	cudaMalloc(&d_pixels, sizeX * sizeY * sizeof(byte));
	cudaMemcpy(d_pixels, h_pixels, sizeX * sizeY * sizeof(byte), cudaMemcpyHostToDevice);
	int candiateCounter = 0;
	for (int i = 0; i < sizeY; i+= startingBlockSize)
	{
		for (int j = 0; j < sizeX; j+= startingBlockSize)
		{
			candidates[candiateCounter] = i * sizeX + j;
			candiateCounter++;
		}
	}
	int blocksize = startingBlockSize;
	while (candiateCounter > 0) 
	{
		int n = sizeY / blocksize;
		int m = sizeX / blocksize;
		int domainCount = n * m;
		float* h_domainAverage = new float[domainCount];
		float* h_rangeAverage = new float[candiateCounter];
		float* h_domainCoeffB = new float[domainCount];
		float* h_resultsArray = new float[domainCount * 8];
		float* h_snapshots = new float[domainCount * 8 * 9];
		float* d_snapshots;
		cudaMalloc(&d_snapshots, domainCount * 8 * 9 * sizeof(float));
		//alocation could be more efficient. check that
		float* d_domainAverage; //= new float[domainCount];
		cudaMalloc(&d_domainAverage, domainCount * sizeof(float));
		float* d_rangeAverage;// = new float[candiateCounter];
		cudaMalloc(&d_rangeAverage, candiateCounter * sizeof(float));
		float* d_domainCoeffB;// = new float[domainCount];
		cudaMalloc(&d_domainCoeffB, domainCount * sizeof(float));
		float* d_resultsArray;// = new float[domainCount * 8];
		cudaMalloc(&d_resultsArray, 8 * domainCount * sizeof(float));
		cudaMemcpy(h_resultsArray, d_resultsArray, domainCount * 8 * sizeof(float), cudaMemcpyDeviceToHost);
		for (int x = 0; (x + 2) * blocksize <= sizeX; x++)
		{
			for (int y = 0; (y + 2) * blocksize <= sizeY; y++)
			{
				int offsetxl = x * blocksize;
				int offsetyl = y * blocksize;
				byte** affineTransfs = new byte*[8];
				affineTransfs[0] = downsize(h_pixels, offsetxl, offsetyl, blocksize * 2, sizeX);
				affineTransfs[1] = rotate90(affineTransfs[0], blocksize);
				affineTransfs[2] = rotate180(affineTransfs[0], blocksize);
				affineTransfs[3] = rotate270(affineTransfs[0], blocksize);
				affineTransfs[4] = flipHorizontal(affineTransfs[0], blocksize);
				affineTransfs[5] = flipVertical(affineTransfs[0], blocksize);
				affineTransfs[6] = flipAlongMainDiagonal(affineTransfs[0], blocksize);
				affineTransfs[7] = flipAlongSubDiagonal(affineTransfs[0], blocksize);
				for (int i = 0; i < 8; i++)
				{
					embed(h_domainPixels, affineTransfs[i], sizeX * sizeY * i + offsetyl * sizeX + offsetxl, sizeX, blocksize);
				}
				//averageandotherconsts
				int dval = 0;
				float b = 0;
				for (int i = 0; i < blocksize; i++)
				{
					for (int j = 0; j < blocksize; j++)
					{
						dval += affineTransfs[0][i * blocksize + j];
					}
				}
				float daverage = ((float)dval) / (blocksize * blocksize);
				for (int i = 0; i < blocksize; i++)
				{
					for (int j = 0; j < blocksize; j++)
					{
						b += (affineTransfs[0][i * blocksize + j] - daverage)*(affineTransfs[0][i * blocksize + j] - daverage);
					}
				}
				h_domainAverage[y * m + x] = daverage;
				h_domainCoeffB[y * m + x] = b;
				for (int i = 0; i < 8; i++)
				{
					delete[] affineTransfs[i];
				}
				delete[] affineTransfs;
			}
		}
		cudaMemcpy(d_domainPixels, h_domainPixels, sizeX * sizeY * 8 * sizeof(byte), cudaMemcpyHostToDevice);
		cudaMemcpy(d_domainAverage, h_domainAverage, domainCount * sizeof(float), cudaMemcpyHostToDevice);
		cudaMemcpy(d_domainCoeffB, h_domainCoeffB, domainCount * sizeof(float), cudaMemcpyHostToDevice);
		for (int i = 0; i < candiateCounter; i++)
		{
			float paverage = 0;
			for (int j = 0; j < blocksize; j++) 
			{
				for (int k = 0; k < blocksize; k++)
				{
					paverage += h_pixels[candidates[i] + j * sizeX + k];
				}
			}
			paverage /= (blocksize * blocksize);
			h_rangeAverage[i] = paverage;
		}
		cudaMemcpy(d_rangeAverage, h_rangeAverage, candiateCounter * sizeof(float), cudaMemcpyHostToDevice);
		int newCandidateCounter = 0;
		int* newCandidates = new int[4 * sizeX * sizeY / (blocksize * blocksize)];
		for (int i = 0; i < candiateCounter; i++)
		{
			dim3 dimBlock(n, m);//dimension count is wrong. fix later
			pickDomain<<<dimBlock, 1>>>(d_pixels, d_domainPixels, n, m, blocksize, candidates[i], d_domainAverage, d_domainCoeffB, h_rangeAverage[i], d_resultsArray, d_snapshots);
			cudaMemcpy(h_resultsArray, d_resultsArray, domainCount * 8 * sizeof(float), cudaMemcpyDeviceToHost);
			cudaMemcpy(h_snapshots, d_snapshots, domainCount * 8 * 9 * sizeof(float), cudaMemcpyDeviceToHost);
			//pickDomainHost(h_pixels, h_domainPixels, n, m, blocksize, candidates[i], h_domainAverage, h_domainCoeffB, h_rangeAverage[i], h_resultsArray);
			float mindiff = h_resultsArray[0];
			int minj = 0;
			for (int j = 0; j < domainCount * 8; j++) {
				if (mindiff > h_resultsArray[j]) 
				{
					mindiff = h_resultsArray[j];
					minj = j;
				}
			}
			mindiff = mindiff / (blocksize * blocksize);
			if (blocksize < 8 || mindiff < 50) {
				BLOCKCODE* blockCode = obtainNodeStart(codes, candidates[i] / sizeX, candidates[i] % sizeX, blocksize);
				blockCode->blockSize = blocksize;
				blockCode->xoffset = candidates[i] % sizeX;
				blockCode->yoffset = candidates[i] / sizeX;
				int affinetransf = minj / domainCount;
				int nonaffoffset = minj % domainCount;
				int offsetdY = nonaffoffset / m * blocksize;
				int offsetdX = nonaffoffset % m * blocksize;
				blockCode->transformType = affinetransf;
				blockCode->ydoffset = offsetdY;
				blockCode->xdoffset = offsetdX;
				float brightDiffValue = 0;
				float contrastCoefficient = 0;
				int offsetDomain = affinetransf * domainCount * blocksize * blocksize + offsetdY * sizeX + offsetdX;
				calcCoeffsHost2(h_pixels, h_domainPixels, sizeX, candidates[i], offsetDomain, blocksize, &brightDiffValue, &contrastCoefficient, 
					h_rangeAverage[i], h_domainAverage[nonaffoffset], h_domainCoeffB[nonaffoffset]);
				blockCode->brightnessDifference = brightDiffValue;
				blockCode->contrastCoefficient = contrastCoefficient;
				(*codecount)++;
			}
			else {
				newCandidates[newCandidateCounter++] = candidates[i];
				newCandidates[newCandidateCounter++] = candidates[i] + blocksize / 2;
				newCandidates[newCandidateCounter++] = candidates[i] + sizeX * blocksize/2;
				newCandidates[newCandidateCounter++] = candidates[i] + sizeX * blocksize / 2 + blocksize/2;
			}
		}
		delete[] candidates;
		candidates = newCandidates;
		candiateCounter = newCandidateCounter;
		blocksize /= 2;
		delete[] h_domainAverage;
		delete[] h_domainCoeffB;
		delete[] h_rangeAverage;
		delete[] h_resultsArray;
		cudaFree(d_domainAverage);
		cudaFree(d_domainCoeffB);
		cudaFree(d_rangeAverage);
		cudaFree(d_resultsArray);
	}
	delete[] candidates;
	delete[] h_domainPixels;
	cudaFree(d_domainPixels);
	cudaFree(d_pixels);
	return codes;
}

void fractalCompressionStep3(byte* pixels, int offsetx, int offsety, int blocksize, int* blockamount, BLOCKCODE** blockCodes, int sizex, int sizey, int qualifer)
{
	int offsetxOfMin = 0;
	int offsetyOfMin = 0;
	double minDifference = MAXINT;
	float brightnessDifference = 0;
	byte affineTransform = 0;
	float contrastCoefficient = 0;
	bool found = false;
	for (int offsetxl = 0; offsetxl + 2 * blocksize <= sizex; offsetxl += blocksize)
	{
		for (int offsetyl = 0; offsetyl + 2 * blocksize <= sizey; offsetyl += blocksize)
		{
			byte** affineTransfs = new byte*[8];
			affineTransfs[0] = downsize(pixels, offsetxl, offsetyl, blocksize * 2, sizex);
			affineTransfs[1] = rotate90(affineTransfs[0], blocksize);
			affineTransfs[2] = rotate180(affineTransfs[0], blocksize);
			affineTransfs[3] = rotate270(affineTransfs[0], blocksize);
			affineTransfs[4] = flipHorizontal(affineTransfs[0], blocksize);
			affineTransfs[5] = flipVertical(affineTransfs[0], blocksize);
			affineTransfs[6] = flipAlongMainDiagonal(affineTransfs[0], blocksize);
			affineTransfs[7] = flipAlongSubDiagonal(affineTransfs[0], blocksize);
			double cdifference;
			for (int i = 0; i < 8; i++)
			{
				cdifference = difference(affineTransfs[i], pixels, offsetx, offsety, blocksize, sizex);
				compareAndUpdate(&minDifference, cdifference, &offsetxOfMin, offsetxl, &offsetyOfMin, offsetyl, &affineTransform, i);
			}
			for (int i = 0; i < 8; i++)
			{
				delete[] affineTransfs[i];
			}
			delete[] affineTransfs;
		}
	}
	minDifference /= (blocksize * blocksize);
	if (minDifference < qualifer || blocksize <= 4)
	{
		byte* downblock = downsize(pixels, offsetxOfMin, offsetyOfMin, blocksize * 2, sizex);
		byte* trblock = nullptr;
		switch (affineTransform)
		{
		case 1:trblock = rotate90(downblock, blocksize); break;
		case 2:trblock = rotate180(downblock, blocksize); break;
		case 3:trblock = rotate270(downblock, blocksize); break;
		case 4:trblock = flipHorizontal(downblock, blocksize); break;
		case 5:trblock = flipVertical(downblock, blocksize); break;
		case 6:trblock = flipAlongMainDiagonal(downblock, blocksize); break;
		case 7:trblock = flipAlongSubDiagonal(downblock, blocksize); break;
		}
		if (affineTransform == 0)
		{
			calcCoeffs(downblock, pixels, offsetx, offsety, blocksize, &brightnessDifference, &contrastCoefficient, sizex);
			delete[] downblock;
		}
		else
		{
			calcCoeffs(trblock, pixels, offsetx, offsety, blocksize, &brightnessDifference, &contrastCoefficient, sizex);
			delete[] downblock;
			delete[] trblock;
		}
		//in the future use initial size and check for overflow, then reallocate
		//causes a brpnt error -> blockCodes = (BLOCKCODE**)realloc(blockCodes, ((*blockamount) + 1) * sizeof(BLOCKCODE*));
		blockCodes[*blockamount] = new BLOCKCODE();
		blockCodes[*blockamount]->blockSize = blocksize;
		blockCodes[*blockamount]->brightnessDifference = brightnessDifference;
		blockCodes[*blockamount]->contrastCoefficient = contrastCoefficient;
		blockCodes[*blockamount]->transformType = affineTransform;
		blockCodes[*blockamount]->xoffset = offsetx;
		blockCodes[*blockamount]->yoffset = offsety;
		blockCodes[*blockamount]->xdoffset = offsetxOfMin;
		blockCodes[*blockamount]->ydoffset = offsetyOfMin;
		(*blockamount)++;
	}
	else
	{
		fractalCompressionStep3(pixels, offsetx, offsety, blocksize / 2, blockamount, blockCodes, sizex, sizey, qualifer);
		fractalCompressionStep3(pixels, offsetx + blocksize / 2, offsety, blocksize / 2, blockamount, blockCodes, sizex, sizey, qualifer);
		fractalCompressionStep3(pixels, offsetx, offsety + blocksize / 2, blocksize / 2, blockamount, blockCodes, sizex, sizey, qualifer);
		fractalCompressionStep3(pixels, offsetx + blocksize / 2, offsety + blocksize / 2, blocksize / 2, blockamount, blockCodes, sizex, sizey, qualifer);
	}
}




void SaveCompressed(const char* fname, BITMAPFILEHEADER* fheader, BITMAPINFOHEADER* iheader, HEADEROFFCOMFILE* cheader, BLOCKCODE** blueCode, BLOCKCODE** redCode, BLOCKCODE** greenCode)
{
	std::ofstream file(fname, std::ios::binary);
	file.write((char*)fheader, sizeof(BITMAPFILEHEADER));
	file.write((char*)iheader, sizeof(BITMAPINFOHEADER));
	file.write((char*)cheader, sizeof(HEADEROFFCOMFILE));

	for (int i = 0; i < cheader->blueDomainCount; i++)
		file.write((char*)(blueCode[i]), sizeof(BLOCKCODE));

	for (int i = 0; i < cheader->greenDomainCount; i++)
		file.write((char*)(greenCode[i]), sizeof(BLOCKCODE));

	for (int i = 0; i < cheader->redDomainCount; i++)
		file.write((char*)(redCode[i]), sizeof(BLOCKCODE));
}

int powerOf2Before(int number)
{
	int twoInPower = 1;
	while (number - twoInPower >= number / 2)
		twoInPower *= 2;
	return twoInPower;
}

void insertQuadNodeIntoArray(QUADNODE* node, BLOCKCODE** blockCodes, int* blockcounter) 
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

BLOCKCODE** quadTreeToArray(QUADTREE* qtree, int blockcount) 
{
	BLOCKCODE** blockCodes = new BLOCKCODE*[blockcount];
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
	return blockCodes;
}

int LoadCompressed(const char* fname, BITMAPFILEHEADER* fheader, BITMAPINFOHEADER* iheader, HEADEROFFCOMFILE* cheader, BLOCKCODE*** blueCode, BLOCKCODE*** redCode, BLOCKCODE*** greenCode)
{
	std::ifstream file(fname, std::ios::binary);
	if (!file)
	{
		std::cout << "can't open file " << fname << "\n";
		return 1;
	}
	file.read((char*)fheader, sizeof(BITMAPFILEHEADER));
	file.read((char*)iheader, sizeof(BITMAPINFOHEADER));
	file.read((char*)cheader, sizeof(HEADEROFFCOMFILE));
	if (fheader->bfType != 0x4D42)
	{
		std::cout << "file " << fname << "is not a bmp file\n";
		return 2;
	}
	*blueCode = new BLOCKCODE*[cheader->blueDomainCount];//чет фигня какаято
	*redCode = new BLOCKCODE*[cheader->redDomainCount];//чет фигня какаято
	*greenCode = new BLOCKCODE*[cheader->greenDomainCount];//чет фигня какаято
	for (int i = 0; i < cheader->blueDomainCount; i++)
	{
		(*blueCode)[i] = new BLOCKCODE();
		file.read((char*)(*blueCode)[i], sizeof(BLOCKCODE));
	}
	for (int i = 0; i < cheader->greenDomainCount; i++)
	{
		(*greenCode)[i] = new BLOCKCODE();
		file.read((char*)(*greenCode)[i], sizeof(BLOCKCODE));
	}
	for (int i = 0; i < cheader->redDomainCount; i++)
	{
		(*redCode)[i] = new BLOCKCODE();
		file.read((char*)(*redCode)[i], sizeof(BLOCKCODE));
	}
	return 0;
}

void copyPixelSquare(byte* from, byte* to, int offsetxf, int offsetyf, int offsetxt, int offsetyt, int n, float brightnessCompr, int diff, int width)
{
	for (int i = 0; i < n; i++)
		for (int j = 0; j < n; j++)
		{
			to[(i + offsetyt) * width +  j + offsetxt] = from[(i + offsetyf) * n + j + offsetxf] * brightnessCompr + diff;
			if (from[(i + offsetyf) * n + j + offsetxf] * brightnessCompr + diff > 255)
				to[(i + offsetyt) * width + j + offsetxt] = 255;
			if (from[(i + offsetyf) * n + j + offsetxf] * brightnessCompr + diff < 0)
				to[(i + offsetyt) * width + j + offsetxt] = 0;
		}
}

void pixelfromfloat(byte** pixels, float** fpixels, int sizex, int sizey)
{
	for (int i = 0; i < sizey; i++)
		for (int j = 0; j < sizex; j++)
		{
			pixels[i][j] = fpixels[i][j];
		}
}

byte* fractalDecompressionStep3(BLOCKCODE** blockCodes, int sizex, int sizey, int blockCount)
{
	byte* iterPixels = new byte[sizex * sizey];
	byte* tPixels = new byte[sizex * sizey];
	for (int i = 0; i < sizex * sizey; i++)
	{
		tPixels[i] = 0;
		iterPixels[i] = 0;
	}
	//for (int i = 0; i < sizex; i++)
	//	for (int j = 0; j < sizey; j++) {
	//		tPixels[i][j] = 255;
	//	}
	for (int iteration = 0; iteration < 100; iteration++)
	{
		for (int j = 0; j < sizey; j++)
			for (int k = 0; k < sizex; k++)
				iterPixels[j * sizex + k] = tPixels[j * sizex + k];
		for (int i = 0; i < blockCount; i++)
		{		
			BLOCKCODE* cblockCode = blockCodes[i];
			byte* affineTransformed = nullptr;
			byte* downSized = downsize(iterPixels, cblockCode->xdoffset, cblockCode->ydoffset, cblockCode->blockSize * 2, sizex);
			switch (cblockCode->transformType)//refactor this stupidity
			{
			case 0:copyPixelSquare(downSized, tPixels, 0, 0, cblockCode->xoffset, cblockCode->yoffset, cblockCode->blockSize, cblockCode->contrastCoefficient, cblockCode->brightnessDifference, sizex);  break;
			case 1:affineTransformed = rotate90(downSized, cblockCode->blockSize);
				copyPixelSquare(affineTransformed, tPixels, 0, 0, cblockCode->xoffset, cblockCode->yoffset, cblockCode->blockSize, cblockCode->contrastCoefficient, cblockCode->brightnessDifference, sizex); break;
			case 2:affineTransformed = rotate180(downSized, cblockCode->blockSize);
				copyPixelSquare(affineTransformed, tPixels, 0, 0, cblockCode->xoffset, cblockCode->yoffset, cblockCode->blockSize, cblockCode->contrastCoefficient, cblockCode->brightnessDifference, sizex); break;
			case 3:affineTransformed = rotate270(downSized, cblockCode->blockSize);
				copyPixelSquare(affineTransformed, tPixels, 0, 0, cblockCode->xoffset, cblockCode->yoffset, cblockCode->blockSize, cblockCode->contrastCoefficient, cblockCode->brightnessDifference, sizex); break;
			case 4:affineTransformed = flipHorizontal(downSized, cblockCode->blockSize);
				copyPixelSquare(affineTransformed, tPixels, 0, 0, cblockCode->xoffset, cblockCode->yoffset, cblockCode->blockSize, cblockCode->contrastCoefficient, cblockCode->brightnessDifference, sizex); break;
			case 5:affineTransformed = flipVertical(downSized, cblockCode->blockSize);
				copyPixelSquare(affineTransformed, tPixels, 0, 0, cblockCode->xoffset, cblockCode->yoffset, cblockCode->blockSize, cblockCode->contrastCoefficient, cblockCode->brightnessDifference, sizex); break;
			case 6:affineTransformed = flipAlongMainDiagonal(downSized, cblockCode->blockSize);
				copyPixelSquare(affineTransformed, tPixels, 0, 0, cblockCode->xoffset, cblockCode->yoffset, cblockCode->blockSize, cblockCode->contrastCoefficient, cblockCode->brightnessDifference, sizex); break;
			case 7:affineTransformed = flipAlongSubDiagonal(downSized, cblockCode->blockSize);
				copyPixelSquare(affineTransformed, tPixels, 0, 0, cblockCode->xoffset, cblockCode->yoffset, cblockCode->blockSize, cblockCode->contrastCoefficient, cblockCode->brightnessDifference, sizex); break;
			default: std::cout << "affine error" << '\n'; break;
			}
			if (cblockCode->transformType != 0)
			{
				delete[] affineTransformed;
			}
			delete[] downSized;
		}
	}
	return tPixels;
}

void print_matr(byte* matr, int n) {
	for (int i = 0; i < n; i++) {
		for (int j = 0; j < n; j++)
			std::cout << std::setw(3) << (int)matr[i * n + j];
		std::cout << '\n';
	}
}

int blocksum(byte* block, int n) {
	int sum = 0;
	for (int i = 0; i < n; i++)
		for (int j = 0; j < n; j++)
			sum += block[i * n +j];
	return sum;
}

void decompressQuad(BLOCKCODE** compressedCodes, int blockSize, int offsetx, int offsety, int* counter)
{
	for (int i = 0; i < 2; i++)
	{
		for (int j = 0; j < 2; j++)
		{
			if (compressedCodes[*counter]->blockSize == blockSize)
			{
				if ((compressedCodes[*counter]->yoffset  != i * blockSize + offsety) 
					|| (compressedCodes[*counter]->xoffset != j * blockSize + offsetx))
					std::cout << "\nwe fooped up\n";
				(*counter)++;
			}
			else
			{
				decompressQuad(compressedCodes, blockSize / 2, offsetx + j * blockSize,
					offsety + i * blockSize, counter);
			}
		}
	}
}

void decompressBlockCodes(BLOCKCODE** compressedCodes, int startingBlockSize, int width, int height) 
{
	//needs more here
	int counter = 0;
	for (int i = 0; i < height; i+= startingBlockSize)
	{
		for (int j = 0; j < width; j += startingBlockSize) 
		{
			if (compressedCodes[counter]->blockSize == startingBlockSize)
			{
				if ((compressedCodes[counter]->xoffset != i) || (compressedCodes[counter]->yoffset != j))
					std::cout << "\nwe fooped up\n";
				counter++;
			}
			else
			{
				decompressQuad(compressedCodes, startingBlockSize / 2, j,
					i, &counter);
			}
		}
	}
}

int main()
{
	BITMAPFILEHEADER* fheader = nullptr;
	BITMAPINFOHEADER* iheader = nullptr;
	fheader = new BITMAPFILEHEADER();
	iheader = new BITMAPINFOHEADER();
	byte* pixels = nullptr;
	byte** reftopixels = &pixels;
	LoadPixels("glss.bmp", reftopixels, fheader, iheader);
	byte *blue, *red, *green;
	blue = new byte[iheader->biHeight * iheader->biWidth];
	red = new byte[iheader->biHeight * iheader->biWidth];
	green = new byte[iheader->biHeight * iheader->biWidth];
	colorChannelSeparator(pixels, blue, green, red, iheader->biWidth, iheader->biHeight);
	colorChannelCombinator(pixels, blue, blue, blue, iheader->biWidth, iheader->biHeight);
	SavePixels("r128b11.bmp", pixels, fheader, iheader);
	std::cout << "blue channel total: " << blocksum(blue, iheader->biHeight) << '\n';
	colorChannelCombinator(pixels, green, green, green, iheader->biWidth, iheader->biHeight);
	SavePixels("r128g11.bmp", pixels, fheader, iheader);
	std::cout << "green channel total: " << blocksum(green, iheader->biHeight) << '\n';
	colorChannelCombinator(pixels, red, red, red, iheader->biWidth, iheader->biHeight);
	SavePixels("r128r11.bmp", pixels, fheader, iheader);
	std::cout << "red channel total " << blocksum(red, iheader->biHeight) << '\n';
	HEADEROFFCOMFILE* cheader = new HEADEROFFCOMFILE();
	BLOCKCODE** blueCode = new BLOCKCODE*[4096];
	BLOCKCODE** greenCode = new BLOCKCODE*[4096];
	BLOCKCODE** redCode = new BLOCKCODE*[4096];
	BLOCKCODE** blueCode2 = new BLOCKCODE*[4096];
	BLOCKCODE** greenCode2 = new BLOCKCODE*[4096];
	BLOCKCODE** redCode2 = new BLOCKCODE*[4096];
	int initialBlockSize = powerOf2Before(min(iheader->biHeight, iheader->biWidth)) / 2;
	int blueblocks = 0;
	int redblocks = 0;
	int greenblocks = 0;
	int blueblocks2 = 0;
	int redblocks2 = 0;
	int greenblocks2 = 0;
	////blue
	//fractalCompressionStep3(blue, 0, 0, initialBlockSize, &blueblocks, blueCode, iheader->biWidth, iheader->biHeight, 50);
	//fractalCompressionStep3(blue, 0, initialBlockSize, initialBlockSize, &blueblocks, blueCode, iheader->biWidth, iheader->biHeight, 50);
	//fractalCompressionStep3(blue, initialBlockSize, 0, initialBlockSize, &blueblocks, blueCode, iheader->biWidth, iheader->biHeight, 50);
	//fractalCompressionStep3(blue, initialBlockSize, initialBlockSize, initialBlockSize, &blueblocks, blueCode, iheader->biWidth, iheader->biHeight, 50);
	QUADTREE* blueTree = fractalCompressionStep4(blue, iheader->biWidth, iheader->biHeight, 16, &blueblocks);
	blueCode = quadTreeToArray(blueTree, blueblocks);
	decompressBlockCodes(blueCode, 16, iheader->biWidth, iheader->biHeight);
	//red
	//fractalCompressionStep3(red, 0, 0, initialBlockSize, &redblocks, redCode, iheader->biWidth, iheader->biHeight, 50);
	//fractalCompressionStep3(red, 0, initialBlockSize, initialBlockSize, &redblocks, redCode, iheader->biWidth, iheader->biHeight, 50);
	//fractalCompressionStep3(red, initialBlockSize, 0, initialBlockSize, &redblocks, redCode, iheader->biWidth, iheader->biHeight, 50);
	//fractalCompressionStep3(red, initialBlockSize, initialBlockSize, initialBlockSize, &redblocks, redCode, iheader->biWidth, iheader->biHeight, 50);
	QUADTREE* redTree = fractalCompressionStep4(red, iheader->biWidth, iheader->biHeight, 16, &redblocks);
	redCode = quadTreeToArray(redTree, redblocks);
	//green
	/*fractalCompressionStep3(green, 0, 0, initialBlockSize, &greenblocks, greenCode, iheader->biWidth, iheader->biHeight, 50);
	fractalCompressionStep3(green, 0, initialBlockSize, initialBlockSize, &greenblocks, greenCode, iheader->biWidth, iheader->biHeight, 50);
	fractalCompressionStep3(green, initialBlockSize, 0, initialBlockSize, &greenblocks, greenCode, iheader->biWidth, iheader->biHeight, 50);
	fractalCompressionStep3(green, initialBlockSize, initialBlockSize, initialBlockSize, &greenblocks, greenCode, iheader->biWidth, iheader->biHeight, 50);*/
	QUADTREE* greenTree = fractalCompressionStep4(green, iheader->biWidth, iheader->biHeight, 16, &greenblocks);
	greenCode = quadTreeToArray(greenTree, greenblocks);
	cheader->blueDomainCount = blueblocks;
	cheader->greenDomainCount = greenblocks;
	cheader->redDomainCount = redblocks;
	SaveCompressed("fcompressed128_1.frc", fheader, iheader, cheader, blueCode, redCode, greenCode);
	delete fheader;
	delete[] pixels;
	delete[] blue;
	delete[] red;
	delete[] green;
	delete iheader;
	free2Dimensions((byte**)blueCode, cheader->blueDomainCount);
	free2Dimensions((byte**)redCode, cheader->redDomainCount);
	free2Dimensions((byte**)greenCode, cheader->greenDomainCount);
	delete cheader;
	//endofcompression

	//startofdecompression
	fheader = new BITMAPFILEHEADER();
	iheader = new BITMAPINFOHEADER(); 
	cheader = new HEADEROFFCOMFILE(); 
	BLOCKCODE*** ptoblueCode = new BLOCKCODE**();
	BLOCKCODE*** ptoredCode = new BLOCKCODE**();
	BLOCKCODE*** ptogreenCode = new BLOCKCODE**();
	LoadCompressed("fcompressed128_1.frc", fheader, iheader, cheader, ptoblueCode, ptoredCode, ptogreenCode);
	byte* bluePixels = fractalDecompressionStep3(*ptoblueCode, iheader->biWidth, iheader->biHeight, cheader->blueDomainCount);
	byte* redPixels = fractalDecompressionStep3(*ptoredCode, iheader->biWidth, iheader->biHeight, cheader->redDomainCount);
	byte* greenPixels = fractalDecompressionStep3(*ptogreenCode, iheader->biWidth, iheader->biHeight, cheader->greenDomainCount);	
	pixels = new byte[iheader->biSizeImage];//чет фигня какаято
	colorChannelCombinator(pixels, bluePixels, greenPixels, redPixels, iheader->biWidth, iheader->biHeight);
	SavePixels("r128_11.bmp", pixels, fheader, iheader);
	std::cout << "blue channel total2: " << blocksum(bluePixels, iheader->biHeight) << '\n';
	colorChannelCombinator(pixels, bluePixels, bluePixels, bluePixels, iheader->biWidth, iheader->biHeight);
	SavePixels("r128b121.bmp", pixels, fheader, iheader);
	std::cout << "green channel total2: " << blocksum(greenPixels, iheader->biHeight) << '\n';
	colorChannelCombinator(pixels, greenPixels, greenPixels, greenPixels, iheader->biWidth, iheader->biHeight);
	SavePixels("r128g121.bmp", pixels, fheader, iheader);
	std::cout << "red channel total2: " << blocksum(redPixels, iheader->biHeight) << '\n';
	colorChannelCombinator(pixels, redPixels, redPixels, redPixels, iheader->biWidth, iheader->biHeight);
	SavePixels("r128r121.bmp", pixels, fheader, iheader);
	delete[] pixels;
	delete[] bluePixels;
	delete[] greenPixels;
	delete[] redPixels;
	int x;
	std::cin >> x;
	return 0;
}


