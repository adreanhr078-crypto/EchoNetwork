using System;
using System.IO;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace ElevenEleven.Opening
{
    internal static class CheckpointFile
    {
        internal static readonly object WriteLock = new object();
        private static readonly JsonLoadSettings StrictJson = new JsonLoadSettings
        {
            DuplicatePropertyNameHandling = DuplicatePropertyNameHandling.Error,
        };

        internal static JObject Read(string path, Func<JObject, bool> validate)
        {
            lock (WriteLock)
            {
                try
                {
                    if (!File.Exists(path)) return null;
                    using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
                    using var reader = new StreamReader(stream, Encoding.UTF8, true);
                    var json = JObject.Parse(reader.ReadToEnd(), StrictJson);
                    return validate(json) ? json : null;
                }
                catch (IOException) { return null; }
                catch (UnauthorizedAccessException) { return null; }
                catch (JsonException) { return null; }
                catch (FormatException) { return null; }
                catch (OverflowException) { return null; }
            }
        }

        internal static bool Save(string path, JObject json, Func<JObject, bool> validate)
        {
            if (!validate(json)) return false;
            lock (WriteLock)
            {
                var temp = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
                try
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(path));
                    using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                    {
                        using (var writer = new StreamWriter(stream, new UTF8Encoding(false), 4096, true))
                            writer.Write(json.ToString(Formatting.None));
                        stream.Flush(true);
                    }
                    if (File.Exists(path))
                        File.Replace(temp, path, Read(path, validate) == null ? null : path + ".bak");
                    else
                        File.Move(temp, path);
                    return true;
                }
                catch (IOException) { return false; }
                catch (UnauthorizedAccessException) { return false; }
                finally
                {
                    try { File.Delete(temp); }
                    catch (IOException) { }
                    catch (UnauthorizedAccessException) { }
                }
            }
        }

    }
}
