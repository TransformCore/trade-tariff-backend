class MeasureCondition < Sequel::Model
  plugin :time_machine

  set_primary_key :measure_condition_sid

  one_to_one :measure, key: :measure_sid,
                       primary_key: :measure_sid

  one_to_one :measure_action, eager_loader_key: :action_code, dataset: -> {
    actual(MeasureAction)
                 .where(action_code: action_code)
  }, eager_loader: (proc do |eo|
    eo[:rows].each{|measure_condition| measure_condition.associations[:measure_action] = nil}

    id_map = eo[:id_map]

    MeasureAction.actual
                 .eager(:measure_action_description)
                 .where(action_code: id_map.keys)
                 .all do |measure_action|
      if measure_conditions = id_map[measure_action.action_code]
        measure_conditions.each do |measure_condition|
          measure_condition.associations[:measure_action] = measure_action
        end
      end
    end
  end)

  one_to_one :certificate, eager_loader_key: :certificate_type_code, dataset: -> {
    actual(Certificate).where(certificate_code: certificate_code,
                      certificate_type_code: certificate_type_code)
  }, eager_loader: (proc do |eo|
    eo[:rows].each{|measure_condition| measure_condition.associations[:certificate] = nil}

    id_map = eo[:id_map]

    Certificate.actual
               .eager(:certificate_description)
               .where(certificate_type_code: id_map.keys).all do |certificate|
      if measure_conditions = id_map[certificate.certificate_type_code]
        measure_conditions.each do |measure_condition|
          measure_condition.associations[:certificate] = certificate
        end
      end
    end
  end)

  one_to_one :measurement_unit, key: {}, primary_key: {}, eager_loader_key: :condition_measurement_unit_code, dataset: -> {
    actual(MeasurementUnit)
                  .where(measurement_unit_code: condition_measurement_unit_code)
  }, eager_loader: (proc do |eo|
    eo[:rows].each{|measure_condition| measure_condition.associations[:measurement_unit] = nil}

    id_map = eo[:id_map]

    MeasurementUnit.actual
                   .eager(:measurement_unit_description)
                   .where(measurement_unit_code: id_map.keys).all do |measurement_unit|
      if measure_conditions = id_map[mesurement_unit.measurement_unit_code]
        measure_conditions.each do |measure_condition|
          measure_condition.associations[:measurement_unit] = measurement_unit
        end
      end
    end
  end)

  one_to_one :monetary_unit, key: {}, primary_key: {}, eager_loader_key: :condition_monetary_unit_code, dataset: -> {
    actual(MonetaryUnit)
                  .where(monetary_unit_code: condition_monetary_unit_code)
  }, eager_loader: (proc do |eo|
    eo[:rows].each{|measure_condition| measure_condition.associations[:monetary_unit] = nil}

    id_map = eo[:id_map]

    MonetaryUnit.actual
                .eager(:monetary_unit_description)
                .where(monetary_unit_code: id_map.keys).all do |monetary_unit|
      if measure_conditions = id_map[monetary_unit.monetary_unit_code]
        measure_conditions.each do |measure_condition|
          measure_condition.associations[:monetary_unit] = monetary_unit
        end
      end
    end
  end)

  one_to_one :measurement_unit_qualifier, key: {}, primary_key: {}, eager_loader_key: :condition_measurement_unit_qualifier_code, dataset: -> {
    actual(MeasurementUnitQualifier)
                  .where(measurement_unit_qualifier_code: condition_measurement_unit_qualifier_code)
  }, eager_loader: (proc do |eo|
    eo[:rows].each{|measure_condition| measure_condition.associations[:measurement_unit_qualifier] = nil}

    id_map = eo[:id_map]

    MeasurementUnitQualifier.actual
                            .eager(:measurement_unit_qualifier_description)
                            .where(measurement_unit_qualifier_code: id_map.keys)
                            .all do |measurement_unit_qualifier|
      if measure_conditions = id_map[monetary_unit.monetary_unit_code]
        measure_conditions.each do |measure_condition|
          measure_condition.associations[:measurement_unit_qualifier] = measurement_unit_qualifier
        end
      end
    end
  end)

  one_to_one :measure_condition_code, key: {}, primary_key: {}, eager_loader_key: :condition_code, dataset: -> {
    actual(MeasureConditionCode)
                  .where(condition_code: condition_code)
  }, eager_loader: (proc do |eo|
    eo[:rows].each{|measure_condition| measure_condition.associations[:measure_condition_code] = nil}

    id_map = eo[:id_map]

    MeasureConditionCode.actual
                        .eager(:measure_condition_code_description)
                        .where(condition_code: id_map.keys)
                        .all do |measure_condition_code|
      if measure_conditions = id_map[measure_condition_code.condition_code]
        measure_conditions.each do |measure_condition|
          measure_condition.associations[:measure_condition_code] = measure_condition_code
        end
      end
    end
  end)

  one_to_many :measure_condition_components, key: :measure_condition_sid,
                                             primary_key: :measure_condition_sid


  def document_code
    "#{certificate_type_code}#{certificate_code}"
  end

  def requirement
    case requirement_type
    when :document
      {
        requirement: certificate.description
      }
    when :duty_expression
      {
        sequence_number: component_sequence_number,
        condition_amount: condition_duty_amount,
        monetary_unit: condition_monetary_unit_code,
        measurement_unit: measurement_unit.try(:description),
        measurement_unit_qualifier: measurement_unit_qualifier.try(:description)
      }
    end
  end

  def action
    measure_action.description
  end

  def condition
    measure_condition_code.description
  end

  def components
  end

  def requirement_type
    if certificate_code.present?
      :document
    elsif condition_duty_amount.present?
      :duty_expression
    end
  end

  def as_duty_expression
    DutyExpressionFormatter.format(duty_expression_id, duty_amount, monetary_unit,
                                   measurement_unit, measurement_unit_qualifier)
  end
end


