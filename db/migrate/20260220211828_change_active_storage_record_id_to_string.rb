class ChangeActiveStorageRecordIdToString < ActiveRecord::Migration[8.0]
  def up
    # Remove the existing index that includes record_id
    remove_index :active_storage_attachments, [:record_type, :record_id, :name, :blob_id],
                 name: 'index_active_storage_attachments_uniqueness'

    # Change record_id from bigint to string to support both integer and UUID primary keys
    change_column :active_storage_attachments, :record_id, :string, null: false

    # Re-add the index
    add_index :active_storage_attachments, [:record_type, :record_id, :name, :blob_id],
              name: 'index_active_storage_attachments_uniqueness', unique: true
  end

  def down
    remove_index :active_storage_attachments, name: 'index_active_storage_attachments_uniqueness'

    # Note: This may fail if there are UUID values stored
    change_column :active_storage_attachments, :record_id, :bigint, null: false

    add_index :active_storage_attachments, [:record_type, :record_id, :name, :blob_id],
              name: 'index_active_storage_attachments_uniqueness', unique: true
  end
end
