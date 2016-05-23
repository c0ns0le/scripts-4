using System;
using System.Collections.Generic;
using System.Configuration;
using System.Diagnostics;
using System.Threading;

namespace WebJobMultiThreaded
{
    class Program_v1
    {
        private static int _NoMessageFoundSleepTimeoutMsec;
        static void Main2(string[] args)
        {
            var threadCount = Convert.ToInt32(ConfigurationManager.AppSettings["ThreadCount"] ?? "5");
            _NoMessageFoundSleepTimeoutMsec = Convert.ToInt32(ConfigurationManager.AppSettings["NoMessageFoundSleepTimeoutMsec"] ?? "500");

            RunAndBlock(threadCount);
        }

        #region Run Threads
        private static volatile bool _Cancel = false;
        private static volatile int _MessageCount = 0;

        private static void RunAndBlock(int threadCount)
        {
            ProfilerStart();

            List<Thread> threads = new List<Thread>();
            for (var i = 0; i < threadCount; i++)
            {
                var t = new Thread(new ThreadStart(RunThreaded));
                threads.Add(t);
                t.Name = (i + 1).ToString();
                t.Start();
            }
            //Pause();

            // release threads
            foreach (var t in threads) { try { t.Join(); } catch { } }
            ProfilerStop();

        }

        private static void RunThreaded()
        {
            var queue = new QueueClient();
            var processor = new Processor();
            while (!_Cancel)
            {
                var message = queue.GetNextMessage();
                if (message == null)
                {
                    Thread.Sleep(millisecondsTimeout: _NoMessageFoundSleepTimeoutMsec);
                }
                else
                {
                    processor.ProcessMessage(message);
                    queue.DeleteMessage(message);
                    _MessageCount++;
                }
            }
        }

        private static void Pause()
        {
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey(intercept: true);
            _Cancel = true;
        }
        #endregion Run Threads


        #region Profiler
        private const int REPORT_REFRESH_RATE_MSEC = 1000;
        private static Stopwatch _Watch;
        private static System.Timers.Timer _Profiler;

        private static void ProfilerStart()
        {
            _Watch = Stopwatch.StartNew();
            _Profiler = new System.Timers.Timer(interval: REPORT_REFRESH_RATE_MSEC);
            _Profiler.AutoReset = true;
            _Profiler.Elapsed += Profiler_ReportProgress;
            _Profiler.Start();
        }


        private static void ProfilerStop()
        {
            if (_Profiler != null)
            {
                _Profiler.Stop();
                _Profiler.Dispose();
                _Profiler = null;

                _Watch.Stop();
                _Watch = null;
            }
        }


        private static void Profiler_ReportProgress(object sender, System.Timers.ElapsedEventArgs e)
        {
            int messagesPerSecond = Convert.ToInt32(_MessageCount / _Watch.Elapsed.TotalSeconds);
            Console.WriteLine("Average Message/Sec: {0} [{1}]", messagesPerSecond, _MessageCount);
        }
        #endregion
    }
}
