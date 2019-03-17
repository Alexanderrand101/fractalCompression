#include "decompressor.h"

namespace fractal_compression {

	void copyPixelSquare(unsigned char* from, unsigned char* to, int offsetxf, int offsetyf, int offsetxt, int offsetyt, int n, float brightnessCompr, short diff, int width)
	{
		for (int i = 0; i < n; i++)
			for (int j = 0; j < n; j++)
			{
				to[(i + offsetyt) * width + j + offsetxt] = from[(i + offsetyf) * n + j + offsetxf] * brightnessCompr + diff;
				if (from[(i + offsetyf) * n + j + offsetxf] * brightnessCompr + diff > 255)
					to[(i + offsetyt) * width + j + offsetxt] = 255;
				if (from[(i + offsetyf) * n + j + offsetxf] * brightnessCompr + diff < 0)
					to[(i + offsetyt) * width + j + offsetxt] = 0;
			}
	}

	unsigned char* fractalDecompressionStep3(BlockCodes* blockCodes, int sizex, int sizey)
	{
		unsigned char* iterPixels = new unsigned char[sizex * sizey];
		unsigned char* tPixels = new unsigned char[sizex * sizey];
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
			for (int i = 0; i < blockCodes->codeCount; i++)
			{
				BlockCode* cblockCode = blockCodes->blockCodes[i];
				unsigned char* affineTransformed = nullptr;
				unsigned char* downSized = downsize(iterPixels, cblockCode->xdoffset, cblockCode->ydoffset, cblockCode->blockSize * 2, sizex);
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
				default: /*std::cout << "affine error" << '\n';*/ break;
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
}