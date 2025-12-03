class CreateIpAddresses < ActiveRecord::Migration[7.1]
  def change
    create_table :ip_addresses, if_not_exists: true do |t|
      t.string :ip, null: false
      t.integer :use_count, default: 0, null: false
      t.datetime :reserved_at

      t.timestamps
    end

    unless index_exists?(:ip_addresses, :ip)
      add_index :ip_addresses, :ip, unique: true
    end
  end
end
