class AddOmniauthToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :name, :string
    add_column :users, :image, :string
    add_column :users, :gmail_token, :text
    add_column :users, :gmail_refresh_token, :text
    
    add_index :users, [:provider, :uid]
  end
end
