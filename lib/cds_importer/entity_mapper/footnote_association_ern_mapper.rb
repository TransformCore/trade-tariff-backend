#
# FootnoteAssociationErn is nested in to ExportRefundNomenclature.
#

class CdsImporter
  class EntityMapper
    class FootnoteAssociationErnMapper < BaseMapper
      self.exclude_mapping = ["metainfo.origin"].freeze

      self.entity_class = "FootnoteAssociationErn".freeze

      self.mapping_path = "footnoteAssociationErn".freeze

      self.entity_mapping = base_mapping.merge(
        "sid" => :export_refund_nomenclature_sid,
        "#{mapping_path}.footnote.footnoteType.footnoteTypeId" => :footnote_type,
        "#{mapping_path}.footnote.footnoteId" => :footnote_id,
        "goodsNomenclature.goodsNomenclatureItemId" => :goods_nomenclature_item_id,
        "additionalCodeType.additionalCodeTypeId" => :additional_code_type,
        "exportRefundCode" => :export_refund_code,
        "productLine" => :productline_suffix
      ).freeze
    end
  end
end
