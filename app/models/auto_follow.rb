class AutoFollow < ApplicationRecord
  self.table_name = 'patchwork_auto_follows'

  has_many :auto_follow_accounts, -> { order(:position, :id) }, foreign_key: :patchwork_auto_follow_id, dependent: :delete_all
  has_many :accounts, through: :auto_follow_accounts

  before_validation :normalize_instance_name
  validates :title, :instance_name, presence: true
  validates :instance_name, uniqueness: true
  validate :enabled_auto_follow_has_account

  def self.ransackable_attributes(_auth_object = nil)
    %w[title instance_name]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def normalize_instance_name
    self.instance_name = instance_name.to_s.parameterize(separator: '')
  end

  def enabled_auto_follow_has_account
    errors.add(:enabled, 'Add an account before enabling auto-follow.') if enabled? && auto_follow_accounts.empty?
  end
end