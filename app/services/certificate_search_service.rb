class CertificateSearchService
  attr_reader :code, :type, :description, :as_of
  attr_reader :current_page, :per_page, :pagination_record_count

  def initialize(attributes, current_page, per_page)
    @as_of = Certificate.point_in_time
    @query = [{
      bool: {
        should: [
          # actual date is either between item's (validity_start_date..validity_end_date)
          {
            bool: {
              must: [
                { range: { validity_start_date: { lte: as_of } } },
                { range: { validity_end_date: { gte: as_of } } }
              ]
            }
          },
          # or is greater than item's validity_start_date
          # and item has blank validity_end_date (is unbounded)
          {
            bool: {
              must: [
                { range: { validity_start_date: { lte: as_of } } },
                { bool: { must_not: { exists: { field: "validity_end_date" } } } }
              ]
            }
          },
          # or item has blank validity_start_date and validity_end_date
          {
            bool: {
              must: [
                { bool: { must_not: { exists: { field: "validity_start_date" } } } },
                { bool: { must_not: { exists: { field: "validity_end_date" } } } }
              ]
            }
          }
        ]
      }
    }]

    @query = []

    @code = attributes['code']
    @code = @code[1..-1] if @code&.length == 4
    @type = attributes['type']
    @description = attributes['description']
    @current_page = current_page
    @per_page = per_page
    @pagination_record_count = 0
  end

  def perform
    apply_code_filter if code.present?
    apply_type_filter if type.present?
    apply_description_filter if description.present?
    fetch
    filter_measures if @result.present?
    @result
  end

  private

  def fetch
    search_client = ::TradeTariffBackend.search_client
    index = ::Cache::CertificateIndex.new(TradeTariffBackend.search_namespace).name
    result = search_client.search index: index, body: { query: { constant_score: { filter: { bool: { must: @query } } } }, size: per_page, from: (current_page - 1) * per_page }
    @pagination_record_count = result&.hits&.total || 0
    @result = result&.hits&.hits&.map(&:_source)
  end

  def filter_measures
    @result.each do |certificate|
      certificate.measures.keep_if do |measure|
        measure.validity_start_date.to_date <= as_of &&
          (measure.validity_end_date.nil? || measure.validity_end_date.to_date >= as_of)
      end
      certificate.measure_ids = certificate.measures.map(&:id)
    end
  end

  def apply_code_filter
    @query.push({ bool: { must: { term: { certificate_code: code } } } })
  end

  def apply_type_filter
    @query.push({ bool: { must: { term: { certificate_type_code: type } } } })
  end

  def apply_description_filter
    @query.push({ multi_match: { query: description, fields: %w[description], operator: 'and' } })
  end
end