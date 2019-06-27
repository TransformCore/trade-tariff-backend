module Api
  module Admin
    module Headings
      class ChapterSerializer
        include FastJsonapi::ObjectSerializer

        set_type :chapter

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id, :description
      end
    end
  end
end
