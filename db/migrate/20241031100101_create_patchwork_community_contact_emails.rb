class CreatePatchworkCommunityContactEmails < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_community_contact_emails, if_not_exists: true do |t|
      t.string :contact_email
      t.references :patchwork_community, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
  end
end
