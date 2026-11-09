using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace WowAddonHelper
{
    /// <summary>깜빡임 없이 직접 그리는 컨트롤 바탕</summary>
    public class PaintedControl : Control
    {
        protected bool Hover;

        public PaintedControl()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Cursor = Cursors.Hand;
        }

        protected override void OnMouseEnter(EventArgs e) { Hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { Hover = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
    }

    /// <summary>와우식 붉은 버튼 (금색 테두리)</summary>
    public class WowButton : PaintedControl
    {
        bool pressed;

        public WowButton() { Font = Theme.ButtonFont; }

        protected override void OnMouseDown(MouseEventArgs e) { pressed = true; Invalidate(); base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { pressed = false; Invalidate(); base.OnMouseUp(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Theme.Smooth(g);
            var r = new Rectangle(0, 0, Width - 1, Height - 1);
            int rad = Theme.S(5);
            Color top, bottom;
            if (!Enabled) { top = Color.FromArgb(70, 64, 58); bottom = Color.FromArgb(36, 32, 28); }
            else if (Hover) { top = Theme.BtnHoverTop; bottom = Theme.BtnHoverBottom; }
            else { top = Theme.BtnTop; bottom = Theme.BtnBottom; }
            if (pressed) { var t = top; top = bottom; bottom = t; }

            using (var path = Theme.RoundRect(r, rad))
            using (var b = new LinearGradientBrush(r, top, bottom, LinearGradientMode.Vertical))
                g.FillPath(b, path);
            // 윗부분 광택
            var gloss = new Rectangle(r.X + Theme.S(3), r.Y + Theme.S(2), r.Width - Theme.S(6), r.Height / 2 - Theme.S(2));
            using (var path = Theme.RoundRect(gloss, Theme.S(3)))
            using (var b = new LinearGradientBrush(gloss, Color.FromArgb(Enabled ? 70 : 25, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), LinearGradientMode.Vertical))
                g.FillPath(b, path);
            // 금색 테두리
            using (var path = Theme.RoundRect(r, rad))
            using (var b = new LinearGradientBrush(r, Enabled ? Theme.GoldLight : Theme.GoldDark, Theme.GoldDark, LinearGradientMode.Vertical))
            using (var p = new Pen(b, Theme.S(2)))
                g.DrawPath(p, path);

            var fmt = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            var tr = new RectangleF(0, pressed ? Theme.S(1) : 0, Width, Height);
            Theme.ShadowText(g, Text, Font, Enabled ? Theme.Gold : Theme.TextDim, tr, fmt);
        }
    }

    /// <summary>금테 네모 체크박스 + 글자</summary>
    public class WowCheckBox : PaintedControl
    {
        bool isChecked;
        public event EventHandler CheckedChanged;

        public bool Checked
        {
            get => isChecked;
            set { if (isChecked == value) return; isChecked = value; Invalidate(); CheckedChanged?.Invoke(this, EventArgs.Empty); }
        }

        public WowCheckBox() { Font = Theme.BodyFont; }

        protected override void OnClick(EventArgs e) { Checked = !Checked; base.OnClick(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Theme.Smooth(g);
            int box = Theme.S(18);
            var r = new Rectangle(1, (Height - box) / 2, box, box);
            DrawBox(g, r, Checked, Hover);
            var tr = new RectangleF(box + Theme.S(8), 0, Width - box - Theme.S(8), Height);
            using (var b = new SolidBrush(Hover ? Theme.Text : Theme.TextDim))
                g.DrawString(Text, Font, b, tr, new StringFormat { LineAlignment = StringAlignment.Center });
        }

        public static void DrawBox(Graphics g, Rectangle r, bool on, bool hover)
        {
            using (var b = new SolidBrush(Color.FromArgb(10, 8, 6))) g.FillRectangle(b, r);
            using (var p = new Pen(hover ? Theme.GoldLight : Theme.GoldMid, Theme.S(2))) g.DrawRectangle(p, r);
            if (!on) return;
            // 와우식 노란 체크 표시
            var pts = new[]
            {
                new PointF(r.X + r.Width * 0.18f, r.Y + r.Height * 0.52f),
                new PointF(r.X + r.Width * 0.42f, r.Y + r.Height * 0.78f),
                new PointF(r.X + r.Width * 0.86f, r.Y + r.Height * 0.20f),
            };
            using (var p = new Pen(Color.FromArgb(120, 60, 0), Theme.S(4)) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round })
                g.DrawLines(p, pts);
            using (var p = new Pen(Theme.Gold, Theme.S(2)) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round })
                g.DrawLines(p, pts);
        }
    }

    /// <summary>애드온 한 줄: [체크] 이름 / 설명 ........ 상태</summary>
    public class AddonRow : PaintedControl
    {
        public AddonInfo Info;
        public bool Checked;
        public string Status = "";
        public Color StatusColor = Theme.TextDim;
        public event EventHandler Toggled;

        public AddonRow() { Height = Theme.S(54); }

        protected override void OnClick(EventArgs e)
        {
            Checked = !Checked;
            Invalidate();
            Toggled?.Invoke(this, EventArgs.Empty);
            base.OnClick(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Theme.Smooth(g);
            if (Hover)
            {
                var hr = new Rectangle(0, 0, Width, Height);
                using (var b = new LinearGradientBrush(hr, Color.FromArgb(60, Theme.Gold), Color.FromArgb(8, Theme.Gold), LinearGradientMode.Horizontal))
                    g.FillRectangle(b, hr);
            }
            // 줄 구분선
            using (var p = new Pen(Color.FromArgb(50, Theme.GoldMid))) g.DrawLine(p, Theme.S(8), Height - 1, Width - Theme.S(8), Height - 1);

            int box = Theme.S(20), pad = Theme.S(12);
            WowCheckBox.DrawBox(g, new Rectangle(pad, (Height - box) / 2, box, box), Checked, Hover);

            int x = pad + box + Theme.S(12);
            int statusW = Theme.S(150);
            var title = Info.Title + (Info.Dev ? "  [진단용]" : "");
            using (var b = new SolidBrush(Checked ? Theme.Gold : Theme.Text))
                g.DrawString(title, Theme.HeadFont, b, new RectangleF(x, Theme.S(8), Width - x - statusW, Theme.S(22)));
            using (var b = new SolidBrush(Theme.TextDim))
                g.DrawString(string.IsNullOrEmpty(Info.Notes) ? Info.Name : Info.Notes, Theme.SmallFont, b,
                    new RectangleF(x, Theme.S(30), Width - x - statusW, Theme.S(20)), new StringFormat { Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap });

            using (var b = new SolidBrush(StatusColor))
                g.DrawString(Status, Theme.BodyFont, b, new RectangleF(Width - statusW - pad, 0, statusW, Height),
                    new StringFormat { Alignment = StringAlignment.Far, LineAlignment = StringAlignment.Center });
        }
    }
}
