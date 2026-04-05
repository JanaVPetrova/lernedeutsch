FactoryBot.define do
  factory :user do
    sequence(:telegram_id) { |n| 100_000 + n }
    first_name { 'Anna' }
    last_name  { 'Müller' }
    username   { 'anna_mueller' }
    preferred_language { 'en' }
  end

  factory :word_group do
    name_ru { 'Животные' }
    name_de { 'Tiere' }
  end

  factory :word do
    sequence(:german_word) { |n| "Wort#{n}" }
    translation { 'word' }
    article     { nil }
    word_group  { nil }

    trait :with_article do
      german_word { 'Hund' }
      article     { 'der' }
      translation { 'dog' }
    end

    trait :in_group do
      association :word_group
    end
  end

  factory :word_review do
    association :word
    association :user
    repetitions { 0 }
    ease_factor { 2.5 }
    interval    { 1 }
    due_date    { Time.now }
    snoozed     { false }
    last_score  { nil }
  end

  factory :reminder do
    association :user
    time    { '09:00' }
    days    { %w[mon tue wed thu fri] }
    enabled { true }
  end
end
