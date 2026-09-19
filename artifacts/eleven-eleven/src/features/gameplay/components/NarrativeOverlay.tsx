import { GameButton } from '../../../ui/design-system';

export interface NarrativeOverlayContent {
  eyebrow: string;
  title: string;
  body: string;
  memoryFragment?: string;
  imagePreviewUrl?: string;
}

interface NarrativeOverlayProps {
  content: NarrativeOverlayContent | null;
  onClose: () => void;
}

export function NarrativeOverlay({
  content,
  onClose,
}: NarrativeOverlayProps) {
  if (!content) return null;

  return (
    <div
      className="gameplay-narrative-backdrop"
      role="presentation"
    >
      <section
        className="gameplay-narrative"
        role="dialog"
        aria-modal="true"
        aria-labelledby="gameplay-narrative-title"
      >
        <small>{content.eyebrow}</small>
        <h2 id="gameplay-narrative-title">{content.title}</h2>
        {content.imagePreviewUrl && (
          <div className="gameplay-narrative__image-frame">
            <img
              src={content.imagePreviewUrl}
              alt={content.title}
              className="gameplay-narrative__image"
              loading="lazy"
            />
          </div>
        )}
        <p>{content.body}</p>
        {content.memoryFragment && (
          <blockquote>
            <span>MEMORY FRAGMENT // RECOVERED</span>
            {content.memoryFragment}
          </blockquote>
        )}
        <GameButton onClick={onClose} autoFocus>
          متابعة
        </GameButton>
      </section>
    </div>
  );
}
