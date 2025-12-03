class RemoveIntegerFromSettings < ActiveRecord::Migration[7.1]
  def change
    if column_exists?(:patchwork_settings, :integer)
      safety_assured { remove_column :patchwork_settings, :integer, :integer }
    end
    change_column_default :patchwork_settings, :app_name, from: nil, to: 0
  end
end