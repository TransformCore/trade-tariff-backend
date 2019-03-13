require 'csv'

module Api
  module V1
    class CommoditiesController < ApiController
      before_action :find_commodity, only: [:show, :changes]

      def show
        @measures = MeasurePresenter.new(
          @commodity.measures_dataset.eager(
            { footnotes: :footnote_descriptions },
            { measure_type: :measure_type_description },
            { measure_components: [{ duty_expression: :duty_expression_description },
                                   { measurement_unit: :measurement_unit_description },
                                   :monetary_unit,
                                   :measurement_unit_qualifier] },
            { measure_conditions: [{ measure_action: :measure_action_description},
                                   { certificate: :certificate_descriptions },
                                   { certificate_type: :certificate_type_description },
                                   { measurement_unit: :measurement_unit_description },
                                   :monetary_unit,
                                   :measurement_unit_qualifier,
                                   { measure_condition_code: :measure_condition_code_description },
                                   { measure_condition_components: [:measure_condition,
                                                                    :duty_expression,
                                                                    :measurement_unit,
                                                                    :monetary_unit,
                                                                    :measurement_unit_qualifier]
                                   }]
            },
            { quota_order_number: :quota_definition },
            { excluded_geographical_areas: :geographical_area_descriptions },
            { geographical_area: :geographical_area_descriptions },
            :additional_code,
            :full_temporary_stop_regulations,
            :measure_partial_temporary_stops
          ).order(
            Sequel.asc(:measures__national, nulls: :last), Sequel.asc(:measures__geographical_area_id)
          ).all, @commodity
        ).validate!

        @geographical_areas = GeographicalArea.actual.where("geographical_area_sid IN ?", @measures.map(&:geographical_area_sid)).
            eager(:geographical_area_descriptions, { contained_geographical_areas: :geographical_area_descriptions }).all

        @commodity_cache_key = "commodity-#{@commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}"
        respond_with @commodity
      end

      def changes
        key = "commodity-#{@commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}/changes"
        @changes = Rails.cache.fetch(key, expires_at: actual_date.end_of_day) do
          ChangeLog.new(@commodity.changes.where { |o|
            o.operation_date <= actual_date
          })
        end

        render 'api/v1/changes/changes'
      end

      def goods_nomenclature
        TimeMachine.at(as_of_date) do
          @commodities = Commodity.actual.declarable.limit(10)
        end
        response.set_header('Date', as_of_date.httpdate )

        respond_to do |format|
          format.json {
            headers['Content-Type'] = 'application/json'
          }
          format.csv {
            filename = params[:filename]
            headers['Content-Type'] = 'text/csv'
            headers['Content-Disposition'] = "attachment; filename=#{filename}" unless filename.blank?
          }
        end
      end

      private

      def find_commodity
        @commodity = Commodity.actual
                              .declarable
                              .by_code(params[:id])
                              .take

        raise Sequel::RecordNotFound if @commodity.children.any?
        raise Sequel::RecordNotFound if @commodity.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end

      def as_of_date
        @as_of ||= begin
          Date.parse(params[:as_of])
        rescue StandardError
          Date.current
        end
      end
    end
  end
end
