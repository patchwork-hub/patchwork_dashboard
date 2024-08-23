class AccountSerializer
  include JSONAPI::Serializer

  set_type :account

  attributes :id,
            :username,
            :display_name,
            :confirmed_at,
            :suspended_at,
            :domain_name

  attribute :confirmed_at do |object|
    object.user.confirmed_at if object.user
  end

  attribute :domain_name do |object|
    object.domain.presence || ENV['PATCHWORK_DASHBOARD_URL']
  end
end
