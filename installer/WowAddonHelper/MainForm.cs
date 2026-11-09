using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace WowAddonHelper
{
    /// <summary>테두리 없는 와우풍 창: 금테 + 제목 띠 + 애드온 목록 + 붉은 버튼</summary>
    public class MainForm : Form
    {
        readonly Label pathLabel = new Label();
        readonly WowButton pathButton = new WowButton { Text = "변경" };
        readonly Panel list = new Panel();
        readonly WowCheckBox autoCheck = new WowCheckBox { Text = "Windows 시작할 때 자동으로 업데이트" };
        readonly WowButton refreshButton = new WowButton { Text = "새로고침" };
        readonly WowButton applyButton = new WowButton { Text = "선택대로 적용" };
        readonly Label statusLabel = new Label();
        readonly Label helpLabel = new Label();
        readonly PaintedClose closeButton = new PaintedClose();

        string addonsDir;
        ReleaseInfo release;
        InstalledState installed;
        readonly List<AddonRow> rows = new List<AddonRow>();
        Rectangle titleBar;
        public string SnapshotPath;

        public MainForm()
        {
            Text = "애드온 도우미";
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(Theme.S(620), Theme.S(520));
            DoubleBuffered = true;
            BackColor = Theme.BgBottom;
            Font = Theme.BodyFont;
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

            int m = Theme.S(24);
            titleBar = new Rectangle(0, 0, ClientSize.Width, Theme.S(56));

            closeButton.Bounds = new Rectangle(ClientSize.Width - Theme.S(44), Theme.S(14), Theme.S(26), Theme.S(26));
            closeButton.Click += (s, e) => Close();

            // 게임 폴더 줄
            var pathCaption = MakeLabel("게임 폴더", Theme.HeadFont, Theme.Gold);
            pathCaption.Bounds = new Rectangle(m, Theme.S(68), Theme.S(80), Theme.S(26));
            pathLabel.Bounds = new Rectangle(m + Theme.S(84), Theme.S(68), ClientSize.Width - m * 2 - Theme.S(84) - Theme.S(76), Theme.S(26));
            StyleLabel(pathLabel, Theme.PathFont, Theme.TextDim);   // 한글 글꼴은 \ 를 ₩ 로 그려서 경로만 Segoe UI
            pathLabel.AutoEllipsis = true;
            pathButton.Bounds = new Rectangle(ClientSize.Width - m - Theme.S(68), Theme.S(66), Theme.S(68), Theme.S(28));
            pathButton.Font = Theme.SmallFont;
            pathButton.Click += (s, e) => PickGameFolder();

            // 목록 (안쪽 판 위에 줄들을 올린다)
            var listArea = new Rectangle(m, Theme.S(104), ClientSize.Width - m * 2, Theme.S(262));
            list.Bounds = Theme.Shrink(listArea, Theme.S(4));
            list.AutoScroll = true;
            list.BackColor = Color.FromArgb(14, 11, 8);
            Tag = listArea;

            helpLabel.Bounds = new Rectangle(m, listArea.Bottom + Theme.S(6), ClientSize.Width - m * 2, Theme.S(36));
            StyleLabel(helpLabel, Theme.SmallFont, Theme.TextDim);
            helpLabel.Text = "체크한 애드온은 설치/업데이트하고, 체크를 끈 애드온은 지웁니다.\n적용 후 게임에서 /reload (새로 추가한 애드온은 게임 재시작).";

            autoCheck.Bounds = new Rectangle(m, Theme.S(414), Theme.S(330), Theme.S(28));
            autoCheck.CheckedChanged += (s, e) => { try { Core.AutoStartEnabled = autoCheck.Checked; } catch (Exception ex) { SetStatus("자동 실행 설정 실패: " + ex.Message, Theme.Red); } };

            refreshButton.Bounds = new Rectangle(ClientSize.Width - m - Theme.S(300), Theme.S(452), Theme.S(120), Theme.S(40));
            refreshButton.Click += async (s, e) => await LoadAsync();
            applyButton.Bounds = new Rectangle(ClientSize.Width - m - Theme.S(170), Theme.S(452), Theme.S(170), Theme.S(40));
            applyButton.Click += async (s, e) => await ApplyAsync();

            statusLabel.Bounds = new Rectangle(m, Theme.S(452), ClientSize.Width - m * 2 - Theme.S(310), Theme.S(40));
            StyleLabel(statusLabel, Theme.SmallFont, Theme.TextDim);

            Controls.AddRange(new Control[] { closeButton, pathCaption, pathLabel, pathButton, list, helpLabel, autoCheck, refreshButton, applyButton, statusLabel });

            Shown += async (s, e) =>
            {
                autoCheck.Checked = Core.AutoStartEnabled;
                addonsDir = Core.LoadGameAddOns();
                UpdatePathLabel();
                await LoadAsync();
                if (SnapshotPath != null)
                {
                    // 개발용: 화면 캡처 없이 창 자체를 그림으로 저장하고 종료 (--snapshot <png>)
                    using (var bmp = new Bitmap(Width, Height))
                    {
                        DrawToBitmap(bmp, new Rectangle(0, 0, Width, Height));
                        bmp.Save(SnapshotPath);
                    }
                    Close();
                }
            };
        }

        static Label MakeLabel(string text, Font f, Color c)
        {
            var l = new Label { Text = text };
            StyleLabel(l, f, c);
            return l;
        }

        static void StyleLabel(Label l, Font f, Color c)
        {
            l.Font = f;
            l.ForeColor = c;
            l.BackColor = Color.Transparent;
            l.TextAlign = ContentAlignment.MiddleLeft;
        }

        void UpdatePathLabel()
        {
            if (addonsDir == null)
            {
                pathLabel.Text = "찾지 못함 — [변경]을 눌러 와우 폴더를 골라 주세요";
                pathLabel.ForeColor = Theme.Red;
            }
            else
            {
                pathLabel.Text = addonsDir;
                pathLabel.ForeColor = Theme.TextDim;
            }
        }

        void SetStatus(string text, Color color)
        {
            statusLabel.Text = text;
            statusLabel.ForeColor = color;
        }

        void SetBusy(bool busy)
        {
            applyButton.Enabled = refreshButton.Enabled = pathButton.Enabled = !busy;
            UseWaitCursor = busy;
        }

        void PickGameFolder()
        {
            using (var dlg = new FolderBrowserDialog { Description = "World of Warcraft 폴더(또는 _forever_ 폴더)를 골라 주세요" })
            {
                if (dlg.ShowDialog(this) != DialogResult.OK) return;
                var p = Core.NormalizeGamePath(dlg.SelectedPath);
                if (p == null)
                {
                    SetStatus("와우 포에버 폴더가 아닙니다. _forever_ 가 들어 있는 폴더를 골라 주세요.", Theme.Red);
                    return;
                }
                addonsDir = p;
                Core.SaveGameAddOns(p);
                UpdatePathLabel();
                RefreshRows();
            }
        }

        async Task LoadAsync()
        {
            SetBusy(true);
            SetStatus("최신 버전 확인 중...", Theme.TextDim);
            try
            {
                release = await Task.Run(() => Core.FetchLatestRelease());
                if (await Task.Run(() => Core.UpdateSelf(release)))
                {
                    SetStatus("도우미 새 버전을 받았습니다. 다시 시작합니다...", Theme.Green);
                    Process.Start(Core.InstalledExe);
                    Close();
                    return;
                }
                RefreshRows();
            }
            catch (Exception ex)
            {
                SetStatus("최신 버전을 가져오지 못했습니다: " + ex.Message, Theme.Red);
            }
            finally { SetBusy(false); }
        }

        void RefreshRows()
        {
            installed = addonsDir != null ? Core.ReadInstalled(addonsDir) : null;
            list.SuspendLayout();
            list.Controls.Clear();
            rows.Clear();
            if (release == null) { list.ResumeLayout(); return; }

            var have = new HashSet<string>(installed?.Addons ?? new List<string>(), StringComparer.OrdinalIgnoreCase);
            // 아무것도 안 깔린 첫 실행이면 개발용이 아닌 애드온을 기본으로 체크해 둔다
            bool firstRun = installed == null;
            foreach (var a in release.Addons.OrderBy(a => a.Dev).ThenBy(a => a.Title))
            {
                var row = new AddonRow { Info = a, Dock = DockStyle.Top, Checked = have.Contains(a.Name) || (firstRun && !a.Dev) };
                bool isInstalled = have.Contains(a.Name);
                if (!isInstalled) { row.Status = "설치 안 됨"; row.StatusColor = Theme.TextDim; }
                else if (installed.Dev) { row.Status = "개발 빌드"; row.StatusColor = Theme.Orange; }
                else if (installed.Version == release.Version) { row.Status = "최신 v" + release.Version; row.StatusColor = Theme.Green; }
                else { row.Status = $"업데이트 v{installed.Version} → v{release.Version}"; row.StatusColor = Theme.Yellow; }
                row.Toggled += (s, e) => UpdateApplyHint();
                rows.Add(row);
            }
            // Dock=Top 은 나중에 넣은 게 위로 가므로 거꾸로 넣는다
            for (int i = rows.Count - 1; i >= 0; i--) list.Controls.Add(rows[i]);
            list.ResumeLayout();
            UpdateApplyHint();
        }

        void UpdateApplyHint()
        {
            if (release == null) return;
            if (addonsDir == null) { SetStatus("게임 폴더를 먼저 정해 주세요.", Theme.Red); return; }
            var want = rows.Where(r => r.Checked).Select(r => r.Info.Name).ToList();
            var have = installed?.Addons ?? new List<string>();
            bool upToDate = installed != null && !installed.Dev && installed.Version == release.Version;
            bool same = want.Count == have.Count && want.All(n => have.Contains(n, StringComparer.OrdinalIgnoreCase));
            if (same && upToDate) SetStatus($"모두 최신입니다 (v{release.Version}).", Theme.Green);
            else if (installed?.Dev == true) SetStatus("개발 빌드가 깔려 있습니다. 적용하면 릴리스 버전으로 바뀝니다.", Theme.Orange);
            else SetStatus("바뀐 내용이 있습니다. [선택대로 적용]을 누르세요.", Theme.Yellow);
        }

        async Task ApplyAsync()
        {
            if (release == null || addonsDir == null) { UpdateApplyHint(); return; }
            var want = rows.Where(r => r.Checked).Select(r => r.Info.Name).ToList();
            SetBusy(true);
            try
            {
                var msg = await Task.Run(() => Core.Apply(addonsDir, release, want, p => BeginInvoke((Action)(() => SetStatus(p, Theme.TextDim)))));
                RefreshRows();
                SetStatus(Core.IsGameRunning() ? "적용 완료! 게임에서 /reload 하세요." : "적용 완료! 게임을 켜면 바로 적용됩니다.", Theme.Green);
            }
            catch (Exception ex)
            {
                SetStatus("실패: " + ex.Message, Theme.Red);
                Core.Log("적용 실패: " + ex);
            }
            finally { SetBusy(false); }
        }

        // ---------- 창 그리기 / 끌기 ----------

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Theme.Smooth(g);
            var r = ClientRectangle;
            using (var b = new LinearGradientBrush(r, Theme.BgTop, Theme.BgBottom, LinearGradientMode.Vertical))
                g.FillRectangle(b, r);
            // 은은한 돌 질감 대신 가로 줄무늬
            using (var p = new Pen(Color.FromArgb(10, 255, 220, 160)))
                for (int y = titleBar.Bottom; y < r.Bottom; y += Theme.S(6)) g.DrawLine(p, 0, y, r.Width, y);

            // 제목 띠
            var tb = new Rectangle(Theme.S(10), Theme.S(10), r.Width - Theme.S(20), titleBar.Height - Theme.S(14));
            using (var b = new LinearGradientBrush(tb, Color.FromArgb(70, 50, 24), Color.FromArgb(28, 20, 10), LinearGradientMode.Vertical))
            using (var path = Theme.RoundRect(tb, Theme.S(4)))
                g.FillPath(b, path);
            using (var p = new Pen(Theme.GoldDark, Theme.S(1)))
                g.DrawLine(p, tb.Left + Theme.S(10), tb.Bottom, tb.Right - Theme.S(10), tb.Bottom);
            Theme.ShadowText(g, "애드온 도우미", Theme.TitleFont, Theme.Gold, tb,
                new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center });
            using (var b = new SolidBrush(Theme.TextDim))
                g.DrawString("v" + Core.AppVersion, Theme.SmallFont, b, tb.Left + Theme.S(12), tb.Top + (tb.Height - Theme.SmallFont.Height) / 2f);

            if (Tag is Rectangle listArea) Theme.InsetPanel(g, listArea);

            Theme.GoldFrame(g, r, Theme.S(8));
            Theme.CornerGems(g, r);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (e.Button == MouseButtons.Left && titleBar.Contains(e.Location))
            {
                NativeMethods.ReleaseCapture();
                NativeMethods.SendMessage(Handle, 0xA1, (IntPtr)2, IntPtr.Zero); // WM_NCLBUTTONDOWN, HTCAPTION
            }
        }

        protected override CreateParams CreateParams
        {
            get
            {
                var cp = base.CreateParams;
                cp.ClassStyle |= 0x20000; // CS_DROPSHADOW: 테두리 없는 창에도 그림자
                cp.Style |= 0x20000;      // WS_MINIMIZEBOX: 작업 표시줄 클릭으로 최소화
                return cp;
            }
        }
    }

    /// <summary>와우식 빨간 원형 닫기 버튼</summary>
    public class PaintedClose : PaintedControl
    {
        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Theme.Smooth(g);
            var r = new Rectangle(1, 1, Width - 3, Height - 3);
            using (var b = new LinearGradientBrush(r, Hover ? Theme.BtnHoverTop : Theme.BtnTop, Theme.BtnBottom, LinearGradientMode.Vertical))
                g.FillEllipse(b, r);
            using (var p = new Pen(Theme.GoldMid, Theme.S(2))) g.DrawEllipse(p, r);
            int i = Width / 3;
            using (var p = new Pen(Theme.Gold, Theme.S(2)) { StartCap = LineCap.Round, EndCap = LineCap.Round })
            {
                g.DrawLine(p, i, i, Width - i - 1, Height - i - 1);
                g.DrawLine(p, Width - i - 1, i, i, Height - i - 1);
            }
        }
    }

    static class NativeMethods
    {
        [System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool ReleaseCapture();
        [System.Runtime.InteropServices.DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);
    }
}
