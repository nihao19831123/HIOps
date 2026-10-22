using System;

namespace HIOps.EndpointSensor.Models
{
    public enum ActionType
    {
        UI_CLICK,
        SCANNER_INPUT,
        WINDOW_SWITCH,
        KEY_ACTION,
        NET_PROBE,
        SYS_EVENT
    }

    public class ActionEntry
    {
        public DateTime Timestamp { get; set; }
        public ActionType Type { get; set; }
        public string Target { get; set; }
        public string Detail { get; set; }

        public ActionEntry()
        {
            Timestamp = DateTime.UtcNow;
        }

        public override string ToString()
        {
            return string.Format("[{0:HH:mm:ss.fff}] {1}: {2} ({3})", Timestamp, Type, Target, Detail);
        }
    }
}
