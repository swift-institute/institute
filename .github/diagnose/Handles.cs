using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class HandleDump
{
    [StructLayout(LayoutKind.Sequential)]
    struct Entry
    {
        public IntPtr Object;
        public IntPtr UniqueProcessId;
        public IntPtr HandleValue;
        public uint GrantedAccess;
        public ushort CreatorBackTraceIndex;
        public ushort ObjectTypeIndex;
        public uint HandleAttributes;
        public uint Reserved;
    }

    [DllImport("ntdll.dll")]
    static extern int NtQuerySystemInformation(int infoClass, IntPtr buffer, int length, out int returned);

    public static List<string> Dump(int[] pids, int fileTypeIndex)
    {
        var wanted = new HashSet<long>();
        foreach (var p in pids) wanted.Add(p);
        int length = 1 << 24;
        IntPtr buffer = IntPtr.Zero;
        int returned;
        while (true)
        {
            buffer = Marshal.AllocHGlobal(length);
            int status = NtQuerySystemInformation(64, buffer, length, out returned);
            if (status == unchecked((int)0xC0000004)) { Marshal.FreeHGlobal(buffer); length *= 2; continue; }
            if (status != 0) throw new Exception("NtQuerySystemInformation 0x" + status.ToString("X"));
            break;
        }
        long count = Marshal.ReadIntPtr(buffer).ToInt64();
        int size = Marshal.SizeOf(typeof(Entry));
        IntPtr first = buffer + IntPtr.Size * 2;
        var lines = new List<string>();
        for (long i = 0; i < count; i++)
        {
            var e = (Entry)Marshal.PtrToStructure(first + (int)(i * size), typeof(Entry));
            long pid = e.UniqueProcessId.ToInt64();
            if (!wanted.Contains(pid)) continue;
            if (fileTypeIndex >= 0 && e.ObjectTypeIndex != fileTypeIndex) continue;
            lines.Add(string.Format("{0}\t0x{1:X}\t0x{2:X}\ttype={3}\taccess=0x{4:X}\tattr=0x{5:X}",
                pid, e.HandleValue.ToInt64(), e.Object.ToInt64(), e.ObjectTypeIndex, e.GrantedAccess, e.HandleAttributes));
        }
        Marshal.FreeHGlobal(buffer);
        return lines;
    }

    public static int TypeIndexOf(int pid, long handleValue)
    {
        foreach (var line in Dump(new[] { pid }, -1))
        {
            var parts = line.Split('\t');
            if (Convert.ToInt64(parts[1].Substring(2), 16) == handleValue)
                return int.Parse(parts[3].Substring(5));
        }
        return -1;
    }
}
