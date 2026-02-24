# frozen_string_literal: true

class AddPreferredStreamingPlatformToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :preferred_streaming_platform, :string
  end
end
