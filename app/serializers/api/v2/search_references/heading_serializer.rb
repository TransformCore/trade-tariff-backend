module Api
  module V2
    module SearchReferences
      class HeadingSerializer
        include FastJsonapi::ObjectSerializer
        set_id :goods_nomenclature_sid
        set_type :heading
        
        attributes :goods_nomenclature_item_id, :producline_suffix, :validity_start_date,
                   :validity_end_date, :description, :number_indents

        has_one :section, serializer: Api::V2::SearchReferences::SectionSerializer
        has_one :chapter, serializer: Api::V2::SearchReferences::ChapterSerializer

      end
    end
  end
end
