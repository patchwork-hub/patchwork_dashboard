class CreatePatchworkContentTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_content_types, if_not_exists: true do |t|
      t.string :channel_type, null: false
      t.string :custom_condition
      t.references :patchwork_community, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
  end
end
