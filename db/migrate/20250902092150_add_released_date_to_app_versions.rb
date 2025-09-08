class AddReleasedDateToAppVersions < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      add_column :patchwork_app_version_histories, :released_date, :datetime, null: true, default: -> { 'CURRENT_TIMESTAMP' } unless column_exists?(:patchwork_app_version_histories, :released_date)
    end
  end
end
