class WidenSpreeUserIdentityTokens < ActiveRecord::Migration[8.1]
  # OAuth access and refresh tokens do not fit a varchar(255) — Douyin's run to
  # several hundred characters — and once ActiveRecord Encryption is configured
  # the stored value is a JSON envelope around the ciphertext, so the limit
  # binds even sooner. Both columns hold credentials, never anything a database
  # has to index or compare.
  def up
    change_column :spree_user_identities, :access_token, :text
    change_column :spree_user_identities, :refresh_token, :text
  end

  def down
    change_column :spree_user_identities, :access_token, :string
    change_column :spree_user_identities, :refresh_token, :string
  end
end
