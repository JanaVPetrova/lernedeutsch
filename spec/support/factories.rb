FactoryBot.define do
  factory :user do
    sequence(:telegram_id) { |n| 100_000 + n }
    first_name { 'Anna' }
    last_name  { 'Müller' }
    username   { 'anna_mueller' }
    preferred_language { 'en' }
  end

  factory :word do
    association :user
    sequence(:german_word) { |n| "Wort#{n}" }
    translation { 'word' }
    article     { nil }

    trait :with_article do
      german_word { 'Hund' }
      article     { 'der' }
      translation { 'dog' }
    end

    # Word's after_create callback auto-creates a WordReview. Destroy it so
    # specs can build their own review with explicit attributes via the
    # :word_review factory without hitting the unique-index violation.
    after(:create) { |word| word.word_review&.destroy }
  end

  factory :word_review do
    association :word
    association :user
    repetitions { 0 }
    ease_factor { 2.5 }
    interval    { 1 }
    due_date    { Date.today }
  end

  factory :reminder do
    association :user
    time    { '09:00' }
    days    { %w[mon tue wed thu fri] }
    enabled { true }
  end
end
