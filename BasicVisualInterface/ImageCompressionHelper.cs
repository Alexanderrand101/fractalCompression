using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

namespace BasicVisualInterface
{
    class ImageCompressionHelper
    {
        [DllImport("FCompLib.dll", CallingConvention = CallingConvention.Cdecl)]
        public static unsafe extern byte* externalFraclalCompression(byte* pixels, int width, int height, int* bitStreamSize);

        [DllImport("FDecompLib.dll", CallingConvention = CallingConvention.Cdecl)]
        public static unsafe extern byte* externalFraclalDecompression(byte* bitstream, int width, int height, int bitStreamSize);

        public static void compressImage(Image image, out byte[] blueBitStreamData, out byte[] redBitStreamData, out byte[] greenBitStreamData, out int blueStreamBitSize, out int redStreamBitSize, out int greenStreambitSize)
        {
            Bitmap toCompress = new Bitmap(image);
            byte[] blueBytes, redBytes, greenBytes;
            splitBitmap(toCompress, out blueBytes, out redBytes, out greenBytes);
            unsafe
            {
                fixed (byte* pixels = blueBytes)
                {
                    int bitStreamSize = 0;
                    int sizeinbytes;
                        byte* bitStream = externalFraclalCompression(pixels, toCompress.Width, toCompress.Height, &bitStreamSize);
                        blueStreamBitSize = bitStreamSize;
                        sizeinbytes = minbytesforbits(bitStreamSize);
                        blueBitStreamData = new byte[sizeinbytes];
                        for (int i = 0; i < sizeinbytes; i++)
                        {
                            blueBitStreamData[i] = bitStream[i];
                        }                    
                }
                fixed (byte* pixels = redBytes)
                {
                    int bitStreamSize = 0;
                    int sizeinbytes;
                    byte* bitStream = externalFraclalCompression(pixels, toCompress.Width, toCompress.Height, &bitStreamSize);
                    redStreamBitSize = bitStreamSize;
                    sizeinbytes = minbytesforbits(bitStreamSize);
                    redBitStreamData = new byte[sizeinbytes];
                    for (int i = 0; i < sizeinbytes; i++)
                    {
                        redBitStreamData[i] = bitStream[i];
                    }
                }
                fixed (byte* pixels = greenBytes)
                {
                    int bitStreamSize = 0;
                    int sizeinbytes;
                    byte* bitStream = externalFraclalCompression(pixels, toCompress.Width, toCompress.Height, &bitStreamSize);
                    greenStreambitSize = bitStreamSize;
                    sizeinbytes = minbytesforbits(bitStreamSize);
                    greenBitStreamData = new byte[sizeinbytes];
                    for (int i = 0; i < sizeinbytes; i++)
                    {
                        greenBitStreamData[i] = bitStream[i];
                    }
                }
            }
        }

        public static Image decompressImage(byte[] blueStream, byte[] redStream, byte[] greenStream, int bluebitsize, int redbitsize, int greenbitsize, int width, int height)
        {
            byte[] blueBytes = new byte[width * height];
            byte[] greenBytes = new byte[width * height];
            byte[] redBytes = new byte[width * height];
            unsafe
            {
                fixed(byte* blueBitStream = blueStream)
                {
                    byte* bluePixels = externalFraclalDecompression(blueBitStream, width, height, bluebitsize);
                    for (int i = 0; i < width*height; i++)
                    {
                        blueBytes[i] = bluePixels[i];
                     }
                }
                fixed (byte* redBitStream = redStream)
                {
                    byte* redPixels = externalFraclalDecompression(redBitStream, width, height, redbitsize);
                    for (int i = 0; i < width * height; i++)
                    {
                        redBytes[i] = redPixels[i];
                    }
                }
                fixed (byte* greenBitStream = greenStream)
                {
                    byte* greenPixels = externalFraclalDecompression(greenBitStream, width, height, greenbitsize);
                    for (int i = 0; i < width * height; i++)
                    {
                        greenBytes[i] = greenPixels[i];
                    }
                }
            }

            Bitmap toDecompress = assembleBitmap(blueBytes, redBytes, greenBytes, width, height);
            return toDecompress;
        }

        private static void splitBitmap(Bitmap bitmap, out byte[] blueBytes, out byte[] redBytes, out byte[] greenBytes)
        {
            blueBytes = new byte[bitmap.Width * bitmap.Height];
            redBytes = new byte[bitmap.Width * bitmap.Height];
            greenBytes = new byte[bitmap.Width * bitmap.Height];
            for (int i = 0; i < bitmap.Height; i++)
            {
                for (int j = 0; j < bitmap.Width; j++)
                {
                    blueBytes[i * bitmap.Width + j] = bitmap.GetPixel(j, i).B;
                    redBytes[i * bitmap.Width + j] = bitmap.GetPixel(j, i).R;
                    greenBytes[i * bitmap.Width + j] = bitmap.GetPixel(j, i).G;
                }
            }
        }

        private static Bitmap assembleBitmap(byte[] blueBytes, byte[] redBytes, byte[] greenBytes, int width, int height)
        {
            Bitmap toAssemble = new Bitmap(width, height);
            for (int i = 0; i < height; i++)
            {
                for (int j = 0; j < width; j++)
                {
                    toAssemble.SetPixel(j, i, Color.FromArgb(redBytes[i * width + j], greenBytes[i * width + j], blueBytes[i * width + j]));
                }
            }
            return toAssemble;
        }

        private static int minbytesforbits(int bits)
        {
            return bits / 8 + (bits % 8 > 0 ? 1 : 0);
        }
    }
}
