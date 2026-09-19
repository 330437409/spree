class WidenServiceAreaCoordinates < ActiveRecord::Migration[8.1]
  # `t.decimal` without a scale means scale 0 on MySQL, and MySQL silently
  # rounds to it: a warehouse at 39.9089 was stored as 39, some 100 km from
  # where it is, while PostgreSQL and SQLite kept the decimals. Seven places is
  # about a centimetre and three digits before the point covers every longitude
  # there is.
  #
  # A migration of its own rather than an edit to the one that added the
  # columns: that one has run where this has not, and editing it would leave
  # those databases with the rounded column and no way to notice.
  def change
    change_column :spree_stock_locations, :latitude, :decimal, precision: 10, scale: 7
    change_column :spree_stock_locations, :longitude, :decimal, precision: 10, scale: 7
  end
end
