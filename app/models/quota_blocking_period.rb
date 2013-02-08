class QuotaBlockingPeriod < Sequel::Model
  plugin :oplog, primary_key: :quota_definition_sid
  set_primary_key  :quota_blocking_period_sid

  dataset_module do
    def last
      order(:end_date.desc).first
    end
  end
end


