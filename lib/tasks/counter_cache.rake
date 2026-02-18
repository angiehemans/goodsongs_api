# frozen_string_literal: true

namespace :counter_cache do
  desc "Reset all counter caches for users"
  task reset_all: :environment do
    puts "Resetting counter caches..."

    # Reset followers_count
    puts "Updating followers_count..."
    User.find_each do |user|
      User.reset_counters(user.id, :passive_follows)
    end

    # Reset following_count
    puts "Updating following_count..."
    User.find_each do |user|
      User.reset_counters(user.id, :active_follows)
    end

    # Reset reviews_count
    puts "Updating reviews_count..."
    User.find_each do |user|
      User.reset_counters(user.id, :reviews)
    end

    puts "Done!"
  end

  desc "Reset counter caches using raw SQL (faster for large datasets)"
  task reset_all_sql: :environment do
    puts "Resetting counter caches using SQL..."

    # Update followers_count
    puts "Updating followers_count..."
    ActiveRecord::Base.connection.execute(<<-SQL.squish)
      UPDATE users
      SET followers_count = (
        SELECT COUNT(*)
        FROM follows
        WHERE follows.followed_id = users.id
      )
    SQL

    # Update following_count
    puts "Updating following_count..."
    ActiveRecord::Base.connection.execute(<<-SQL.squish)
      UPDATE users
      SET following_count = (
        SELECT COUNT(*)
        FROM follows
        WHERE follows.follower_id = users.id
      )
    SQL

    # Update reviews_count
    puts "Updating reviews_count..."
    ActiveRecord::Base.connection.execute(<<-SQL.squish)
      UPDATE users
      SET reviews_count = (
        SELECT COUNT(*)
        FROM reviews
        WHERE reviews.user_id = users.id
      )
    SQL

    puts "Done!"
  end
end
