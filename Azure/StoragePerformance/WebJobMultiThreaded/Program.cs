using System;
using System.Collections.Generic;
using System.Configuration;
using System.Diagnostics;
using System.Threading;

namespace WebJobMultiThreaded
{
    class Program
    {
        private static int _NoMessageFoundSleepTimeoutMsec;
        static void Main(string[] args)
        {
            var threadCount = Convert.ToInt32(ConfigurationManager.AppSettings["ThreadCount"] ?? "5");
            _NoMessageFoundSleepTimeoutMsec = Convert.ToInt32(ConfigurationManager.AppSettings["NoMessageFoundSleepTimeoutMsec"] ?? "500");

            RunAndBlock(threadCount);
        }

        #region Semaphores
        private static SemaphoreSlim _Semaphore;

        #endregion

        #region Run Threads
        private static volatile bool _Cancel = false;
        private static volatile int _MessageCount = 0;

        private static void RunAndBlock(int threadCount)
        {
            ProfilerStart();
            _Semaphore = new SemaphoreSlim(threadCount, threadCount);

            var queue = new QueueClient();


            while (!_Cancel)
            {
                _Semaphore.Wait();
                var solicutud = queue.GetNextMessage();
                if (solicutud == null)
                {
                    Thread.Sleep(millisecondsTimeout: _NoMessageFoundSleepTimeoutMsec);
                }
                else
                {
                    var t = new Thread(new ParameterizedThreadStart(RunThreaded));
                    t.Start(solicutud);
                }
            }
            //Pause();

            // release threads
            ProfilerStop();

        }

        private static void RunThreaded(object messageObject)
        {
            try
            {
                Message solicutud = (Message)messageObject;
                var processor = new Processor();

                processor.ProcessMessage(solicutud);
                _MessageCount++;
            }
            finally
            {
                _Semaphore.Release();
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
