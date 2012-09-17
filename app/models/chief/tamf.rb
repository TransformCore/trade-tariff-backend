module Chief
  class Tamf < Sequel::Model
    # TODO missing order on audited tsmp
    set_dataset db[:chief_tamf].
                order(:msrgp_code.asc).
                order_more(:msr_type.asc).
                order_more(:tty_code.asc).
                order_more(:fe_tsmp.desc)

    set_primary_key [:msrgp_code, :msr_type, :tty_code, :cngp_code, :cntry_orig, :fe_tsmp]

    one_to_many :measure_type_conds, key: [:measure_group_code, :measure_type],
                                     primary_key: [:msrgp_code, :msr_type],
                                     class_name: 'Chief::MeasureTypeCond'


    one_to_one :measure_type_adco, key: [:measure_group_code, :measure_type, :tax_type_code],
                                   primary_key: [:msrgp_code, :msr_type, :tty_code],
                                   class_name: 'Chief::MeasureTypeAdco'

    one_to_one :duty_expression, key: [:adval1_rate, :adval2_rate, :spfc1_rate, :spfc2_rate],
                                 primary_key: [:adval1_rate_key, :adval2_rate_key, :spfc1_rate_key, :spfc2_rate_key],
                                 class_name: 'Chief::DutyExpression'

    def adval1_rate_key; adval1_rate.present?; end
    def adval2_rate_key; adval2_rate.present?; end
    def spfc1_rate_key; spfc1_rate.present?; end
    def spfc2_rate_key; spfc2_rate.present?; end

    dataset_module do
      def untransformed
        filter(transformed: false)
      end
    end

    def measurement_unit(cmpd_uoq, uoq)
      if cmpd_uoq.present?
        Chief::MeasurementUnit.where(spfc_cmpd_uoq: cmpd_uoq,
                                     spfc_uoq: uoq)
      elsif uoq.present?
        Chief::MeasurementUnit.where(spfc_uoq: uoq)
      end
    end

    def measure_components
      return [] if duty_expression(true).blank?

      components = []

      if duty_expression.duty_expression_id_spfc1.present?
        measure_component = MeasureComponent.new do |mc|
          mc.duty_amount = spfc1_rate
          mc.duty_expression_id = duty_expression.duty_expression_id_spfc1
          mc.monetary_unit_code = duty_expression.monetary_unit_code_spfc1
        end
        if measure_component.monetary_unit_code.present?
          m_unit = measurement_unit(spfc1_cmpd_uoq, spfc1_uoq)
          measure_component.measurement_unit_code = m_unit.measurem_unit_cd if m_unit
          measure_component.measurement_unit_qualifier_code = m_unit.measurem_unit_qual_cd if m_unit
        end

        components << measure_component
      end

      if duty_expression.duty_expression_id_spfc2.present?
        measure_component = MeasureComponent.new do |mc|
          mc.duty_amount = spfc2_rate
          mc.duty_expression_id = duty_expression.duty_expression_id_spfc2
          mc.monetary_unit_code = duty_expression.monetary_unit_code_spfc2
        end
        # TODO, why?
        #     if (measurementUnitMapping == null && (tamfVO.getSpecific2UnitOfQuantity() != null || tamfVO.getSpecific1CompoundUnitOfQuantity() != null)) {
        #         throw new TariffSystemException(this.getClass().getName() + ".getMeasureComponentMap: found no measurement unit for "
        #                 + tamfVO.getSpecific1CompoundUnitOfQuantity()
        #                 + ", "
        #                 + tamfVO.getSpecific2UnitOfQuantity());
        #     }
        if measure_component.monetary_unit_code.present?
          m_unit = measurement_unit(spfc1_cmpd_uoq, spfc2_uoq)
          measure_component.measurement_unit_code = m_unit.measurem_unit_cd if m_unit
          measure_component.measurement_unit_qualifier_code = m_unit.measurem_unit_qual_cd if m_unit
        end

        components << measure_component
      end

      if duty_expression.duty_expression_id_adval1.present?
        measure_component = MeasureComponent.new do |mc|
          mc.duty_amount = adval1_rate
          mc.duty_expression_id = duty_expression.duty_expression_id_adval1
        end

        components << measure_component
      end

      if duty_expression.duty_expression_id_adval2.present?
        measure_component = MeasureComponent.new do |mc|
          mc.duty_amount = adval2_rate
          mc.duty_expression_id = duty_expression.duty_expression_id_adval2
        end

        components << measure_component
      end

      components
    end
  end
end
