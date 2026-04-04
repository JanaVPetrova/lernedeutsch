require 'csv'
require 'net/http'
require 'json'

class WordImporter
  ARTICLES = %w[der die das].freeze

  # Download a Telegram document and return its text content.
  def self.download_document(file_id, token)
    file_info = JSON.parse(Net::HTTP.get(URI("https://api.telegram.org/bot#{token}/getFile?file_id=#{file_id}")))
    return nil unless file_info['ok']

    file_path = file_info['result']['file_path']
    Net::HTTP.get(URI("https://api.telegram.org/file/bot#{token}/#{file_path}"))
  end

  # Parse TSV content into an array of word attribute hashes.
  def self.parse(content)
    content = content.dup.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
    content.gsub!("\xEF\xBB\xBF", '')  # strip UTF-8 BOM

    words = []
    CSV.parse(content, col_sep: "\t") do |row|
      next if row.empty?
      german_full = row[0]&.strip
      translation = row[1]&.strip
      next if german_full.nil? || german_full.empty? || german_full.start_with?('#')
      next if translation.nil? || translation.empty?

      article, german_word = split_article(german_full)
      words << { german_word: german_word, article: article, translation: translation }
    end

    words
  end

  # Persist words for a user, skipping duplicates. Returns count of new records.
  def self.import(user, words_data, word_group: nil)
    count = 0
    words_data.each do |attrs|
      word = Word.find_or_initialize_by(user: user, german_word: attrs[:german_word])
      next unless word.new_record?

      word.article     = attrs[:article]
      word.translation = attrs[:translation]
      word.word_group  = word_group
      word.save!
      count += 1
    end
    count
  end

  def self.split_article(german_full)
    parts = german_full.split(' ', 2)
    ARTICLES.include?(parts[0].downcase) ? [parts[0].downcase, parts[1]] : [nil, german_full]
  end
end
