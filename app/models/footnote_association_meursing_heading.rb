class FootnoteAssociationMeursingHeading < Sequel::Model
  plugin :oplog, primary_key: [:measure_sid,
                               :footnote_id,
                               :meursing_table_plan_id]
  set_primary_key [:footnote_id, :meursing_table_plan_id]
end


