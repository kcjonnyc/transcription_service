import { useState } from 'react';
import { MerchantBuyerResponse } from '../../types';
import SpeakerLabelEditor from './SpeakerLabelEditor';
import ConversationTranscript from './ConversationTranscript';

interface MerchantBuyerResultProps {
  result: MerchantBuyerResponse;
}

function MerchantBuyerResult({ result }: MerchantBuyerResultProps) {
  const [speakerLabels, setSpeakerLabels] = useState<Record<string, string>>(
    () => ({ ...result.speaker_labels })
  );

  function handleLabelChange(speakerId: string, label: string) {
    setSpeakerLabels((prev) => ({
      ...prev,
      [speakerId]: label,
    }));
  }

  return (
    <div className="merchant-buyer-result">
      <SpeakerLabelEditor
        speakers={result.speakers}
        speakerLabels={speakerLabels}
        onLabelChange={handleLabelChange}
      />

      <ConversationTranscript
        segments={result.segments}
        speakerLabels={speakerLabels}
      />

      {result.translation && (
        <div className="translation-section">
          <h3 className="section-title">Translation (English)</h3>
          <div className="translation-content">
            <p>{result.translation}</p>
          </div>
        </div>
      )}
    </div>
  );
}

export default MerchantBuyerResult;
