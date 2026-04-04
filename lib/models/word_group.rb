class WordGroup < ActiveRecord::Base
  has_many :words, dependent: :nullify

  validates :name_ru, presence: true
  validates :name_de, presence: true
end
