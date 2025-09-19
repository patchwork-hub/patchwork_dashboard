# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

Dir[Rails.root.join('db', 'seeds', '*.rb')].each do |seed|
  load seed
end

# Run the domain_block import rake task
Rake::Task['domain_block:import'].invoke

# Run default community types
Rake::Task['community_types:create'].invoke