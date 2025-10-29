class AddConfidenceToProducts < ActiveRecord::Migration[8.1]
  def change
    # Column already exists, so we'll just add a comment
    # add_column :products, :confidence, :decimal
  end
end
