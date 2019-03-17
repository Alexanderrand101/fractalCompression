#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "quadtree.h"
#include "compressor.h"

namespace fractal_compression {

	__device__ void calcCoeffsDevice2(unsigned char* pixels, unsigned char* domainPixels, int width, int offsetPixels, int offsetDomain, int blocksize, short* brightDiffValue, float* contrastCoefficient,
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

	void calcCoeffsHost2(unsigned char* pixels, unsigned char* domainPixels, int width, int offsetPixels, int offsetDomain, int blocksize, short* brightDiffValue, float* contrastCoefficient,
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

	__device__ float calcDiff2(unsigned char* pixels, unsigned char* domainPixels, int width, int offsetPixels, int offsetDomain, int blocksize,
		float paverage, float daverage, float b, float* snapshots, int snapshotoffset)
	{
		float difference = 0;
		short brightDiffValue = 0;
		float contrastCoefficient = 0;
		calcCoeffsDevice2(pixels, domainPixels, width, offsetPixels, offsetDomain, blocksize, &brightDiffValue, &contrastCoefficient, paverage, daverage, b, snapshots, snapshotoffset);
		for (int i = 0; i < blocksize; i++)
		{
			for (int j = 0; j < blocksize; j++)
			{
				double baseDiff = domainPixels[offsetDomain + i * width + j] * contrastCoefficient + brightDiffValue - pixels[offsetPixels + i * width + j];
				difference += baseDiff * baseDiff;
			}
		}
		return difference;
	}

	float calcDiff2Host(unsigned char* pixels, unsigned char* domainPixels, int width, int offsetPixels, int offsetDomain, int blocksize,
		float paverage, float daverage, float b)
	{
		float difference = 0;
		short brightDiffValue = 0;
		float contrastCoefficient = 0;
		calcCoeffsHost2(pixels, domainPixels, width, offsetPixels, offsetDomain, blocksize, &brightDiffValue, &contrastCoefficient, paverage, daverage, b);
		for (int i = 0; i < blocksize; i++)
		{
			for (int j = 0; j < blocksize; j++)
			{
				double baseDiff = domainPixels[offsetDomain + i * width + j] * contrastCoefficient + brightDiffValue - pixels[offsetPixels + i * width + j];
				difference += baseDiff * baseDiff;
			}
		}
		return difference;
	}

	__global__ void pickDomain(unsigned char* pixels, unsigned char* domainPixels, int n, int m, int blocksize, int pixelOffset, float* domainAverage,
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
		}
	}

	void pickDomainHost(unsigned char* pixels, unsigned char* domainPixels, int n, int m, int blocksize, int pixelOffset, float* domainAverage,
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

	QuadTree* fractalCompressionStep4(unsigned char* h_pixels, int sizeX, int sizeY, int startingBlockSize)
	{
		QuadTree* codes = new QuadTree(sizeY / startingBlockSize, sizeX / startingBlockSize, startingBlockSize);
		int* candidates = new int[sizeX * sizeY / (startingBlockSize * startingBlockSize)];
		unsigned char* h_domainPixels = new unsigned char[sizeX * sizeY * 8];
		unsigned char* h_domainPixels2 = new unsigned char[sizeX * sizeY * 8];
		unsigned char* d_domainPixels;
		cudaMalloc(&d_domainPixels, sizeX * sizeY * 8 * sizeof(unsigned char));
		unsigned char* d_pixels;
		cudaMalloc(&d_pixels, sizeX * sizeY * sizeof(unsigned char));
		cudaMemcpy(d_pixels, h_pixels, sizeX * sizeY * sizeof(unsigned char), cudaMemcpyHostToDevice);
		int candiateCounter = 0;
		for (int i = 0; i < sizeY; i += startingBlockSize)
		{
			for (int j = 0; j < sizeX; j += startingBlockSize)
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
					unsigned char** affineTransfs = new unsigned char*[8];
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
			cudaMemcpy(d_domainPixels, h_domainPixels, sizeX * sizeY * 8 * sizeof(unsigned char), cudaMemcpyHostToDevice);
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
				pickDomain <<< dimBlock, 1 >>>(d_pixels, d_domainPixels, n, m, blocksize, candidates[i], d_domainAverage, d_domainCoeffB, h_rangeAverage[i], d_resultsArray, d_snapshots);
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
				if (blocksize < 8 || mindiff < 0) {
					BlockCode* blockCode = codes->obtainNodeStart(candidates[i] / sizeX, candidates[i] % sizeX, blocksize);
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
					short brightDiffValue = 0;
					float contrastCoefficient = 0;
					int offsetDomain = affinetransf * domainCount * blocksize * blocksize + offsetdY * sizeX + offsetdX;
					calcCoeffsHost2(h_pixels, h_domainPixels, sizeX, candidates[i], offsetDomain, blocksize, &brightDiffValue, &contrastCoefficient,
						h_rangeAverage[i], h_domainAverage[nonaffoffset], h_domainCoeffB[nonaffoffset]);
					blockCode->brightnessDifference = brightDiffValue;
					blockCode->contrastCoefficient = contrastCoefficient;
					codes->codeCount++;
				}
				else {
					newCandidates[newCandidateCounter++] = candidates[i];
					newCandidates[newCandidateCounter++] = candidates[i] + blocksize / 2;
					newCandidates[newCandidateCounter++] = candidates[i] + sizeX * blocksize / 2;
					newCandidates[newCandidateCounter++] = candidates[i] + sizeX * blocksize / 2 + blocksize / 2;
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
}