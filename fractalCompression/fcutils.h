#pragma once

namespace fractal_compression {

	void voodo(unsigned char* toflip);
	unsigned char evaluate(int value);
	void copyBits(unsigned char* dst, unsigned char* src, int *destoffset, int srcoffset, int bitlength);
	int minbytesforbits(int bitsize);
	unsigned char* rotate90(unsigned char* block, int n);
	unsigned char* rotate180(unsigned char* block, int n);
	unsigned char* rotate270(unsigned char* block, int n);
	unsigned char* flipHorizontal(unsigned char* block, int n);
	unsigned char* flipVertical(unsigned char* block, int n);
	unsigned char* flipAlongMainDiagonal(unsigned char* block, int n);
	unsigned char* flipAlongSubDiagonal(unsigned char* block, int n);
	unsigned char* downsize(unsigned char* pixels, int xoffset, int yoffset, int n, int width);
	void colorChannelSeparator(unsigned char* pixels, unsigned char* blue, unsigned char* green, unsigned char* red, int width, int pwidth, int height);
	void colorChannelCombinator(unsigned char* pixels, unsigned char* blue, unsigned char* green, unsigned char* red, int width, int pwidth, int height);
	void embed(unsigned char* pixels, unsigned char* toEmbed, int offset, int width, int blocksize);
	unsigned char* padtoSize(unsigned char* pixels, int oldx, int oldy, int newx, int newy);
	unsigned char* croptoSize(unsigned char* pixels, int oldx, int oldy, int newx, int newy);
	int roundToDivisibleBy(int value, int divider);
}
