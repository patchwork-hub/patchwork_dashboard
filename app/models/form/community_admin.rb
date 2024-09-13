class Form::CommunityAdmin
  include ActiveModel::Model

  attr_accessor :community_id, :display_name, :username, :email, :password

  def initialize(options = {})
    options = options.is_a?(Hash) ? options.symbolize_keys : options
    @community_id = options.fetch(:community_id) if options[:community_id]
    @role = options.fetch(:role) if options[:role]
    @display_name = options.fetch(:display_name, nil) if options[:display_name]
    @email = options.fetch(:email, nil) if options[:email]
    @username = options.fetch(:username, nil) if options[:username]
    @password = options.fetch(:password, nil) if options[:password]
  end
end
