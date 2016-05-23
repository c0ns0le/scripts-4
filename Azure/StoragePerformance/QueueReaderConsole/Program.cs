using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Queue;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

namespace QueueReaderConsole
{
    class Program
    {
        private static volatile bool _Cancel = false;
        private static volatile int _MessageCount;
        private static CloudQueue _Queue;
        private static Stopwatch _Watch;
        private static Random _Random;



        public static void Main(string[] args)
        {
            _Random = new Random(Environment.TickCount);
            QueueInit();
            TimerStart();

            //int maxParallelThreads = Math.Max(Environment.ProcessorCount, 8);
            int maxParallelThreads = 10;
            try { if (args != null && args.Length > 0) { maxParallelThreads = Math.Max(maxParallelThreads, Convert.ToInt32(args[0])); } }
            catch (Exception ex) { Console.WriteLine(ex.Message); }

            Console.WriteLine("Threads: {0}", maxParallelThreads);

            List<Thread> threads = new List<Thread>();
            for (var i = 0; i < maxParallelThreads; i++)
            {
                var t = new Thread(new ThreadStart(QueueGetMessages));
                threads.Add(t);
                t.Start();
            }
            Pause();

            _Cancel = true;
            foreach (var t in threads) { t.Join(); }
            TimerStop();
        }

        #region Timer
        private const int REPORT_REFRESH_RATE_MSEC = 1000;
        private static System.Timers.Timer _Timer;
        private static void TimerStart()
        {
            _Timer = new System.Timers.Timer(interval: REPORT_REFRESH_RATE_MSEC);
            _Timer.AutoReset = true;
            _Timer.Elapsed += Timer_ReportProgress;
            _Timer.Start();
        }


        private static void TimerStop()
        {
            if (_Timer != null)
            {
                _Timer.Stop();
                _Timer.Dispose();
                _Timer = null;
            }
        }


        private static void Timer_ReportProgress(object sender, System.Timers.ElapsedEventArgs e)
        {
            int messagesPerSecond = Convert.ToInt32(_MessageCount / _Watch.Elapsed.TotalSeconds);
            Console.WriteLine("Average Message/Sec: {0} [{1}]", messagesPerSecond, _MessageCount);
        }
        #endregion

        #region Queue
        private static void QueueInit()
        {
            const string queueName = "performance-demo";
            CloudStorageAccount storageAccount = CloudStorageAccount.Parse(ConfigurationManager.AppSettings["AzureStorageConnectionString"]);

            var cloudQueueClient = storageAccount.CreateCloudQueueClient();
            _Queue = cloudQueueClient.GetQueueReference(queueName);
            _Queue.CreateIfNotExists();

            _Watch = Stopwatch.StartNew();
        }

        public static void QueueGetMessages()
        {
            try
            {
                while (!_Cancel)
                {
                    var message = _Queue.GetMessage();
                    if (message == null) {
                        Thread.Sleep(millisecondsTimeout: 1000);
                    }
                    else
                    {
                        var processingTime = _Random.Next(4000, 10000);
                        Thread.Sleep(millisecondsTimeout: processingTime);
                        try
                        {
                            _Queue.DeleteMessage(message);
                        }
                        // message already deleted
                        catch (StorageException ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                        _MessageCount++;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.ToString());
            }
        }
        #endregion

        private static void Pause()
        {
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey(intercept: true);
        }
    }
}
