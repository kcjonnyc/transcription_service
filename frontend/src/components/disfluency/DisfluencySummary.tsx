import { DisfluencyAnalysis } from '../../types';

interface DisfluencySummaryProps {
  summary: DisfluencyAnalysis['summary'];
}

const CATEGORY_DISPLAY_NAMES: Record<string, string> = {
  filler_words: 'Filler Words',
  word_repetitions: 'Word Repetitions',
  sound_repetitions: 'Sound Repetitions (Stuttering)',
  prolongations: 'Prolongations',
  revisions: 'Revisions',
  partial_words: 'Partial Words',
  pauses: 'Pauses',
};

function DisfluencySummary({ summary }: DisfluencySummaryProps) {
  const categoryEntries = Object.entries(summary.by_category);
  const fillerEntries = Object.entries(summary.most_common_fillers)
    .sort(([, a], [, b]) => b - a);

  return (
    <div className="disfluency-summary">
      <h3 className="section-title">Analysis Summary</h3>

      <div className="summary-stats-grid">
        <div className="stat-card stat-card-primary">
          <div className="stat-value">{summary.total_disfluencies}</div>
          <div className="stat-label">Total Disfluencies</div>
        </div>
        <div className="stat-card stat-card-secondary">
          <div className="stat-value">{summary.disfluency_rate.toFixed(1)}</div>
          <div className="stat-label">Per 100 Words</div>
        </div>
      </div>

      {categoryEntries.length > 0 && (
        <div className="category-breakdown">
          <h4 className="subsection-title">Category Breakdown</h4>
          <table className="category-table">
            <thead>
              <tr>
                <th>Category</th>
                <th>Count</th>
                <th>Examples</th>
              </tr>
            </thead>
            <tbody>
              {categoryEntries.map(([category, stats]) => (
                <tr key={category}>
                  <td className="category-name">
                    {CATEGORY_DISPLAY_NAMES[category] || category}
                  </td>
                  <td className="category-count">{stats.count}</td>
                  <td className="category-examples">
                    {stats.examples.slice(0, 3).map((ex, i) => (
                      <span key={i} className="example-chip">{ex}</span>
                    ))}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {fillerEntries.length > 0 && (
        <div className="common-fillers">
          <h4 className="subsection-title">Most Common Fillers</h4>
          <div className="filler-chips">
            {fillerEntries.map(([filler, count]) => (
              <span key={filler} className="filler-chip">
                &ldquo;{filler}&rdquo;
                <span className="filler-count">{count}</span>
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

export default DisfluencySummary;
