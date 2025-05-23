# == Schema Information
#
# Table name: api_keys
#
#  id         :bigint           not null, primary key
#  key        :string
#  secret     :string
#  status     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class ApiKey < ApplicationRecord
  before_validation :set_status # Activated and Deactivated

  validates :key, :secret, :status, presence: true

  def activated?
    !!(status == 'Activated')
  end

  private

  def set_status
    self.status = 'Activated'
  end
end
