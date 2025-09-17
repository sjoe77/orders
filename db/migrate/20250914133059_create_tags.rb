class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name_nm
      t.string :color_code_nm

      t.timestamps
    end
  end
end
