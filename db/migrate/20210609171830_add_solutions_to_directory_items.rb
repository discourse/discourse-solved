# frozen_string_literal: true

class AddSolutionsToDirectoryItems < ActiveRecord::Migration[6.1]
  def change
    add_column :directory_items, :solutions, :integer, default: 0
  end
end
