using System.Threading;

namespace WebJobMultiThreaded
{
    public class QueueClient
    {
        private static volatile int _Counter;
        public Message GetNextMessage()
        {
            return new Message { ID = ++_Counter };
        }

        public bool DeleteMessage(Message message)
        {
            Thread.Sleep(millisecondsTimeout: 35);
            return true;
        }
    }
}
