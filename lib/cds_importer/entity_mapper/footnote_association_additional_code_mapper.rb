#
# FootnoteAssociationAdditionalCode is nested in to AdditionalCode.
#

class CdsImporter
  class EntityMapper
    class FootnoteAssociationAdditionalCodeMapper < BaseMapper
      self.entity_class = "FootnoteAssociationAdditionalCode".freeze

      self.mapping_root = "AdditionalCode".freeze

      self.mapping_path = "footnoteAssociationAdditionalCode".freeze

      self.exclude_mapping = ["metainfo.origin"].freeze

      self.entity_mapping = base_mapping.merge(
        "sid" => :additional_code_sid,
        "additionalCodeType.additionalCodeTypeId" => :additional_code_type_id,
        "additionalCodeCode" => :additional_code,
        "#{mapping_path}.footnote.footnoteType.footnoteTypeId" => :footnote_type_id,
        "#{mapping_path}.footnote.footnoteId" => :footnote_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
