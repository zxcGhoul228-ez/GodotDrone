using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;

namespace DroneScriptOneFile;

internal static class Program
{
    private const string PayloadResourceName = "DroneScriptOneFile.Payload.payload.zip";

    [STAThread]
    private static int Main(string[] args)
    {
        ApplicationConfiguration.Initialize();

        try
        {
            var extractRoot = Path.Combine(
                Path.GetTempPath(),
                PayloadManifest.ExtractFolderName,
                PayloadManifest.PayloadHash
            );

            using var mutex = new Mutex(
                false,
                @"Local\DroneScriptOneFile_" + PayloadManifest.PayloadHash
            );

            mutex.WaitOne();
            try
            {
                EnsurePayloadExtracted(extractRoot);
                CleanupOlderPayloads(extractRoot);
            }
            finally
            {
                mutex.ReleaseMutex();
            }

            var entryPath = Path.Combine(extractRoot, PayloadManifest.EntryExeName);
            if (!File.Exists(entryPath))
            {
                throw new FileNotFoundException("Main game executable was not found after extraction.", entryPath);
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = entryPath,
                WorkingDirectory = extractRoot,
                UseShellExecute = false
            };

            foreach (var arg in args)
            {
                startInfo.ArgumentList.Add(arg);
            }

            var process = Process.Start(startInfo);
            if (process == null)
            {
                throw new InvalidOperationException("Failed to start the extracted game executable.");
            }

            return 0;
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                "Could not start the game.\n\n" + exception,
                PayloadManifest.ProductName,
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
            return 1;
        }
    }

    private static void EnsurePayloadExtracted(string extractRoot)
    {
        var markerPath = Path.Combine(extractRoot, ".payload_ready");
        if (File.Exists(markerPath))
        {
            var currentMarker = File.ReadAllText(markerPath, Encoding.UTF8).Trim();
            if (string.Equals(currentMarker, PayloadManifest.PayloadHash, StringComparison.OrdinalIgnoreCase))
            {
                return;
            }
        }

        if (Directory.Exists(extractRoot))
        {
            TryDeleteDirectory(extractRoot);
        }

        Directory.CreateDirectory(extractRoot);

        using var resourceStream = Assembly.GetExecutingAssembly().GetManifestResourceStream(PayloadResourceName);
        if (resourceStream == null)
        {
            throw new FileNotFoundException("Embedded payload archive was not found.", PayloadResourceName);
        }

        using var archive = new ZipArchive(resourceStream, ZipArchiveMode.Read, leaveOpen: false);
        foreach (var entry in archive.Entries)
        {
            var destinationPath = Path.GetFullPath(Path.Combine(extractRoot, entry.FullName));
            if (!destinationPath.StartsWith(Path.GetFullPath(extractRoot), StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Payload contains an invalid path.");
            }

            if (string.IsNullOrEmpty(entry.Name))
            {
                Directory.CreateDirectory(destinationPath);
                continue;
            }

            var destinationDirectory = Path.GetDirectoryName(destinationPath);
            if (!string.IsNullOrEmpty(destinationDirectory))
            {
                Directory.CreateDirectory(destinationDirectory);
            }

            entry.ExtractToFile(destinationPath, overwrite: true);
        }

        File.WriteAllText(markerPath, PayloadManifest.PayloadHash, Encoding.UTF8);
    }

    private static void CleanupOlderPayloads(string currentExtractRoot)
    {
        try
        {
            var baseDirectory = Directory.GetParent(currentExtractRoot)?.FullName;
            if (string.IsNullOrEmpty(baseDirectory) || !Directory.Exists(baseDirectory))
            {
                return;
            }

            foreach (var directory in Directory.GetDirectories(baseDirectory))
            {
                if (string.Equals(directory, currentExtractRoot, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                TryDeleteDirectory(directory);
            }
        }
        catch
        {
            // Best effort only.
        }
    }

    private static void TryDeleteDirectory(string path)
    {
        try
        {
            Directory.Delete(path, recursive: true);
        }
        catch
        {
            // If an older version is currently running, leave it alone.
        }
    }
}
