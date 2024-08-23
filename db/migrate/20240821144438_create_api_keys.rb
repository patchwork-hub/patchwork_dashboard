class CreateApiKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :api_keys do |t|
      t.string :key
      t.string :secret
      t.string :status

      t.timestamps
    end
  end
end