#include <fstream>
#include <iostream>
#include <iomanip>
#include <Windows.h>
#include "compressor.h"
#include "blockcodes.h"
#include "decompressor.h"

using namespace fractal_compression;

typedef struct HEADEROFFCOMFILE //todo. correct the size
{
	int blueDomainCount;
	int redDomainCount;
	int greenDomainCount;
	int maxblocksize;
	//int startingblocksize;
};

unsigned char* somebytes;
int valoffset = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);

//first draft. needs work. also need to be able to select filetype.
int LoadPixels(const char* fname, unsigned char** reftopixels, BITMAPFILEHEADER* fheader, BITMAPINFOHEADER* iheader)
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
	somebytes = new unsigned char[fheader->bfOffBits - valoffset];
	file.read((char*)somebytes, fheader->bfOffBits - valoffset);
	*reftopixels = new unsigned char[iheader->biSizeImage];//чет фигня какаято
	file.read((char*)*reftopixels, iheader->biSizeImage);
	return 0;
}

void SavePixels(const char* fname, unsigned char* pixels, BITMAPFILEHEADER* fheader, BITMAPINFOHEADER* iheader)
{
	std::ofstream file(fname, std::ios::binary);
	file.write((char*)fheader, sizeof(BITMAPFILEHEADER));
	file.write((char*)iheader, sizeof(BITMAPINFOHEADER));
	file.write((char*)somebytes, fheader->bfOffBits - valoffset);
	//int padsize = (4 - (iheader->biWidth * 3) % 4);
	//if (padsize == 4) padsize = 0;
	//byte padding = 0;
	for (int i = 0; i < iheader->biHeight; i++)
	{
		file.write((char*)pixels /*+ i * iheader->biWidth * 3*/, /*(iheader->biWidth * 3)*/ iheader->biSizeImage);
		//for (int j = 0; j < padsize; j++)
		//	file.write((char*)&padding, sizeof(byte));
	}
}

int blocksum(unsigned char* block, int n, int m) {
	int sum = 0;
	for (int i = 0; i < n; i++)
		for (int j = 0; j < m; j++)
			sum += block[i * m + j];
	return sum;
}

void SaveCompressed2(const char* fname, BITMAPFILEHEADER* fheader, BITMAPINFOHEADER* iheader, HEADEROFFCOMFILE* cheader, unsigned char* bluestream, unsigned char* redstream, unsigned char* greenstream)
{
	std::ofstream file(fname, std::ios::binary);
	file.write((char*)fheader, sizeof(BITMAPFILEHEADER));
	file.write((char*)iheader, sizeof(BITMAPINFOHEADER));
	file.write((char*)cheader, sizeof(HEADEROFFCOMFILE));
	file.write((char*)bluestream, minbytesforbits(cheader->blueDomainCount));
	file.write((char*)greenstream, minbytesforbits(cheader->greenDomainCount));
	file.write((char*)redstream, minbytesforbits(cheader->redDomainCount));
}

int LoadCompressed2(const char* fname, BITMAPFILEHEADER* fheader, BITMAPINFOHEADER* iheader, HEADEROFFCOMFILE* cheader, unsigned char** bluestream, unsigned char** redstream, unsigned char** greenstream)
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
	*bluestream = new unsigned char[minbytesforbits(cheader->blueDomainCount)];//чет фигня какаято
	*greenstream = new unsigned char[minbytesforbits(cheader->greenDomainCount)];//чет фигня какаято
	*redstream = new unsigned char[minbytesforbits(cheader->redDomainCount)];//чет фигня какаято
	file.read((char*)*bluestream, minbytesforbits(cheader->blueDomainCount));
	file.read((char*)*greenstream, minbytesforbits(cheader->greenDomainCount));
	file.read((char*)*redstream, minbytesforbits(cheader->redDomainCount));
	return 0;
}

int main()
{
	/*int length = 0, codecount = 0;
	BLOCKCODE* code = new BLOCKCODE();
	code->blockSize = 8;
	code->brightnessDifference = 100;
	code->contrastCoefficient = 999;
	code->transformType = 6;
	code->xdoffset = 6400;
	code->ydoffset = 64000;
	BLOCKCODE* code2 = new BLOCKCODE();
	code2->blockSize = 4;
	code2->brightnessDifference = 1;
	code2->contrastCoefficient = 96;
	code2->transformType = 2;
	code2->xdoffset = 32;
	code2->ydoffset = 16;
	BLOCKCODE* code3 = new BLOCKCODE();
	code3->blockSize = 16;
	code3->brightnessDifference = 1;
	code3->contrastCoefficient = 96;
	code3->transformType = 2;
	code3->xdoffset = 160;
	code3->ydoffset = 400;
	BLOCKCODE** blockcodes = new BLOCKCODE*[3]{ code, code2, code3 };
	unsigned char* res = blockcodesToBitStream(blockcodes, 16, 16000, 320000, 3, &length);
	BLOCKCODE** blockcodes2 = bitstreamToBlockCodes(res, 16, 16000, 320000, &codecount, length);*/
	BITMAPFILEHEADER* fheader = nullptr;
	BITMAPINFOHEADER* iheader = nullptr;
	fheader = new BITMAPFILEHEADER();
	iheader = new BITMAPINFOHEADER();
	unsigned char* pixels = nullptr;
	unsigned char** reftopixels = &pixels;
	LoadPixels("Lighthouse.bmp", reftopixels, fheader, iheader);
	SavePixels("r128all.bmp", pixels, fheader, iheader);
	unsigned char *blue, *red, *green;
	blue = new unsigned char[iheader->biHeight * iheader->biWidth];
	red = new unsigned char[iheader->biHeight * iheader->biWidth];
	green = new unsigned char[iheader->biHeight * iheader->biWidth];
	colorChannelSeparator(pixels, blue, green, red, iheader->biWidth, iheader->biSizeImage / iheader->biHeight, iheader->biHeight);
	colorChannelCombinator(pixels, blue, blue, blue, iheader->biWidth, iheader->biSizeImage / iheader->biHeight, iheader->biHeight);
	SavePixels("r128b11.bmp", pixels, fheader, iheader);
	std::cout << "blue channel total: " << blocksum(blue, iheader->biHeight, iheader->biWidth) << '\n';
	colorChannelCombinator(pixels, green, green, green, iheader->biWidth, iheader->biSizeImage / iheader->biHeight, iheader->biHeight);
	SavePixels("r128g11.bmp", pixels, fheader, iheader);
	std::cout << "green channel total: " << blocksum(green, iheader->biHeight, iheader->biWidth) << '\n';
	colorChannelCombinator(pixels, red, red, red, iheader->biWidth, iheader->biSizeImage / iheader->biHeight, iheader->biHeight);
	SavePixels("r128r11.bmp", pixels, fheader, iheader);
	std::cout << "red channel total " << blocksum(red, iheader->biHeight, iheader->biWidth) << '\n';
	HEADEROFFCOMFILE* cheader = new HEADEROFFCOMFILE();
	//BLOCKCODE** blueCode = new BLOCKCODE*[4096];
	//BLOCKCODE** greenCode = new BLOCKCODE*[4096];
	//BLOCKCODE** redCode = new BLOCKCODE*[4096];
	//BLOCKCODE** blueCode2 = new BLOCKCODE*[4096];
	//BLOCKCODE** greenCode2 = new BLOCKCODE*[4096];
	//BLOCKCODE** redCode2 = new BLOCKCODE*[4096];
	//int initialBlockSize = powerOf2Before(min(iheader->biHeight, iheader->biWidth)) / 2;
	int blueblocks = 0;
	int redblocks = 0;
	int greenblocks = 0;
	//int blueblocks2 = 0;
	//int redblocks2 = 0;
	//int greenblocks2 = 0;
	//////blue
	////fractalCompressionStep3(blue, 0, 0, initialBlockSize, &blueblocks, blueCode, iheader->biWidth, iheader->biHeight, 50);
	////fractalCompressionStep3(blue, 0, initialBlockSize, initialBlockSize, &blueblocks, blueCode, iheader->biWidth, iheader->biHeight, 50);
	////fractalCompressionStep3(blue, initialBlockSize, 0, initialBlockSize, &blueblocks, blueCode, iheader->biWidth, iheader->biHeight, 50);
	////fractalCompressionStep3(blue, initialBlockSize, initialBlockSize, initialBlockSize, &blueblocks, blueCode, iheader->biWidth, iheader->biHeight, 50);
	int paddedWidth = roundToDivisibleBy(iheader->biWidth, 16);
	int paddedHeight = roundToDivisibleBy(iheader->biHeight, 16);
	unsigned char* paddedBlue = padtoSize(blue, iheader->biWidth, iheader->biHeight, paddedWidth, paddedHeight);
	QuadTree* blueTree = fractalCompressionStep4(paddedBlue, paddedWidth, paddedHeight, 16);
	BlockCodes* blueCodes = new BlockCodes(blueTree);
	int bluelength = 0;
	unsigned char* bluestream = blueCodes->blockcodesToBitStream(16, paddedWidth, paddedHeight, &bluelength);
	delete blueTree;
	delete blueCodes;
	unsigned char* paddedRed = padtoSize(red, iheader->biWidth, iheader->biHeight, paddedWidth, paddedHeight);
	QuadTree* redTree = fractalCompressionStep4(paddedRed, paddedWidth, paddedHeight, 16);
	BlockCodes* redCodes = new BlockCodes(redTree);
	int redlength = 0;
	unsigned char* redstream = redCodes->blockcodesToBitStream(16, paddedWidth, paddedHeight, &redlength);
	delete redTree;
	delete redCodes;
	unsigned char* paddedGreen = padtoSize(green, iheader->biWidth, iheader->biHeight, paddedWidth, paddedHeight);
	QuadTree* greenTree = fractalCompressionStep4(paddedGreen, paddedWidth, paddedHeight, 16);
	BlockCodes* greenCodes = new BlockCodes(greenTree);
	int greenlength = 0;
	unsigned char* greenstream = greenCodes->blockcodesToBitStream(16, paddedWidth, paddedHeight, &greenlength);
	delete greenTree;
	delete greenCodes;
	/*BLOCKCODE** blueCode2 = bitstreamToBlockCodes(res, 16, iheader->biWidth, iheader->biHeight, &blueblocks2, reslength);
	decompressBlockCodes(blueCode2, 16, iheader->biWidth, iheader->biHeight);
	assertCodes(blueCode, blueCode2, blueblocks, blueblocks2);*/
	////red
	////fractalCompressionStep3(red, 0, 0, initialBlockSize, &redblocks, redCode, iheader->biWidth, iheader->biHeight, 50);
	////fractalCompressionStep3(red, 0, initialBlockSize, initialBlockSize, &redblocks, redCode, iheader->biWidth, iheader->biHeight, 50);
	////fractalCompressionStep3(red, initialBlockSize, 0, initialBlockSize, &redblocks, redCode, iheader->biWidth, iheader->biHeight, 50);
	////fractalCompressionStep3(red, initialBlockSize, initialBlockSize, initialBlockSize, &redblocks, redCode, iheader->biWidth, iheader->biHeight, 50);
	//QUADTREE* redTree = fractalCompressionStep4(red, iheader->biWidth, iheader->biHeight, 16, &redblocks);
	//redCode = quadTreeToArray(redTree, redblocks);
	////green
	///*fractalCompressionStep3(green, 0, 0, initialBlockSize, &greenblocks, greenCode, iheader->biWidth, iheader->biHeight, 50);
	//fractalCompressionStep3(green, 0, initialBlockSize, initialBlockSize, &greenblocks, greenCode, iheader->biWidth, iheader->biHeight, 50);
	//fractalCompressionStep3(green, initialBlockSize, 0, initialBlockSize, &greenblocks, greenCode, iheader->biWidth, iheader->biHeight, 50);
	//fractalCompressionStep3(green, initialBlockSize, initialBlockSize, initialBlockSize, &greenblocks, greenCode, iheader->biWidth, iheader->biHeight, 50);*/
	//QUADTREE* greenTree = fractalCompressionStep4(green, iheader->biWidth, iheader->biHeight, 16, &greenblocks);
	//greenCode = quadTreeToArray(greenTree, greenblocks);
	cheader->blueDomainCount = bluelength;
	cheader->greenDomainCount = greenlength;
	cheader->redDomainCount = redlength;
	cheader->maxblocksize = 16;
	//SaveCompressed("fcompressed128_1.frc", fheader, iheader, cheader, blueCode, redCode, greenCode);
	SaveCompressed2("fcompressed128_1.frc", fheader, iheader, cheader, bluestream, redstream, greenstream);
	delete fheader;
	delete[] pixels;
	delete[] blue;
	delete[] red;
	delete[] green;
	delete[] paddedBlue;
	delete[] paddedRed;
	delete[] paddedGreen;
	delete iheader;
	delete[] redstream;
	delete[] bluestream;
	delete[] greenstream;
	////free2Dimensions((unsigned char**)blueCode, cheader->blueDomainCount);
	////free2Dimensions((unsigned char**)redCode, cheader->redDomainCount);
	////free2Dimensions((unsigned char**)greenCode, cheader->greenDomainCount);
	delete cheader;
	//////endofcompression

	//////startofdecompression
	fheader = new BITMAPFILEHEADER;
	iheader = new BITMAPINFOHEADER;
	cheader = new HEADEROFFCOMFILE;
	unsigned char** pbluestream = new unsigned char*;
	unsigned char** predstream = new unsigned char*;
	unsigned char** pgreenstream = new unsigned char*;
	int bluecodecount = 0;
	int redcodecount = 0;
	int greencodecount = 0;
	LoadCompressed2("fcompressed128_1.frc", fheader, iheader, cheader, pbluestream, predstream, pgreenstream);
	int paddedWidthDec = roundToDivisibleBy(iheader->biWidth, cheader->maxblocksize);
	int paddedHeightDec = roundToDivisibleBy(iheader->biHeight, cheader->maxblocksize);
	BlockCodes* blueCodes2 = new BlockCodes(*pbluestream, cheader->maxblocksize, paddedWidthDec, paddedHeightDec, cheader->blueDomainCount);
	delete[] * pbluestream;
	BlockCodes* redCodes2 = new BlockCodes(*predstream, cheader->maxblocksize, paddedWidthDec, paddedHeightDec, cheader->redDomainCount);
	delete[] * predstream;
	BlockCodes* greenCodes2 = new BlockCodes(*pgreenstream, cheader->maxblocksize, paddedWidthDec, paddedHeightDec, cheader->greenDomainCount);
	delete[] * pgreenstream;
	////LoadCompressed("fcompressed128_1.frc", fheader, iheader, cheader, ptoblueCode, ptoredCode, ptogreenCode);

	blueCodes2->restoreOffsets(cheader->maxblocksize, paddedWidthDec, paddedHeightDec);
	redCodes2->restoreOffsets(cheader->maxblocksize, paddedWidthDec, paddedHeightDec);
	//delete[] * predstream;
	greenCodes2->restoreOffsets(cheader->maxblocksize, paddedWidthDec, paddedHeightDec);
	//delete[] *pgreenstream;
	//assertCodes(blueCode, ptoblueCode, blueblocks, bluecodecount);
	//assertCodes(redCode, ptoredCode, redblocks, redcodecount);
	//assertCodes(greenCode, ptogreenCode, greenblocks, greencodecount);
	unsigned char* paddedBluePixels = fractalDecompressionStep3(blueCodes2, paddedWidthDec, paddedHeightDec);
	unsigned char* paddedRedPixels = fractalDecompressionStep3(redCodes2, paddedWidthDec, paddedHeightDec);
	unsigned char* paddedGreenPixels = fractalDecompressionStep3(greenCodes2, paddedWidthDec, paddedHeightDec);
	unsigned char* bluePixels = croptoSize(paddedBluePixels, paddedWidthDec, paddedHeightDec, iheader->biWidth, iheader->biHeight);
	unsigned char* redPixels = croptoSize(paddedRedPixels, paddedWidthDec, paddedHeightDec, iheader->biWidth, iheader->biHeight);
	unsigned char* greenPixels = croptoSize(paddedGreenPixels, paddedWidthDec, paddedHeightDec, iheader->biWidth, iheader->biHeight);
	delete blueCodes2;
	delete redCodes2;
	delete greenCodes2;
	pixels = new unsigned char[iheader->biSizeImage];//чет фигня какаято
	colorChannelCombinator(pixels, bluePixels, greenPixels, redPixels, iheader->biWidth, iheader->biSizeImage / iheader->biHeight, iheader->biHeight);
	SavePixels("r128_11.bmp", pixels, fheader, iheader);
	std::cout << "blue channel total2: " << blocksum(bluePixels, iheader->biHeight, iheader->biWidth) << '\n';
	colorChannelCombinator(pixels, bluePixels, bluePixels, bluePixels, iheader->biWidth, iheader->biSizeImage / iheader->biHeight, iheader->biHeight);
	SavePixels("r128b121.bmp", pixels, fheader, iheader);
	std::cout << "green channel total2: " << blocksum(greenPixels, iheader->biHeight, iheader->biWidth) << '\n';
	colorChannelCombinator(pixels, greenPixels, greenPixels, greenPixels, iheader->biWidth, iheader->biSizeImage / iheader->biHeight, iheader->biHeight);
	SavePixels("r128g121.bmp", pixels, fheader, iheader);
	std::cout << "red channel total2: " << blocksum(redPixels, iheader->biHeight, iheader->biWidth) << '\n';
	colorChannelCombinator(pixels, redPixels, redPixels, redPixels, iheader->biWidth, iheader->biSizeImage / iheader->biHeight, iheader->biHeight);
	SavePixels("r128r121.bmp", pixels, fheader, iheader);
	delete[] pixels;
	delete[] bluePixels;
	delete[] greenPixels;
	delete[] redPixels;
	delete[] paddedBluePixels;
	delete[] paddedGreenPixels;
	delete[] paddedRedPixels;
	int x;
	std::cin >> x;
	return 0;
}