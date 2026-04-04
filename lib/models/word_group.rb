class WordGroup < ActiveRecord::Base
  belongs_to :user
  has_many   :words, dependent: :destroy

  validates :name_ru, presence: true
  validates :name_de, presence: true
  validates :user, presence: true
end
