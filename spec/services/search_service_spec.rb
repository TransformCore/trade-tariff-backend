require 'spec_helper'

describe SearchService do
  describe 'initialization' do
    let(:query) { Forgery(:basic).text }

    it 'assigns search query' do
      SearchService.new(q: query).q.should == query
    end
  end

  describe "#valid?" do
    it 'is not valid if has no q param assigned' do
      SearchService.new(q: nil).valid?.should be_false
    end

    it 'is not valid if has no as_of param assigned' do
      SearchService.new(q: 'value').valid?.should be_false
    end

    it 'is valid if has both q and as_of params provided' do
      SearchService.new(q: 'value', as_of: Date.today).valid?.should be_true
    end
  end

  # Searching in local tables
  describe 'exact search' do
    context 'chapters' do
      let(:chapter) { create :chapter }
      let(:pattern) {
        {
          type: 'exact_match',
          entry: {
            endpoint: 'chapters',
            id: chapter.goods_nomenclature_item_id.first(2)
          }
        }
      }

      it 'returns endpoint and identifier if provided with 2 symbol chapter code' do
        result = SearchService.new(q: chapter.goods_nomenclature_item_id.first(2),
                                   as_of: Date.today).to_json

        result.should match_json_expression pattern
      end

      it 'returns endpoint and identifier if provided with matching 3 symbol chapter code' do
        result = SearchService.new(q: chapter.goods_nomenclature_item_id.first(2),
                                   as_of: Date.today).to_json

        result.should match_json_expression pattern
      end
    end

    context 'headings' do
      let(:heading) { create :heading }
      let(:pattern) {
        {
          type: 'exact_match',
          entry: {
            endpoint: 'headings',
            id: heading.goods_nomenclature_item_id.first(4)
          }
        }
      }

      it 'returns endpoint and identifier if provided with 4 symbol heading code' do
        result = SearchService.new(q: heading.goods_nomenclature_item_id.first(4),
                                   as_of: Date.today).to_json

        result.should match_json_expression pattern
      end

      it 'returns endpoint and identifier if provided with matching 6 (or any between length of 4 to 9) symbol heading code' do
        result = SearchService.new(q: heading.goods_nomenclature_item_id.first(6),
                                   as_of: Date.today).to_json

        result.should match_json_expression pattern
      end
    end

    context 'commodities' do
      let(:commodity) { create :commodity, :declarable }
      let(:heading) { create :heading, :declarable }
      let(:commodity_pattern) {
        {
          type: 'exact_match',
          entry: {
            endpoint: 'commodities',
            id: commodity.goods_nomenclature_item_id.first(10)
          }
        }
      }
      let(:heading_pattern) {
        {
          type: 'exact_match',
          entry: {
            endpoint: 'headings',
            id: heading.goods_nomenclature_item_id.first(4)
          }
        }
      }

      it 'returns endpoint and identifier if provided with 10 symbol commodity code' do
        result = SearchService.new(q: commodity.goods_nomenclature_item_id.first(10),
                                   as_of: Date.today).to_json

        result.should match_json_expression commodity_pattern
      end

      it 'returns endpoint and identifier if provided with matching 12 symbol commodity code' do
        result = SearchService.new(q: commodity.goods_nomenclature_item_id + commodity.producline_suffix,
                                   as_of: Date.today).to_json

        result.should match_json_expression commodity_pattern
      end

      it 'returns endpoint and identifier if provided with matching 10 symbol declarable heading code' do
        result = SearchService.new(q: heading.goods_nomenclature_item_id,
                                   as_of: Date.today).to_json

        result.should match_json_expression heading_pattern
      end
    end
  end

  # Searching in ElasticSearch index
  describe 'fuzzy search' do
  end
end