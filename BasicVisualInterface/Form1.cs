using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace BasicVisualInterface
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

        private void compressBtn_Click(object sender, EventArgs e)
        {
            byte[] blueStream, redStream, greenStream;
            int bluesize, redsize, greensize;
            ImageCompressionHelper.compressImage(pictureBox1.Image, out blueStream, out redStream, out greenStream, out bluesize, out redsize, out greensize);
            pictureBox2.Image = ImageCompressionHelper.decompressImage(blueStream, redStream, greenStream, bluesize, redsize, greensize, pictureBox1.Image.Width, pictureBox1.Image.Height);
        }

        private void pictureBox1_Click(object sender, EventArgs e)
        {

        }
    }
}
