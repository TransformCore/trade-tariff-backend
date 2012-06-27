class CreateFootnoteDescriptionPeriods < ActiveRecord::Migration
  def change
    create_table :footnote_description_periods, :id => false do |t|
      t.string :footnote_description_period_sid
      t.string :footnote_type_id
      t.string :footnote_id
      t.date :validity_start_date

      t.timestamps
    end
  end
end