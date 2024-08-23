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
