require 'tariff_synchronizer/base_update'
require 'tariff_synchronizer/file_service'
require 'tariff_synchronizer/taric_file_name_generator'
require 'ostruct'

module TariffSynchronizer
  class TaricUpdate < BaseUpdate
    class << self

      def download(date)

        url = TaricFileNameGenerator.new(date).url

        instrument("get_taric_update_name.tariff_synchronizer", date: date, url: url)
        response = download_content(url)

        if response.success?
          if response.content_present?
            taric_updates = response.content.
                              split("\n").
                              map{|name| name.gsub(/[^0-9a-zA-Z\.]/i, '')}.
                              map{|name|
                                OpenStruct.new(
                                  file_name: name,
                                  url: TariffSynchronizer.taric_update_url_template % {
                                         host: TariffSynchronizer.host,
                                         file_name: name }
                                )
                              }

            taric_updates.each do |taric_update|
              local_file_name = "#{date}_#{taric_update.file_name}"
              perform_download(local_file_name, taric_update.url, date)
            end
          else
            create_update_entry(date, BaseUpdate::FAILED_STATE, missing_update_name_for(date))
            instrument("blank_update.tariff_synchronizer", date: date, url: response.url)
          end
        elsif response.retry_count_exceeded?
          create_update_entry(date, BaseUpdate::FAILED_STATE, missing_update_name_for(date))
          instrument("retry_exceeded.tariff_synchronizer", date: date, url: response.url)
        elsif response.not_found?
          # We will be retrying a few more times today, so do not create
          # missing record until we are sure
          if date < Date.current
            create_update_entry(date, BaseUpdate::MISSING_STATE, missing_update_name_for(date))
            instrument("not_found.tariff_synchronizer", date: date, url: url)
            false
          end
        end
      end

      def update_type
        :taric
      end
    end

    def import!
      instrument("apply_taric.tariff_synchronizer", filename: filename) do
        TaricImporter.new(file_path, issue_date).import
        update_file_size(file_path)
        mark_as_applied
      end
    end

    private

    def update_file_size(file_path)
      update(filesize: File.size(file_path))
    end

    def self.validate_file!(response)
      begin
        Nokogiri::XML(response.content) do |config|
          config.options = Nokogiri::XML::ParseOptions::STRICT
        end
      rescue Nokogiri::XML::SyntaxError => e
        raise InvalidContents.new(e.message, e)
      else
        true
      end
    end
  end
end
