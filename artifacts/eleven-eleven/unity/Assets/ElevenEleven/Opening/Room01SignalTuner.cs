using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class Room01SignalTuner : MonoBehaviour
    {
        [SerializeField] private Slider frequencyHalfSteps;
        [SerializeField] private Slider phase;
        [SerializeField] private Slider channel;
        [SerializeField] private Text frequencyValue;
        [SerializeField] private Text phaseValue;
        [SerializeField] private Text channelValue;
        [SerializeField] private Text status;
        [SerializeField] private Button back;
        [SerializeField] private Button proceed;

        public bool IsOpen => gameObject.activeSelf;
        public event Action<bool> Closed;

        private bool aligned;

        private void Awake()
        {
            frequencyHalfSteps.onValueChanged.AddListener(Refresh);
            phase.onValueChanged.AddListener(Refresh);
            channel.onValueChanged.AddListener(Refresh);
        }

        public void Open()
        {
            if (IsOpen) return;
            gameObject.SetActive(true);
            Refresh(0);
            if (EventSystem.current != null)
                EventSystem.current.SetSelectedGameObject(aligned ? proceed.gameObject : frequencyHalfSteps.gameObject);
        }

        public void Close()
        {
            if (!IsOpen) return;
            gameObject.SetActive(false);
            Closed?.Invoke(aligned);
        }

        internal void Restore(Room01Checkpoint state)
        {
            aligned = state.Terminal;
            frequencyHalfSteps.SetValueWithoutNotify((float)state.Frequency * 2f);
            phase.SetValueWithoutNotify((float)state.Phase);
            channel.SetValueWithoutNotify((float)state.Channel);
        }

        internal void Capture(Room01Checkpoint state)
        {
            state.Frequency = frequencyHalfSteps.value * 0.5f;
            state.Phase = phase.value;
            state.Channel = channel.value;
        }

        private void Refresh(float _)
        {
            var frequency = frequencyHalfSteps.value * 0.5f;
            frequencyValue.text = FormattableString.Invariant($"{frequency:F1} MHz");
            phaseValue.text = FormattableString.Invariant($"{phase.value:F0}°");
            channelValue.text = FormattableString.Invariant($"CH-{channel.value:F0}");

            if (IsOpen && Mathf.Abs(frequency - 111f) <= 2f && Mathf.Abs(phase.value - 45f) <= 5f && channel.value == 7f)
                aligned = true;

            status.text = aligned ? "Signal aligned" : "Match the trace: 111 MHz · 45° · Channel 7";
            frequencyHalfSteps.interactable = !aligned;
            phase.interactable = !aligned;
            channel.interactable = !aligned;
            back.gameObject.SetActive(!aligned);
            proceed.gameObject.SetActive(aligned);
            var events = EventSystem.current;
            if (aligned && events != null && events.currentSelectedGameObject != proceed.gameObject)
                events.SetSelectedGameObject(proceed.gameObject);
        }
    }
}
