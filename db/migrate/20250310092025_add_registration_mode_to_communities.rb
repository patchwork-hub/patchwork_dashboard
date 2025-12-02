class AddRegistrationModeToCommunities < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_communities, :registration_mode)
      add_column :patchwork_communities, :registration_mode, :string, default: 'none'
    end
  end
end
