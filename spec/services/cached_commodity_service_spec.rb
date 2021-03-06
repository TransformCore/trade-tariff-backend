require 'rails_helper'

describe CachedCommodityService do
  subject(:service) { described_class.new(commodity.reload, actual_date, filter_params) }

  let(:actual_date) { Time.zone.today }
  let(:filter_params) { ActionController::Parameters.new(geographical_area_id: 'RO').permit! }

  let!(:commodity) do
    create(
      :commodity,
      :with_indent,
      :with_chapter,
      :with_heading,
      :with_description,
      :declarable,
    )
  end

  describe '#call' do
    let(:pattern) do
      {
        data: {
          id: String,
          type: 'commodity',
          attributes: Hash,
          relationships: {
            footnotes: Hash,
            section: Hash,
            chapter: Hash,
            heading: Hash,
            ancestors: Hash,
            import_measures: Hash,
            export_measures: Hash,
          },
          meta: {
            duty_calculator: Hash,
          },
        },
        included: [
          {
            id: String,
            type: 'chapter',
            attributes: Hash,
            relationships: {
              guides: Hash,
            },
          },
          {
            id: String,
            type: 'heading',
            attributes: Hash,
          },
          {
            id: String,
            type: 'section',
            attributes: Hash,
          },
          {
            id: String,
            type: 'duty_expression',
            attributes: Hash,
          },
          {
            id: String,
            type: 'measure_type',
            attributes: Hash,
          },
          {
            id: String,
            type: 'legal_act',
            attributes: Hash,
          },
          {
            id: String,
            type: 'geographical_area',
            attributes: Hash,
            relationships: {
              children_geographical_areas: Hash,
            },
          },
          {
            id: String,
            type: 'measure',
            attributes: Hash,
            relationships: {
              duty_expression: Hash,
              measure_type: Hash,
              legal_acts: Hash,
              measure_conditions: Hash,
              measure_components: Hash,
              national_measurement_units: Hash,
              geographical_area: Hash,
              excluded_countries: Hash,
              footnotes: Hash,
              order_number: Hash,
            },
          },
        ],
      }
    end

    let(:geographical_area) { create(:geographical_area, :country) }
    let(:measure) { create(:measure) }

    before do
      allow(Rails.cache).to receive(:fetch).and_call_original

      geographical_area.geographical_area_id = 'RO'
      geographical_area.save

      measure.goods_nomenclature_item_id = commodity.goods_nomenclature_item_id
      measure.goods_nomenclature_sid = commodity.goods_nomenclature_sid
      measure.geographical_area_sid = geographical_area.geographical_area_sid
      measure.geographical_area_id = geographical_area.geographical_area_id
      measure.save
    end

    it 'returns a correctly serialized hash' do
      expect(service.call.to_json).to match_json_expression pattern
    end

    context 'when the filter specifies a geographical area' do
      let(:filter_params) do
        ActionController::Parameters.new(
          geographical_area_id: geographical_area.reload.geographical_area_id,
        ).permit!
      end

      it 'uses a cache key with an area filter in it' do
        expected_key = "_commodity-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-#{geographical_area.geographical_area_id}"
        service.call
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
      end
    end

    context 'when the filter does not specify a geographical area' do
      let(:filter_params) { ActionController::Parameters.new.permit! }

      it 'uses a cache key with an area filter in it' do
        expected_key = "_commodity-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}"
        service.call
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
      end
    end
  end
end
