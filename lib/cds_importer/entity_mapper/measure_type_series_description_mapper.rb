class CdsImporter
  class EntityMapper
    class MeasureTypeSeriesDescriptionMapper < BaseMapper
      self.entity_class = 'MeasureTypeSeriesDescription'.freeze

      self.mapping_root = 'MeasureTypeSeries'.freeze

      self.mapping_path = 'measureTypeSeriesDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'measureTypeSeriesId' => :measure_type_series_id,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
