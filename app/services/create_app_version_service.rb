class CreateAppVersionService
  include ActiveModel::Model

  attr_accessor :version_name, :app_name, :os_type, :released_date

  validates :version_name, presence: true
  validates :released_date, presence: true
  validate :valid_app_name

  def initialize(params = {})
    @version_name = params[:version_name]
    @app_name = params[:app_name]
    @os_type = params[:os_type]&.strip&.downcase
    @released_date = params[:released_date]
  end

  def call
    return false unless valid?

    AppVersion.transaction do
      @app_version = AppVersion.create!(
        version_name: version_name,
        app_name: app_value
      )

      history_records = if both_os?
                          %w[android ios].map { |os| history_attributes(os) }
                        else
                          [history_attributes(os_type)]
                        end
      AppVersionHistory.insert_all(history_records)
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, "Failed to create record: #{e.record.errors.full_messages.to_sentence}")
    false
  end

  private

  def history_attributes(os)
    {
      app_version_id: @app_version.id,
      os_type: os,
      released_date: @released_date,
      deprecated: false,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def valid_app_name

    if @app_name.blank? || @app_name.empty?
      errors.add(:app_name, 'cannot be blank')
    end

    if AppVersion.app_names.value?(@app_name&.to_i)
      return @app_name&.to_i
    end

    errors.add(:app_name, 'is not valid')
  end

  def app_value
    @app_name&.to_i
  end

  def both_os?
    @os_type == 'both'
  end
end