class AddReasonToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :reason, :text
  end
end
