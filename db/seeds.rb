# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

Dir[Rails.root.join('db', 'seeds', '*.rb')].each do |seed|
  load seed
  load 'db/seeds/community_user_role.rb'
end

# Run the insert_server_setting_data rake task
Rake::Task['db:insert_server_setting_data'].invoke
