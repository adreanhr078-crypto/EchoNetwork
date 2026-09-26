using System;
using System.Collections.Generic;
using FlaxEngine;
using FlaxEngine.GUI;

namespace EchoNetwork.UI
{
    public struct DialogueLine
    {
        public string SpeakerName;
        public string Text;
        public Texture Portrait;
    }

    /// <summary>
    /// Narrative Dialogue Overlay Controller in Flax Engine.
    /// Manages anime dialogue presentation, typewriter text animation,
    /// character portrait switching, and input progression.
    /// </summary>
    public class DialogueOverlayController : Script
    {
        [Header("UI Control Roots")]
        public UIControl DialogueBoxRoot;
        public UIControl SpeakerNameLabel;
        public UIControl DialogueBodyLabel;
        public UIControl CharacterPortraitImage;

        [Header("Tuning")]
        public float TypewriterSpeed = 0.035f;

        public bool IsDialogueActive { get; private set; }

        private readonly Queue<DialogueLine> _dialogueQueue = new Queue<DialogueLine>();
        private DialogueLine _currentLine;
        private string _fullText = "";
        private float _typewriterTimer = 0f;
        private int _characterIndex = 0;
        private bool _isLineFullyRevealed = false;

        public event Action OnDialogueSequenceFinished;

        public override void OnStart()
        {
            if (DialogueBoxRoot != null)
                DialogueBoxRoot.IsActive = false;
        }

        public override void OnUpdate()
        {
            if (!IsDialogueActive)
                return;

            if (!_isLineFullyRevealed)
            {
                _typewriterTimer += Time.DeltaTime;
                if (_typewriterTimer >= TypewriterSpeed)
                {
                    _typewriterTimer = 0f;
                    _characterIndex++;

                    if (_characterIndex >= _fullText.Length)
                    {
                        _characterIndex = _fullText.Length;
                        _isLineFullyRevealed = true;
                    }
                }
            }

            if (Input.GetAction("Interact") || Input.GetMouseButtonDown(MouseButton.Left))
            {
                if (!_isLineFullyRevealed)
                {
                    // Instant reveal remaining text
                    _characterIndex = _fullText.Length;
                    _isLineFullyRevealed = true;
                }
                else
                {
                    AdvanceToNextLine();
                }
            }
        }

        public void StartDialogueSequence(IEnumerable<DialogueLine> lines)
        {
            _dialogueQueue.Clear();
            foreach (var line in lines)
            {
                _dialogueQueue.Enqueue(line);
            }

            IsDialogueActive = true;
            if (DialogueBoxRoot != null)
                DialogueBoxRoot.IsActive = true;

            AdvanceToNextLine();
        }

        private void AdvanceToNextLine()
        {
            if (_dialogueQueue.Count > 0)
            {
                _currentLine = _dialogueQueue.Dequeue();
                _fullText = _currentLine.Text;
                _characterIndex = 0;
                _isLineFullyRevealed = false;
            }
            else
            {
                EndDialogue();
            }
        }

        private void EndDialogue()
        {
            IsDialogueActive = false;
            if (DialogueBoxRoot != null)
                DialogueBoxRoot.IsActive = false;

            OnDialogueSequenceFinished?.Invoke();
        }
    }
}
