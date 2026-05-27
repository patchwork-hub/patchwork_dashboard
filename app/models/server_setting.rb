# == Schema Information
#
# Table name: server_settings
#
#  id             :bigint           not null, primary key
#  deleted_at     :datetime
#  key            :string
#  name           :string
#  optional_value :string
#  position       :integer
#  value          :boolean
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  parent_id      :bigint
#
# Indexes
#
#  index_server_settings_on_key  (key) UNIQUE WHERE (key IS NOT NULL)
#
class ServerSetting < ApplicationRecord
  include ServerSettingConfig

  validates :name, presence: true
  validates :key, uniqueness: true, allow_nil: true

  has_many :keyword_filter_groups, dependent: :destroy

  belongs_to :parent, class_name: "ServerSetting", optional: true
  has_many :children, class_name: "ServerSetting", foreign_key: "parent_id", dependent: :destroy

  after_update :invoke_keyword_schedule, if: -> { saved_change_to_value? && content_or_spam_filters? }

  after_update :update_accounts_discoverable, if: -> { saved_change_to_value? && search_opt_out_filter? }

  after_update :update_bluesky_bridge_enabled, if: -> { saved_change_to_value? && bluesky_bridge_enabled? }

  after_commit :sync_setting

  def parent
    self.class.find(parent_id) if parent_id
  end

  def has_parent?
    !!parent
  end

  private

  def invoke_keyword_schedule
    KeywordFiltersJob.perform_now(key)
  end

  def content_or_spam_filters?
    key.in?([KEY_CONTENT_FILTERS, KEY_SPAM_FILTERS])
  end

  def sync_setting
    SyncSettingService.new(self).call if saved_change_to_value? && has_parent?
  end

  def search_opt_out_filter?
    key == KEY_SEARCH_OPT_OUT
  end

  def bluesky_bridge_enabled?
    key == KEY_BLUESKY_BRIDGE_AUTO
  end

  def update_accounts_discoverable
    UpdateAccountsDiscoverabilityJob.perform_later(value)
  end

  def update_bluesky_bridge_enabled
    return unless value
    BlueskyBridgeEnabledJob.perform_later(value)
  end
end
