class AddPrivateIpToIpAddresses < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:ip_addresses, :private_ip)
      add_column :ip_addresses, :private_ip, :string
    end
  end
end
