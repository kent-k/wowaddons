using System;
using System.Drawing;
using System.Linq;
using System.Threading;
using System.Windows.Forms;

namespace WowAddonHelper
{
    static class Program
    {
        [STAThread]
        static int Main(string[] args)
        {
            using (var mutex = new Mutex(true, @"Local\wowaddons-helper", out bool first))
            {
                if (!first) return 0;   // 이미 실행 중
                Core.CleanupOldSelf();
                if (args.Contains("--auto")) return AutoUpdate();

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                using (var g = Graphics.FromHwnd(IntPtr.Zero)) Theme.Init(g.DpiX);
                var form = new MainForm();
                int snap = Array.IndexOf(args, "--snapshot");
                if (snap >= 0 && snap + 1 < args.Length) form.SnapshotPath = args[snap + 1];
                else
                {
                    try { Core.EnsureInstalledCopy(); } catch (Exception ex) { Core.Log("사본 설치 실패: " + ex.Message); }
                }
                Application.Run(form);
                return 0;
            }
        }

        /// <summary>
        /// Windows 시작 시 창 없이 실행: 깔려 있는 애드온만 최신 릴리스로 맞춘다.
        /// </summary>
        static int AutoUpdate()
        {
            try
            {
                var dir = Core.LoadGameAddOns();
                if (dir == null) { Core.Log("자동 업데이트: 게임 폴더를 찾지 못함"); return 1; }
                var installed = Core.ReadInstalled(dir);
                var rel = Core.FetchLatestRelease();
                Core.UpdateSelf(rel);
                if (installed == null || installed.Addons.Count == 0) { Core.Log("자동 업데이트: 설치된 애드온 없음"); return 0; }
                if (installed.Version == rel.Version) { Core.Log($"자동 업데이트: 이미 최신 v{rel.Version}"); return 0; }
                // 릴리스에서 빠진 애드온은 지우고, 남은 것만 다시 깐다
                var keep = installed.Addons.Where(n => rel.Addons.Count == 0 || rel.Addons.Any(a => a.Name.Equals(n, StringComparison.OrdinalIgnoreCase))).ToList();
                Core.Apply(dir, rel, keep, _ => { });
                return 0;
            }
            catch (Exception ex)
            {
                Core.Log("자동 업데이트 실패: " + ex.Message);
                return 1;
            }
        }
    }
}
