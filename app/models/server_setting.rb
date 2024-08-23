class ServerSetting < ApplicationRecord
  validates :name, presence: true

  has_many :keyword_filter_groups, dependent: :destroy

  belongs_to :parent, class_name: "ServerSetting", optional: true
  has_many :children, class_name: "ServerSetting", foreign_key: "parent_id", dependent: :destroy

  after_update :invoke_keyword_schedule, if: :saved_change_to_value?, if: :content_or_spam_filters?

  after_commit :sync_setting

  def parent
    self.class.find(parent_id) if parent_id
  end

  def has_parent?
    !!parent
  end

  private

  def invoke_keyword_schedule
    KeywordFiltersJob.perform_now(name)
  end

  def content_or_spam_filters?
    name == "Content filters" || name == "Spam filters"
  end

  def sync_setting
    if (endpoint = ENV['PATCHWORK_HUB_URL']) && (saved_change_to_value? && has_parent?)
      @api_key = ApiKey.first

      params = {
        server_setting: {
          settings: [
            {
              name: parent.name,
              options: [
                {
                  name: name,
                  value: value,
                  position: position
                }
              ]
            }
          ]
        }
      }
      conn = Faraday.new(
        url: endpoint,
        params: params,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': @api_key.key,
          'x-api-secret': @api_key.secret
        }
      )

      response = conn.post('/api/v1/server_settings/upsert')
      Rails.logger.info "✅ Settings synced!"
    end
  end
end
