# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe RegexDisfluencyAnalyzer do
  describe '.analyze' do
    # -------------------------------------------------------------------------
    # Category 1: Filler Words
    # -------------------------------------------------------------------------
    context 'filler_words' do
      it 'detects simple fillers like um and uh' do
        result = RegexDisfluencyAnalyzer.analyze('Um, I was, uh, thinking.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        fillers = disfluencies.select { |d| d[:category] == 'filler_words' }

        expect(fillers.length).to eq(2)
        expect(fillers[0][:text].downcase).to eq('um')
        expect(fillers[1][:text].downcase).to eq('uh')
      end

      it 'detects multi-word fillers like "you know" and "I mean"' do
        result = RegexDisfluencyAnalyzer.analyze('You know, I mean, it was fine.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        fillers = disfluencies.select { |d| d[:category] == 'filler_words' }

        texts = fillers.map { |f| f[:text].downcase }
        expect(texts).to include('you know')
        expect(texts).to include('i mean')
      end

      it 'detects basically, actually, literally as fillers' do
        result = RegexDisfluencyAnalyzer.analyze('Basically, I actually literally went there.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        fillers = disfluencies.select { |d| d[:category] == 'filler_words' }

        texts = fillers.map { |f| f[:text].downcase }
        expect(texts).to include('basically')
        expect(texts).to include('actually')
        expect(texts).to include('literally')
      end

      it 'detects "like" as filler only when surrounded by commas or at start of sentence' do
        result = RegexDisfluencyAnalyzer.analyze('Like, I was, like, going to the store.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        fillers = disfluencies.select { |d| d[:category] == 'filler_words' }
        like_fillers = fillers.select { |f| f[:text].downcase == 'like' }

        expect(like_fillers.length).to eq(2)
      end

      it 'does NOT flag "like" when used normally (e.g., "I like cats")' do
        result = RegexDisfluencyAnalyzer.analyze('I like cats.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        fillers = disfluencies.select { |d| d[:category] == 'filler_words' }
        like_fillers = fillers.select { |f| f[:text].downcase == 'like' }

        expect(like_fillers.length).to eq(0)
      end

      it 'detects "right" as filler when used as filler' do
        result = RegexDisfluencyAnalyzer.analyze('So, right, we need to go.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        fillers = disfluencies.select { |d| d[:category] == 'filler_words' }
        right_fillers = fillers.select { |f| f[:text].downcase == 'right' }

        expect(right_fillers.length).to eq(1)
      end

      it 'detects hmm as a filler' do
        result = RegexDisfluencyAnalyzer.analyze('Hmm, I am not sure about that.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        fillers = disfluencies.select { |d| d[:category] == 'filler_words' }

        expect(fillers.length).to be >= 1
        expect(fillers[0][:text].downcase).to eq('hmm')
      end

      it 'reports correct position and length for fillers' do
        result = RegexDisfluencyAnalyzer.analyze('Um, hello.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        filler = disfluencies.find { |d| d[:category] == 'filler_words' }

        expect(filler[:position]).to eq(0)
        expect(filler[:length]).to eq(2)
      end
    end

    # -------------------------------------------------------------------------
    # Category 2: Word Repetitions
    # -------------------------------------------------------------------------
    context 'word_repetitions' do
      it 'detects consecutive repeated words like "I I"' do
        result = RegexDisfluencyAnalyzer.analyze('I I I went to the store.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        reps = disfluencies.select { |d| d[:category] == 'word_repetitions' }

        expect(reps.length).to be >= 1
        expect(reps[0][:text].downcase).to include('i i')
      end

      it 'detects "the the" as a word repetition' do
        result = RegexDisfluencyAnalyzer.analyze('I went to the the store.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        reps = disfluencies.select { |d| d[:category] == 'word_repetitions' }

        expect(reps.length).to eq(1)
        expect(reps[0][:text].downcase).to include('the the')
      end

      it 'reports correct position and length for word repetitions' do
        result = RegexDisfluencyAnalyzer.analyze('Go to the the store.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        rep = disfluencies.find { |d| d[:category] == 'word_repetitions' }

        expect(rep[:position]).to eq(6)
        expect(rep[:length]).to eq(7) # "the the"
      end
    end

    # -------------------------------------------------------------------------
    # Category 3: Sound Repetitions (Stuttering)
    # -------------------------------------------------------------------------
    context 'sound_repetitions' do
      it 'detects stutter patterns like "b- but"' do
        result = RegexDisfluencyAnalyzer.analyze('I was b- but I went anyway.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        stutters = disfluencies.select { |d| d[:category] == 'sound_repetitions' }

        expect(stutters.length).to eq(1)
        expect(stutters[0][:text]).to include('b- but')
      end

      it 'detects "wh- what" as a sound repetition' do
        result = RegexDisfluencyAnalyzer.analyze('I said wh- what do you mean.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        stutters = disfluencies.select { |d| d[:category] == 'sound_repetitions' }

        expect(stutters.length).to eq(1)
        expect(stutters[0][:text]).to include('wh- what')
      end

      it 'detects "s- so" as a sound repetition' do
        result = RegexDisfluencyAnalyzer.analyze('S- so I went home.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        stutters = disfluencies.select { |d| d[:category] == 'sound_repetitions' }

        expect(stutters.length).to eq(1)
        expect(stutters[0][:text].downcase).to include('s- so')
      end

      it 'reports correct position and length for sound repetitions' do
        result = RegexDisfluencyAnalyzer.analyze('I was b- but fine.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        stutter = disfluencies.find { |d| d[:category] == 'sound_repetitions' }

        expect(stutter[:position]).to eq(6)
        expect(stutter[:length]).to eq(6) # "b- but"
      end
    end

    # -------------------------------------------------------------------------
    # Category 4: Prolongations
    # -------------------------------------------------------------------------
    context 'prolongations' do
      it 'detects words with 3+ consecutive repeated characters like "sooo"' do
        result = RegexDisfluencyAnalyzer.analyze('Sooo I went to the store.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        prolongations = disfluencies.select { |d| d[:category] == 'prolongations' }

        expect(prolongations.length).to eq(1)
        expect(prolongations[0][:text].downcase).to eq('sooo')
      end

      it 'detects "wellll" as a prolongation' do
        result = RegexDisfluencyAnalyzer.analyze('Wellll that was interesting.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        prolongations = disfluencies.select { |d| d[:category] == 'prolongations' }

        expect(prolongations.length).to eq(1)
        expect(prolongations[0][:text].downcase).to eq('wellll')
      end

      it 'detects "ummmm" as a prolongation' do
        result = RegexDisfluencyAnalyzer.analyze('Ummmm, I think so.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        prolongations = disfluencies.select { |d| d[:category] == 'prolongations' }

        expect(prolongations.length).to be >= 1
      end

      it 'does NOT flag normal words with double letters like "book" or "see"' do
        result = RegexDisfluencyAnalyzer.analyze('I see the book.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        prolongations = disfluencies.select { |d| d[:category] == 'prolongations' }

        expect(prolongations.length).to eq(0)
      end

      it 'reports correct position and length for prolongations' do
        result = RegexDisfluencyAnalyzer.analyze('I was sooo tired.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        prolongation = disfluencies.find { |d| d[:category] == 'prolongations' }

        expect(prolongation[:position]).to eq(6)
        expect(prolongation[:length]).to eq(4) # "sooo"
      end
    end

    # -------------------------------------------------------------------------
    # Category 5: Revisions
    # -------------------------------------------------------------------------
    context 'revisions' do
      it 'detects self-corrections with double-dash like "I was going-- I went"' do
        result = RegexDisfluencyAnalyzer.analyze('I was going-- I went to the park.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        revisions = disfluencies.select { |d| d[:category] == 'revisions' }

        expect(revisions.length).to eq(1)
        expect(revisions[0][:text]).to include('--')
      end

      it 'detects "the red-- blue car" as a revision' do
        result = RegexDisfluencyAnalyzer.analyze('I saw the red-- blue car.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        revisions = disfluencies.select { |d| d[:category] == 'revisions' }

        expect(revisions.length).to eq(1)
        expect(revisions[0][:text]).to include('red-- blue')
      end

      it 'reports correct position and length for revisions' do
        # "I was going-- I went to the park."
        #  0123456
        result = RegexDisfluencyAnalyzer.analyze('I was going-- I went to the park.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        revision = disfluencies.find { |d| d[:category] == 'revisions' }

        expect(revision[:position]).to be >= 0
        expect(revision[:length]).to be > 0
      end
    end

    # -------------------------------------------------------------------------
    # Category 6: Partial Words
    # -------------------------------------------------------------------------
    context 'partial_words' do
      it 'detects words ending with a single hyphen like "gon-"' do
        result = RegexDisfluencyAnalyzer.analyze('I was gon- going to the store.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        partials = disfluencies.select { |d| d[:category] == 'partial_words' }

        expect(partials.length).to eq(1)
        expect(partials[0][:text]).to eq('gon-')
      end

      it 'detects "thi-" as a partial word' do
        result = RegexDisfluencyAnalyzer.analyze('I was thi- thinking about it.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        partials = disfluencies.select { |d| d[:category] == 'partial_words' }

        expect(partials.length).to eq(1)
        expect(partials[0][:text]).to eq('thi-')
      end

      it 'detects "beca-" as a partial word' do
        result = RegexDisfluencyAnalyzer.analyze('It was beca- because of the rain.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        partials = disfluencies.select { |d| d[:category] == 'partial_words' }

        expect(partials.length).to eq(1)
        expect(partials[0][:text]).to eq('beca-')
      end

      it 'does NOT flag stutter patterns as partial words' do
        result = RegexDisfluencyAnalyzer.analyze('I was b- but fine.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        partials = disfluencies.select { |d| d[:category] == 'partial_words' }

        expect(partials.length).to eq(0)
      end

      it 'reports correct position and length for partial words' do
        result = RegexDisfluencyAnalyzer.analyze('I was gon- going.')
        disfluencies = result[:annotated_sentences][0][:disfluencies]
        partial = disfluencies.find { |d| d[:category] == 'partial_words' }

        expect(partial[:position]).to eq(6)
        expect(partial[:length]).to eq(4) # "gon-"
      end
    end

    # -------------------------------------------------------------------------
    # Struggle Score
    # -------------------------------------------------------------------------
    context 'struggle_score' do
      it 'returns 0 for clean sentences with no disfluencies' do
        result = RegexDisfluencyAnalyzer.analyze('The weather is nice today.')
        score = result[:annotated_sentences][0][:struggle_score]

        expect(score).to eq(0.0)
      end

      it 'returns a positive score for sentences with fillers' do
        result = RegexDisfluencyAnalyzer.analyze('Um, uh, I went there.')
        score = result[:annotated_sentences][0][:struggle_score]

        expect(score).to be > 0
        expect(score).to be <= 100
      end

      it 'weights higher-weight categories more heavily' do
        # sound_repetitions have weight 2 vs filler_words weight 1
        filler_result = RegexDisfluencyAnalyzer.analyze('Um, I went to the store today please.')
        stutter_result = RegexDisfluencyAnalyzer.analyze('B- but I went to the store today please.')

        filler_score = filler_result[:annotated_sentences][0][:struggle_score]
        stutter_score = stutter_result[:annotated_sentences][0][:struggle_score]

        # stutter (weight 2) should produce a higher score than filler (weight 1)
        # with the same number of total words
        expect(stutter_score).to be > filler_score
      end

      it 'caps the score at 100' do
        # A sentence that is almost entirely disfluencies
        result = RegexDisfluencyAnalyzer.analyze('Um, uh, um, uh, um.')
        score = result[:annotated_sentences][0][:struggle_score]

        expect(score).to be <= 100.0
      end

      it 'calculates score as (sum of weighted disfluencies / total words) * 100' do
        # "Um, I went." => 3 words, 1 filler (weight 1)
        # score = (1 / 3) * 100 = 33.33...
        result = RegexDisfluencyAnalyzer.analyze('Um, I went.')
        score = result[:annotated_sentences][0][:struggle_score]

        expect(score).to be_within(1.0).of(33.3)
      end

      it 'returns a Float' do
        result = RegexDisfluencyAnalyzer.analyze('Hello there.')
        score = result[:annotated_sentences][0][:struggle_score]

        expect(score).to be_a(Float)
      end
    end

    # -------------------------------------------------------------------------
    # Summary Statistics
    # -------------------------------------------------------------------------
    context 'summary' do
      it 'includes total_disfluencies count' do
        result = RegexDisfluencyAnalyzer.analyze('Um, I went. Uh, yeah.')
        summary = result[:summary]

        expect(summary[:total_disfluencies]).to be >= 2
      end

      it 'calculates disfluency_rate as disfluencies per 100 words' do
        result = RegexDisfluencyAnalyzer.analyze('Um, I went to the store and uh I bought things.')
        summary = result[:summary]

        expect(summary[:disfluency_rate]).to be_a(Float)
        expect(summary[:disfluency_rate]).to be > 0
      end

      it 'includes by_category with count and examples' do
        result = RegexDisfluencyAnalyzer.analyze('Um, I mean, basically it was, uh, fine.')
        summary = result[:summary]

        expect(summary[:by_category]).to be_a(Hash)
        filler_cat = summary[:by_category]['filler_words']
        expect(filler_cat).to be_a(Hash)
        expect(filler_cat[:count]).to be >= 3
        expect(filler_cat[:examples]).to be_an(Array)
        expect(filler_cat[:examples].length).to be <= 5
      end

      it 'includes most_common_fillers hash' do
        result = RegexDisfluencyAnalyzer.analyze('Um, I went. Um, yeah. Uh, really. Um, ok.')
        summary = result[:summary]

        expect(summary[:most_common_fillers]).to be_a(Hash)
        expect(summary[:most_common_fillers]['um']).to be >= 3
      end

      it 'limits most_common_fillers to top 10' do
        result = RegexDisfluencyAnalyzer.analyze('Um, I went there.')
        summary = result[:summary]

        expect(summary[:most_common_fillers].length).to be <= 10
      end

      it 'limits examples in by_category to 5' do
        result = RegexDisfluencyAnalyzer.analyze(
          'Um, uh, hmm, basically, actually, literally, I mean, you know, right, it was fine.'
        )
        summary = result[:summary]
        filler_cat = summary[:by_category]['filler_words']

        expect(filler_cat[:examples].length).to be <= 5
      end

      it 'returns zero stats for text with no disfluencies' do
        result = RegexDisfluencyAnalyzer.analyze('The weather is nice. I like it.')
        summary = result[:summary]

        expect(summary[:total_disfluencies]).to eq(0)
        expect(summary[:disfluency_rate]).to eq(0.0)
        expect(summary[:most_common_fillers]).to eq({})
      end
    end

    # -------------------------------------------------------------------------
    # Clean Text (no disfluencies)
    # -------------------------------------------------------------------------
    context 'with clean text' do
      it 'returns empty disfluencies arrays' do
        result = RegexDisfluencyAnalyzer.analyze('I went to the store. The weather was nice.')

        result[:annotated_sentences].each do |sentence|
          expect(sentence[:disfluencies]).to eq([])
        end
      end

      it 'returns zero struggle scores' do
        result = RegexDisfluencyAnalyzer.analyze('The sun is shining.')
        expect(result[:annotated_sentences][0][:struggle_score]).to eq(0.0)
      end

      it 'preserves the original sentence text' do
        result = RegexDisfluencyAnalyzer.analyze('Hello world.')
        expect(result[:annotated_sentences][0][:text]).to eq('Hello world.')
      end
    end

    # -------------------------------------------------------------------------
    # Multi-sentence Text
    # -------------------------------------------------------------------------
    context 'with multi-sentence text' do
      it 'splits text into multiple annotated sentences' do
        result = RegexDisfluencyAnalyzer.analyze('I went home. You stayed. They left!')

        expect(result[:annotated_sentences].length).to eq(3)
      end

      it 'analyzes each sentence independently' do
        result = RegexDisfluencyAnalyzer.analyze('Um, I went. The weather was nice.')

        first = result[:annotated_sentences][0]
        second = result[:annotated_sentences][1]

        expect(first[:disfluencies].length).to be >= 1
        expect(second[:disfluencies].length).to eq(0)
      end

      it 'aggregates disfluencies across sentences in summary' do
        result = RegexDisfluencyAnalyzer.analyze('Um, I went. Uh, yeah. Hmm, ok.')
        summary = result[:summary]

        expect(summary[:total_disfluencies]).to be >= 3
      end

      it 'splits on period, exclamation mark, and question mark' do
        result = RegexDisfluencyAnalyzer.analyze('Hello. How are you? Great!')

        expect(result[:annotated_sentences].length).to eq(3)
      end
    end

    # -------------------------------------------------------------------------
    # Return Structure
    # -------------------------------------------------------------------------
    context 'return structure' do
      it 'returns a hash with :annotated_sentences and :summary keys' do
        result = RegexDisfluencyAnalyzer.analyze('Hello there.')

        expect(result).to be_a(Hash)
        expect(result).to have_key(:annotated_sentences)
        expect(result).to have_key(:summary)
      end

      it 'each annotated sentence has :text, :disfluencies, :struggle_score' do
        result = RegexDisfluencyAnalyzer.analyze('Um, hello.')
        sentence = result[:annotated_sentences][0]

        expect(sentence).to have_key(:text)
        expect(sentence).to have_key(:disfluencies)
        expect(sentence).to have_key(:struggle_score)
      end

      it 'each disfluency has :category, :text, :position, :length' do
        result = RegexDisfluencyAnalyzer.analyze('Um, hello.')
        disfluency = result[:annotated_sentences][0][:disfluencies][0]

        expect(disfluency).to have_key(:category)
        expect(disfluency).to have_key(:text)
        expect(disfluency).to have_key(:position)
        expect(disfluency).to have_key(:length)
      end

      it 'summary has :total_disfluencies, :disfluency_rate, :by_category, :most_common_fillers' do
        result = RegexDisfluencyAnalyzer.analyze('Hello there.')
        summary = result[:summary]

        expect(summary).to have_key(:total_disfluencies)
        expect(summary).to have_key(:disfluency_rate)
        expect(summary).to have_key(:by_category)
        expect(summary).to have_key(:most_common_fillers)
      end
    end

    # -------------------------------------------------------------------------
    # Mixed / Complex Cases
    # -------------------------------------------------------------------------
    context 'with mixed disfluencies' do
      it 'detects multiple categories in a single sentence' do
        text = 'Um, I I was, like, b- but sooo tired.'
        result = RegexDisfluencyAnalyzer.analyze(text)
        disfluencies = result[:annotated_sentences][0][:disfluencies]

        categories = disfluencies.map { |d| d[:category] }.uniq
        expect(categories).to include('filler_words')
        expect(categories).to include('word_repetitions')
        expect(categories).to include('sound_repetitions')
        expect(categories).to include('prolongations')
      end

      it 'handles a sentence with revisions and partial words' do
        text = 'I was gon- going-- I went home.'
        result = RegexDisfluencyAnalyzer.analyze(text)
        disfluencies = result[:annotated_sentences][0][:disfluencies]

        categories = disfluencies.map { |d| d[:category] }
        expect(categories).to include('partial_words')
        expect(categories).to include('revisions')
      end
    end
  end
end
