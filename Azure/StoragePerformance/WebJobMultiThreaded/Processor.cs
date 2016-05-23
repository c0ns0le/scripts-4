using System;
using System.Threading;

namespace WebJobMultiThreaded
{
    public class Processor
    {
        private static Random _Random;

        public Processor()
        {
            _Random = new Random(Environment.TickCount);
        }

        public void ProcessMessage(Message message)
        {
            var processingTime = _Random.Next(1000, 5000);
            Thread.Sleep(millisecondsTimeout: processingTime);
        }
    }
}
