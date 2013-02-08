class GeographicalAreaDescription < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: [:geographical_area_description_period_sid,
                               :geographical_area_sid]

  set_primary_key [:geographical_area_description_period_sid, :geographical_area_sid]

  one_to_one :geographical_area, key: :geographical_area_sid,
                                 primary_key: :geographical_area_sid
  one_to_one :geographical_area_description_period, key: :geographical_area_description_period_sid,
                                                    primary_key: :geographical_area_description_period_sid

  dataset_module do
    def latest
      order(:operation_date.desc)
    end
  end
end


