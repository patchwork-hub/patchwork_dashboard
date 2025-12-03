class AddIpAddressToCommunities < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    unless column_exists?(:patchwork_communities, :ip_address_id)
      add_reference :patchwork_communities, :ip_address, index: {algorithm: :concurrently}
    else
      # Ensure index exists if column already exists
      unless index_exists?(:patchwork_communities, :ip_address_id)
        add_index :patchwork_communities, :ip_address_id, algorithm: :concurrently
      end
    end
  end
end