class AddAttachmentAvatarImageBannerImageToCommunities < ActiveRecord::Migration[7.1]
  def self.up
    safety_assured do
      change_table :patchwork_communities do |t|
        unless column_exists?(:patchwork_communities, :avatar_image_file_name)
          t.attachment :avatar_image
        end
        unless column_exists?(:patchwork_communities, :banner_image_file_name)
          t.attachment :banner_image
        end
      end
    end
  end

  def self.down
    remove_attachment :patchwork_communities, :avatar_image if column_exists?(:patchwork_communities, :avatar_image_file_name)
    remove_attachment :patchwork_communities, :banner_image if column_exists?(:patchwork_communities, :banner_image_file_name)
  end
end