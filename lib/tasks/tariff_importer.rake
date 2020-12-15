# Import TARIC or CDS file manually. Usually for initial seed files.
namespace :importer do
  namespace :taric do
    desc "Import TARIC file"
    task import: %i[environment class_eager_load] do
      if ENV["TARGET"] && File.exist?(ENV["TARGET"])
        # We will be fetching updates from Taric and modifying primary keys
        # so unrestrict it for all models.
        Sequel::Model.subclasses.each(&:unrestrict_primary_key)
        Sequel::Model.plugin :skip_create_refresh
        dummy_update = OpenStruct.new(file_path: ENV["TARGET"], issue_date: nil)
        TaricImporter.new(dummy_update).import(validate: false)
      else
        puts "Please provide TARGET environment variable pointing to Tariff file to import"
      end
    end

    desc "Import TARIC file from S3"
    task import_from_s3: %i[environment class_eager_load] do
      if ENV["TARGET"] && File.exist?(ENV["TARGET"])
        Sequel::Model.subclasses.each(&:unrestrict_primary_key)
        Sequel::Model.plugin :skip_create_refresh
        taric_update = TariffSynchronizer::TaricUpdate.new(
          filename: ENV["TARGET"],
          issue_date: '1970-01-01',
          state: "P",
          update_type: "TariffSynchronizer::TaricUpdate"
        )
        TaricImporter.new(taric_update).import(validate: false)
      else
        puts "Please provide TARGET environment variable pointing to Tariff file to import"
      end
    end
  end


  namespace :cds do
    desc "Import CDS file"
    task import: %i[environment class_eager_load] do
      if ENV["TARGET"] && File.exist?(ENV["TARGET"])
        # We will be fetching updates from Taric and modifying primary keys
        # so unrestrict it for all models.
        Sequel::Model.subclasses.each(&:unrestrict_primary_key)
        Sequel::Model.plugin :skip_create_refresh
        dummy_update = OpenStruct.new(file_path: ENV["TARGET"], issue_date: nil)

        CdsImporter.new(dummy_update).import
      else
        puts "Please provide TARGET environment variable pointing to Tariff file to import"
      end
    end

    desc "Initial CDS load"
    task init: %i[environment class_eager_load] do
      # Before running this task
      # - install db and load structure
      # - load shared data (sections, notes, etc.)
      # - upload initial update files to S3
      files = TariffSynchronizer::FileService.bucket.objects.to_a
                                                    .select{ |o| o.key.include? "data/cds/tariff" }
                                                    .map{ |f| f.key.split("/").last }
      files.each do |file|
        u = TariffSynchronizer::CdsUpdate.where(filename: file).first
        next if u.present?
        u = TariffSynchronizer::CdsUpdate.new
        u.filename = file
        u.issue_date = Date.parse file[-20..-13]
        u.state = "P"
        u.update_type = "TariffSynchronizer::CdsUpdate"
        u.filesize = TariffSynchronizer::FileService.file_size(u.file_path)
        u.save
      end

      Sequel::Model.subclasses.each(&:unrestrict_primary_key)
      Sequel::Model.plugin :skip_create_refresh

      TariffSynchronizer::CdsUpdate.pending
                                   .where("filename SIMILAR TO 'tariff_(yearly|monthly)Extract%'")
                                   .order(Sequel.asc(:issue_date))
                                   .each(&:import!)
    end
  end
end
