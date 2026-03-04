class AddUserIdAndMakeBandOptionalOnEvents < ActiveRecord::Migration[8.0]
  def up
    # Add user_id column (nullable initially for backfill)
    add_reference :events, :user, null: true, foreign_key: true

    # Backfill user_id from bands.user_id for existing events
    execute <<~SQL
      UPDATE events
      SET user_id = bands.user_id
      FROM bands
      WHERE events.band_id = bands.id
        AND bands.user_id IS NOT NULL
    SQL

    # Make user_id NOT NULL after backfill
    change_column_null :events, :user_id, false

    # Make band_id nullable
    change_column_null :events, :band_id, true
  end

  def down
    # Make band_id NOT NULL again
    change_column_null :events, :band_id, false

    # Remove user_id column
    remove_reference :events, :user
  end
end
