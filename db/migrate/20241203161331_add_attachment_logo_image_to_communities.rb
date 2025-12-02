class AddAttachmentLogoImageToCommunities < ActiveRecord::Migration[7.1]
  def self.up
    safety_assured do
      change_table :patchwork_communities do |t|
        unless column_exists?(:patchwork_communities, :logo_image_file_name)
          t.attachment :logo_image
        end
      end
    end
  end

  def self.down
    remove_attachment :patchwork_communities, :logo_image if column_exists?(:patchwork_communities, :logo_image_file_name)
  end
end