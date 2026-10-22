using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

namespace HIOps.EndpointSensor.Core
{
    /// <summary>
    /// 敏感个人隐私 (PII) 几何遮罩与脱敏引擎
    /// 严禁明文患者信息出端，对患者姓名栏、身份证号、病历区域应用纯黑遮罩或均值模糊
    /// </summary>
    public class PiiMaskingEngine
    {
        public static Bitmap CaptureAndMaskWindow(IntPtr hWnd, Rectangle[] sensitiveRegions = null)
        {
            // 抓取全屏或窗口位图
            var bounds = GetWindowBounds(hWnd);
            if (bounds.Width <= 0 || bounds.Height <= 0)
            {
                bounds = new Rectangle(0, 0, 1024, 768);
            }

            var bmp = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp))
            {
                g.CopyFromScreen(bounds.Location, Point.Empty, bounds.Size);

                // 应用遮罩 (若未传入特定坐标，默认对顶部患者信息条进行黑块遮蔽)
                if (sensitiveRegions == null || sensitiveRegions.Length == 0)
                {
                    // 默认门诊顶部患者信息条遮罩区: 宽 80%，高 45px
                    var defaultMask = new Rectangle(bounds.Width / 10, 30, (int)(bounds.Width * 0.8), 45);
                    MaskRegion(g, defaultMask);
                }
                else
                {
                    foreach (var rect in sensitiveRegions)
                    {
                        MaskRegion(g, rect);
                    }
                }
            }

            return bmp;
        }

        public static void MaskRegion(Graphics g, Rectangle rect)
        {
            using (var brush = new SolidBrush(Color.Black))
            {
                g.FillRectangle(brush, rect);
            }
            using (var pen = new Pen(Color.Red, 1))
            {
                g.DrawRectangle(pen, rect);
            }
        }

        public static string ConvertToCompressedBase64(Bitmap bmp, int maxWidth = 800)
        {
            int newWidth = Math.Min(bmp.Width, maxWidth);
            int newHeight = (int)((double)bmp.Height / bmp.Width * newWidth);

            using (var thumb = new Bitmap(newWidth, newHeight))
            using (var g = Graphics.FromImage(thumb))
            using (var ms = new MemoryStream())
            {
                g.DrawImage(bmp, 0, 0, newWidth, newHeight);
                thumb.Save(ms, ImageFormat.Jpeg);
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        private static Rectangle GetWindowBounds(IntPtr hWnd)
        {
            // 默认返回当前屏幕工作区
            return System.Windows.Forms.Screen.PrimaryScreen.Bounds;
        }
    }
}
