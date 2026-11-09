using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Linq;

namespace WowAddonHelper
{
    /// <summary>
    /// 와우 UI 분위기의 색/글꼴/그리기 도구. 블리자드 이미지는 쓰지 않고 직접 그린다.
    /// </summary>
    public static class Theme
    {
        // 바탕: 어두운 돌/가죽 느낌
        public static readonly Color BgTop = Color.FromArgb(38, 30, 22);
        public static readonly Color BgBottom = Color.FromArgb(16, 12, 9);
        public static readonly Color Inset = Color.FromArgb(10, 8, 6);
        public static readonly Color InsetLine = Color.FromArgb(60, 48, 32);

        // 금색 테두리 / 제목
        public static readonly Color Gold = Color.FromArgb(255, 209, 0);        // 와우 제목 금색
        public static readonly Color GoldLight = Color.FromArgb(232, 196, 120);
        public static readonly Color GoldMid = Color.FromArgb(176, 136, 64);
        public static readonly Color GoldDark = Color.FromArgb(92, 68, 30);

        // 글자
        public static readonly Color Text = Color.FromArgb(240, 236, 226);
        public static readonly Color TextDim = Color.FromArgb(160, 150, 128);
        public static readonly Color Green = Color.FromArgb(30, 255, 0);        // 고급 아이템 초록
        public static readonly Color Yellow = Color.FromArgb(255, 210, 60);
        public static readonly Color Orange = Color.FromArgb(255, 128, 0);
        public static readonly Color Red = Color.FromArgb(255, 70, 60);

        // 붉은 버튼
        public static readonly Color BtnTop = Color.FromArgb(170, 22, 14);
        public static readonly Color BtnBottom = Color.FromArgb(92, 6, 4);
        public static readonly Color BtnHoverTop = Color.FromArgb(205, 40, 24);
        public static readonly Color BtnHoverBottom = Color.FromArgb(120, 12, 6);

        public static float Scale = 1f;
        public static int S(int v) => (int)Math.Round(v * Scale);

        public static Font TitleFont, HeadFont, BodyFont, SmallFont, ButtonFont, PathFont;

        public static void Init(float dpi)
        {
            Scale = dpi / 96f;
            var installed = new InstalledFontCollection().Families.Select(f => f.Name).ToArray();
            string Pick(params string[] names) => names.FirstOrDefault(n => installed.Contains(n)) ?? "Segoe UI";
            // 제목은 명조 계열로 판타지 느낌, 본문은 읽기 쉬운 고딕
            var serif = Pick("바탕", "Batang", "Gungsuh", "맑은 고딕", "Malgun Gothic");
            var sans = Pick("맑은 고딕", "Malgun Gothic", "Segoe UI");
            TitleFont = new Font(serif, 15f, FontStyle.Bold);
            HeadFont = new Font(sans, 10.5f, FontStyle.Bold);
            BodyFont = new Font(sans, 9.5f);
            SmallFont = new Font(sans, 8.5f);
            ButtonFont = new Font(sans, 10f, FontStyle.Bold);
            PathFont = new Font("Segoe UI", 8.5f);
        }

        public static GraphicsPath RoundRect(RectangleF r, float radius)
        {
            var p = new GraphicsPath();
            if (radius <= 0) { p.AddRectangle(r); return p; }
            float d = radius * 2;
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        public static void Smooth(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        }

        /// <summary>금속 느낌 금색 이중 테두리 (바깥 밝게, 안쪽 어둡게)</summary>
        public static void GoldFrame(Graphics g, Rectangle r, int radius)
        {
            using (var outer = new LinearGradientBrush(r, GoldLight, GoldDark, LinearGradientMode.Vertical))
            using (var pen = new Pen(outer, S(3)))
            using (var path = RoundRect(Shrink(r, S(2)), radius))
                g.DrawPath(pen, path);
            using (var pen = new Pen(Color.FromArgb(200, GoldDark), S(1)))
            using (var path = RoundRect(Shrink(r, S(5)), Math.Max(0, radius - S(3))))
                g.DrawPath(pen, path);
        }

        /// <summary>테두리 모서리 장식: 작은 금색 마름모</summary>
        public static void CornerGems(Graphics g, Rectangle r)
        {
            int o = S(4), sz = S(7);
            foreach (var pt in new[] { new Point(r.Left + o, r.Top + o), new Point(r.Right - o, r.Top + o),
                                       new Point(r.Left + o, r.Bottom - o), new Point(r.Right - o, r.Bottom - o) })
            {
                var pts = new[] { new PointF(pt.X, pt.Y - sz), new PointF(pt.X + sz, pt.Y),
                                  new PointF(pt.X, pt.Y + sz), new PointF(pt.X - sz, pt.Y) };
                using (var b = new LinearGradientBrush(new RectangleF(pt.X - sz, pt.Y - sz, sz * 2, sz * 2), GoldLight, GoldDark, 45f))
                    g.FillPolygon(b, pts);
                using (var p = new Pen(Color.FromArgb(60, 40, 10), 1))
                    g.DrawPolygon(p, pts);
            }
        }

        /// <summary>안쪽이 파인 어두운 판 (목록/입력 칸 바탕)</summary>
        public static void InsetPanel(Graphics g, Rectangle r)
        {
            using (var b = new SolidBrush(Color.FromArgb(220, Inset)))
            using (var path = RoundRect(r, S(4)))
            {
                g.FillPath(b, path);
                using (var p = new Pen(InsetLine, 1)) g.DrawPath(p, path);
            }
        }

        public static Rectangle Shrink(Rectangle r, int by) => new Rectangle(r.X + by, r.Y + by, r.Width - by * 2, r.Height - by * 2);

        /// <summary>제목 글자: 검은 그림자 + 금색</summary>
        public static void ShadowText(Graphics g, string text, Font f, Color c, RectangleF r, StringFormat fmt)
        {
            using (var sh = new SolidBrush(Color.FromArgb(200, 0, 0, 0)))
                g.DrawString(text, f, sh, new RectangleF(r.X + S(1), r.Y + S(1), r.Width, r.Height), fmt);
            using (var b = new SolidBrush(c))
                g.DrawString(text, f, b, r, fmt);
        }
    }
}
