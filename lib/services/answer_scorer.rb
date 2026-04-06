class AnswerScorer
  ARTICLES = %w[der die das].freeze

  # Returns an integer score 0–100.
  # `expected` may be a String or an Array of accepted answers.
  def self.score(expected:, given:)
    Array(expected).map { |alt| new(alt, given).score }.max || 0
  end

  def initialize(expected, given)
    @expected = normalize(expected)
    @given    = normalize(given)
  end

  def score
    return 0   if @given.empty?
    return 100 if @expected == @given

    exp_article, exp_word = split_article(@expected)
    giv_article, giv_word = split_article(@given)

    word_score = string_similarity(exp_word, giv_word)

    if exp_article
      if giv_article.nil?
        word_score = (word_score * 0.7).round    # missing article
      elsif exp_article != giv_article
        word_score = (word_score * 0.7).round    # wrong article
      end
    end

    word_score
  end

  private

  def normalize(str)
    str.to_s.gsub(/\([^)]*\)/, '').gsub(/[[:punct:]]/, '').strip.downcase.squeeze(' ')
  end

  def split_article(str)
    parts = str.split(' ', 2)
    ARTICLES.include?(parts[0]) ? parts : [nil, str]
  end

  # Returns 0–100 based on Levenshtein similarity.
  def string_similarity(expected, given)
    return 100 if expected == given
    return 0   if expected.empty?

    dist       = levenshtein(expected, given)
    max_length = [expected.length, given.length].max
    [(1.0 - dist.to_f / max_length) * 100, 0].max.round
  end

  def levenshtein(s1, s2)
    m, n = s1.length, s2.length
    dp = Array.new(m + 1) { Array.new(n + 1, 0) }

    (0..m).each { |i| dp[i][0] = i }
    (0..n).each { |j| dp[0][j] = j }

    (1..m).each do |i|
      (1..n).each do |j|
        dp[i][j] = if s1[i - 1] == s2[j - 1]
                     dp[i - 1][j - 1]
                   else
                     1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].min
                   end
      end
    end

    dp[m][n]
  end
end
