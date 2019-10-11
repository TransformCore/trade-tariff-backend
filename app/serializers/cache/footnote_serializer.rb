module Cache
  class FootnoteSerializer
    include ::Cache::SearchCacheMethods

    attr_reader :footnote, :as_of

    def initialize(footnote)
      @footnote = footnote
      @as_of = Date.current.midnight
    end

    def as_json
      footnote_attributes = {
        code: footnote.code,
        footnote_type_id: footnote.footnote_type_id,
        footnote_id: footnote.footnote_id,
        description: footnote.description,
        formatted_description: footnote.formatted_description,
        validity_start_date: footnote.validity_start_date,
        validity_end_date: footnote.validity_end_date,
        goods_nomenclatures: footnote.goods_nomenclatures.reject do |goods_nomenclature|
          HiddenGoodsNomenclature.codes.include? goods_nomenclature.goods_nomenclature_item_id
        end.select do |goods_nomenclature|
          has_valid_dates(goods_nomenclature)
        end.map do |goods_nomenclature|
          goods_nomenclature_attributes(goods_nomenclature)
        end
      }

      measures = footnote.measures.select { |measure| has_valid_dates(measure) }
      footnote_attributes[:measures] = measures.map do |measure|
        {
          id: measure.measure_sid,
          measure_sid: measure.measure_sid,
          validity_start_date: measure.validity_start_date,
          validity_end_date: measure.validity_end_date,
          goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
          goods_nomenclature_sid: measure.goods_nomenclature_sid,
          goods_nomenclature: goods_nomenclature_attributes(measure.goods_nomenclature)
        }
      end unless measures.size >= 1000
      footnote_attributes[:extra_large_measures] = measures.size >= 1000
      footnote_attributes
    end
  end
end
