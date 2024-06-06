class KeywordFilter < ApplicationRecord
  self.table_name = 'keyword_filters'
  validates :keyword, presence: true, uniqueness: true

  enum filter_type: { hashtag: 0, both: 1, content: 2 }

end
