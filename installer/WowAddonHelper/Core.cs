using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Text;
using System.Web.Script.Serialization;
using Microsoft.Win32;

namespace WowAddonHelper
{
    /// <summary>릴리스에 들어 있는 애드온 하나 (wowaddons-manifest.json 의 addons 항목)</summary>
    public class AddonInfo
    {
        public string Name;
        public string Title;
        public string Notes;
        public bool Dev;   // 진단용 애드온(X-Dev): 기본으로 체크하지 않는다
    }

    /// <summary>GitHub 최신 릴리스</summary>
    public class ReleaseInfo
    {
        public string Version;
        public List<AddonInfo> Addons = new List<AddonInfo>();
        public string ZipUrl;
        public string InstallerUrl;
    }

    /// <summary>게임 AddOns 폴더에 설치된 상태 (같은 이름의 manifest 파일)</summary>
    public class InstalledState
    {
        public string Version;
        public List<string> Addons = new List<string>();
    }

    public static class Core
    {
        public const string Repo = "kent-k/wowaddons";
        public const string ManifestName = "wowaddons-manifest.json";
        public const string ExeName = "WowAddonHelper.exe";
        const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        const string RunValue = "wowaddons";

        public static readonly string HomeDir =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "wowaddons");
        public static string InstalledExe => Path.Combine(HomeDir, ExeName);
        static string ConfigPath => Path.Combine(HomeDir, "config.json");
        static string LogPath => Path.Combine(HomeDir, "update.log");

        static readonly JavaScriptSerializer Json = new JavaScriptSerializer();

        public static string AppVersion
        {
            get
            {
                var v = Assembly.GetExecutingAssembly().GetName().Version;
                return $"{v.Major}.{v.Minor}.{v.Build}";
            }
        }

        static Core()
        {
            Directory.CreateDirectory(HomeDir);
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        }

        public static void Log(string msg)
        {
            try { File.AppendAllText(LogPath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss}  {msg}\r\n", Encoding.UTF8); }
            catch { /* 로그 실패는 무시 */ }
        }

        // ---------- 설정 / 게임 폴더 ----------

        public static string LoadGameAddOns()
        {
            try
            {
                if (File.Exists(ConfigPath))
                {
                    var cfg = Json.Deserialize<Dictionary<string, object>>(File.ReadAllText(ConfigPath));
                    if (cfg.TryGetValue("gameAddOns", out var p) && p is string s && Directory.Exists(Path.GetDirectoryName(s)))
                        return s;
                }
            }
            catch { }
            return FindGameAddOns();
        }

        public static void SaveGameAddOns(string path)
        {
            File.WriteAllText(ConfigPath, Json.Serialize(new Dictionary<string, object> { ["gameAddOns"] = path }), Encoding.UTF8);
        }

        /// <summary>_forever_ 폴더를 찾는다. 못 찾으면 null.</summary>
        public static string FindGameAddOns()
        {
            var roots = new List<string> { @"C:\Program Files (x86)\World of Warcraft" };
            foreach (var key in new[] { @"SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft",
                                        @"SOFTWARE\Blizzard Entertainment\World of Warcraft" })
            {
                try
                {
                    using (var k = Registry.LocalMachine.OpenSubKey(key))
                    {
                        var p = k?.GetValue("InstallPath") as string;
                        if (!string.IsNullOrEmpty(p)) roots.Add(Path.GetDirectoryName(p.TrimEnd('\\')));
                    }
                }
                catch { }
            }
            foreach (var d in DriveInfo.GetDrives().Where(x => x.DriveType == DriveType.Fixed))
                foreach (var sub in new[] { "World of Warcraft", @"Games\World of Warcraft", @"Program Files (x86)\World of Warcraft", @"Game\World of Warcraft" })
                    roots.Add(Path.Combine(d.RootDirectory.FullName, sub));

            foreach (var r in roots.Distinct(StringComparer.OrdinalIgnoreCase))
            {
                var forever = Path.Combine(r, "_forever_");
                if (Directory.Exists(forever)) return Path.Combine(forever, "Interface", "AddOns");
            }
            return null;
        }

        /// <summary>사용자가 고른 폴더(와우 폴더, _forever_, AddOns 어디든)를 AddOns 경로로 바꾼다.</summary>
        public static string NormalizeGamePath(string picked)
        {
            if (picked == null) return null;
            var p = picked.TrimEnd('\\');
            if (p.EndsWith(@"Interface\AddOns", StringComparison.OrdinalIgnoreCase)) return p;
            if (Directory.Exists(Path.Combine(p, "_forever_"))) return Path.Combine(p, "_forever_", "Interface", "AddOns");
            if (File.Exists(Path.Combine(p, "Wow.exe")) || p.EndsWith("_forever_", StringComparison.OrdinalIgnoreCase))
                return Path.Combine(p, "Interface", "AddOns");
            return null;
        }

        // ---------- GitHub 릴리스 ----------

        static WebClient Web()
        {
            var w = new WebClient { Encoding = Encoding.UTF8 };
            w.Headers[HttpRequestHeader.UserAgent] = "wowaddons-helper";
            return w;
        }

        public static ReleaseInfo FetchLatestRelease()
        {
            using (var w = Web())
            {
                var rel = Json.Deserialize<Dictionary<string, object>>(
                    w.DownloadString($"https://api.github.com/repos/{Repo}/releases/latest"));
                var info = new ReleaseInfo { Version = ((string)rel["tag_name"]).TrimStart('v') };
                string manifestUrl = null;
                foreach (Dictionary<string, object> a in (System.Collections.ArrayList)rel["assets"])
                {
                    var name = (string)a["name"];
                    var url = (string)a["browser_download_url"];
                    if (name == ManifestName) manifestUrl = url;
                    else if (name == ExeName) info.InstallerUrl = url;
                    else if (name.StartsWith("wowaddons-") && name.EndsWith(".zip")) info.ZipUrl = url;
                }
                if (info.ZipUrl == null) throw new Exception($"릴리스 v{info.Version} 에 애드온 zip 파일이 없습니다.");
                string manifestJson;
                if (manifestUrl != null) manifestJson = w.DownloadString(manifestUrl);
                else
                {
                    // 예전 릴리스: 목록 파일이 따로 없으면 zip 안의 것을 읽는다
                    using (var ms = new MemoryStream(w.DownloadData(info.ZipUrl)))
                    using (var zip = new ZipArchive(ms, ZipArchiveMode.Read))
                    using (var r = new StreamReader(zip.GetEntry(ManifestName).Open(), Encoding.UTF8))
                        manifestJson = r.ReadToEnd();
                }
                info.Addons = ParseAddons(Json.Deserialize<Dictionary<string, object>>(manifestJson));
                return info;
            }
        }

        /// <summary>addons 항목: 예전 형식(이름 문자열)과 새 형식(객체) 둘 다 읽는다.</summary>
        static List<AddonInfo> ParseAddons(Dictionary<string, object> m)
        {
            var list = new List<AddonInfo>();
            if (!m.TryGetValue("addons", out var raw) || !(raw is System.Collections.ArrayList arr)) return list;
            foreach (var item in arr)
            {
                if (item is string s) list.Add(new AddonInfo { Name = s, Title = s, Notes = "" });
                else if (item is Dictionary<string, object> d)
                    list.Add(new AddonInfo
                    {
                        Name = (string)d["name"],
                        Title = d.TryGetValue("title", out var t) ? t as string : (string)d["name"],
                        Notes = d.TryGetValue("notes", out var n) ? n as string ?? "" : "",
                        Dev = d.TryGetValue("dev", out var dv) && dv is bool b && b,
                    });
            }
            return list;
        }

        // ---------- 설치 상태 ----------

        public static InstalledState ReadInstalled(string addonsDir)
        {
            var path = Path.Combine(addonsDir, ManifestName);
            if (!File.Exists(path)) return null;
            try
            {
                var m = Json.Deserialize<Dictionary<string, object>>(File.ReadAllText(path));
                return new InstalledState
                {
                    Version = m.TryGetValue("version", out var v) ? v as string : null,
                    Addons = ParseAddons(m).Select(a => a.Name).ToList(),
                };
            }
            catch { return null; }
        }

        static void WriteInstalled(string addonsDir, string version, IEnumerable<string> names)
        {
            var m = new Dictionary<string, object>
            {
                ["version"] = version,
                ["addons"] = names.ToArray(),
                ["installedBy"] = "helper " + AppVersion,
                ["installed"] = DateTime.Now.ToString("s"),
            };
            File.WriteAllText(Path.Combine(addonsDir, ManifestName), Json.Serialize(m), new UTF8Encoding(false));
        }

        static void RemoveDir(string path)
        {
            if (!Directory.Exists(path)) return;
            var info = new DirectoryInfo(path);
            if ((info.Attributes & FileAttributes.ReparsePoint) != 0) info.Delete();   // 정션은 링크만 삭제
            else info.Delete(true);
        }

        /// <summary>
        /// 설치 상태를 wanted 목록과 똑같이 맞춘다: 체크된 것은 릴리스 버전으로 (재)설치, 빠진 것은 제거.
        /// </summary>
        public static string Apply(string addonsDir, ReleaseInfo rel, ICollection<string> wanted, Action<string> progress)
        {
            Directory.CreateDirectory(addonsDir);
            var before = ReadInstalled(addonsDir);
            var previously = before?.Addons ?? new List<string>();
            var tmp = Path.Combine(Path.GetTempPath(), "wowaddons-" + Guid.NewGuid().ToString("N"));
            try
            {
                if (wanted.Count > 0)
                {
                    progress("내려받는 중...");
                    Directory.CreateDirectory(tmp);
                    var zip = Path.Combine(tmp, "addons.zip");
                    using (var w = Web()) w.DownloadFile(rel.ZipUrl, zip);
                    progress("압축 푸는 중...");
                    ZipFile.ExtractToDirectory(zip, Path.Combine(tmp, "x"));
                }

                foreach (var name in previously.Union(wanted, StringComparer.OrdinalIgnoreCase))
                    RemoveDir(Path.Combine(addonsDir, name));

                foreach (var name in wanted)
                {
                    progress($"{name} 설치 중...");
                    CopyDir(Path.Combine(tmp, "x", name), Path.Combine(addonsDir, name));
                }
                WriteInstalled(addonsDir, rel.Version, wanted);

                var removed = previously.Except(wanted, StringComparer.OrdinalIgnoreCase).ToList();
                var msg = $"v{rel.Version} 적용 완료. 설치: {(wanted.Count > 0 ? string.Join(", ", wanted) : "없음")}" +
                          (removed.Count > 0 ? $" / 제거: {string.Join(", ", removed)}" : "");
                Log(msg);
                return msg;
            }
            finally
            {
                try { if (Directory.Exists(tmp)) Directory.Delete(tmp, true); } catch { }
            }
        }

        static void CopyDir(string src, string dst)
        {
            if (!Directory.Exists(src)) throw new Exception($"릴리스 zip 안에 {Path.GetFileName(src)} 폴더가 없습니다.");
            Directory.CreateDirectory(dst);
            foreach (var f in Directory.GetFiles(src)) File.Copy(f, Path.Combine(dst, Path.GetFileName(f)), true);
            foreach (var d in Directory.GetDirectories(src)) CopyDir(d, Path.Combine(dst, Path.GetFileName(d)));
        }

        public static bool IsGameRunning() => Process.GetProcessesByName("Wow").Length > 0;

        // ---------- 자동 실행 (HKCU Run, 관리자 권한 불필요) ----------

        public static bool AutoStartEnabled
        {
            get
            {
                using (var k = Registry.CurrentUser.OpenSubKey(RunKey))
                    return k?.GetValue(RunValue) != null;
            }
            set
            {
                using (var k = Registry.CurrentUser.CreateSubKey(RunKey))
                {
                    if (value) k.SetValue(RunValue, $"\"{InstalledExe}\" --auto");
                    else k.DeleteValue(RunValue, false);
                }
            }
        }

        // ---------- 설치기 자신 ----------

        /// <summary>
        /// 처음 실행하면 %LOCALAPPDATA%\wowaddons 에 자신을 복사하고 시작 메뉴 바로가기를 만든다.
        /// (다운로드 폴더에서 실행해도 이후엔 시작 메뉴에서 찾을 수 있게)
        /// </summary>
        public static void EnsureInstalledCopy()
        {
            var self = Assembly.GetExecutingAssembly().Location;
            if (!string.Equals(self, InstalledExe, StringComparison.OrdinalIgnoreCase))
            {
                var needCopy = !File.Exists(InstalledExe) ||
                               new Version(FileVersionInfo.GetVersionInfo(InstalledExe).FileVersion ?? "0.0.0") <
                               Assembly.GetExecutingAssembly().GetName().Version;
                if (needCopy)
                {
                    try { File.Copy(self, InstalledExe, true); } catch (IOException) { /* 실행 중이면 다음 기회에 */ }
                }
            }
            try
            {
                var menu = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "애드온 도우미.lnk");
                if (!File.Exists(menu)) CreateShortcut(menu, InstalledExe);
            }
            catch { }
        }

        static void CreateShortcut(string lnkPath, string target)
        {
            var shellType = Type.GetTypeFromProgID("WScript.Shell");
            dynamic shell = Activator.CreateInstance(shellType);
            dynamic lnk = shell.CreateShortcut(lnkPath);
            lnk.TargetPath = target;
            lnk.WorkingDirectory = Path.GetDirectoryName(target);
            lnk.Description = "와우 포에버 애드온 설치/업데이트";
            lnk.Save();
        }

        public static void CleanupOldSelf()
        {
            try { File.Delete(InstalledExe + ".old"); } catch { }
        }

        public static bool IsNewer(string release, string current)
        {
            return Version.TryParse(release, out var r) && Version.TryParse(current, out var c) && r > c;
        }

        /// <summary>새 설치기를 받아 %LOCALAPPDATA% 사본을 교체한다. 교체했으면 true.</summary>
        public static bool UpdateSelf(ReleaseInfo rel)
        {
            if (rel.InstallerUrl == null || AppVersion == "0.0.0" || !IsNewer(rel.Version, AppVersion)) return false;
            var tmp = InstalledExe + ".new";
            using (var w = Web()) w.DownloadFile(rel.InstallerUrl, tmp);
            if (File.Exists(InstalledExe))
            {
                try { File.Delete(InstalledExe + ".old"); } catch { }
                File.Move(InstalledExe, InstalledExe + ".old");   // 실행 중인 exe 도 이름 변경은 된다
            }
            File.Move(tmp, InstalledExe);
            Log($"도우미 업데이트: {AppVersion} -> {rel.Version}");
            return true;
        }
    }
}
