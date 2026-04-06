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
  # Pipe-separated values in either column expand into multiple rows
  # (the cross-product of German forms × translations).
  def self.parse(content)
    content = content.dup.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
    content.gsub!("\xEF\xBB\xBF", '')  # strip UTF-8 BOM

    words = []
    CSV.parse(content, col_sep: "\t") do |row|
      next if row.empty?
      de_raw = row[0]&.strip
      ru_raw = row[1]&.strip
      next if de_raw.nil? || de_raw.empty? || de_raw.start_with?('#')
      next if ru_raw.nil? || ru_raw.empty?

      de_forms = de_raw.split('|').map(&:strip)
      ru_forms = ru_raw.split('|').map(&:strip)

      de_forms.each do |g|
        article_de, de = split_article(g)
        ru_forms.each do |r|
          words << { de: de, article_de: article_de, ru: r }
        end
      end
    end

    words
  end

  # Persist words globally, skipping duplicates. Returns count of new records.
  def self.import(words_data, word_group: nil)
    count = 0
    words_data.each do |attrs|
      dn = Word.normalize(attrs[:de])
      rn = Word.normalize(attrs[:ru])
      word = Word.find_by(de_normalized: dn, ru_normalized: rn) ||
             Word.new(de: attrs[:de], ru: attrs[:ru])
      next unless word.new_record?

      word.article_de = attrs[:article_de]
      word.word_group = word_group
      word.save!
      count += 1
    end
    count
  end

  def self.split_article(de_full)
    parts = de_full.split(' ', 2)
    ARTICLES.include?(parts[0].downcase) ? [parts[0].downcase, parts[1]] : [nil, de_full]
  end
end
