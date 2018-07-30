Sequel.migration do
  change do
    create_table :tariff_update_destroy_errors do
      primary_key :id
      String :tariff_update_filename, null: false
      String :model_name, null: false
      jsonb :attributes

      index :tariff_update_filename
    end
  end
end
