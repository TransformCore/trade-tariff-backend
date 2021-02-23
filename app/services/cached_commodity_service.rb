class CachedCommodityService
  DEFAULT_COMMODITY_INCLUDES = [
    'section',
    'chapter',
    'chapter.guides',
    'heading',
    'ancestors',
    'footnotes',
    'import_measures.duty_expression',
    'import_measures.measure_type',
    'import_measures.legal_acts',
    'import_measures.suspending_regulation',
    'import_measures.measure_conditions',
    'import_measures.measure_conditions.measure_condition_components',
    'import_measures.measure_components',
    'import_measures.national_measurement_units',
    'import_measures.geographical_area',
    'import_measures.geographical_area.contained_geographical_areas',
    'import_measures.excluded_geographical_areas',
    'import_measures.footnotes',
    'import_measures.additional_code',
    'import_measures.order_number',
    'import_measures.order_number.definition',
    'export_measures.duty_expression',
    'export_measures.measure_type',
    'export_measures.legal_acts',
    'export_measures.suspending_regulation',
    'export_measures.measure_conditions',
    'export_measures.measure_conditions.measure_condition_components',
    'export_measures.measure_components',
    'export_measures.national_measurement_units',
    'export_measures.geographical_area',
    'export_measures.geographical_area.contained_geographical_areas',
    'export_measures.excluded_geographical_areas',
    'export_measures.footnotes',
    'export_measures.additional_code',
    'export_measures.order_number',
    'export_measures.order_number.definition',
  ].freeze

  MEASURES_EAGER_LOAD_GRAPH = [
    { footnotes: :footnote_descriptions },
    { measure_type: :measure_type_description },
    {
      measure_components: [
        { duty_expression: :duty_expression_description },
        { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
        { measure: { measure_type: :measure_type_description } },
        :monetary_unit,
        :measurement_unit_qualifier,
      ],
    },
    {
      measure_conditions: [
        { measure_action: :measure_action_description },
        { certificate: :certificate_descriptions },
        { certificate_type: :certificate_type_description },
        { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
        :monetary_unit,
        :measurement_unit_qualifier,
        { measure_condition_code: :measure_condition_code_description },
        {
          measure_condition_components: [
            { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
            :measure_condition,
            :duty_expression,
            :monetary_unit,
            :measurement_unit_qualifier,
          ],
        },
      ],
    },
    { quota_order_number: { quota_definition: %i[quota_balance_events quota_suspension_periods quota_blocking_periods] } },
    { excluded_geographical_areas: :geographical_area_descriptions },
    { geographical_area: [:geographical_area_descriptions,
                          { contained_geographical_areas: :geographical_area_descriptions }] },
    { additional_code: :additional_code_descriptions },
    :footnotes,
    :base_regulation,
    :modification_regulation,
    :full_temporary_stop_regulations,
    :measure_partial_temporary_stops,
  ].freeze

  TTL = 24.hours

  def initialize(commodity, actual_date)
    @commodity = commodity
    @actual_date = actual_date
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: TTL) do
      Api::V2::Commodities::CommoditySerializer.new(presented_commodity, options).serializable_hash
    end
  end

  private

  attr_reader :commodity, :actual_date

  def presented_commodity
    Api::V2::Commodities::CommodityPresenter.new(commodity, presented_measures)
  end

  def presented_measures
    MeasurePresenter.new(measures, commodity).validate!
  end

  def options
    {
      is_collection: false,
      include: DEFAULT_COMMODITY_INCLUDES,
    }
  end

  def measures
    @commodity.measures_dataset.eager(*MEASURES_EAGER_LOAD_GRAPH).all
  end

  def cache_key
    "_commodity-#{commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}"
  end
end
