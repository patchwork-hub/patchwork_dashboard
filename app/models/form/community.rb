# frozen_string_literal: true

# Form::Community is a form object used for handling community-related form data.
# It is not directly associated with a database table but manages form inputs

class Form::Community
  include ActiveModel::Model

  attr_accessor :id, :name, :collection_id, :bio, :banner_image, :avatar_image

  def initialize(options = {})
    options = options.is_a?(Hash) ? options.symbolize_keys : options
    @name = options.fetch(:name) if options[:name]
    @collection_id = options.fetch(:collection_id) if options[:collection_id]
    @bio = options.fetch(:bio, nil) if options[:bio]
    @banner_image = options.fetch(:banner_image, nil) if options[:banner_image]
    @avatar_image = options.fetch(:avatar_image, nil) if options[:avatar_image]
  end
end
