using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace WowAddonHelper
{
    /// <summary>와우풍 확인 창: 제목 + 설명 + (선택) 체크박스 + [확인] [취소]</summary>
    public class WowDialog : Form
    {
        readonly string title;
        public WowCheckBox Option { get; }

        public WowDialog(string title, string message, string okText, string optionText = null, bool optionChecked = false, bool showCancel = true)
        {
            this.title = title;
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.CenterParent;
            ShowInTaskbar = false;
            DoubleBuffered = true;
            BackColor = Theme.BgBottom;
            ClientSize = new Size(Theme.S(420), Theme.S(optionText != null ? 250 : 210));
            KeyPreview = true;
            KeyDown += (s, e) => { if (e.KeyCode == Keys.Escape) { DialogResult = DialogResult.Cancel; Close(); } };

            int m = Theme.S(24);
            var msg = new Label
            {
                Text = message,
                Font = Theme.BodyFont,
                ForeColor = Theme.Text,
                BackColor = Color.Transparent,
                Bounds = new Rectangle(m, Theme.S(60), ClientSize.Width - m * 2, Theme.S(80)),
            };
            Controls.Add(msg);

            if (optionText != null)
            {
                Option = new WowCheckBox { Text = optionText, Checked = optionChecked, Bounds = new Rectangle(m, Theme.S(146), ClientSize.Width - m * 2, Theme.S(28)) };
                Controls.Add(Option);
            }

            int by = ClientSize.Height - Theme.S(60);
            var okX = showCancel ? ClientSize.Width / 2 - Theme.S(150) : (ClientSize.Width - Theme.S(140)) / 2;
            var ok = new WowButton { Text = okText, Bounds = new Rectangle(okX, by, Theme.S(140), Theme.S(38)) };
            var cancel = new WowButton { Text = "취소", Bounds = new Rectangle(ClientSize.Width / 2 + Theme.S(10), by, Theme.S(140), Theme.S(38)) };
            ok.Click += (s, e) => { DialogResult = DialogResult.OK; Close(); };
            cancel.Click += (s, e) => { DialogResult = DialogResult.Cancel; Close(); };
            Controls.Add(ok);
            if (showCancel) Controls.Add(cancel);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Theme.Smooth(g);
            var r = ClientRectangle;
            using (var b = new LinearGradientBrush(r, Theme.BgTop, Theme.BgBottom, LinearGradientMode.Vertical))
                g.FillRectangle(b, r);
            var tb = new Rectangle(Theme.S(10), Theme.S(10), r.Width - Theme.S(20), Theme.S(40));
            using (var b = new LinearGradientBrush(tb, Color.FromArgb(70, 50, 24), Color.FromArgb(28, 20, 10), LinearGradientMode.Vertical))
            using (var path = Theme.RoundRect(tb, Theme.S(4)))
                g.FillPath(b, path);
            Theme.ShadowText(g, title, Theme.HeadFont, Theme.Gold, tb,
                new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center });
            Theme.GoldFrame(g, r, Theme.S(8));
            Theme.CornerGems(g, r);
        }

        protected override CreateParams CreateParams
        {
            get { var cp = base.CreateParams; cp.ClassStyle |= 0x20000; return cp; }   // 그림자
        }
    }
}
