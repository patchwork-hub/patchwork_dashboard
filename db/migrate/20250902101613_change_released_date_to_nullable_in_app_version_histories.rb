class ChangeReleasedDateToNullableInAppVersionHistories < ActiveRecord::Migration[7.1]
  def change
    change_column :patchwork_app_version_histories, :released_date, :datetime, null: true, default: -> { 'CURRENT_TIMESTAMP' }
  end
end
