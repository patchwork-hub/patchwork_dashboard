roles = [
  { name: 'OrganisationAdmin', position: 1010, permissions: %w[invite_users] },
  { name: 'MasterAdmin', position: 1100, permissions: %w[administrator] },
  { name: 'UserAdmin', position: 1200, permissions: %w[invite_users] },
  { name: 'HubAdmin', position: 1300, permissions: %w[invite_users] },
  { name: 'NewsmastAdmin', position: 1400, permissions: %w[invite_users] }
]

roles.each do |role_attrs|
  permissions = role_attrs[:permissions].reduce(0) do |bitmask, permission|
    if UserRole::FLAGS.key?(permission.to_sym)
      bitmask | UserRole::FLAGS[permission.to_sym]
    else
      raise ArgumentError, "Unknown permission: #{permission}"
    end
  end

  UserRole.find_or_create_by!(name: role_attrs[:name]) do |role|
    role.position = role_attrs[:position]
    role.permissions = permissions
  end
end
