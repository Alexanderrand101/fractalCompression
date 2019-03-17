#include "fcutils.h"

namespace fractal_compression {

	void voodo(unsigned char* toflip)
	{
		unsigned char frst = toflip[0];
		unsigned char scnd = toflip[1];
		toflip[0] = toflip[3];
		toflip[1] = toflip[2];
		toflip[3] = frst;
		toflip[2] = scnd;
	}

	unsigned char evaluate(int value)
	{
		unsigned char i = 0;
		while (value >> i > 0)
		{
			i++;
		}
		return i;
	}

	void copyBits(unsigned char* dst, unsigned char* src, int *destoffset, int srcoffset, int bitlength)
	{
		int dstbitoffset = *destoffset % 8;
		int srcbitoffset = srcoffset % 8;
		dst += *destoffset / 8;
		src += srcoffset / 8;
		*destoffset += bitlength;
		for (; bitlength > 0; bitlength -= 8)
		{
			unsigned char transfer = *src << srcbitoffset;
			src++;
			if (srcbitoffset != 0 && srcbitoffset + bitlength > 8)
				transfer |= *src >> (8 - srcbitoffset);
			*dst &= (0xFF << (8 - dstbitoffset));
			*dst |= transfer >> dstbitoffset;
			dst++;
			if (dstbitoffset != 0 && dstbitoffset + bitlength > 8)
			{
				*dst = 0;
				*dst |= transfer << (8 - dstbitoffset);
			}
		}
	}

	int minbytesforbits(int bitsize)
	{
		return bitsize / 8 + (bitsize % 8 > 0 ? 1 : 0);
	}

	unsigned char* rotate90(unsigned char* block, int n)
	{
		unsigned char* newblock = new unsigned char[n * n];
		for (int i = 0; i < n; i++)
		{
			for (int j = 0; j < n; j++)
			{
				newblock[i * n + j] = block[n * (n - j - 1) + i];
			}
		}
		return newblock;
	}

	unsigned char* rotate180(unsigned char* block, int n)
	{
		unsigned char* newblock = new unsigned char[n * n];
		for (int i = 0; i < n; i++)
		{
			for (int j = 0; j < n; j++)
			{
				newblock[i * n + j] = block[n * (n - i - 1) + n - j - 1];
			}
		}
		return newblock;
	}

	unsigned char* rotate270(unsigned char* block, int n)
	{
		unsigned char* newblock = new unsigned char[n * n];
		for (int i = 0; i < n; i++)
		{
			for (int j = 0; j < n; j++)
			{
				newblock[i * n + j] = block[j * n + n - i - 1];
			}
		}
		return newblock;
	}

	unsigned char* flipHorizontal(unsigned char* block, int n)
	{
		unsigned char* newblock = new unsigned char[n * n];
		for (int i = 0; i < n; i++)
		{
			for (int j = 0; j < n; j++)
			{
				newblock[i * n + j] = block[i * n + n - j - 1];
			}
		}
		return newblock;
	}

	unsigned char* flipVertical(unsigned char* block, int n)
	{
		unsigned char* newblock = new unsigned char[n * n];
		for (int i = 0; i < n; i++)
		{
			for (int j = 0; j < n; j++)
			{
				newblock[i * n + j] = block[(n - i - 1) * n + j];
			}
		}
		return newblock;
	}

	unsigned char* flipAlongMainDiagonal(unsigned char* block, int n)
	{
		unsigned char* newblock = new unsigned char[n * n];;
		for (int i = 0; i < n; i++)
		{
			for (int j = 0; j < n; j++)
			{
				newblock[i * n + j] = block[j * n + i];
			}
		}
		return newblock;
	}

	unsigned char* flipAlongSubDiagonal(unsigned char* block, int n)
	{
		unsigned char* newblock = new unsigned char[n * n];
		for (int i = 0; i < n; i++)
		{
			for (int j = 0; j < n; j++)
			{
				newblock[i * n + j] = block[(n - j - 1) * n + n - i - 1];
			}
		}
		return newblock;
	}

	unsigned char* downsize(unsigned char* pixels, int xoffset, int yoffset, int n, int width)
	{
		int m = n / 2;
		unsigned char* newblock = new unsigned char[m * m];
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

	void colorChannelSeparator(unsigned char* pixels, unsigned char* blue, unsigned char* green, unsigned char* red, int width, int pwidth, int height)
	{
		for (int i = 0; i < height; i++)
		{
			for (int j = 0; j < width; j++)
			{
				blue[i * width + j] = pixels[i * pwidth + j * 3];
				green[i * width + j] = pixels[i * pwidth  + j * 3 + 1];
				red[i * width + j] = pixels[i * pwidth + j * 3 + 2];
			}
		}
	}

	void colorChannelCombinator(unsigned char* pixels, unsigned char* blue, unsigned char* green, unsigned char* red, int width, int pwidth, int height)
	{
		for (int i = 0; i < height; i++)
		{
			for (int j = 0; j < width; j++)
			{
				pixels[i * pwidth + j * 3] = blue[i * width + j];
				pixels[i * pwidth + j * 3 + 1] = green[i * width + j];
				pixels[i * pwidth + j * 3 + 2] = red[i * width + j];
			}
		}
	}

	void embed(unsigned char* pixels, unsigned char* toEmbed, int offset, int width, int blocksize)
	{
		for (int i = 0; i < blocksize; i++)
		{
			for (int j = 0; j < blocksize; j++)
			{
				pixels[offset + i * width + j] = toEmbed[i * blocksize + j];
			}
		}
	}

	unsigned char* padtoSize(unsigned char* pixels, int oldx, int oldy, int newx, int newy)
	{
		unsigned char* newPixels = new unsigned char[newx * newy];
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

	unsigned char* croptoSize(unsigned char* pixels, int oldx, int oldy, int newx, int newy)
	{
		unsigned char* newPixels = new unsigned char[newx * newy];
		for (int i = 0; i <  newy; i++)
		{
			for (int j = 0; j < newx; j++) newPixels[i * newx + j] = pixels[i * oldx + j];
		}
		return newPixels;
	}

	int roundToDivisibleBy(int value, int divider) {
		return (value % divider > 0 ? value + divider - value % divider : value);
	}

}